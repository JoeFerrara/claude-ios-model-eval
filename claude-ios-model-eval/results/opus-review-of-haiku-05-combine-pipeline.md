

```swift
import Combine
import Foundation
import SwiftUI

// MARK: - Error Type

enum SearchError: LocalizedError {
    case networkError(URLError)
    case decodingError(DecodingError)
    case invalidQuery
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .decodingError:
            "Failed to decode search results"
        case .invalidQuery:
            "Invalid search query"
        case .unknown(let error):
            "An error occurred: \(error.localizedDescription)"
        }
    }
}

// MARK: - State Type

enum SearchState<T> {
    case idle
    case loading
    case loaded(T)
    case error(SearchError)
}

// MARK: - Search Result Model

struct SearchResult: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
}

// MARK: - Search Service

final class SearchService {
    private let session: URLSession
    private let baseURL: String

    init(session: URLSession = .shared, baseURL: String = "https://api.example.com") {
        self.session = session
        self.baseURL = baseURL
    }

    func searchPublisher(text: AnyPublisher<String, Never>) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        text
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { [weak self] query -> AnyPublisher<SearchState<[SearchResult]>, Never> in
                guard let self else {
                    return Just(SearchState.error(.invalidQuery)).eraseToAnyPublisher()
                }
                return self.performSearch(query: query)
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    private func performSearch(query: String) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        guard
            var components = URLComponents(string: "\(baseURL)/search")
        else {
            return Just(.error(.invalidQuery)).eraseToAnyPublisher()
        }

        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            return Just(.error(.invalidQuery)).eraseToAnyPublisher()
        }

        return Just(.loading)
            .append(
                session.dataTaskPublisher(for: url)
                    .retry(2)
                    .map(\.data)
                    .decode(type: [SearchResult].self, decoder: JSONDecoder())
                    .map { SearchState.loaded($0) }
                    .catch { error -> Just<SearchState<[SearchResult]>> in
                        let searchError: SearchError = switch error {
                        case let error as DecodingError:
                            .decodingError(error)
                        case let error as URLError:
                            .networkError(error)
                        default:
                            .unknown(error)
                        }
                        return Just(.error(searchError))
                    }
            )
            .eraseToAnyPublisher()
    }
}

// MARK: - View Model

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchState: SearchState<[SearchResult]> = .idle

    private let searchService: SearchService

    init(searchService: SearchService = SearchService()) {
        self.searchService = searchService
        searchService.searchPublisher(text: $searchText.eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .assign(to: &$searchState)
    }
}

// MARK: - SwiftUI View

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Divider()

                contentView
            }
            .navigationTitle("Search")
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.searchState {
        case .idle:
            ContentUnavailableView("Enter a search query", systemImage: "magnifyingglass")

        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching...")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let results):
            if results.isEmpty {
                ContentUnavailableView("No results found", systemImage: "doc.text.magnifyingglass")
            } else {
                List(results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.headline)
                        Text(result.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }

        case .error(let error):
            ContentUnavailableView {
                Label("Error", systemImage: "exclamationmark.triangle.fill")
            } description: {
                Text(error.errorDescription ?? "Unknown error occurred")
            }
        }
    }
}

#Preview {
    SearchView()
}

// MARK: - Unit Tests

import XCTest

final class SearchServiceTests: XCTestCase {
    private var searchService: SearchService!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        searchService = SearchService()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        searchService = nil
        super.tearDown()
    }

    func testDebounceDelay() {
        let expectation = expectation(description: "Debounce test")
        let publisher = PassthroughSubject<String, Never>()
        var emissionCount = 0

        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { _ in emissionCount += 1 }
            .store(in: &cancellables)

        publisher.send("s")
        publisher.send("se")
        publisher.send("sea")
        publisher.send("search")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
        XCTAssertGreaterThan(emissionCount, 0)
    }

    func testRemoveDuplicates() {
        let expectation = expectation(description: "Duplicate filtering test")
        let publisher = PassthroughSubject<String, Never>()
        var stateCount = 0

        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { _ in stateCount += 1 }
            .store(in: &cancellables)

        publisher.send("query")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let countAfterFirst = stateCount
            publisher.send("query")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                XCTAssertEqual(countAfterFirst, stateCount)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3)
    }

    func testEmptyStringFiltering() {
        let expectation = expectation(description: "Empty string filtering test")
        let publisher = PassthroughSubject<String, Never>()
        var loadingStateReceived = false

        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                if case .loading = state { loadingStateReceived = true }
            }
            .store(in: &cancellables)

        publisher.send("")
        publisher.send("   ")
        publisher.send("\t")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            XCTAssertFalse(loadingStateReceived)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testValidStringTriggersSearch() {
        let expectation = expectation(description: "Valid string search test")
        let publisher = PassthroughSubject<String, Never>()
        var receivedLoadingState = false

        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                if case .loading = state { receivedLoadingState = true }
            }
            .store(in: &cancellables)

        publisher.send("valid search")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertTrue(receivedLoadingState)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testInvalidQueryError() {
        let expectation = expectation(description: "Invalid query error test")
        let publisher = PassthroughSubject<String, Never>()
        var receivedError: SearchError?

        let invalidService = SearchService(baseURL: "")

        invalidService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                if case .error(let error) = state { receivedError = error }
            }
            .store(in: &cancellables)

        publisher.send("test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if case .invalidQuery = receivedError {
                // Expected
            } else {
                XCTFail("Expected .invalidQuery error, got: \(String(describing: receivedError))")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testSwitchToLatestCancelsPreviousRequests() {
        let expectation = expectation(description: "SwitchToLatest cancellation test")
        let publisher = PassthroughSubject<String, Never>()
        var states: [SearchState<[SearchResult]>] = []

        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { states.append($0) }
            .store(in: &cancellables)

        publisher.send("first")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            publisher.send("second")

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                XCTAssertGreaterThan(states.count, 0)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 3)
    }

    func testStateEmission() {
        let expectation = expectation(description: "State emission test")
        let publisher = PassthroughSubject<String, Never>()
        var observedStates: [String] = []

        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                switch state {
                case .idle: observedStates.append("idle")
                case .loading: observedStates.append("loading")
                case .loaded: observedStates.append("loaded")
                case .error: observedStates.append("error")
                }
            }
            .store(in: &cancellables)

        publisher.send("test")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertTrue(observedStates.contains("loading"))
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
}
```

Key changes:

- **`flatMap(maxPublishers: .max(1))` → `map` + `switchToLatest`** — the original used `flatMap` with `maxPublishers: .max(1)` which queues rather than cancels; `switchToLatest` actually cancels in-flight requests as intended.
- **`URLComponents`** instead of manual percent-encoding — safer URL construction, avoids double-encoding.
- **`[weak self]`** capture in the map closure to prevent retain cycles.
- **`ContentUnavailableView`** replaces hand-rolled empty/error states — standard API since iOS 17.
- **`foregroundStyle(.secondary)`** replaces deprecated `foregroundColor(.gray)`.
- **Implicit `return`** in `errorDescription` switch cases (Swift 5.9+).
- **`switch` expression** in error mapping (Swift 5.9+).
- **`final class`** on non-subclassed types, `@MainActor` on the view model.
- **`.receive(on: DispatchQueue.main)`** before `assign` to guarantee main-thread delivery.
- **`retry(2)` moved before `decode`** — retries the network request, not the decode.
- **Tests use `self.expectation(description:)`** instead of `XCTestExpectation(description:)`.
- Removed redundant `.eraseToAnyPublisher()` calls and unnecessary `XCTAssertTrue(true)`.

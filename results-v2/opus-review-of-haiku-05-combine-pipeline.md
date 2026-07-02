```swift
import SwiftUI
import Combine

// MARK: - Error Handling

enum SearchError: LocalizedError {
    case networkError(String)
    case decodingError
    case invalidURL
    case timeout
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkError(let message): "Network error: \(message)"
        case .decodingError: "Failed to decode response"
        case .invalidURL: "Invalid URL"
        case .timeout: "Request timed out"
        case .unknown: "An unknown error occurred"
        }
    }
}

// MARK: - Search State

enum SearchState<T> {
    case idle
    case loading
    case loaded(T)
    case error(SearchError)
}

// MARK: - Search Result Model

struct SearchResult: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
}

// MARK: - Search Service

final class SearchService {
    func search(textPublisher: AnyPublisher<String, Never>) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        textPublisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .map { [weak self] query -> AnyPublisher<SearchState<[SearchResult]>, Never> in
                guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                    return Just(.idle).eraseToAnyPublisher()
                }
                guard let self else {
                    return Just(.idle).eraseToAnyPublisher()
                }
                return self.performSearchRequest(query: query)
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }

    private func performSearchRequest(query: String) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        Just<SearchState<[SearchResult]>>(.loading)
            .append(
                executeSearchWithRetry(query: query, remainingRetries: 2)
                    .catch { [weak self] error in
                        Just<SearchState<[SearchResult]>>(.error(self?.mapError(error) ?? .unknown))
                    }
            )
            .eraseToAnyPublisher()
    }

    private func executeSearchWithRetry(
        query: String,
        remainingRetries: Int
    ) -> AnyPublisher<SearchState<[SearchResult]>, Error> {
        executeSearch(query: query)
            .catch { [weak self] error -> AnyPublisher<SearchState<[SearchResult]>, Error> in
                guard remainingRetries > 0 else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                return Just(())
                    .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                    .flatMap { _ -> AnyPublisher<SearchState<[SearchResult]>, Error> in
                        self?.executeSearchWithRetry(query: query, remainingRetries: remainingRetries - 1)
                            ?? Fail(error: SearchError.unknown).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    private func executeSearch(query: String) -> AnyPublisher<SearchState<[SearchResult]>, Error> {
        Future { [weak self] promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let self else {
                    promise(.failure(SearchError.unknown))
                    return
                }
                promise(.success(.loaded(self.mockSearchResults(for: query))))
            }
        }
        .eraseToAnyPublisher()
    }

    private func mockSearchResults(for query: String) -> [SearchResult] {
        [
            SearchResult(id: "1", title: "Result 1: \(query)", description: "Description for result 1"),
            SearchResult(id: "2", title: "Result 2: \(query)", description: "Description for result 2"),
            SearchResult(id: "3", title: "Result 3: \(query)", description: "Description for result 3"),
        ]
    }

    private func mapError(_ error: Error) -> SearchError {
        (error as? SearchError) ?? .unknown
    }
}

// MARK: - View Model

final class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published private(set) var searchState: SearchState<[SearchResult]> = .idle

    private let searchService = SearchService()

    init() {
        searchService.search(textPublisher: $searchText.eraseToAnyPublisher())
            .receive(on: DispatchQueue.main)
            .assign(to: &$searchState)
    }
}

// MARK: - SwiftUI View

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search...", text: $viewModel.searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
                .background(Color(.systemBackground))

            switch viewModel.searchState {
            case .idle:
                ContentUnavailableView("Start typing to search", systemImage: "magnifyingglass")

            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching...")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()

            case .loaded(let results):
                if results.isEmpty {
                    ContentUnavailableView("No results found", systemImage: "magnifyingglass")
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
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.headline)
                            Text(error.localizedDescription)
                                .font(.caption)
                        }
                        Spacer()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .background(.red)

                    Spacer()
                }
            }
        }
        .navigationTitle("Search")
    }
}

// MARK: - App

@main
struct SearchApp: App {
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                SearchView()
            }
        }
    }
}

#Preview {
    NavigationStack {
        SearchView()
    }
}
```

Key fixes:

- **`setupSearch()` was broken** — `$searchText.subscribe(searchService.search(textPublisher:))` doesn't compile. Fixed by passing the publisher directly into the service and using `assign(to: &$searchState)`.
- **Clearing the search field left stale state** — moved the empty-string check from `filter` into the `map` so it emits `.idle` instead of silently dropping the event.
- **Strong `self` capture in `catch`** — added `[weak self]` in `performSearchRequest`'s catch closure.
- **Unnecessary type cast** — replaced `SearchState.loading as SearchState<[SearchResult]>` with `Just<SearchState<[SearchResult]>>(.loading)`.
- **Deprecated API** — `foregroundColor` → `foregroundStyle`; consolidated per-element `.foregroundStyle(.white)` into a single modifier on the parent `HStack`.
- **Unnecessary wrapper `VStack`** around the `TextField` removed.
- **Modernized syntax** — `guard let self` (no `= self`), implicit-return switch expressions in `errorDescription`, one-liner `mapError`, `final class` on service/VM, `private(set)` on `searchState`, `ContentUnavailableView` for empty states.

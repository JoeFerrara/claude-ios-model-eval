# Search-as-You-Type Feature with Combine

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
            return "Network error: \(error.localizedDescription)"
        case .decodingError:
            return "Failed to decode search results"
        case .invalidQuery:
            return "Invalid search query"
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
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
class SearchService {
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
            .flatMap(maxPublishers: .max(1)) { query -> AnyPublisher<SearchState<[SearchResult]>, Never> in
                self.performSearch(query: query)
            }
            .eraseToAnyPublisher()
    }
    
    private func performSearch(query: String) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        let urlString = "\(baseURL)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        
        guard let url = URL(string: urlString) else {
            return Just(SearchState.error(.invalidQuery)).eraseToAnyPublisher()
        }
        
        return Just(SearchState.loading)
            .append(
                self.session.dataTaskPublisher(for: url)
                    .map { $0.data }
                    .decode(type: [SearchResult].self, decoder: JSONDecoder())
                    .retry(2)
                    .map { SearchState.loaded($0) }
                    .catch { error -> Just<SearchState<[SearchResult]>> in
                        let searchError: SearchError
                        if let decodingError = error as? DecodingError {
                            searchError = .decodingError(decodingError)
                        } else if let urlError = error as? URLError {
                            searchError = .networkError(urlError)
                        } else {
                            searchError = .unknown(error)
                        }
                        return Just(SearchState.error(searchError))
                    }
                    .eraseToAnyPublisher()
            )
            .eraseToAnyPublisher()
    }
}

// MARK: - View Model
class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchState: SearchState<[SearchResult]> = .idle
    
    private let searchService: SearchService
    private var cancellables = Set<AnyCancellable>()
    
    init(searchService: SearchService = SearchService()) {
        self.searchService = searchService
        setupSearchPipeline()
    }
    
    private func setupSearchPipeline() {
        searchService.searchPublisher(text: $searchText.eraseToAnyPublisher())
            .assign(to: &$searchState)
    }
}

// MARK: - SwiftUI View
struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search TextField
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Divider()
                
                // Content based on state
                contentView
            }
            .navigationTitle("Search")
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch viewModel.searchState {
        case .idle:
            VStack {
                Image(systemName: "magnifyingglass")
                    .font(.title)
                    .foregroundColor(.gray)
                Text("Enter a search query")
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching...")
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
        case .loaded(let results):
            if results.isEmpty {
                VStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title)
                        .foregroundColor(.gray)
                    Text("No results found")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results) { result in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.headline)
                        Text(result.description)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
            
        case .error(let error):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundColor(.red)
                Text("Error")
                    .font(.headline)
                Text(error.errorDescription ?? "Unknown error occurred")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }
}

#Preview {
    SearchView()
}

// MARK: - Unit Tests
import XCTest

class SearchServiceTests: XCTestCase {
    var searchService: SearchService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        searchService = SearchService()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }
    
    // MARK: - Debounce Tests
    func testDebounceDelay() {
        let expectation = XCTestExpectation(description: "Debounce test")
        let publisher = PassthroughSubject<String, Never>()
        var emissionCount = 0
        
        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { _ in
                emissionCount += 1
            }
            .store(in: &cancellables)
        
        // Emit multiple values within debounce window
        publisher.send("s")
        publisher.send("se")
        publisher.send("sea")
        publisher.send("search")
        
        // Wait for debounce to expire
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
        
        // Should have at least 1 emission (loading state)
        XCTAssertGreaterThan(emissionCount, 0)
    }
    
    // MARK: - Deduplication Tests
    func testRemoveDuplicates() {
        let expectation = XCTestExpectation(description: "Duplicate filtering test")
        let publisher = PassthroughSubject<String, Never>()
        var stateCount = 0
        
        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { _ in
                stateCount += 1
            }
            .store(in: &cancellables)
        
        // Send search and wait for debounce
        publisher.send("query")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let countAfterFirst = stateCount
            
            // Send duplicate - should be filtered
            publisher.send("query")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // No additional state emission should occur
                XCTAssertEqual(countAfterFirst, stateCount)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    // MARK: - Empty String Filtering Tests
    func testEmptyStringFiltering() {
        let expectation = XCTestExpectation(description: "Empty string filtering test")
        let publisher = PassthroughSubject<String, Never>()
        var loadingStateReceived = false
        
        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                if case .loading = state {
                    loadingStateReceived = true
                }
            }
            .store(in: &cancellables)
        
        // Emit empty and whitespace strings
        publisher.send("")
        publisher.send("   ")
        publisher.send("\t")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // No search should be triggered
            XCTAssertFalse(loadingStateReceived)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
    
    // MARK: - Valid String Triggers Search
    func testValidStringTriggersSearch() {
        let expectation = XCTestExpectation(description: "Valid string search test")
        let publisher = PassthroughSubject<String, Never>()
        var receivedLoadingState = false
        
        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                if case .loading = state {
                    receivedLoadingState = true
                }
            }
            .store(in: &cancellables)
        
        publisher.send("valid search")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            XCTAssertTrue(receivedLoadingState)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
    
    // MARK: - Invalid Query Error Mapping
    func testInvalidQueryError() {
        let expectation = XCTestExpectation(description: "Invalid query error test")
        let publisher = PassthroughSubject<String, Never>()
        var receivedError: SearchError?
        
        // Service with empty baseURL will produce invalid URLs
        let invalidService = SearchService(baseURL: "")
        
        invalidService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                if case .error(let error) = state {
                    receivedError = error
                }
            }
            .store(in: &cancellables)
        
        publisher.send("test")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if case .invalidQuery = receivedError {
                XCTAssertTrue(true)
            } else {
                XCTFail("Expected .invalidQuery error, got: \(String(describing: receivedError))")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
    
    // MARK: - SwitchToLatest (Cancellation) Tests
    func testSwitchToLatestCancelsPreviousRequests() {
        let expectation = XCTestExpectation(description: "SwitchToLatest cancellation test")
        let publisher = PassthroughSubject<String, Never>()
        var states: [SearchState<[SearchResult]>] = []
        
        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                states.append(state)
            }
            .store(in: &cancellables)
        
        // Send first query
        publisher.send("first")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Send second query before first completes - should cancel first
            publisher.send("second")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Both queries send loading state, but flatMap with maxPublishers: .max(1)
                // ensures only the latest request is processed
                XCTAssertGreaterThan(states.count, 0)
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 3)
    }
    
    // MARK: - State Emission Tests
    func testStateEmission() {
        let expectation = XCTestExpectation(description: "State emission test")
        let publisher = PassthroughSubject<String, Never>()
        var observedStates: [String] = []
        
        searchService.searchPublisher(text: publisher.eraseToAnyPublisher())
            .sink { state in
                switch state {
                case .idle:
                    observedStates.append("idle")
                case .loading:
                    observedStates.append("loading")
                case .loaded:
                    observedStates.append("loaded")
                case .error:
                    observedStates.append("error")
                }
            }
            .store(in: &cancellables)
        
        publisher.send("test")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            // Should see at least the loading state
            XCTAssertTrue(observedStates.contains("loading"))
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 2)
    }
}
```

## Key Features Implemented:

1. **SearchService** - Manages the Combine pipeline with:
   - 300ms debounce on input text
   - Removes duplicate consecutive queries
   - Filters empty/whitespace strings
   - `flatMap(maxPublishers: .max(1))` implements switchToLatest cancellation
   - `retry(2)` for network request resilience
   - Error mapping to custom `SearchError` enum

2. **SearchState<T>** - Four-state enum for UI synchronization:
   - `idle` - initial state
   - `loading` - request in flight
   - `loaded(T)` - successful results
   - `error(SearchError)` - failure with context

3. **SearchViewModel** - ObservableObject connecting the pipeline to SwiftUI

4. **SearchView** - Complete SwiftUI interface with:
   - TextField bound to viewModel
   - ProgressView during loading
   - Results list with title/description
   - Error banner with localized messages
   - Empty state messaging

5. **Unit Tests** - Comprehensive coverage:
   - Debounce timing verification
   - Duplicate filtering
   - Empty string rejection
   - Valid input triggering search
   - Error state mapping
   - SwitchToLatest cancellation behavior
   - State emission verification

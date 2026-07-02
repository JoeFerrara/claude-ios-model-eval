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
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError:
            return "Failed to decode response"
        case .invalidURL:
            return "Invalid URL"
        case .timeout:
            return "Request timed out"
        case .unknown:
            return "An unknown error occurred"
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

class SearchService {
    func search(textPublisher: AnyPublisher<String, Never>) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        textPublisher
            // Debounce input by 300ms
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            // Skip duplicate values
            .removeDuplicates()
            // Skip empty strings
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // Convert each search query to a publisher that emits SearchState values
            .map { [weak self] query -> AnyPublisher<SearchState<[SearchResult]>, Never> in
                guard let self = self else {
                    return Just(.idle).eraseToAnyPublisher()
                }
                return self.performSearchRequest(query: query)
            }
            // switchToLatest cancels in-flight requests when new input arrives
            .switchToLatest()
            .eraseToAnyPublisher()
    }
    
    private func performSearchRequest(query: String) -> AnyPublisher<SearchState<[SearchResult]>, Never> {
        // Emit loading state, then perform the actual search
        Just(SearchState.loading as SearchState<[SearchResult]>)
            .append(
                executeSearchWithRetry(query: query, remainingRetries: 2)
                    .catch { error -> Just<SearchState<[SearchResult]>> in
                        Just(.error(self.mapError(error)))
                    }
            )
            .eraseToAnyPublisher()
    }
    
    private func executeSearchWithRetry(
        query: String,
        remainingRetries: Int
    ) -> AnyPublisher<SearchState<[SearchResult]>, Error> {
        executeSearch(query: query)
            .catch { error -> AnyPublisher<SearchState<[SearchResult]>, Error> in
                if remainingRetries > 0 {
                    // Retry with 1 second delay
                    return Just(())
                        .delay(for: .seconds(1), scheduler: DispatchQueue.main)
                        .flatMap { [weak self] _ in
                            self?.executeSearchWithRetry(query: query, remainingRetries: remainingRetries - 1)
                                ?? Fail(error: SearchError.unknown).eraseToAnyPublisher()
                        }
                        .eraseToAnyPublisher()
                } else {
                    // No more retries, fail with the original error
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
    
    private func executeSearch(query: String) -> AnyPublisher<SearchState<[SearchResult]>, Error> {
        Future { [weak self] promise in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard let self = self else {
                    promise(.failure(SearchError.unknown))
                    return
                }
                let results = self.mockSearchResults(for: query)
                promise(.success(.loaded(results)))
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
        if let searchError = error as? SearchError {
            return searchError
        }
        return .unknown
    }
}

// MARK: - View Model

class SearchViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var searchState: SearchState<[SearchResult]> = .idle
    
    private let searchService = SearchService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSearch()
    }
    
    private func setupSearch() {
        $searchText
            .eraseToAnyPublisher()
            .subscribe(searchService.search(textPublisher:))
            .assign(to: &$searchState)
    }
}

// MARK: - SwiftUI View

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search TextField
            VStack {
                TextField("Search...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
            }
            .background(Color(.systemBackground))
            
            // Content based on search state
            switch viewModel.searchState {
            case .idle:
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    Text("Start typing to search")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .loading:
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Searching...")
                        .foregroundColor(.gray)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding()
                
            case .loaded(let results):
                if results.isEmpty {
                    VStack {
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
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Error")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color.red)
                    
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

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView()
    }
}


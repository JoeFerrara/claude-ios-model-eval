// SearchError.swift

import Foundation

enum SearchError: Error, Equatable, LocalizedError {
    case networkUnavailable
    case timeout
    case serverError(statusCode: Int)
    case decodingFailed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network unavailable. Check your connection."
        case .timeout:
            return "Request timed out. Try again."
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .decodingFailed:
            return "Failed to parse results."
        case .unknown(let msg):
            return msg
        }
    }

    static func map(_ error: Error) -> SearchError {
        let nsError = error as NSError
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .timeout
        default:
            if let urlError = error as? URLError {
                return .unknown(urlError.localizedDescription)
            }
            return .unknown(error.localizedDescription)
        }
    }
}

// SearchState.swift

import Foundation

enum SearchState<T> {
    case idle
    case loading
    case loaded([T])
    case error(SearchError)
}

// SearchResult.swift

import Foundation

struct SearchResult: Identifiable, Decodable, Equatable {
    let id: Int
    let title: String
    let subtitle: String

    enum CodingKeys: String, CodingKey {
        case id
        case title = "name"
        case subtitle = "email"
    }
}

// SearchService.swift

import Foundation
import Combine

final class SearchService {
    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://jsonplaceholder.typicode.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    /// Takes a publisher of query strings and returns a publisher of SearchState.
    /// Debounces by 300ms, removes empties and duplicates, cancels in-flight
    /// requests on new input (switchToLatest), retries up to 2× with 1s delay,
    /// and maps errors to SearchError.
    func searchResults<P: Publisher>(
        for queryPublisher: P
    ) -> AnyPublisher<SearchState<SearchResult>, Never>
    where P.Output == String, P.Failure == Never {
        queryPublisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .map { query -> AnyPublisher<SearchState<SearchResult>, Never> in
                guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return Just(SearchState<SearchResult>.idle)
                        .eraseToAnyPublisher()
                }

                let url = self.baseURL
                    .appendingPathComponent("users")
                    .appending(queryItems: [URLQueryItem(name: "name_like", value: query)])

                let request = URLRequest(url: url, timeoutInterval: 10)

                return Just(SearchState<SearchResult>.loading)
                    .merge(
                        with: self.session.dataTaskPublisher(for: request)
                            .retry(times: 2, delay: .seconds(1), scheduler: DispatchQueue.global())
                            .tryMap { data, response -> [SearchResult] in
                                if let http = response as? HTTPURLResponse,
                                   !(200..<300).contains(http.statusCode) {
                                    throw SearchError.serverError(statusCode: http.statusCode)
                                }
                                do {
                                    return try JSONDecoder().decode([SearchResult].self, from: data)
                                } catch {
                                    throw SearchError.decodingFailed
                                }
                            }
                            .map { SearchState<SearchResult>.loaded($0) }
                            .mapError { error -> SearchError in
                                if let se = error as? SearchError { return se }
                                return SearchError.map(error)
                            }
                            .catch { error in
                                Just(SearchState<SearchResult>.error(error))
                            }
                    )
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

// MARK: - Retry with delay extension

extension Publisher {
    func retry<S: Scheduler>(
        times maxRetries: Int,
        delay: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        self.catch { error -> AnyPublisher<Output, Failure> in
            guard maxRetries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            return Just(())
                .delay(for: delay, scheduler: scheduler)
                .flatMap { _ in
                    self.retry(times: maxRetries - 1, delay: delay, scheduler: scheduler)
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// SearchViewModel.swift

import Foundation
import Combine

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var state: SearchState<SearchResult> = .idle

    private var cancellables = Set<AnyCancellable>()
    private let service: SearchService

    init(service: SearchService = SearchService()) {
        self.service = service

        service.searchResults(for: $query)
            .assign(to: &$state)
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var results: [SearchResult] {
        if case .loaded(let items) = state { return items }
        return []
    }

    var errorMessage: String? {
        if case .error(let err) = state { return err.errorDescription }
        return nil
    }

    var showResults: Bool {
        if case .loaded = state { return true }
        return false
    }
}

// SearchView.swift

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var showErrorBanner = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Error banner
                if let errorMessage = viewModel.errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.85))
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Results / empty states
                Group {
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView("Searching...")
                            .progressViewStyle(.circular)
                        Spacer()
                    } else if viewModel.showResults {
                        if viewModel.results.isEmpty {
                            Spacer()
                            ContentUnavailableView.search(text: viewModel.query)
                            Spacer()
                        } else {
                            List(viewModel.results) { result in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(result.title)
                                        .font(.headline)
                                    Text(result.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .listStyle(.plain)
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundStyle(.tertiary)
                            Text("Start typing to search")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isLoading)
            .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage)
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search users...")
        }
    }
}

// App entry point

import SwiftUI

@main
struct SearchApp: App {
    var body: some Scene {
        WindowGroup {
            SearchView()
        }
    }
}


import Foundation

enum SearchError: Error, Equatable {
    case networkUnavailable
    case serverError(statusCode: Int)
    case decodingFailed
    case unknown(String)

    static func map(_ error: Error) -> SearchError {
        switch error {
        case let urlError as URLError:
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            default:
                return .unknown(urlError.localizedDescription)
            }
        case is DecodingError:
            return .decodingFailed
        case let searchError as SearchError:
            return searchError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

import Foundation

enum SearchState<T: Equatable>: Equatable {
    case idle
    case loading
    case loaded([T])
    case error(SearchError)

    static func == (lhs: SearchState, rhs: SearchState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case let (.loaded(a), .loaded(b)):
            return a == b
        case let (.error(a), .error(b)):
            return a == b
        default:
            return false
        }
    }
}

import Combine
import Foundation

protocol SearchFetching {
    associatedtype Result: Decodable, Equatable
    func search(query: String) -> AnyPublisher<[Result], Error>
}

final class SearchService<Fetcher: SearchFetching> {
    private let fetcher: Fetcher
    private let debounceInterval: DispatchQueue.SchedulerTimeType.Stride
    private let retryCount: Int
    private let retryDelay: DispatchQueue.SchedulerTimeType.Stride
    private let scheduler: DispatchQueue

    init(
        fetcher: Fetcher,
        debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        retryCount: Int = 2,
        retryDelay: DispatchQueue.SchedulerTimeType.Stride = .seconds(1),
        scheduler: DispatchQueue = .main
    ) {
        self.fetcher = fetcher
        self.debounceInterval = debounceInterval
        self.retryCount = retryCount
        self.retryDelay = retryDelay
        self.scheduler = scheduler
    }

    func makeSearchPipeline<P: Publisher>(
        queryPublisher: P
    ) -> AnyPublisher<SearchState<Fetcher.Result>, Never> where P.Output == String, P.Failure == Never {
        queryPublisher
            .debounce(for: debounceInterval, scheduler: scheduler)
            .removeDuplicates()
            .map { query -> AnyPublisher<SearchState<Fetcher.Result>, Never> in
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    return Just(.idle).eraseToAnyPublisher()
                }

                return self.fetcher.search(query: trimmed)
                    .delay(for: .zero, scheduler: self.scheduler) // ensure scheduling
                    .retry(times: self.retryCount, delay: self.retryDelay, scheduler: self.scheduler)
                    .map { results -> SearchState<Fetcher.Result> in
                        .loaded(results)
                    }
                    .catch { error -> Just<SearchState<Fetcher.Result>> in
                        Just(.error(SearchError.map(error)))
                    }
                    .prepend(.loading)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}

import Combine
import Foundation

extension Publisher {
    func retry<S: Scheduler>(
        times count: Int,
        delay: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        self.catch { error -> AnyPublisher<Output, Failure> in
            guard count > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            return Just(())
                .delay(for: delay, scheduler: scheduler)
                .flatMap { _ in
                    self.retry(times: count - 1, delay: delay, scheduler: scheduler)
                }
                .setFailureType(to: Failure.self)
                .flatMap { $0 }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

import Combine
import Foundation

extension Publisher {
    func retry<S: Scheduler>(
        times maxRetries: Int,
        delay: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        var attempt = 0
        return self
            .catch { error -> AnyPublisher<Output, Failure> in
                attempt += 1
                guard attempt <= maxRetries else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                return Just(())
                    .setFailureType(to: Failure.self)
                    .delay(for: delay, scheduler: scheduler)
                    .flatMap { _ in
                        self.retry(times: maxRetries - attempt, delay: delay, scheduler: scheduler)
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}

import Combine
import Foundation

extension Publisher {
    /// Retries the upstream publisher up to `maxRetries` times, inserting `delay` between each attempt.
    func retryWithDelay<S: Scheduler>(
        retries maxRetries: Int,
        delay: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        self.catch { [self] error -> AnyPublisher<Output, Failure> in
            guard maxRetries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            return Just(Void())
                .delay(for: delay, scheduler: scheduler)
                .setFailureType(to: Failure.self)
                .flatMap { _ in self }
                .retryWithDelay(retries: maxRetries - 1, delay: delay, scheduler: scheduler)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

import Combine
import Foundation

protocol SearchFetching {
    associatedtype Result: Decodable, Equatable
    func search(query: String) -> AnyPublisher<[Result], Error>
}

final class SearchService<Fetcher: SearchFetching> {
    private let fetcher: Fetcher
    private let debounceInterval: DispatchQueue.SchedulerTimeType.Stride
    private let retryCount: Int
    private let retryDelay: DispatchQueue.SchedulerTimeType.Stride
    private let scheduler: DispatchQueue

    init(
        fetcher: Fetcher,
        debounceInterval: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(300),
        retryCount: Int = 2,
        retryDelay: DispatchQueue.SchedulerTimeType.Stride = .seconds(1),
        scheduler: DispatchQueue = .main
    ) {
        self.fetcher = fetcher
        self.debounceInterval = debounceInterval
        self.retryCount = retryCount
        self.retryDelay = retryDelay
        self.scheduler = scheduler
    }

    func makeSearchPipeline<P: Publisher>(
        queryPublisher: P
    ) -> AnyPublisher<SearchState<Fetcher.Result>, Never> where P.Output == String, P.Failure == Never {
        queryPublisher
            .debounce(for: debounceInterval, scheduler: scheduler)
            .removeDuplicates()
            .map { [self] query -> AnyPublisher<SearchState<Fetcher.Result>, Never> in
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !trimmed.isEmpty else {
                    return Just(.idle).eraseToAnyPublisher()
                }

                return fetcher.search(query: trimmed)
                    .retryWithDelay(
                        retries: retryCount,
                        delay: retryDelay,
                        scheduler: scheduler
                    )
                    .map { SearchState.loaded($0) }
                    .catch { error in
                        Just(SearchState.error(SearchError.map(error)))
                    }
                    .prepend(.loading)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
    }
}

import Combine
import Foundation

final class SearchViewModel<Fetcher: SearchFetching>: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var state: SearchState<Fetcher.Result> = .idle

    private var cancellables = Set<AnyCancellable>()

    init(fetcher: Fetcher, scheduler: DispatchQueue = .main) {
        let service = SearchService(fetcher: fetcher, scheduler: scheduler)

        service.makeSearchPipeline(queryPublisher: $query)
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }
}

import SwiftUI

// A concrete result type for demonstration
struct SearchItem: Codable, Equatable, Identifiable {
    let id: Int
    let title: String
}

struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel<APISearchFetcher>

    init(fetcher: APISearchFetcher = APISearchFetcher()) {
        _viewModel = StateObject(wrappedValue: SearchViewModel(fetcher: fetcher))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Error banner
                if case .error(let error) = viewModel.state {
                    errorBanner(error)
                }

                List {
                    switch viewModel.state {
                    case .idle:
                        ContentUnavailableView(
                            "Search",
                            systemImage: "magnifyingglass",
                            description: Text("Type to begin searching")
                        )

                    case .loading:
                        HStack {
                            Spacer()
                            ProgressView("Searching…")
                            Spacer()
                        }
                        .listRowSeparator(.hidden)

                    case .loaded(let items):
                        if items.isEmpty {
                            ContentUnavailableView.search(text: viewModel.query)
                        } else {
                            ForEach(items) { item in
                                Text(item.title)
                            }
                        }

                    case .error:
                        // Banner already shown above the list
                        ContentUnavailableView(
                            "Something went wrong",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Try a different search")
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Search")
            .searchable(text: $viewModel.query, prompt: "Search items…")
        }
    }

    @ViewBuilder
    private func errorBanner(_ error: SearchError) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(errorMessage(error))
                .font(.subheadline)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.12))
        .foregroundStyle(.red)
    }

    private func errorMessage(_ error: SearchError) -> String {
        switch error {
        case .networkUnavailable:
            return "No internet connection."
        case .serverError(let code):
            return "Server error (\(code)). Try again later."
        case .decodingFailed:
            return "Unexpected response format."
        case .unknown(let msg):
            return msg
        }
    }
}

import Combine
import Foundation

struct APISearchFetcher: SearchFetching {
    typealias Result = SearchItem

    private let session: URLSession
    private let baseURL: URL

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.example.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func search(query: String) -> AnyPublisher<[SearchItem], Error> {
        var components = URLComponents(url: baseURL.appendingPathComponent("search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        let request = URLRequest(url: components.url!)

        return session.dataTaskPublisher(for: request)
            .tryMap { data, response in
                guard let http = response as? HTTPURLResponse else {
                    throw SearchError.unknown("Invalid response")
                }
                guard (200..<300).contains(http.statusCode) else {
                    throw SearchError.serverError(statusCode: http.statusCode)
                }
                return data
            }
            .decode(type: [SearchItem].self, decoder: JSONDecoder())
            .mapError { SearchError.map($0) }
            .eraseToAnyPublisher()
    }
}

import Combine
import XCTest

// MARK: - Mock Fetcher

final class MockSearchFetcher: SearchFetching {
    typealias Result = SearchItem

    var searchHandler: (String) -> AnyPublisher<[SearchItem], Error> = { _ in
        Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
    }

    private(set) var searchCallCount = 0
    private(set) var searchQueries: [String] = []

    func search(query: String) -> AnyPublisher<[SearchItem], Error> {
        searchCallCount += 1
        searchQueries.append(query)
        return searchHandler(query)
    }
}

// MARK: - Tests

final class SearchServiceTests: XCTestCase {
    private var cancellables: Set<AnyCancellable>!
    private var fetcher: MockSearchFetcher!
    private var scheduler: DispatchQueue!

    override func setUp() {
        super.setUp()
        cancellables = []
        fetcher = MockSearchFetcher()
        scheduler = DispatchQueue(label: "test.search", qos: .userInitiated)
    }

    override func tearDown() {
        cancellables = nil
        fetcher = nil
        scheduler = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeService(
        debounce: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(100),
        retryCount: Int = 2,
        retryDelay: DispatchQueue.SchedulerTimeType.Stride = .milliseconds(50)
    ) -> SearchService<MockSearchFetcher> {
        SearchService(
            fetcher: fetcher,
            debounceInterval: debounce,
            retryCount: retryCount,
            retryDelay: retryDelay,
            scheduler: scheduler
        )
    }

    // MARK: - Empty/Whitespace Input → .idle

    func testEmptyStringEmitsIdle() {
        let service = makeService()
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "idle")

        var states: [SearchState<SearchItem>] = []

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                states.append(state)
                if case .idle = state { expectation.fulfill() }
            }
            .store(in: &cancellables)

        subject.send("")

        waitForExpectations(timeout: 2)
        XCTAssertEqual(states.last, .idle)
        XCTAssertEqual(fetcher.searchCallCount, 0, "Should not hit network for empty query")
    }

    func testWhitespaceOnlyEmitsIdle() {
        let service = makeService()
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "idle")

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                if case .idle = state { expectation.fulfill() }
            }
            .store(in: &cancellables)

        subject.send("   ")

        waitForExpectations(timeout: 2)
        XCTAssertEqual(fetcher.searchCallCount, 0)
    }

    // MARK: - Deduplication

    func testDuplicateQueriesAreSuppressed() {
        let service = makeService(debounce: .milliseconds(50))
        let subject = PassthroughSubject<String, Never>()
        let loadedExpectation = expectation(description: "loaded")

        let items = [SearchItem(id: 1, title: "Swift")]
        fetcher.searchHandler = { _ in
            Just(items).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        var loadedCount = 0

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                if case .loaded = state {
                    loadedCount += 1
                    loadedExpectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Send the same value — after debounce, removeDuplicates should collapse them
        subject.send("swift")

        waitForExpectations(timeout: 2)

        // Now send same value again — should be deduped
        let dupExpectation = expectation(description: "no dup")
        dupExpectation.isInverted = true

        service.makeSearchPipeline(queryPublisher: Just("swift"))
            .dropFirst() // skip initial
            .sink { state in
                if case .loaded = state {
                    dupExpectation.fulfill() // should NOT fire
                }
            }
            .store(in: &cancellables)

        waitForExpectations(timeout: 0.5)
        XCTAssertEqual(fetcher.searchCallCount, 1, "Duplicate query should not trigger another fetch")
    }

    // MARK: - Loading → Loaded transition

    func testSuccessfulSearchEmitsLoadingThenLoaded() {
        let service = makeService(debounce: .milliseconds(50))
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "loaded")

        let items = [SearchItem(id: 1, title: "Result")]
        fetcher.searchHandler = { _ in
            Just(items).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        var states: [SearchState<SearchItem>] = []

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                states.append(state)
                if case .loaded = state { expectation.fulfill() }
            }
            .store(in: &cancellables)

        subject.send("test")

        waitForExpectations(timeout: 2)
        // Should see .loading then .loaded
        XCTAssertTrue(states.contains(.loading))
        XCTAssertEqual(states.last, .loaded(items))
    }

    // MARK: - Error mapping

    func testNetworkErrorMapsToSearchError() {
        let service = makeService(debounce: .milliseconds(50), retryCount: 0)
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "error")

        fetcher.searchHandler = { _ in
            Fail(error: URLError(.notConnectedToInternet))
                .eraseToAnyPublisher()
        }

        var states: [SearchState<SearchItem>] = []

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                states.append(state)
                if case .error = state { expectation.fulfill() }
            }
            .store(in: &cancellables)

        subject.send("fail")

        waitForExpectations(timeout: 2)
        XCTAssertEqual(states.last, .error(.networkUnavailable))
    }

    // MARK: - Retry behavior

    func testRetryEventuallySucceeds() {
        let service = makeService(debounce: .milliseconds(50), retryCount: 2, retryDelay: .milliseconds(50))
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "loaded after retry")

        var callCount = 0
        let items = [SearchItem(id: 1, title: "Recovered")]
        fetcher.searchHandler = { _ in
            callCount += 1
            if callCount <= 2 {
                return Fail(error: URLError(.timedOut)).eraseToAnyPublisher()
            }
            return Just(items).setFailureType(to: Error.self).eraseToAnyPublisher()
        }

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                if case .loaded(let results) = state {
                    XCTAssertEqual(results, items)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        subject.send("retry")

        waitForExpectations(timeout: 5)
        XCTAssertGreaterThanOrEqual(callCount, 3, "Should have retried at least twice before succeeding")
    }

    func testRetryExhaustedEmitsError() {
        let service = makeService(debounce: .milliseconds(50), retryCount: 2, retryDelay: .milliseconds(50))
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "error after exhausted retries")

        fetcher.searchHandler = { _ in
            Fail(error: URLError(.timedOut)).eraseToAnyPublisher()
        }

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                if case .error = state { expectation.fulfill() }
            }
            .store(in: &cancellables)

        subject.send("alwaysfail")

        waitForExpectations(timeout: 5)
        // 1 original + 2 retries = 3 calls
        XCTAssertEqual(fetcher.searchCallCount, 3)
    }

    // MARK: - Cancellation via switchToLatest

    func testNewQueryCancelsPreviousInFlightRequest() {
        let service = makeService(debounce: .milliseconds(50))
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "only second result arrives")

        let slowSubject = PassthroughSubject<[SearchItem], Error>()
        let fastItems = [SearchItem(id: 2, title: "Fast")]

        var queryIndex = 0
        fetcher.searchHandler = { query in
            queryIndex += 1
            if queryIndex == 1 {
                // First query: hangs via a subject we never complete
                return slowSubject.eraseToAnyPublisher()
            } else {
                // Second query: responds immediately
                return Just(fastItems).setFailureType(to: Error.self).eraseToAnyPublisher()
            }
        }

        var loadedResults: [[SearchItem]] = []

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                if case .loaded(let items) = state {
                    loadedResults.append(items)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Send first query
        subject.send("slow")

        // After debounce settles, send a different query that will supersede it
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            subject.send("fast")
        }

        waitForExpectations(timeout: 3)

        // The slow query's result should never arrive — switchToLatest cancels it
        XCTAssertEqual(loadedResults.count, 1)
        XCTAssertEqual(loadedResults.first, fastItems)
    }

    // MARK: - Debounce

    func testDebounceCoalescesRapidInput() {
        let service = makeService(debounce: .milliseconds(200))
        let subject = PassthroughSubject<String, Never>()
        let expectation = expectation(description: "loaded")

        fetcher.searchHandler = { query in
            Just([SearchItem(id: 1, title: query)])
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        var loadedStates: [SearchState<SearchItem>] = []

        service.makeSearchPipeline(queryPublisher: subject)
            .sink { state in
                if case .loaded = state {
                    loadedStates.append(state)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        // Rapid fire — only the last should survive debounce
        subject.send("s")
        subject.send("sw")
        subject.send("swi")
        subject.send("swift")

        waitForExpectations(timeout: 2)

        // Only "swift" should have triggered a fetch
        XCTAssertEqual(fetcher.searchQueries, ["swift"])
        XCTAssertEqual(loadedStates.count, 1)
    }
}


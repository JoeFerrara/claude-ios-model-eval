// ============================================================
// MARK: - SearchError.swift
// ============================================================

import Foundation

enum SearchError: Error, Equatable {
    case networkUnavailable
    case serverError(statusCode: Int)
    case decodingFailed
    case unknown(description: String)

    var message: String {
        switch self {
        case .networkUnavailable:
            return "No internet connection. Please check your network."
        case .serverError(let code):
            return "Server error (HTTP \(code)). Please try again."
        case .decodingFailed:
            return "Couldn't parse the search results."
        case .unknown(let desc):
            return "An unexpected error occurred: \(desc)"
        }
    }
}

// ============================================================
// MARK: - SearchState.swift
// ============================================================

enum SearchState<T> {
    case idle
    case loading
    case loaded([T])
    case error(SearchError)
}

extension SearchState {
    var isLoading: Bool {
        guard case .loading = self else { return false }
        return true
    }

    var results: [T] {
        guard case .loaded(let items) = self else { return [] }
        return items
    }

    var searchError: SearchError? {
        guard case .error(let err) = self else { return nil }
        return err
    }
}

// ============================================================
// MARK: - SearchResult.swift  (example domain model)
// ============================================================

import Foundation

struct SearchResult: Identifiable, Decodable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

// ============================================================
// MARK: - Publisher+RetryWithDelay.swift
// ============================================================

import Combine

extension Publisher {
    /// Retries the upstream publisher up to `maxRetries` times,
    /// inserting a `delay` between each attempt.
    func retryWithDelay<S: Scheduler>(
        _ maxRetries: Int,
        delay: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        self.catch { error -> AnyPublisher<Output, Failure> in
            guard maxRetries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            return self
                .delay(for: delay, scheduler: scheduler)
                .retryWithDelay(maxRetries - 1, delay: delay, scheduler: scheduler)
        }
        .eraseToAnyPublisher()
    }
}

// ============================================================
// MARK: - SearchNetworkClient.swift
// ============================================================

import Combine
import Foundation

protocol SearchNetworkClientProtocol {
    func search(query: String) -> AnyPublisher<[SearchResult], SearchError>
}

final class SearchNetworkClient: SearchNetworkClientProtocol {
    private let session: URLSession
    private let baseURL: URL

    init(session: URLSession = .shared, baseURL: URL) {
        self.session = session
        self.baseURL = baseURL
    }

    func search(query: String) -> AnyPublisher<[SearchResult], SearchError> {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return Fail(error: .unknown(description: "Invalid base URL")).eraseToAnyPublisher()
        }
        components.path += "/search"
        components.queryItems = [URLQueryItem(name: "q", value: query)]

        guard let url = components.url else {
            return Fail(error: .unknown(description: "Could not build request URL")).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .tryMap { data, response -> Data in
                guard let http = response as? HTTPURLResponse else {
                    throw SearchError.unknown(description: "Non-HTTP response")
                }
                guard (200...299).contains(http.statusCode) else {
                    throw SearchError.serverError(statusCode: http.statusCode)
                }
                return data
            }
            .decode(type: [SearchResult].self, decoder: JSONDecoder())
            .mapError(SearchError.from)
            // Retry before the pipeline is erased; resubscribes the full chain above.
            // In production you may want to filter and only retry transient errors.
            .retryWithDelay(2, delay: .seconds(1), scheduler: DispatchQueue.global())
            .eraseToAnyPublisher()
    }
}

private extension SearchError {
    static func from(_ error: Error) -> SearchError {
        if let e = error as? SearchError  { return e }
        if error is DecodingError         { return .decodingFailed }
        if let e = error as? URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return .networkUnavailable
            default:
                return .unknown(description: e.localizedDescription)
            }
        }
        return .unknown(description: error.localizedDescription)
    }
}

// ============================================================
// MARK: - SearchService.swift
// ============================================================

import Combine
import Foundation

final class SearchService {
    private let client: SearchNetworkClientProtocol

    init(client: SearchNetworkClientProtocol) {
        self.client = client
    }

    /// Transforms a raw text publisher into a stream of `SearchState` values.
    ///
    /// Pipeline order:
    ///   raw text
    ///     → debounce(300 ms)          — wait for typing to settle
    ///     → filter(!isEmpty)          — skip empty strings
    ///     → removeDuplicates          — skip unchanged queries
    ///     → map → inner publisher     — one publisher per accepted query
    ///     → switchToLatest            — cancel in-flight when new query arrives
    ///     → prepend(.idle)            — clean initial state
    func statePublisher(
        from textPublisher: some Publisher<String, Never>
    ) -> AnyPublisher<SearchState<SearchResult>, Never> {
        textPublisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .filter { !$0.isEmpty }
            .removeDuplicates()
            .map { [client] query -> AnyPublisher<SearchState<SearchResult>, Never> in
                client.search(query: query)
                    .map(SearchState.loaded)
                    .catch { Just(SearchState<SearchResult>.error($0)) }
                    .prepend(.loading)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .prepend(.idle)
            .eraseToAnyPublisher()
    }
}

// ============================================================
// MARK: - SearchViewModel.swift
// ============================================================

import Combine
import Foundation

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var state: SearchState<SearchResult> = .idle

    init(service: SearchService) {
        service.statePublisher(from: $query)
            .receive(on: DispatchQueue.main)
            .assign(to: &$state)
    }
}

// ============================================================
// MARK: - SearchView.swift
// ============================================================
// Requires iOS 16+ (.searchable placement), iOS 17+ (ContentUnavailableView).

import SwiftUI

struct SearchView: View {
    @StateObject private var vm: SearchViewModel

    init(service: SearchService) {
        _vm = StateObject(wrappedValue: SearchViewModel(service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Error banner — slides in from top when present
                if let error = vm.state.searchError {
                    ErrorBannerView(message: error.message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }

                // Main content area
                Group {
                    switch vm.state {
                    case .idle:
                        ContentUnavailableView(
                            "Search",
                            systemImage: "magnifyingglass",
                            description: Text("Start typing to search.")
                        )

                    case .loading:
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Searching…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .loaded(let results) where results.isEmpty:
                        ContentUnavailableView.search(text: vm.query)

                    case .loaded(let results):
                        List(results) { result in
                            SearchResultRow(result: result)
                        }
                        .listStyle(.plain)

                    case .error:
                        ContentUnavailableView(
                            "Search Failed",
                            systemImage: "exclamationmark.triangle",
                            description: Text("Please try a different search term.")
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.state.isLoading)
            }
            .navigationTitle("Search")
            .searchable(
                text: $vm.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search…"
            )
        }
    }
}

// MARK: - Supporting Views

struct ErrorBannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red)
    }
}

struct SearchResultRow: View {
    let result: SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(result.title)
                .font(.headline)
            Text(result.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}

// ============================================================
// MARK: - MockSearchNetworkClient.swift  (test target only)
// ============================================================

import Combine
import XCTest

final class MockSearchNetworkClient: SearchNetworkClientProtocol {
    // Configure per-test to return any publisher you need
    var handler: (String) -> AnyPublisher<[SearchResult], SearchError> = { _ in
        Just([]).setFailureType(to: SearchError.self).eraseToAnyPublisher()
    }

    private(set) var receivedQueries: [String] = []

    func search(query: String) -> AnyPublisher<[SearchResult], SearchError> {
        receivedQueries.append(query)
        return handler(query)
    }
}

// ============================================================
// MARK: - SearchServiceTests.swift
// ============================================================
// Note: debounce/time-based operators are tested here with real-clock
// XCTestExpectation timeouts. For fully deterministic tests, replace
// DispatchQueue.main in SearchService with an injectable AnyScheduler
// (e.g. from pointfreeco/combine-schedulers) and pass
// ImmediateScheduler.shared in tests.

@testable import YourAppModule  // ← replace with your module name

final class SearchServiceTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()
    private var mockClient: MockSearchNetworkClient!
    private var service: SearchService!

    override func setUp() {
        super.setUp()
        mockClient = MockSearchNetworkClient()
        service = SearchService(client: mockClient)
    }

    override func tearDown() {
        cancellables = []
        super.tearDown()
    }

    // MARK: - Empty string filtering

    func test_emptyString_doesNotTriggerSearch() {
        let subject = PassthroughSubject<String, Never>()
        let exp = expectation(description: "No loading state emitted")
        exp.isInverted = true  // fulfilled = test failure

        service.statePublisher(from: subject)
            .filter { if case .loading = $0 { return true }; return false }
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        subject.send("")

        wait(for: [exp], timeout: 0.5)
        XCTAssertTrue(mockClient.receivedQueries.isEmpty)
    }

    // MARK: - Deduplication

    func test_duplicateConsecutiveQuery_searchedOnlyOnce() {
        let subject = PassthroughSubject<String, Never>()

        let firstLoaded = expectation(description: "First loaded state")
        service.statePublisher(from: subject)
            .filter { if case .loaded = $0 { return true }; return false }
            .first()
            .sink { _ in firstLoaded.fulfill() }
            .store(in: &cancellables)

        subject.send("swift")
        wait(for: [firstLoaded], timeout: 1.0)

        // Same query again — must not trigger a second network call
        subject.send("swift")

        let pause = expectation(description: "Dedup pause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { pause.fulfill() }
        wait(for: [pause], timeout: 1.0)

        XCTAssertEqual(
            mockClient.receivedQueries.filter { $0 == "swift" }.count, 1,
            "Duplicate query should not be forwarded to the network client"
        )
    }

    // MARK: - Debounce

    func test_rapidBurst_onlyLastValueSearched() {
        let subject = PassthroughSubject<String, Never>()
        let exp = expectation(description: "Loaded state received")

        service.statePublisher(from: subject)
            .filter { if case .loaded = $0 { return true }; return false }
            .first()
            .sink { _ in exp.fulfill() }
            .store(in: &cancellables)

        // All sent within the 300 ms debounce window
        ["s", "sw", "swi", "swif", "swift"].forEach { subject.send($0) }

        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(
            mockClient.receivedQueries, ["swift"],
            "Only the last value in a rapid burst should reach the network"
        )
    }

    // MARK: - State sequence

    func test_stateSequence_idleThenLoadingThenLoaded() {
        // Delay result so .loading is observable before .loaded
        mockClient.handler = { _ in
            Just([SearchResult(id: "1", title: "Result", subtitle: "")])
                .setFailureType(to: SearchError.self)
                .delay(for: .milliseconds(50), scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<String, Never>()
        var names: [String] = []
        let exp = expectation(description: "Three-state sequence")

        service.statePublisher(from: subject)
            .prefix(3)   // .idle, .loading, .loaded
            .collect()
            .sink { states in
                names = states.map {
                    switch $0 {
                    case .idle:    return "idle"
                    case .loading: return "loading"
                    case .loaded:  return "loaded"
                    case .error:   return "error"
                    }
                }
                exp.fulfill()
            }
            .store(in: &cancellables)

        subject.send("test")

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(names, ["idle", "loading", "loaded"])
    }

    // MARK: - Error handling

    func test_networkError_emitsErrorState() {
        mockClient.handler = { _ in
            Fail(error: SearchError.networkUnavailable).eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<String, Never>()
        var receivedError: SearchError?
        let exp = expectation(description: "Error state")

        service.statePublisher(from: subject)
            .compactMap { if case .error(let e) = $0 { return e }; return nil }
            .first()
            .sink { receivedError = $0; exp.fulfill() }
            .store(in: &cancellables)

        subject.send("anything")

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(receivedError, .networkUnavailable)
    }

    func test_serverError_propagatesStatusCode() {
        mockClient.handler = { _ in
            Fail(error: SearchError.serverError(statusCode: 503)).eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<String, Never>()
        var receivedError: SearchError?
        let exp = expectation(description: "Server error state")

        service.statePublisher(from: subject)
            .compactMap { if case .error(let e) = $0 { return e }; return nil }
            .first()
            .sink { receivedError = $0; exp.fulfill() }
            .store(in: &cancellables)

        subject.send("query")

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(receivedError, .serverError(statusCode: 503))
    }

    func test_errorFollowedBySuccess_stateRecovers() {
        var callCount = 0
        mockClient.handler = { _ in
            callCount += 1
            if callCount == 1 {
                return Fail(error: SearchError.networkUnavailable).eraseToAnyPublisher()
            }
            return Just([SearchResult(id: "1", title: "OK", subtitle: "")])
                .setFailureType(to: SearchError.self)
                .eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<String, Never>()
        var terminalStates: [String] = []
        let exp = expectation(description: "error then loaded")

        service.statePublisher(from: subject)
            .compactMap { state -> String? in
                switch state {
                case .loaded: return "loaded"
                case .error:  return "error"
                default:      return nil
                }
            }
            .prefix(2)
            .collect()
            .sink { terminalStates = $0; exp.fulfill() }
            .store(in: &cancellables)

        subject.send("first")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            subject.send("second")
        }

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(terminalStates, ["error", "loaded"])
    }

    // MARK: - Cancellation via switchToLatest

    func test_newQueryBeforeResponseArrives_onlyLatestResultDelivered() {
        // Each search completes after 250 ms
        mockClient.handler = { query in
            Future<[SearchResult], SearchError> { promise in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    promise(.success([SearchResult(id: query, title: query, subtitle: "")]))
                }
            }
            .eraseToAnyPublisher()
        }

        let subject = PassthroughSubject<String, Never>()
        var loadedIDs: [String] = []
        let exp = expectation(description: "Only latest result delivered")

        service.statePublisher(from: subject)
            .compactMap { state -> [SearchResult]? in
                if case .loaded(let r) = state { return r }
                return nil
            }
            .prefix(1)
            .sink { loadedIDs = $0.map(\.id); exp.fulfill() }
            .store(in: &cancellables)

        // Send "first" — passes debounce after 300 ms, starts in-flight request
        subject.send("first")

        // Send "second" 400 ms later — passes debounce too, switchToLatest cancels "first"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            subject.send("second")
        }

        wait(for: [exp], timeout: 3.0)
        XCTAssertEqual(loadedIDs, ["second"],
                       "switchToLatest should cancel the first in-flight request")
    }
}

// ============================================================
// MARK: - RetryWithDelayTests.swift
// ============================================================

final class RetryWithDelayTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables = []
        super.tearDown()
    }

    func test_allAttemptsExhausted_correctAttemptCount() {
        var attemptCount = 0
        let publisher = Deferred {
            Future<Int, SearchError> { promise in
                attemptCount += 1
                promise(.failure(.networkUnavailable))
            }
        }

        let exp = expectation(description: "Failure after retries")
        var finalError: SearchError?

        publisher
            .retryWithDelay(2, delay: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink(
                receiveCompletion: {
                    if case .failure(let e) = $0 { finalError = e }
                    exp.fulfill()
                },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(attemptCount, 3, "1 initial attempt + 2 retries = 3 total")
        XCTAssertEqual(finalError, .networkUnavailable)
    }

    func test_succeedsOnSecondAttempt_deliversValue() {
        var attemptCount = 0
        let publisher = Deferred {
            Future<Int, SearchError> { promise in
                attemptCount += 1
                promise(attemptCount >= 2 ? .success(42) : .failure(.networkUnavailable))
            }
        }

        let exp = expectation(description: "Value delivered on retry")
        var result: Int?

        publisher
            .retryWithDelay(2, delay: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { result = $0; exp.fulfill() }
            )
            .store(in: &cancellables)

        wait(for: [exp], timeout: 2.0)
        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(result, 42)
    }

    func test_zeroRetries_failsAfterSingleAttempt() {
        var attemptCount = 0
        let publisher = Deferred {
            Future<Int, SearchError> { promise in
                attemptCount += 1
                promise(.failure(.networkUnavailable))
            }
        }

        let exp = expectation(description: "Immediate failure, no retries")

        publisher
            .retryWithDelay(0, delay: .seconds(60), scheduler: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in exp.fulfill() },
                receiveValue: { _ in }
            )
            .store(in: &cancellables)

        // If retries were attempted, the .seconds(60) delay would blow this timeout
        wait(for: [exp], timeout: 1.0)
        XCTAssertEqual(attemptCount, 1)
    }
}


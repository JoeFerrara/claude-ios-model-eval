```swift
import SwiftUI
import Combine

// ─────────────────────────────────────────────
// MARK: - SearchError
// ─────────────────────────────────────────────

enum SearchError: Error, LocalizedError {
    case networkUnavailable
    case serverError(Int)
    case decodingFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection."
        case .serverError(let c): return "Server error \(c)."
        case .decodingFailed:     return "Could not parse results."
        case .unknown:            return "Something went wrong."
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - SearchState
// ─────────────────────────────────────────────

enum SearchState<T> {
    case idle
    case loading
    case loaded([T])
    case error(SearchError)
}

// ─────────────────────────────────────────────
// MARK: - Domain Model
// ─────────────────────────────────────────────

struct SearchResult: Identifiable, Decodable {
    let trackId: Int?
    let collectionId: Int?
    let trackName: String?
    let collectionName: String?
    let artistName: String?

    var id: Int           { trackId ?? collectionId ?? 0 }
    var displayTitle: String  { trackName ?? collectionName ?? "Unknown" }
    var displayArtist: String { artistName ?? "" }
}

private struct iTunesResponse: Decodable {
    let results: [SearchResult]
}

// ─────────────────────────────────────────────
// MARK: - Publisher Extension: Retry with Delay
// ─────────────────────────────────────────────

extension Publisher {
    /// Re-subscribes up to `retries` times, waiting `delay` between each attempt.
    func retryWithDelay<S: Scheduler>(
        _ retries: Int,
        delay: S.SchedulerTimeType.Stride,
        scheduler: S
    ) -> AnyPublisher<Output, Failure> {
        self.catch { error -> AnyPublisher<Output, Failure> in
            guard retries > 0 else {
                return Fail(error: error).eraseToAnyPublisher()
            }
            return Just(())
                .setFailureType(to: Failure.self)   // match outer Failure for flatMap
                .delay(for: delay, scheduler: scheduler)
                .flatMap { _ in
                    self.retryWithDelay(retries - 1, delay: delay, scheduler: scheduler)
                }
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}

// ─────────────────────────────────────────────
// MARK: - SearchService
// ─────────────────────────────────────────────

final class SearchService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // Entry point: consumes any String publisher, returns state updates.
    func results(
        for textPublisher: AnyPublisher<String, Never>
    ) -> AnyPublisher<SearchState<SearchResult>, Never> {
        textPublisher
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            // Map each query to its own inner publisher, then flatten with
            // switchToLatest so a new query cancels the in-flight request.
            .map { [weak self] rawQuery -> AnyPublisher<SearchState<SearchResult>, Never> in
                let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !query.isEmpty, let self else {
                    return Just(.idle).eraseToAnyPublisher()   // clear → reset to idle
                }
                return self.statePublisher(for: query)
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    // Emits .loading immediately, then .loaded or .error.
    private func statePublisher(
        for query: String
    ) -> AnyPublisher<SearchState<SearchResult>, Never> {
        networkPublisher(for: query)
            .retryWithDelay(2, delay: .seconds(1), scheduler: DispatchQueue.global())
            .map  { SearchState<SearchResult>.loaded($0) }
            .catch { Just(SearchState<SearchResult>.error($0)) }
            .prepend(.loading)
            .eraseToAnyPublisher()
    }

    // Raw fetch: [SearchResult] or a typed SearchError.
    private func networkPublisher(
        for query: String
    ) -> AnyPublisher<[SearchResult], SearchError> {
        var comps = URLComponents(string: "https://itunes.apple.com/search")!
        comps.queryItems = [
            URLQueryItem(name: "term",  value: query),
            URLQueryItem(name: "limit", value: "25"),
            URLQueryItem(name: "media", value: "software"),
        ]
        guard let url = comps.url else {
            return Fail(error: .unknown).eraseToAnyPublisher()
        }

        return session.dataTaskPublisher(for: url)
            .tryMap { data, response throws -> Data in
                guard let http = response as? HTTPURLResponse else {
                    throw SearchError.networkUnavailable
                }
                guard (200...299).contains(http.statusCode) else {
                    throw SearchError.serverError(http.statusCode)
                }
                return data
            }
            .decode(type: iTunesResponse.self, decoder: JSONDecoder())
            .map(\.results)
            .mapError { error -> SearchError in
                if let se = error as? SearchError   { return se }
                if error is DecodingError            { return .decodingFailed }
                if let ue = error as? URLError,
                   ue.code == .notConnectedToInternet { return .networkUnavailable }
                return .unknown
            }
            .eraseToAnyPublisher()
    }
}

// ─────────────────────────────────────────────
// MARK: - SearchViewModel
// ─────────────────────────────────────────────

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var state: SearchState<SearchResult> = .idle

    private let service: SearchService

    init(service: SearchService = SearchService()) {
        self.service = service
        // Wire the @Published query into the Combine pipeline.
        // assign(to:) keeps the subscription alive for the object's lifetime.
        service
            .results(for: $query.eraseToAnyPublisher())
            .assign(to: &$state)
    }
}

// ─────────────────────────────────────────────
// MARK: - SearchView
// ─────────────────────────────────────────────

struct SearchView: View {
    @StateObject private var vm = SearchViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                contentArea
            }
            .navigationTitle("App Search")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search apps…", text: $vm.query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !vm.query.isEmpty {
                Button { vm.query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }

    // MARK: State-driven content

    @ViewBuilder
    private var contentArea: some View {
        switch vm.state {
        case .idle:              idlePlaceholder
        case .loading:           loadingView
        case .loaded(let items): resultsList(items)
        case .error(let err):    errorView(err)
        }
    }

    // MARK: Idle placeholder

    private var idlePlaceholder: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(.quaternary)
            Text("Find Apps")
                .font(.title2.weight(.semibold))
            Text("Start typing to search the App Store.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: Loading indicator

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Searching…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: Results list

    @ViewBuilder
    private func resultsList(_ results: [SearchResult]) -> some View {
        if results.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 52))
                    .foregroundStyle(.quaternary)
                Text("No Results")
                    .font(.title2.weight(.semibold))
                Text("Nothing matched "\(vm.query)".")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
        } else {
            List(results) { result in
                VStack(alignment: .leading, spacing: 3) {
                    Text(result.displayTitle)
                        .font(.headline)
                    if !result.displayArtist.isEmpty {
                        Text(result.displayArtist)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
            .listStyle(.plain)
        }
    }

    // MARK: Error banner

    private func errorView(_ error: SearchError) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error.localizedDescription ?? "An error occurred.")
                    .font(.subheadline)
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.red, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.top, 8)
            Spacer()
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - App Entry Point
// ─────────────────────────────────────────────

@main
struct SearchApp: App {
    var body: some Scene {
        WindowGroup {
            SearchView()
        }
    }
}
```

---

**Architecture walkthrough**

| Layer | Responsibility |
|---|---|
| `SearchError` | Typed domain errors; `LocalizedError` for display strings |
| `SearchState<T>` | Generic state enum covering all four UI phases |
| `retryWithDelay` | `Publisher` extension that re-subscribes after a `delay` up to `retries` times, using `setFailureType` to make `Just<Void>` match the outer failure type |
| `SearchService.results(for:)` | Debounce → dedup → map-to-inner-publisher → **`switchToLatest`** cancels in-flight request on new input |
| `SearchService.statePublisher(for:)` | `prepend(.loading)` before the network call, then retry ×2 / 1 s, then `.loaded` or `.error` |
| `SearchViewModel` | `@MainActor`; wires `$query` into the service pipeline via `assign(to: &$state)` — no `AnyCancellable` storage needed |
| `SearchView` | `@ViewBuilder` switch over `vm.state`; search bar always visible; error shown as a red banner at the top of the content area |

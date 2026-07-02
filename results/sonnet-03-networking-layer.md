## Networking Layer — 8 Files

---

### `APIError.swift`

```swift
import Foundation

enum APIError: LocalizedError {
    case badURL
    case unauthorized
    case serverError(Int)
    case decodingFailed
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "The URL is malformed or could not be constructed."
        case .unauthorized:
            return "Request is unauthorized. Check your credentials."
        case .serverError(let code):
            return "Server returned an error with status code \(code)."
        case .decodingFailed:
            return "Failed to decode the server response."
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds."
        }
    }
}
```

---

### `RequestInterceptor.swift`

```swift
import Foundation

/// Adopt this protocol to mutate outgoing requests before they are sent —
/// e.g. to attach auth headers, sign requests, or add tracing identifiers.
protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

// MARK: - Built-in interceptors

/// Attaches a Bearer token to every request.
struct BearerTokenInterceptor: RequestInterceptor {
    /// Closure is called per-request so tokens can be refreshed dynamically.
    private let tokenProvider: () async throws -> String

    init(tokenProvider: @escaping () async throws -> String) {
        self.tokenProvider = tokenProvider
    }

    func intercept(_ request: inout URLRequest) async throws {
        let token = try await tokenProvider()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

/// Attaches static key/value headers to every request.
struct StaticHeadersInterceptor: RequestInterceptor {
    let headers: [String: String]

    func intercept(_ request: inout URLRequest) async throws {
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
    }
}
```

---

### `CacheManager.swift`

```swift
import Foundation

struct CachedEntry {
    let data: Data
    let expiresAt: Date

    var isExpired: Bool { Date() > expiresAt }
}

/// Thread-safe in-memory response cache backed by a Swift actor.
actor CacheManager {
    private var store: [String: CachedEntry] = [:]
    let defaultTTL: TimeInterval

    init(defaultTTL: TimeInterval = 300) {
        self.defaultTTL = defaultTTL
    }

    func set(_ data: Data, for key: String, ttl: TimeInterval? = nil) {
        let expiry = Date().addingTimeInterval(ttl ?? defaultTTL)
        store[key] = CachedEntry(data: data, expiresAt: expiry)
    }

    func get(for key: String) -> Data? {
        guard let entry = store[key] else { return nil }
        if entry.isExpired {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func invalidate(for key: String) {
        store.removeValue(forKey: key)
    }

    func invalidateAll() {
        store.removeAll()
    }
}
```

---

### `APIRequest.swift`

```swift
import Foundation

// MARK: - HTTPMethod

enum HTTPMethod: String {
    case get    = "GET"
    case post   = "POST"
    case put    = "PUT"
    case delete = "DELETE"
}

// MARK: - Sentinel types

/// Use as `Body` when a request carries no body.
struct EmptyBody: Encodable {}

/// Use as `Response` when the server returns 204 No Content.
struct EmptyResponse: Decodable {}

// MARK: - APIRequest

struct APIRequest<Body: Encodable> {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let body: Body?
    let headers: [String: String]?
    /// Non-nil enables caching for GET responses; value is TTL in seconds.
    let cacheTTL: TimeInterval?

    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem]? = nil,
        body: Body? = nil,
        headers: [String: String]? = nil,
        cacheTTL: TimeInterval? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.headers = headers
        self.cacheTTL = cacheTTL
    }
}

// Convenience init for body-less requests
extension APIRequest where Body == EmptyBody {
    init(
        path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil,
        cacheTTL: TimeInterval? = nil
    ) {
        self.init(
            path: path,
            method: method,
            queryItems: queryItems,
            body: nil,
            headers: headers,
            cacheTTL: cacheTTL
        )
    }
}
```

---

### `APIClient.swift`

```swift
import Foundation

// MARK: - Configuration

struct APIClientConfiguration {
    let baseURL: URL
    let defaultHeaders: [String: String]
    let timeoutInterval: TimeInterval
    let maxRetries: Int

    init(
        baseURL: URL,
        defaultHeaders: [String: String] = [
            "Content-Type": "application/json",
            "Accept":       "application/json"
        ],
        timeoutInterval: TimeInterval = 30,
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
        self.timeoutInterval = timeoutInterval
        self.maxRetries = maxRetries
    }
}

// MARK: - APIClient

final class APIClient {
    private let configuration: APIClientConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let interceptors: [RequestInterceptor]
    private let cache: CacheManager

    init(
        configuration: APIClientConfiguration,
        interceptors: [RequestInterceptor] = [],
        cache: CacheManager = CacheManager(),
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.interceptors = interceptors
        self.cache = cache
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    // MARK: - Generic send

    func send<Body: Encodable, Response: Decodable>(
        _ request: APIRequest<Body>
    ) async throws -> Response {
        let urlRequest = try await buildURLRequest(from: request)
        let cacheKey = urlRequest.url?.absoluteString ?? request.path

        if request.method == .get, let cached = await cache.get(for: cacheKey) {
            return try decode(cached)
        }

        let data = try await execute(urlRequest, retriesRemaining: configuration.maxRetries)

        if request.method == .get, let ttl = request.cacheTTL {
            await cache.set(data, for: cacheKey, ttl: ttl)
        }

        return try decode(data)
    }

    // MARK: - Convenience methods

    func get<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil,
        cacheTTL: TimeInterval? = nil
    ) async throws -> Response {
        try await send(APIRequest<EmptyBody>(
            path: path,
            method: .get,
            queryItems: queryItems,
            headers: headers,
            cacheTTL: cacheTTL
        ))
    }

    func post<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> Response {
        try await send(APIRequest(path: path, method: .post, body: body, headers: headers))
    }

    func put<Body: Encodable, Response: Decodable>(
        _ path: String,
        body: Body,
        headers: [String: String]? = nil
    ) async throws -> Response {
        try await send(APIRequest(path: path, method: .put, body: body, headers: headers))
    }

    func delete<Response: Decodable>(
        _ path: String,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil
    ) async throws -> Response {
        try await send(APIRequest<EmptyBody>(
            path: path,
            method: .delete,
            queryItems: queryItems,
            headers: headers
        ))
    }

    // MARK: - Request building

    private func buildURLRequest<Body: Encodable>(
        from request: APIRequest<Body>
    ) async throws -> URLRequest {
        guard var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: true
        ) else {
            throw APIError.badURL
        }
        components.queryItems = request.queryItems?.isEmpty == false ? request.queryItems : nil

        guard let url = components.url else {
            throw APIError.badURL
        }

        var urlRequest = URLRequest(url: url, timeoutInterval: configuration.timeoutInterval)
        urlRequest.httpMethod = request.method.rawValue

        for (field, value) in configuration.defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }
        for (field, value) in (request.headers ?? [:]) {
            urlRequest.setValue(value, forHTTPHeaderField: field)
        }

        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(body)
        }

        for interceptor in interceptors {
            try await interceptor.intercept(&urlRequest)
        }

        return urlRequest
    }

    // MARK: - Execution + retry

    private func execute(_ request: URLRequest, retriesRemaining: Int) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            try validate(response, data: data)
            return data
        } catch APIError.rateLimited(let retryAfter) {
            guard retriesRemaining > 0 else { throw APIError.rateLimited(retryAfter: retryAfter) }
            try await Task.sleep(for: .seconds(retryAfter))
            return try await execute(request, retriesRemaining: retriesRemaining - 1)
        } catch APIError.serverError(let code) where (500...599).contains(code) {
            guard retriesRemaining > 0 else { throw APIError.serverError(code) }
            let attempt = configuration.maxRetries - retriesRemaining
            let delay = min(pow(2.0, Double(attempt)), 30)   // 1s, 2s, 4s … capped at 30s
            try await Task.sleep(for: .seconds(delay))
            return try await execute(request, retriesRemaining: retriesRemaining - 1)
        } catch let apiError as APIError {
            throw apiError
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Validation

    private func validate(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            let retryAfter = http.retryAfterSeconds ?? 60
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            throw APIError.serverError(http.statusCode)
        }
    }

    // MARK: - Decoding

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        // Gracefully handle 204 No Content / empty bodies when T is EmptyResponse
        let source = data.isEmpty ? Data("{}".utf8) : data
        do {
            return try decoder.decode(T.self, from: source)
        } catch {
            throw APIError.decodingFailed
        }
    }
}

// MARK: - Retry-After header parsing

private extension HTTPURLResponse {
    var retryAfterSeconds: TimeInterval? {
        guard let value = value(forHTTPHeaderField: "Retry-After") else { return nil }
        if let seconds = TimeInterval(value) { return seconds }
        // RFC 7231 HTTP-date fallback
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSinceNow)
    }
}
```

---

### `GitHubModels.swift`

```swift
import Foundation

struct GitHubRepo: Decodable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let htmlUrl: String
    let stargazersCount: Int
    let forksCount: Int
    let language: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, language
        case fullName       = "full_name"
        case htmlUrl        = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount     = "forks_count"
        case isPrivate      = "private"
    }
}

struct GitHubUser: Decodable {
    let login: String
    let name: String?
    let publicRepos: Int
    let followers: Int

    enum CodingKeys: String, CodingKey {
        case login, name, followers
        case publicRepos = "public_repos"
    }
}
```

---

### `GitHubService.swift`

```swift
import Foundation

final class GitHubService {
    private let client: APIClient

    /// - Parameter token: Optional personal access token for higher rate limits.
    init(token: String? = nil) {
        let baseURL = URL(string: "https://api.github.com")!

        var interceptors: [RequestInterceptor] = [
            StaticHeadersInterceptor(headers: ["X-GitHub-Api-Version": "2022-11-28"])
        ]
        if let token {
            interceptors.append(BearerTokenInterceptor(tokenProvider: { token }))
        }

        let config = APIClientConfiguration(
            baseURL: baseURL,
            defaultHeaders: [
                "Content-Type": "application/json",
                "Accept":       "application/vnd.github+json"
            ]
        )

        client = APIClient(
            configuration: config,
            interceptors: interceptors,
            cache: CacheManager(defaultTTL: 60)
        )
    }

    // MARK: - Endpoints

    func repos(
        for username: String,
        sort: String = "updated",
        perPage: Int = 30
    ) async throws -> [GitHubRepo] {
        try await client.get(
            "/users/\(username)/repos",
            queryItems: [
                URLQueryItem(name: "sort",     value: sort),
                URLQueryItem(name: "per_page", value: String(perPage))
            ],
            cacheTTL: 300  // 5 minutes
        )
    }

    func repo(owner: String, name: String) async throws -> GitHubRepo {
        try await client.get("/repos/\(owner)/\(name)", cacheTTL: 300)
    }

    func user(_ username: String) async throws -> GitHubUser {
        try await client.get("/users/\(username)", cacheTTL: 600)
    }
}
```

---

### `GitHubExample.swift`

```swift
import SwiftUI

// MARK: - ViewModel

@MainActor
final class ReposViewModel: ObservableObject {
    @Published var repos: [GitHubRepo] = []
    @Published var errorMessage: String?
    @Published var isLoading = false

    private let service: GitHubService

    init(service: GitHubService = GitHubService()) {
        self.service = service
    }

    func loadRepos(for username: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            repos = try await service.repos(for: username)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct ReposView: View {
    @StateObject private var vm = ReposViewModel()
    private let username = "apple"

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("Loading…")
                } else if let error = vm.errorMessage {
                    ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
                } else {
                    List(vm.repos) { repo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repo.name).font(.headline)
                            if let desc = repo.description {
                                Text(desc).font(.subheadline).foregroundStyle(.secondary)
                            }
                            HStack(spacing: 12) {
                                Label("\(repo.stargazersCount)", systemImage: "star")
                                Label("\(repo.forksCount)",      systemImage: "tuningfork")
                                if let lang = repo.language {
                                    Text(lang).font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("\(username)'s Repos")
            .task { await vm.loadRepos(for: username) }
        }
    }
}
```

---

## Architecture summary

| File | Responsibility |
|---|---|
| `APIError.swift` | Typed error domain |
| `RequestInterceptor.swift` | Protocol + `BearerTokenInterceptor`, `StaticHeadersInterceptor` |
| `CacheManager.swift` | Actor-safe TTL cache |
| `APIRequest.swift` | `HTTPMethod`, `APIRequest<Body>`, `EmptyBody`, `EmptyResponse` |
| `APIClient.swift` | Core client — build, intercept, execute, retry, cache, decode |
| `GitHubModels.swift` | `GitHubRepo`, `GitHubUser` |
| `GitHubService.swift` | Thin service wrapping `APIClient` for GitHub's API |
| `GitHubExample.swift` | SwiftUI `ObservableObject` ViewModel + List view |

**Retry behavior:** 5xx errors use exponential backoff (`1s → 2s → 4s`, capped at 30s). 429s sleep for the `Retry-After` header value (defaults to 60s if absent). Both stop after `maxRetries` (default 3) and rethrow the original `APIError`.

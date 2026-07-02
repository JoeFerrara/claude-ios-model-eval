Here are all the files for a production-quality Swift networking layer:

---

### `APIError.swift`

```swift
import Foundation

public enum APIError: Error, LocalizedError {
    case badURL
    case unauthorized
    case serverError(Int)
    case decodingFailed
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .badURL:
            return "The request URL is invalid."
        case .unauthorized:
            return "Authentication required. Check your credentials."
        case .serverError(let code):
            return "Server returned status code \(code)."
        case .decodingFailed:
            return "Failed to decode the server response."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter) seconds."
        }
    }
}
```

---

### `HTTPMethod.swift`

```swift
public enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}
```

---

### `APIRequest.swift`

```swift
import Foundation

/// Placeholder body type for requests with no body (GET, DELETE, etc.)
public struct EmptyBody: Encodable {}

/// Placeholder response type for endpoints that return no body (e.g. 204 No Content)
public struct EmptyResponse: Decodable {}

public protocol APIRequest {
    associatedtype Response: Decodable
    associatedtype Body: Encodable = EmptyBody

    /// Path relative to the client's base URL, e.g. "/users/apple/repos"
    var path: String { get }
    var method: HTTPMethod { get }
    /// Per-request headers merged on top of interceptor-provided headers
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Body? { get }
}

// MARK: - Default Implementations

public extension APIRequest {
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem]? { nil }
}

public extension APIRequest where Body == EmptyBody {
    var body: EmptyBody? { nil }
}
```

---

### `RequestInterceptor.swift`

```swift
import Foundation

/// Modify an outgoing URLRequest before it is sent — add auth headers, trace IDs, etc.
public protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

// MARK: - Built-in Interceptors

public struct BearerTokenInterceptor: RequestInterceptor {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func intercept(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

public struct BasicAuthInterceptor: RequestInterceptor {
    private let encoded: String

    public init(username: String, password: String) {
        self.encoded = Data("\(username):\(password)".utf8).base64EncodedString()
    }

    public func intercept(_ request: inout URLRequest) async throws {
        request.setValue("Basic \(encoded)", forHTTPHeaderField: "Authorization")
    }
}
```

---

### `ResponseCache.swift`

```swift
import Foundation

actor ResponseCache {
    private struct Entry {
        let data: Data
        let expiresAt: Date

        var isExpired: Bool { Date() >= expiresAt }
    }

    private var storage: [String: Entry] = [:]

    func get(for key: String) -> Data? {
        guard let entry = storage[key] else { return nil }
        guard !entry.isExpired else {
            storage.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func set(_ data: Data, for key: String, ttl: TimeInterval) {
        storage[key] = Entry(data: data, expiresAt: Date().addingTimeInterval(ttl))
    }

    func invalidate(for key: String) {
        storage.removeValue(forKey: key)
    }

    func invalidateAll() {
        storage.removeAll()
    }

    func purgeExpired() {
        storage = storage.filter { !$0.value.isExpired }
    }
}
```

---

### `APIClient.swift`

```swift
import Foundation

public struct APIClient {

    // MARK: - Configuration

    private let baseURL: URL
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let cache: ResponseCache
    private let maxRetries: Int

    // MARK: - Init

    /// - Parameters:
    ///   - baseURL: Root URL for all requests, e.g. `https://api.github.com`
    ///   - session: Defaults to `.shared`; inject a custom session for testing
    ///   - interceptors: Applied in order before each request is sent
    ///   - decoder: Defaults to a plain `JSONDecoder`; configure key strategies here
    ///   - encoder: Defaults to a plain `JSONEncoder`
    ///   - maxRetries: How many times to retry 429 / 5xx responses (default 3)
    public init(
        baseURL: URL,
        session: URLSession = .shared,
        interceptors: [any RequestInterceptor] = [],
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptors = interceptors
        self.decoder = decoder
        self.encoder = encoder
        self.cache = ResponseCache()
        self.maxRetries = maxRetries
    }

    // MARK: - Public API

    /// Perform a typed network request.
    ///
    /// - Parameters:
    ///   - apiRequest: A value conforming to `APIRequest` that describes the endpoint.
    ///   - cacheTTL: When provided, GET responses are cached for this many seconds.
    /// - Returns: The decoded `Response` associated type.
    @discardableResult
    public func perform<R: APIRequest>(
        _ apiRequest: R,
        cacheTTL: TimeInterval? = nil
    ) async throws -> R.Response {
        let url = try buildURL(for: apiRequest)
        let cacheKey = url.absoluteString

        // Serve from cache for GET requests
        if apiRequest.method == .GET, let cached = await cache.get(for: cacheKey) {
            return try decodeResponse(cached)
        }

        var urlRequest = try buildURLRequest(for: apiRequest, url: url)

        for interceptor in interceptors {
            try await interceptor.intercept(&urlRequest)
        }

        let (data, _) = try await executeWithRetry(urlRequest)

        // Cache successful GET responses
        if apiRequest.method == .GET, let ttl = cacheTTL {
            await cache.set(data, for: cacheKey, ttl: ttl)
        }

        return try decodeResponse(data)
    }

    public func invalidateCache(for path: String) async {
        guard let url = URL(string: path, relativeTo: baseURL) else { return }
        await cache.invalidate(for: url.absoluteString)
    }

    public func invalidateAllCache() async {
        await cache.invalidateAll()
    }

    // MARK: - URL + Request Building

    private func buildURL<R: APIRequest>(for apiRequest: R) throws -> URL {
        // Strip leading slash so appendingPathComponent behaves consistently
        let trimmed = apiRequest.path.hasPrefix("/")
            ? String(apiRequest.path.dropFirst())
            : apiRequest.path

        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(trimmed),
            resolvingAgainstBaseURL: true
        ) else {
            throw APIError.badURL
        }

        if let items = apiRequest.queryItems, !items.isEmpty {
            components.queryItems = items
        }

        guard let url = components.url else {
            throw APIError.badURL
        }

        return url
    }

    private func buildURLRequest<R: APIRequest>(for apiRequest: R, url: URL) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = apiRequest.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        for (key, value) in apiRequest.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = apiRequest.body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }

    // MARK: - Retry + Execution

    /// Executes the request, retrying on 429 and 5xx up to `maxRetries` times
    /// using exponential backoff. Respects the `Retry-After` header for 429s.
    private func executeWithRetry(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0

        while true {
            try Task.checkCancellation()

            do {
                let (data, response) = try await session.data(for: urlRequest)

                guard let http = response as? HTTPURLResponse else {
                    throw APIError.networkError(URLError(.badServerResponse))
                }

                switch http.statusCode {
                case 200...299:
                    return (data, http)

                case 401:
                    throw APIError.unauthorized // never retried

                case 429:
                    let retryAfter = http.retryAfterInterval ?? pow(2.0, Double(attempt))
                    guard attempt < maxRetries else {
                        throw APIError.rateLimited(retryAfter: retryAfter)
                    }
                    try await sleep(seconds: retryAfter)

                case 500...599:
                    guard attempt < maxRetries else {
                        throw APIError.serverError(http.statusCode)
                    }
                    try await sleep(seconds: pow(2.0, Double(attempt)))

                default:
                    throw APIError.serverError(http.statusCode) // never retried
                }

            } catch is CancellationError {
                throw CancellationError()
            } catch let error as APIError {
                throw error // already classified; do not wrap or retry
            } catch {
                guard attempt < maxRetries else {
                    throw APIError.networkError(error)
                }
                try await sleep(seconds: pow(2.0, Double(attempt)))
            }

            attempt += 1
        }
    }

    // MARK: - Helpers

    private func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Decodes `data` into `T`. Passes `{}` for empty bodies so that
    /// `EmptyResponse` (used for 204 No Content) decodes without error.
    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        let effective = data.isEmpty ? Data("{}".utf8) : data
        do {
            return try decoder.decode(T.self, from: effective)
        } catch {
            throw APIError.decodingFailed
        }
    }
}

// MARK: - HTTPURLResponse + Retry-After

private extension HTTPURLResponse {
    /// Returns the `Retry-After` value in seconds, supporting both numeric
    /// (e.g. `"120"`) and HTTP-date (e.g. `"Wed, 21 Oct 2025 07:28:00 GMT"`) formats.
    var retryAfterInterval: TimeInterval? {
        guard let raw = value(forHTTPHeaderField: "Retry-After") else { return nil }

        if let seconds = TimeInterval(raw) {
            return max(0, seconds)
        }

        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        if let date = fmt.date(from: raw) {
            return max(0, date.timeIntervalSinceNow)
        }

        return nil
    }
}
```

---

### `GitHubAPI.swift`

```swift
import Foundation

// MARK: - Models

public struct GitHubRepo: Decodable, Identifiable {
    public let id: Int
    public let name: String
    public let fullName: String
    public let description: String?
    public let htmlURL: String
    public let stargazersCount: Int
    public let forksCount: Int
    public let language: String?
    public let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description, language
        case fullName       = "full_name"
        case htmlURL        = "html_url"
        case stargazersCount = "stargazers_count"
        case forksCount     = "forks_count"
        case isPrivate      = "private"
    }
}

public struct GitHubUser: Decodable {
    public let login: String
    public let id: Int
    public let name: String?
    public let bio: String?
    public let publicRepos: Int
    public let followers: Int

    enum CodingKeys: String, CodingKey {
        case login, id, name, bio, followers
        case publicRepos = "public_repos"
    }
}

public struct NewRepoBody: Encodable {
    public let name: String
    public let description: String?
    public let isPrivate: Bool

    public init(name: String, description: String? = nil, isPrivate: Bool = false) {
        self.name = name
        self.description = description
        self.isPrivate = isPrivate
    }

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPrivate = "private"
    }
}

// MARK: - Request Types

public struct FetchUserReposRequest: APIRequest {
    public typealias Response = [GitHubRepo]

    public let username: String
    public let sort: String
    public let perPage: Int

    public var path: String { "/users/\(username)/repos" }
    public var method: HTTPMethod { .GET }
    public var queryItems: [URLQueryItem]? {
        [
            URLQueryItem(name: "sort",     value: sort),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
    }

    public init(username: String, sort: String = "updated", perPage: Int = 30) {
        self.username = username
        self.sort     = sort
        self.perPage  = perPage
    }
}

public struct FetchUserRequest: APIRequest {
    public typealias Response = GitHubUser

    public let username: String
    public var path: String   { "/users/\(username)" }
    public var method: HTTPMethod { .GET }

    public init(username: String) { self.username = username }
}

public struct CreateRepoRequest: APIRequest {
    public typealias Response = GitHubRepo
    public typealias Body     = NewRepoBody

    public var path: String   { "/user/repos" }
    public var method: HTTPMethod { .POST }
    public var body: NewRepoBody?

    public init(body: NewRepoBody) { self.body = body }
}

public struct DeleteRepoRequest: APIRequest {
    public typealias Response = EmptyResponse   // 204 No Content

    public let owner: String
    public let repo: String
    public var path: String   { "/repos/\(owner)/\(repo)" }
    public var method: HTTPMethod { .DELETE }

    public init(owner: String, repo: String) {
        self.owner = owner
        self.repo  = repo
    }
}

// MARK: - GitHub-specific Interceptor

/// Adds the Accept and API-version headers GitHub requires.
private struct GitHubHeadersInterceptor: RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws {
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28",                  forHTTPHeaderField: "X-GitHub-Api-Version")
    }
}

// MARK: - High-level Service

public final class GitHubService {
    private let client: APIClient

    public init(token: String) {
        let decoder = JSONDecoder()
        // snake_case → camelCase handled via explicit CodingKeys above,
        // but .convertFromSnakeCase would work equally well here.

        client = APIClient(
            baseURL: URL(string: "https://api.github.com")!,
            interceptors: [
                BearerTokenInterceptor(token: token),
                GitHubHeadersInterceptor()
            ],
            decoder: decoder
        )
    }

    /// Returns all repos for `username`, cached for 5 minutes.
    public func repos(for username: String) async throws -> [GitHubRepo] {
        try await client.perform(
            FetchUserReposRequest(username: username),
            cacheTTL: 300
        )
    }

    /// Returns public profile info for `username`, cached for 10 minutes.
    public func user(_ username: String) async throws -> GitHubUser {
        try await client.perform(
            FetchUserRequest(username: username),
            cacheTTL: 600
        )
    }

    /// Creates a new repo under the authenticated user's account.
    public func createRepo(
        name: String,
        description: String? = nil,
        isPrivate: Bool = false
    ) async throws -> GitHubRepo {
        try await client.perform(
            CreateRepoRequest(body: NewRepoBody(
                name: name,
                description: description,
                isPrivate: isPrivate
            ))
        )
    }

    /// Deletes a repo. Succeeds silently on 204 No Content.
    public func deleteRepo(owner: String, repo: String) async throws {
        try await client.perform(DeleteRepoRequest(owner: owner, repo: repo))
    }
}

// MARK: - Example Usage (call from a Task or async context)

/*
 let service = GitHubService(token: "ghp_yourTokenHere")

 // --- Fetch repos ---
 do {
     let repos = try await service.repos(for: "apple")
     for repo in repos {
         print("\(repo.name)  ★\(repo.stargazersCount)  \(repo.language ?? "—")")
     }
 } catch APIError.unauthorized {
     print("Bad token")
 } catch APIError.rateLimited(let after) {
     print("Rate limited — retry in \(after)s")
 } catch APIError.serverError(let code) {
     print("Server error \(code)")
 } catch APIError.networkError(let err) {
     print("Network: \(err.localizedDescription)")
 }

 // --- Fetch a user ---
 let user = try await service.user("torvalds")
 print("\(user.login) has \(user.publicRepos) public repos and \(user.followers) followers")

 // --- Create a repo ---
 let created = try await service.createRepo(
     name: "swift-networking-demo",
     description: "Reusable async/await networking layer",
     isPrivate: false
 )
 print("Created: \(created.htmlURL)")

 // --- Delete a repo ---
 try await service.deleteRepo(owner: "myusername", repo: "old-project")
*/
```

---

### Architecture summary

| File | Responsibility |
|---|---|
| `APIError.swift` | Typed errors with `LocalizedError` descriptions |
| `HTTPMethod.swift` | Strongly typed `GET / POST / PUT / DELETE` |
| `APIRequest.swift` | Generic request protocol; `EmptyBody` / `EmptyResponse` helpers |
| `RequestInterceptor.swift` | Pre-send mutation hook; `Bearer` + `Basic` built-ins |
| `ResponseCache.swift` | `actor`-isolated, TTL-keyed in-memory cache |
| `APIClient.swift` | Core engine: URL building, interceptors, retry loop, decode |
| `GitHubAPI.swift` | Concrete models, request types, service wrapper, usage examples |

**Key design decisions:**
- `APIClient` is a `struct` — all mutable state lives in `ResponseCache`, which is an `actor` and handles its own data-race safety.
- `executeWithRetry` is an iterative `while true` loop (not recursive), so stack depth is constant regardless of retry count.
- `Task.checkCancellation()` is called at the top of every retry cycle so cooperative cancellation is respected immediately.
- `401` and non-5xx errors are thrown immediately with no retry.
- The `Retry-After` header is parsed for both numeric seconds and HTTP-date formats.
- Empty responses (204 No Content) are handled by falling back to `{}` before decoding, so `EmptyResponse: Decodable` works without special-casing in the caller.

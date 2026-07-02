## APIError.swift

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
        case .badURL: "Invalid URL"
        case .unauthorized: "Unauthorized"
        case .serverError(let code): "Server error: \(code)"
        case .decodingFailed: "Failed to decode response"
        case .networkError(let error): "Network error: \(error.localizedDescription)"
        case .rateLimited(let delay): "Rate limited — retry after \(Int(delay))s"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .badURL: "Check that the URL is properly formatted"
        case .unauthorized: "Verify your authentication credentials"
        case .serverError: "Try again later"
        case .decodingFailed: "The response format may have changed"
        case .networkError: "Check your internet connection"
        case .rateLimited: "Wait before retrying"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .serverError(let code): (500...599).contains(code)
        case .rateLimited, .networkError: true
        case .badURL, .unauthorized, .decodingFailed: false
        }
    }
}
```

## HTTPMethod.swift

```swift
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
```

## APIRequest.swift

```swift
import Foundation

protocol APIRequest<Response> {
    associatedtype Response: Decodable

    var baseURL: URL { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: (any Encodable)? { get }
}

extension APIRequest {
    var headers: [String: String] { ["Content-Type": "application/json"] }
    var body: (any Encodable)? { nil }

    var url: URL {
        baseURL.appending(path: path)
    }
}
```

## RequestInterceptor.swift

```swift
import Foundation

protocol RequestInterceptor: Sendable {
    func intercept(_ request: inout URLRequest) async throws
}

struct AuthInterceptor: RequestInterceptor {
    let token: String

    func intercept(_ request: inout URLRequest) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
```

## CacheManager.swift

```swift
import Foundation
import CryptoKit

actor CacheManager {
    private let directory: URL

    private struct Entry: Codable {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval

        var isExpired: Bool {
            Date.now.timeIntervalSince(timestamp) > ttl
        }
    }

    init() {
        directory = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "APICache")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func get(for key: String) -> Data? {
        let url = fileURL(for: key)
        guard let raw = try? Data(contentsOf: url),
              let entry = try? JSONDecoder().decode(Entry.self, from: raw) else {
            return nil
        }
        if entry.isExpired {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        return entry.data
    }

    func set(_ data: Data, for key: String, ttl: TimeInterval) {
        let entry = Entry(data: data, timestamp: .now, ttl: ttl)
        guard let encoded = try? JSONEncoder().encode(entry) else { return }
        try? encoded.write(to: fileURL(for: key))
    }

    func remove(for key: String) {
        try? FileManager.default.removeItem(at: fileURL(for: key))
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String) -> URL {
        let hash = SHA256.hash(data: Data(key.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return directory.appending(path: hash)
    }
}
```

## APIClient.swift

```swift
import Foundation

final class APIClient: @unchecked Sendable {
    private let session: URLSession
    private let interceptors: [any RequestInterceptor]
    private let cacheManager = CacheManager()

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(session: URLSession = .shared, interceptors: [any RequestInterceptor] = []) {
        self.session = session
        self.interceptors = interceptors
    }

    func request<R: APIRequest>(_ apiRequest: R, cacheTTL: TimeInterval = 0) async throws -> R.Response {
        let url = apiRequest.url
        let cacheKey = "\(apiRequest.method.rawValue):\(url.absoluteString)"

        if apiRequest.method == .get, cacheTTL > 0,
           let cached = await cacheManager.get(for: cacheKey) {
            return try decoder.decode(R.Response.self, from: cached)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = apiRequest.method.rawValue
        urlRequest.allHTTPHeaderFields = apiRequest.headers

        if let body = apiRequest.body {
            urlRequest.httpBody = try encoder.encode(body)
        }

        for interceptor in interceptors {
            try await interceptor.intercept(&urlRequest)
        }

        let data = try await performWithRetry(urlRequest, maxRetries: 3)

        if apiRequest.method == .get, cacheTTL > 0 {
            await cacheManager.set(data, for: cacheKey, ttl: cacheTTL)
        }

        do {
            return try decoder.decode(R.Response.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Private

    private func performWithRetry(_ request: URLRequest, maxRetries: Int) async throws -> Data {
        var lastError: APIError = .networkError(URLError(.unknown))

        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    throw APIError.networkError(URLError(.badServerResponse))
                }

                switch http.statusCode {
                case 200...299:
                    return data
                case 401:
                    throw APIError.unauthorized
                case 429:
                    let delay = retryAfter(from: http) ?? backoff(attempt)
                    throw APIError.rateLimited(retryAfter: delay)
                default:
                    throw APIError.serverError(http.statusCode)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as APIError where error.isRetryable && attempt < maxRetries {
                lastError = error
                let delay: TimeInterval
                if case .rateLimited(let retryAfter) = error {
                    delay = retryAfter
                } else {
                    delay = backoff(attempt)
                }
                try await Task.sleep(for: .seconds(delay))
            } catch let error as APIError {
                throw error
            } catch {
                lastError = .networkError(error)
                guard attempt < maxRetries else { throw lastError }
                try await Task.sleep(for: .seconds(backoff(attempt)))
            }
        }

        throw lastError
    }

    private func backoff(_ attempt: Int) -> TimeInterval {
        pow(2.0, Double(attempt))
    }

    private func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        response.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
    }
}
```

## Example.swift

```swift
import Foundation

// MARK: - GitHub API

struct GitHubReposRequest: APIRequest {
    typealias Response = [GitHubRepo]

    let username: String

    var baseURL: URL { URL(string: "https://api.github.com")! }
    var path: String { "/users/\(username)/repos" }
    var method: HTTPMethod { .get }
    var headers: [String: String] { ["Accept": "application/vnd.github.v3+json"] }
}

struct GitHubRepo: Decodable {
    let id: Int
    let name: String
    let fullName: String
    let htmlURL: URL
    let description: String?
    let stargazersCount: Int
    let language: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, language
        case fullName = "full_name"
        case htmlURL = "html_url"
        case stargazersCount = "stargazers_count"
    }
}
```

---

**Bugs fixed:**
- `CacheManager.hashKey` used `String.hashValue` which is **non-deterministic across launches** — replaced with `SHA256`
- `CancellationError` was swallowed into `.networkError` during retry sleeps — now propagated
- Decoding failures after a successful HTTP response threw raw `DecodingError` instead of `APIError.decodingFailed`
- 4xx errors (e.g. 403, 404) were retried as if they were server errors — `isRetryable` now only retries 5xx

**Modernized:**
- `CacheManager` → `actor` (thread safety)
- `Task.sleep(for: .seconds(...))` instead of nanosecond arithmetic
- `Response: Decodable` (not `Codable` — responses are only decoded)
- `(any Encodable)?` explicit existential, encoded via SE-0352 implicit opening
- `APIRequest<Response>` primary associated type syntax
- `@unchecked Sendable` on `APIClient`, `Sendable` on `RequestInterceptor`
- `AuthInterceptor` → `struct`
- `URL.appending(path:)` instead of deprecated `appendingPathComponent`
- `Date.now` instead of `Date()`
- Implicit switch returns, closure-initialized encoder/decoder

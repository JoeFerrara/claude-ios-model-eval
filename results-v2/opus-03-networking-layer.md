Here's the complete networking layer:

## APIError.swift

```swift
import Foundation

enum APIError: Error, LocalizedError {
    case badURL
    case unauthorized
    case serverError(Int)
    case decodingFailed
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid URL"
        case .unauthorized:
            return "Unauthorized (401)"
        case .serverError(let code):
            return "Server error (\(code))"
        case .decodingFailed:
            return "Failed to decode response"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            return "Rate limited. Retry after \(retryAfter)s"
        }
    }
}
```

## HTTPMethod.swift

```swift
import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}
```

## APIRequest.swift

```swift
import Foundation

struct APIRequest<Response: Decodable> {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: (any Encodable)?

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: (any Encodable)? = nil
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
    }
}
```

## RequestInterceptor.swift

```swift
import Foundation

protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

struct BearerTokenInterceptor: RequestInterceptor {
    let token: () -> String?

    func intercept(_ request: inout URLRequest) async throws {
        if let token = token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }
}
```

## ResponseCache.swift

```swift
import Foundation

actor ResponseCache {
    private struct Entry {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
        var isExpired: Bool { Date().timeIntervalSince(timestamp) > ttl }
    }

    private var store: [String: Entry] = [:]
    private let defaultTTL: TimeInterval

    init(defaultTTL: TimeInterval = 300) {
        self.defaultTTL = defaultTTL
    }

    func get(for key: String) -> Data? {
        guard let entry = store[key], !entry.isExpired else {
            store.removeValue(forKey: key)
            return nil
        }
        return entry.data
    }

    func set(_ data: Data, for key: String, ttl: TimeInterval? = nil) {
        store[key] = Entry(data: data, timestamp: Date(), ttl: ttl ?? defaultTTL)
    }

    func clear() {
        store.removeAll()
    }
}
```

## APIClient.swift

```swift
import Foundation

final class APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let cache: ResponseCache
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let maxRetries: Int

    init(
        baseURL: URL,
        session: URLSession = .shared,
        interceptors: [RequestInterceptor] = [],
        cache: ResponseCache = ResponseCache(),
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        maxRetries: Int = 3
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptors = interceptors
        self.cache = cache
        self.decoder = decoder
        self.encoder = encoder
        self.maxRetries = maxRetries
    }

    func send<T: Decodable>(_ request: APIRequest<T>, cacheTTL: TimeInterval? = nil) async throws -> T {
        let urlRequest = try await buildURLRequest(from: request)
        let cacheKey = urlRequest.url?.absoluteString ?? request.path

        // Check cache for GET requests
        if request.method == .get, let cached = await cache.get(for: cacheKey) {
            if let decoded = try? decoder.decode(T.self, from: cached) {
                return decoded
            }
        }

        let data = try await executeWithRetry(urlRequest, attempt: 0)

        // Cache GET responses
        if request.method == .get {
            await cache.set(data, for: cacheKey, ttl: cacheTTL)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    // MARK: - Private

    private func buildURLRequest<T>(from request: APIRequest<T>) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path), resolvingAgainstBaseURL: true) else {
            throw APIError.badURL
        }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems
        }

        guard let url = components.url else {
            throw APIError.badURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(body)
            if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        for interceptor in interceptors {
            try await interceptor.intercept(&urlRequest)
        }

        return urlRequest
    }

    private func executeWithRetry(_ request: URLRequest, attempt: Int) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200..<300:
                return data

            case 401:
                throw APIError.unauthorized

            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(TimeInterval.init) ?? pow(2.0, Double(attempt))

                if attempt < maxRetries {
                    try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                    return try await executeWithRetry(request, attempt: attempt + 1)
                }
                throw APIError.rateLimited(retryAfter: retryAfter)

            case 500...599:
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    return try await executeWithRetry(request, attempt: attempt + 1)
                }
                throw APIError.serverError(httpResponse.statusCode)

            default:
                throw APIError.serverError(httpResponse.statusCode)
            }

        } catch let error as APIError {
            throw error
        } catch {
            if attempt < maxRetries {
                let delay = pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            throw APIError.networkError(error)
        }
    }
}
```

## GitHubModels.swift

```swift
import Foundation

struct GitHubRepo: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let stargazersCount: Int
    let language: String?
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, description, language
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case htmlUrl = "html_url"
    }
}
```

## GitHubService.swift

```swift
import Foundation

struct GitHubService {
    private let client: APIClient

    init(token: String? = nil) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var interceptors: [RequestInterceptor] = []
        if let token {
            interceptors.append(BearerTokenInterceptor(token: { token }))
        }

        self.client = APIClient(
            baseURL: URL(string: "https://api.github.com")!,
            interceptors: interceptors,
            cache: ResponseCache(defaultTTL: 60),
            decoder: decoder
        )
    }

    func fetchRepos(for username: String) async throws -> [GitHubRepo] {
        let request = APIRequest<[GitHubRepo]>(
            path: "/users/\(username)/repos",
            headers: ["Accept": "application/vnd.github.v3+json"],
            queryItems: [
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "per_page", value: "30")
            ]
        )
        return try await client.send(request, cacheTTL: 120)
    }
}
```

## ExampleUsage.swift

```swift
import SwiftUI

@Observable
final class RepoListViewModel {
    private(set) var repos: [GitHubRepo] = []
    private(set) var errorMessage: String?
    private(set) var isLoading = false

    private let service = GitHubService()

    func loadRepos(for username: String) async {
        isLoading = true
        errorMessage = nil

        do {
            repos = try await service.fetchRepos(for: username)
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

struct RepoListView: View {
    @State private var viewModel = RepoListViewModel()
    @State private var username = "apple"

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading…")
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
                } else {
                    List(viewModel.repos) { repo in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repo.name).font(.headline)
                            if let desc = repo.description {
                                Text(desc).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                            }
                            HStack {
                                if let lang = repo.language {
                                    Label(lang, systemImage: "chevron.left.forwardslash.chevron.right")
                                }
                                Label("\(repo.stargazersCount)", systemImage: "star")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Repos")
            .searchable(text: $username, prompt: "GitHub username")
            .onSubmit(of: .search) {
                Task { await viewModel.loadRepos(for: username) }
            }
            .task {
                await viewModel.loadRepos(for: username)
            }
        }
    }
}
```

---

**Summary of the architecture:**

- **`APIError`** — 6 typed error cases including `rateLimited(retryAfter:)` and `serverError(Int)`
- **`APIRequest<Response>`** — generic request struct parameterized by its `Decodable` response type
- **`RequestInterceptor`** — protocol for mutating outgoing `URLRequest`s (auth headers, logging, etc.). Ships with `BearerTokenInterceptor`.
- **`ResponseCache`** — actor-based in-memory cache with per-entry configurable TTL
- **`APIClient`** — the core engine: builds requests, runs interceptors, executes with automatic retry (exponential backoff, respects `Retry-After` header on 429), caches GET responses, decodes the typed response
- **`GitHubService`** / **`RepoListView`** — concrete example wiring it all together in a SwiftUI screen

Retry logic: network errors, 429, and 5xx responses retry up to 3 times with `2^attempt` second delays. 429 retries honor the server's `Retry-After` header when present. All other errors (401, 4xx, decode failures) fail immediately.

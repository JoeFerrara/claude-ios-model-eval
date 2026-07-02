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

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

import Foundation

struct APIRequest<Response: Decodable> {
    let path: String
    let method: HTTPMethod
    let body: Encodable?
    let queryItems: [URLQueryItem]?
    let headers: [String: String]?

    init(
        path: String,
        method: HTTPMethod = .get,
        body: Encodable? = nil,
        queryItems: [URLQueryItem]? = nil,
        headers: [String: String]? = nil
    ) {
        self.path = path
        self.method = method
        self.body = body
        self.queryItems = queryItems
        self.headers = headers
    }
}

import Foundation

protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

struct BearerTokenInterceptor: RequestInterceptor {
    let tokenProvider: () async -> String?

    func intercept(_ request: inout URLRequest) async throws {
        guard let token = await tokenProvider() else { return }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}

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

    func remove(for key: String) {
        store.removeValue(forKey: key)
    }

    func removeAll() {
        store.removeAll()
    }
}

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

    func send<T: Decodable>(
        _ request: APIRequest<T>,
        cacheTTL: TimeInterval? = nil
    ) async throws -> T {
        let urlRequest = try await buildURLRequest(from: request)
        let cacheKey = urlRequest.url!.absoluteString

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
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: true
        ) else {
            throw APIError.badURL
        }

        components.queryItems = request.queryItems

        guard let url = components.url else {
            throw APIError.badURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(AnyEncodable(body))
        }

        for interceptor in interceptors {
            try await interceptor.intercept(&urlRequest)
        }

        return urlRequest
    }

    private func executeWithRetry(_ request: URLRequest, attempt: Int) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            if attempt < maxRetries {
                try await backoff(attempt: attempt)
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                NSError(domain: "APIClient", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Invalid response type"
                ])
            )
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return data

        case 401:
            throw APIError.unauthorized

        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap(TimeInterval.init) ?? pow(2, Double(attempt))
            if attempt < maxRetries {
                try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            throw APIError.rateLimited(retryAfter: retryAfter)

        case 500...599:
            if attempt < maxRetries {
                try await backoff(attempt: attempt)
                return try await executeWithRetry(request, attempt: attempt + 1)
            }
            throw APIError.serverError(httpResponse.statusCode)

        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }

    private func backoff(attempt: Int) async throws {
        let delay = pow(2.0, Double(attempt)) // 1s, 2s, 4s
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
}

import Foundation

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ wrapped: Encodable) {
        self.encodeFunc = wrapped.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

import Foundation

// MARK: - Models

struct GitHubRepo: Codable {
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

struct CreateRepoBody: Encodable {
    let name: String
    let description: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case name, description
        case isPrivate = "private"
    }
}

// MARK: - Service

struct GitHubService {
    private let client: APIClient

    init(token: String? = nil) {
        let decoder = JSONDecoder()

        var interceptors: [RequestInterceptor] = []
        if let token {
            interceptors.append(BearerTokenInterceptor { token })
        }

        client = APIClient(
            baseURL: URL(string: "https://api.github.com")!,
            interceptors: interceptors,
            cache: ResponseCache(defaultTTL: 120),
            decoder: decoder
        )
    }

    func fetchRepos(for username: String) async throws -> [GitHubRepo] {
        let request = APIRequest<[GitHubRepo]>(
            path: "/users/\(username)/repos",
            queryItems: [
                URLQueryItem(name: "sort", value: "updated"),
                URLQueryItem(name: "per_page", value: "30")
            ]
        )
        return try await client.send(request, cacheTTL: 60)
    }

    func createRepo(name: String, description: String?, isPrivate: Bool) async throws -> GitHubRepo {
        let request = APIRequest<GitHubRepo>(
            path: "/user/repos",
            method: .post,
            body: CreateRepoBody(name: name, description: description, isPrivate: isPrivate)
        )
        return try await client.send(request)
    }
}

// MARK: - Usage in a ViewModel

@MainActor
final class RepoListViewModel: ObservableObject {
    @Published var repos: [GitHubRepo] = []
    @Published var error: String?
    @Published var isLoading = false

    private let service = GitHubService()

    func loadRepos(for username: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            repos = try await service.fetchRepos(for: username)
        } catch let apiError as APIError {
            error = apiError.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}


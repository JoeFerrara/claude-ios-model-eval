import Foundation

enum APIError: Error, LocalizedError {
    case badURL
    case unauthorized
    case serverError(Int)
    case decodingFailed(Error)
    case networkError(Error)
    case rateLimited(retryAfter: TimeInterval)
    case invalidRequest

    var errorDescription: String? {
        switch self {
        case .badURL:
            "Invalid URL"
        case .unauthorized:
            "Unauthorized – invalid credentials"
        case .serverError(let code):
            "Server error: \(code)"
        case .decodingFailed(let error):
            "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            "Rate limited – retry after \(Int(retryAfter)) seconds"
        case .invalidRequest:
            "Invalid request"
        }
    }
}

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

protocol APIRequest {
    associatedtype ResponseType: Codable

    var method: HTTPMethod { get }
    var path: String { get }
    var queryParameters: [String: String]? { get }
    var body: (any Encodable)? { get }
    var headers: [String: String]? { get }
}

extension APIRequest {
    var queryParameters: [String: String]? { nil }
    var body: (any Encodable)? { nil }
    var headers: [String: String]? { nil }
}

import Foundation

protocol RequestInterceptor: Sendable {
    func intercept(_ request: URLRequest) async throws -> URLRequest
}

import Foundation

struct ResponseCache {
    private struct Entry {
        let data: Data
        let expiresAt: Date
    }

    private var storage: [String: Entry] = [:]

    func get(_ key: String) -> Data? {
        guard let entry = storage[key], entry.expiresAt > .now else { return nil }
        return entry.data
    }

    mutating func set(_ key: String, data: Data, ttl: TimeInterval) {
        storage[key] = Entry(data: data, expiresAt: .now.addingTimeInterval(ttl))
    }

    mutating func removeAll() {
        storage.removeAll()
    }
}

import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let interceptor: (any RequestInterceptor)?
    private var cache = ResponseCache()
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let maxRetries = 3

    init(
        baseURL: URL,
        session: URLSession = .shared,
        interceptor: (any RequestInterceptor)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptor = interceptor
    }

    func request<R: APIRequest>(
        _ request: R,
        cacheTTL: TimeInterval? = nil
    ) async throws -> R.ResponseType {
        let cacheKey = cacheKey(for: request)

        if cacheTTL != nil, let cachedData = cache.get(cacheKey) {
            return try decode(R.ResponseType.self, from: cachedData)
        }

        let data = try await performWithRetry(request)

        if let cacheTTL {
            cache.set(cacheKey, data: data, ttl: cacheTTL)
        }

        return try decode(R.ResponseType.self, from: data)
    }

    // MARK: - Private

    private func performWithRetry<R: APIRequest>(_ request: R) async throws -> Data {
        var lastError: (any Error)?

        for attempt in 0..<maxRetries {
            do {
                let urlRequest = try await buildURLRequest(for: request)
                let (data, response) = try await session.data(for: urlRequest)
                try validateResponse(response)
                return data
            } catch {
                lastError = error

                let retryable: Bool
                if let apiError = error as? APIError {
                    retryable = isRetryable(apiError)
                } else {
                    retryable = true
                }

                guard retryable, attempt < maxRetries - 1 else { throw error }
                try await Task.sleep(for: .seconds(pow(2.0, Double(attempt))))
            }
        }

        throw lastError ?? APIError.networkError(URLError(.unknown))
    }

    private func buildURLRequest<R: APIRequest>(for request: R) async throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw APIError.badURL
        }

        components.path = request.path

        if let queryParams = request.queryParameters {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw APIError.badURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        request.headers?.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let interceptor {
            urlRequest = try await interceptor.intercept(urlRequest)
        }

        if let body = request.body {
            urlRequest.httpBody = try body.encodedData(using: encoder)
        }

        return urlRequest
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidRequest
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            let retry = TimeInterval(http.value(forHTTPHeaderField: "Retry-After") ?? "") ?? 60
            throw APIError.rateLimited(retryAfter: retry)
        default:
            throw APIError.serverError(http.statusCode)
        }
    }

    private func isRetryable(_ error: APIError) -> Bool {
        switch error {
        case .rateLimited:
            true
        case .serverError(let code):
            code >= 500
        default:
            false
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }

    private func cacheKey<R: APIRequest>(for request: R) -> String {
        var key = "\(request.method.rawValue):\(request.path)"
        if let params = request.queryParameters {
            let sorted = params.sorted { $0.key < $1.key }
            key += "?" + sorted.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        }
        return key
    }
}

private extension Encodable {
    func encodedData(using encoder: JSONEncoder) throws -> Data {
        try encoder.encode(self)
    }
}

import Foundation

struct GitHubRepo: Codable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let url: URL
    let language: String?
    let starsCount: Int
    let forksCount: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case fullName = "full_name"
        case description
        case url = "html_url"
        case language
        case starsCount = "stargazers_count"
        case forksCount = "forks_count"
    }
}

struct GetUserReposRequest: APIRequest {
    typealias ResponseType = [GitHubRepo]

    let username: String

    var method: HTTPMethod { .get }
    var path: String { "/users/\(username)/repos" }
    var queryParameters: [String: String]? {
        ["sort": "stars", "per_page": "10", "type": "public"]
    }
}

import Foundation

struct GitHubAuthInterceptor: RequestInterceptor {
    let token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var request = request
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        return request
    }
}

import SwiftUI

struct ContentView: View {
    @State private var repos: [GitHubRepo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var username = "apple"
    @State private var apiClient = APIClient(
        baseURL: URL(string: "https://api.github.com")!,
        interceptor: GitHubAuthInterceptor()
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLoading)
                        .onSubmit(searchRepos)
                }
                .padding(.horizontal)

                if let errorMessage {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(errorMessage)
                        Spacer()
                    }
                    .padding()
                    .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal)
                }

                if isLoading {
                    ProgressView()
                        .frame(maxHeight: .infinity)
                } else if repos.isEmpty {
                    if errorMessage == nil {
                        VStack(spacing: 20) {
                            Image(systemName: "folder")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Enter a GitHub username and tap Search")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxHeight: .infinity)
                    }
                } else {
                    List(repos, id: \.id) { repo in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(repo.name)
                                .font(.headline)

                            if let description = repo.description {
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            HStack(spacing: 16) {
                                Label("\(repo.starsCount)", systemImage: "star.fill")
                                    .font(.caption2)
                                if let language = repo.language {
                                    Label(language, systemImage: "chevron.left.forwardslash.chevron.right")
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("GitHub Repos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: searchRepos) {
                        Image(systemName: "magnifyingglass")
                    }
                    .disabled(isLoading || username.isEmpty)
                }
            }
        }
    }

    private func searchRepos() {
        guard !username.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                repos = try await apiClient.request(
                    GetUserReposRequest(username: username),
                    cacheTTL: 300
                )
            } catch {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI

@main
struct GitHubReposApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


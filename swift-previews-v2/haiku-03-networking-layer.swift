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
            return "Invalid URL"
        case .unauthorized:
            return "Unauthorized - invalid credentials"
        case .serverError(let code):
            return "Server error: \(code)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            return "Rate limited - retry after \(Int(retryAfter)) seconds"
        case .invalidRequest:
            return "Invalid request"
        }
    }
}

import Foundation

protocol APIRequest {
    associatedtype ResponseType: Codable
    
    var method: HTTPMethod { get }
    var path: String { get }
    var queryParameters: [String: String]? { get }
    var body: Encodable? { get }
    var headers: [String: String]? { get }
}

extension APIRequest {
    var queryParameters: [String: String]? { nil }
    var body: Encodable? { nil }
    var headers: [String: String]? { nil }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
}

import Foundation

protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

import Foundation

final class ResponseCache {
    private struct CachedResponse {
        let data: Data
        let expiresAt: Date
    }
    
    private var cache: [String: CachedResponse] = [:]
    private let queue = DispatchQueue(label: "com.api.cache.queue", attributes: .concurrent)
    
    func get(_ key: String) -> Data? {
        queue.sync {
            guard let cached = cache[key] else { return nil }
            guard cached.expiresAt > Date() else { return nil }
            return cached.data
        }
    }
    
    func set(_ key: String, data: Data, ttl: TimeInterval) {
        queue.async(flags: .barrier) {
            self.cache[key] = CachedResponse(
                data: data,
                expiresAt: Date().addingTimeInterval(ttl)
            )
        }
    }
    
    func remove(_ key: String) {
        queue.async(flags: .barrier) {
            self.cache.removeValue(forKey: key)
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) {
            self.cache.removeAll()
        }
    }
}

import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let interceptor: RequestInterceptor?
    private let cache: ResponseCache
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    private let maxRetries = 3
    
    init(
        baseURL: URL,
        session: URLSession = .shared,
        interceptor: RequestInterceptor? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.interceptor = interceptor
        self.cache = ResponseCache()
        
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }
    
    func request<Request: APIRequest>(
        _ request: Request,
        cacheTTL: TimeInterval? = nil
    ) async throws -> Request.ResponseType {
        let cacheKey = generateCacheKey(method: request.method.rawValue, path: request.path)
        
        // Check cache if TTL specified
        if let cacheTTL = cacheTTL, let cachedData = cache.get(cacheKey) {
            return try decoder.decode(Request.ResponseType.self, from: cachedData)
        }
        
        // Perform request with retry logic
        let data = try await performRequestWithRetry(request)
        
        // Cache response if TTL specified
        if let cacheTTL = cacheTTL {
            cache.set(cacheKey, data: data, ttl: cacheTTL)
        }
        
        // Decode and return
        return try decoder.decode(Request.ResponseType.self, from: data)
    }
    
    private func performRequestWithRetry<Request: APIRequest>(
        _ request: Request
    ) async throws -> Data {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                let urlRequest = try buildURLRequest(for: request)
                let (data, response) = try await session.data(for: urlRequest)
                
                // Validate and return on success
                try validateResponse(response, data: data)
                return data
                
            } catch let error as APIError {
                lastError = error
                
                // Determine if we should retry
                let shouldRetry = shouldRetryError(error)
                
                if shouldRetry && attempt < maxRetries - 1 {
                    let delay = exponentialBackoffDelay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw error
                
            } catch {
                lastError = APIError.networkError(error)
                
                // Retry network errors with backoff
                if attempt < maxRetries - 1 {
                    let delay = exponentialBackoffDelay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw lastError ?? APIError.networkError(error)
            }
        }
        
        throw lastError ?? APIError.networkError(URLError(.unknown))
    }
    
    private func buildURLRequest<Request: APIRequest>(
        for request: Request
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
        components?.path = request.path
        
        if let queryParams = request.queryParameters {
            components?.queryItems = queryParams.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        }
        
        guard let url = components?.url else {
            throw APIError.badURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        // Set default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add custom headers
        if let headers = request.headers {
            headers.forEach { key, value in
                urlRequest.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Apply interceptor for auth headers, etc
        if let interceptor = interceptor {
            try await interceptor.intercept(&urlRequest)
        }
        
        // Encode body if present
        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(body)
        }
        
        return urlRequest
    }
    
    private func validateResponse(
        _ response: URLResponse,
        data: Data
    ) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidRequest
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 429:
            let retryAfter = extractRetryAfter(from: httpResponse)
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 400...499:
            throw APIError.serverError(httpResponse.statusCode)
        case 500...599:
            throw APIError.serverError(httpResponse.statusCode)
        default:
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    private func shouldRetryError(_ error: APIError) -> Bool {
        switch error {
        case .rateLimited, .serverError:
            return true
        default:
            return false
        }
    }
    
    private func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfter) {
            return seconds
        }
        return 60.0
    }
    
    private func exponentialBackoffDelay(for attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s
        return pow(2.0, Double(attempt))
    }
    
    private func generateCacheKey(method: String, path: String) -> String {
        return "\(method):\(path)"
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
        case id
        case name
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

class GitHubAuthInterceptor: RequestInterceptor {
    private let token: String?
    
    init(token: String? = nil) {
        self.token = token
    }
    
    func intercept(_ request: inout URLRequest) async throws {
        if let token = token {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
    }
}

import SwiftUI

struct ContentView: View {
    @State private var repos: [GitHubRepo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var apiClient: APIClient?
    @State private var username: String = "apple"
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .disabled(isLoading)
                    }
                    .padding()
                    
                    if repos.isEmpty && !isLoading && errorMessage == nil {
                        VStack(spacing: 20) {
                            Image(systemName: "repo")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("Enter a GitHub username and tap Search")
                                .foregroundColor(.gray)
                        }
                        .frame(maxHeight: .infinity)
                    } else if isLoading {
                        ProgressView()
                            .frame(maxHeight: .infinity)
                    } else {
                        List(repos, id: \.id) { repo in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(repo.name)
                                    .font(.headline)
                                
                                if let description = repo.description {
                                    Text(description)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                                
                                HStack(spacing: 16) {
                                    Label("\(repo.starsCount)", systemImage: "star.fill")
                                        .font(.caption2)
                                    
                                    if let language = repo.language {
                                        Label(language, systemImage: "code")
                                            .font(.caption2)
                                    }
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let errorMessage = errorMessage {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.circle")
                            Text(errorMessage)
                            Spacer()
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: searchRepos) {
                            Image(systemName: "magnifyingglass")
                        }
                        .disabled(isLoading || username.isEmpty)
                    }
                }
                .navigationTitle("GitHub Repos")
            }
            .task {
                setupAPIClient()
            }
        }
    }
    
    private func setupAPIClient() {
        let baseURL = URL(string: "https://api.github.com")!
        let interceptor = GitHubAuthInterceptor()
        apiClient = APIClient(
            baseURL: baseURL,
            interceptor: interceptor
        )
    }
    
    private func searchRepos() {
        guard let apiClient = apiClient else { return }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let request = GetUserReposRequest(username: username)
                let repos = try await apiClient.request(request, cacheTTL: 300)
                
                await MainActor.run {
                    self.repos = repos
                    self.isLoading = false
                }
            } catch let error as APIError {
                await MainActor.run {
                    self.errorMessage = error.errorDescription ?? "Unknown error"
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
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


I'll build a complete, production-ready networking layer for you. Here are all the components:

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
        case .badURL:
            return "Invalid URL"
        case .unauthorized:
            return "Unauthorized - check your credentials"
        case .serverError(let code):
            return "Server error with code: \(code)"
        case .decodingFailed:
            return "Failed to decode response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited(let retryAfter):
            return "Rate limited - retry after \(Int(retryAfter)) seconds"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .badURL:
            return "Check that the URL is properly formatted"
        case .unauthorized:
            return "Verify your authentication token or credentials"
        case .serverError:
            return "The server encountered an error. Try again later"
        case .decodingFailed:
            return "The response format may have changed"
        case .networkError:
            return "Check your internet connection"
        case .rateLimited:
            return "Wait before making the next request"
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

protocol APIRequest {
    associatedtype Response: Codable
    
    var baseURL: URL { get }
    var endpoint: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var body: Encodable? { get }
    
    func url() throws -> URL
}

extension APIRequest {
    var headers: [String: String] {
        ["Content-Type": "application/json"]
    }
    
    var body: Encodable? {
        nil
    }
    
    func url() throws -> URL {
        let fullURL = baseURL.appendingPathComponent(endpoint)
        guard let url = URLComponents(url: fullURL, resolvingAgainstBaseURL: true)?.url else {
            throw APIError.badURL
        }
        return url
    }
}
```

## RequestInterceptor.swift

```swift
import Foundation

protocol RequestInterceptor {
    func intercept(_ request: inout URLRequest) async throws
}

// MARK: - Example: AuthInterceptor

class AuthInterceptor: RequestInterceptor {
    private let token: String
    
    init(token: String) {
        self.token = token
    }
    
    func intercept(_ request: inout URLRequest) async throws {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
```

## CacheManager.swift

```swift
import Foundation

class CacheManager {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    private struct CacheEntry: Codable {
        let data: Data
        let timestamp: Date
        let ttl: TimeInterval
        
        func isExpired() -> Bool {
            Date().timeIntervalSince(timestamp) > ttl
        }
    }
    
    init() {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("APICache")
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    func get(for key: String) -> Data? {
        let fileURL = cacheDirectory.appendingPathComponent(hashKey(key))
        guard let data = try? Data(contentsOf: fileURL),
              let entry = try? PropertyListDecoder().decode(CacheEntry.self, from: data) else {
            return nil
        }
        
        if entry.isExpired() {
            try? fileManager.removeItem(at: fileURL)
            return nil
        }
        
        return entry.data
    }
    
    func set(_ data: Data, for key: String, ttl: TimeInterval) {
        let entry = CacheEntry(data: data, timestamp: Date(), ttl: ttl)
        guard let encodedData = try? PropertyListEncoder().encode(entry) else { return }
        let fileURL = cacheDirectory.appendingPathComponent(hashKey(key))
        try? encodedData.write(to: fileURL)
    }
    
    func remove(for key: String) {
        let fileURL = cacheDirectory.appendingPathComponent(hashKey(key))
        try? fileManager.removeItem(at: fileURL)
    }
    
    func clear() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func hashKey(_ key: String) -> String {
        String(abs(key.hashValue))
    }
}
```

## APIClient.swift

```swift
import Foundation

class APIClient {
    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    private let cacheManager = CacheManager()
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    init(session: URLSession = .shared, interceptors: [RequestInterceptor] = []) {
        self.session = session
        self.interceptors = interceptors
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    /// Performs an API request with automatic retry and caching
    /// - Parameters:
    ///   - request: The API request to perform
    ///   - cacheTTL: Time to live for cache in seconds (0 = no cache)
    /// - Returns: The decoded response
    func request<Request: APIRequest>(
        _ request: Request,
        cacheTTL: TimeInterval = 0
    ) async throws -> Request.Response {
        let url = try request.url()
        
        // Check cache for GET requests only
        let cacheKey = "\(request.method.rawValue):\(url.absoluteString)"
        if request.method == .get && cacheTTL > 0, let cachedData = cacheManager.get(for: cacheKey) {
            return try decoder.decode(Request.Response.self, from: cachedData)
        }
        
        // Build request
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.allHTTPHeaderFields = request.headers
        
        // Encode body if present
        if let body = request.body {
            urlRequest.httpBody = try encoder.encode(body)
        }
        
        // Apply interceptors
        for interceptor in interceptors {
            try await interceptor.intercept(&urlRequest)
        }
        
        // Perform request with retry logic
        let responseData = try await performRequestWithRetry(urlRequest, maxRetries: 3)
        
        // Cache successful responses
        if request.method == .get && cacheTTL > 0 {
            cacheManager.set(responseData, for: cacheKey, ttl: cacheTTL)
        }
        
        return try decoder.decode(Request.Response.self, from: responseData)
    }
    
    // MARK: - Private Methods
    
    private func performRequestWithRetry(_ urlRequest: URLRequest, maxRetries: Int) async throws -> Data {
        var lastError: APIError?
        
        for attempt in 0...maxRetries {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.networkError(URLError(.badServerResponse))
                }
                
                // Handle status codes
                switch httpResponse.statusCode {
                case 200...299:
                    return data
                    
                case 401:
                    throw APIError.unauthorized
                    
                case 429:
                    let retryAfter = extractRetryAfter(from: httpResponse) ?? pow(2.0, Double(attempt))
                    if attempt < maxRetries {
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                        continue
                    }
                    throw APIError.rateLimited(retryAfter: retryAfter)
                    
                case 500...599:
                    let serverError = APIError.serverError(httpResponse.statusCode)
                    if attempt < maxRetries {
                        let delay = pow(2.0, Double(attempt))
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        lastError = serverError
                        continue
                    }
                    throw serverError
                    
                default:
                    throw APIError.networkError(URLError(.badServerResponse))
                }
            } catch let error as APIError {
                // Re-throw API errors immediately
                throw error
            } catch let error as URLError where error.code == .timedOut {
                // Retry on timeout
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw APIError.networkError(error)
            } catch {
                // Network error - retry if attempts remaining
                lastError = APIError.networkError(error)
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                    throw lastError ?? APIError.networkError(error)
                }
            }
        }
        
        throw lastError ?? APIError.networkError(URLError(.unknown))
    }
    
    private func extractRetryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After") {
            // Try parsing as seconds (integer)
            if let seconds = TimeInterval(retryAfter) {
                return seconds
            }
            // Could also parse HTTP-date format here if needed
        }
        return nil
    }
}
```

## Example.swift

```swift
import Foundation

// MARK: - GitHub API Models

struct GitHubReposRequest: APIRequest {
    typealias Response = [GitHubRepo]
    
    let username: String
    
    var baseURL: URL {
        URL(string: "https://api.github.com")!
    }
    
    var endpoint: String {
        "/users/\(username)/repos"
    }
    
    var method: HTTPMethod {
        .get
    }
    
    var headers: [String: String] {
        ["Accept": "application/vnd.github.v3+json"]
    }
}

struct GitHubRepo: Codable {
    let id: Int
    let name: String
    let fullName: String
    let htmlUrl: URL
    let description: String?
    let stargazersCount: Int
    let language: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, language
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case description
        case stargazersCount = "stargazers_count"
    }
}

// MARK: - Usage Example

/*
// Create client (optionally with interceptors)
let authInterceptor = AuthInterceptor(token: "your_github_token")
let client = APIClient(interceptors: [authInterceptor])

// Fetch GitHub repos
Task {
    do {
        let request = GitHubReposRequest(username: "torvalds")
        let repos = try await client.request(request, cacheTTL: 3600) // Cache for 1 hour
        
        // Display results
        for repo in repos.sorted(by: { $0.stargazersCount > $1.stargazersCount }).prefix(5) {
            print("📦 \(repo.name)")
            print("   ⭐ Stars: \(repo.stargazersCount)")
            if let description = repo.description {
                print("   📝 \(description)")
            }
            if let language = repo.language {
                print("   🔧 \(language)")
            }
            print()
        }
    } catch let error as APIError {
        print("❌ API Error: \(error.localizedDescription)")
        print("💡 \(error.recoverySuggestion ?? "")")
    } catch {
        print("❌ Unexpected error: \(error)")
    }
}
*/
```

## Key Features:

✅ **Generic async/await design** - Works with any `Codable` request/response  
✅ **Automatic retry with exponential backoff** - Handles 429 and 5xx errors (max 3 retries, 1s → 2s → 4s)  
✅ **Request interceptors** - Add auth headers, custom logging, etc.  
✅ **Response caching with TTL** - File-based, configurable per-request  
✅ **Comprehensive error handling** - Typed `APIError` with recovery suggestions  
✅ **Production-ready** - Proper HTTP status handling, timeout support, memory efficiency  

The example fetches the top GitHub repos by stars for any username with automatic caching and retry logic included.

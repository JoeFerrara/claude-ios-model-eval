Build a reusable networking layer in Swift for an iOS app. Requirements:
- Generic `APIClient` with async/await
- Support GET, POST, PUT, DELETE
- Typed request/response using Codable
- Custom error type `APIError` with cases: badURL, unauthorized, serverError(Int), decodingFailed, networkError(Error), rateLimited(retryAfter: TimeInterval)
- Automatic retry with exponential backoff (max 3 retries) for 429 and 5xx errors
- Request interceptor protocol for adding auth headers
- Response caching with configurable TTL
- Example usage: fetch a list of GitHub repos for a username

Output all code in separate logical files (APIClient.swift, APIError.swift, etc.). Do not include unit tests or XCTest code. All code must compile as a single iOS app target — no test targets, no XCTest imports, no @testable.
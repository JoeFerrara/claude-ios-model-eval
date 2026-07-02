Build a search-as-you-type feature using Combine. Requirements:
- `SearchService` class that takes a text publisher and returns search results
- Debounce input by 300ms
- Skip empty strings and duplicates
- Cancel in-flight requests when new input arrives (switchToLatest)
- Retry failed network requests up to 2 times with 1s delay
- Map network errors to a custom `SearchError` enum
- Emit loading/loaded/error states via a `SearchState<T>` enum
- Include a SwiftUI view that binds to this pipeline, showing: a TextField, loading indicator, results list, and error banner

Output all code. Do not include unit tests or XCTest code. All code must compile as a single iOS app target — no test targets, no XCTest imports, no @testable.
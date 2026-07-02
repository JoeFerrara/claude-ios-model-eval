# Swift Previews — Xcode Setup Guide

These `.swift` files contain extracted code from model evaluation results. Each file represents a single model's response to a specific Swift coding test.

## File Naming Convention

```
{model}-{test-number}-{test-name}.swift
```

- **Models**: `haiku`, `sonnet`, `opus`, `opus-review-of-haiku`
- **Tests**: `01-simple-list-view`, `02-core-data-crud`, `03-networking-layer`, `04-compositional-layout`, `05-combine-pipeline`, `06-full-feature`

## How to Preview in Xcode

### Option A: Quick Preview (Single File)

1. Open Xcode and create a new iOS App project (File > New > Project > App).
2. Set the minimum deployment target to **iOS 17.0**.
3. Copy any single `.swift` file into the project's Sources directory.
4. If the file has `#Preview { }` at the bottom, you can use Xcode's Canvas preview (Editor > Canvas).
5. Some files contain `@main` — remove or rename that attribute if your project already has an `@main` entry point.

### Option B: Side-by-Side Comparison

To compare models on the same test:

1. Create a new Xcode project.
2. For each model's version of a test, create a separate Swift file with unique type names. Since many files define the same type names (e.g., `Contact`, `ContactListView`), you will need to either:
   - Put each file in its own Swift package target, or
   - Rename conflicting types (e.g., prefix with the model name: `HaikuContact`, `SonnetContact`).

### Option C: Swift Package (Multiple Targets)

Create a `Package.swift` at the `swift-previews/` level:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ModelEvalPreviews",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        // One target per file to avoid naming conflicts
        .executableTarget(name: "Haiku01", path: ".", sources: ["haiku-01-simple-list-view.swift"]),
        .executableTarget(name: "Sonnet01", path: ".", sources: ["sonnet-01-simple-list-view.swift"]),
        .executableTarget(name: "Opus01", path: ".", sources: ["opus-01-simple-list-view.swift"]),
        // ... add more as needed
    ]
)
```

Note: This approach works for pure SwiftUI files but not for files that import UIKit or CoreData — those require an Xcode project with the appropriate frameworks linked.

## Framework Requirements by Test

| Test | Frameworks Required |
|------|-------------------|
| 01 - Simple List View | SwiftUI |
| 02 - Core Data CRUD | CoreData, Foundation |
| 03 - Networking Layer | Foundation, SwiftUI (for the demo view) |
| 04 - Compositional Layout | UIKit |
| 05 - Combine Pipeline | Combine, SwiftUI, XCTest (tests) |
| 06 - Full Feature | SwiftUI, PhotosUI, UIKit |

## Notes

- Files with multiple code blocks are concatenated with `// MARK: - Next Code Block` separators.
- Test 05 (Combine Pipeline) includes unit test classes — these require an XCTest target.
- Test 04 (Compositional Layout) uses UIKit and cannot use SwiftUI `#Preview` directly. Wrap in a `UIViewControllerRepresentable` or use Xcode's UIKit previews.
- Test 06 (Full Feature) references `PhotosPicker` from PhotosUI — requires iOS 16+.
- Some files reference `@testable import YourAppModule` — replace with your actual module name.

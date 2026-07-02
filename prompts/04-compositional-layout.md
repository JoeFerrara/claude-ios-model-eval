Build a UICollectionView with UICollectionViewCompositionalLayout that mimics the App Store "Today" tab. Requirements:
- Section 1: Featured banner — full-width, horizontally scrolling cards with paging behavior, 350pt tall
- Section 2: "Top Charts" — horizontal scrolling row of small square items (3 visible at a time)
- Section 3: "Categories" — vertical list of full-width cells, each 80pt tall
- Each section has a header with title and "See All" button
- Use UICollectionViewDiffableDataSource with proper item identifiers
- Implement self-sizing where appropriate
- Use modern UICollectionView cell registration (not register/dequeue)

Write it as a single UIViewController subclass with all supporting types. Do not include unit tests or XCTest code. All code must compile as a single iOS app target — no test targets, no XCTest imports, no @testable.
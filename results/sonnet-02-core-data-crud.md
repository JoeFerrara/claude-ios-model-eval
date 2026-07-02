```swift
// MARK: - Programmatic NSManagedObjectModel

import CoreData
import Foundation

private extension NSManagedObjectModel {
    static let taskModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "TaskItem"
        entity.managedObjectClassName = NSStringFromClass(TaskItem.self)

        func attr(
            _ name: String,
            _ type: NSAttributeType,
            optional: Bool = false,
            defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let d = NSAttributeDescription()
            d.name = name
            d.attributeType = type
            d.isOptional = optional
            if let v = defaultValue { d.defaultValue = v }
            return d
        }

        entity.properties = [
            attr("id",          .UUIDAttributeType),
            attr("title",       .stringAttributeType),
            attr("notes",       .stringAttributeType,    optional: true),
            attr("priority",    .integer16AttributeType, defaultValue: Int16(0)),
            attr("isCompleted", .booleanAttributeType,   defaultValue: false),
            attr("createdAt",   .dateAttributeType),
            attr("completedAt", .dateAttributeType,      optional: true),
        ]

        model.entities = [entity]
        return model
    }()
}

// MARK: - TaskItem (NSManagedObject)

@objc(TaskItem)
public final class TaskItem: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var notes: String?
    @NSManaged public var priority: Int16       // 0 = low, 1 = medium, 2 = high
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var completedAt: Date?

    public enum Priority: Int16, CaseIterable, Sendable {
        case low = 0, medium = 1, high = 2
    }
}

// MARK: - TaskItemValue
//
// NSManagedObject is not Sendable, so we convert to this value type before
// crossing actor/concurrency boundaries. Callers work entirely with this type.

public struct TaskItemValue: Sendable, Identifiable, Hashable {
    public let id: UUID
    public var title: String
    public var notes: String?
    public var priority: TaskItem.Priority
    public var isCompleted: Bool
    public let createdAt: Date
    public var completedAt: Date?

    fileprivate init(_ m: TaskItem) {
        id          = m.id
        title       = m.title
        notes       = m.notes
        priority    = TaskItem.Priority(rawValue: m.priority) ?? .low
        isCompleted = m.isCompleted
        createdAt   = m.createdAt
        completedAt = m.completedAt
    }
}

// MARK: - CoreDataStack

/// Immutable after initialisation, so @unchecked Sendable is safe.
public final class CoreDataStack: @unchecked Sendable {
    public static let shared = CoreDataStack()

    public let container: NSPersistentContainer

    /// Main-thread context for SwiftUI / UIKit bindings.
    public var viewContext: NSManagedObjectContext { container.viewContext }

    public init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "TaskManager",
            managedObjectModel: .taskModel
        )
        if inMemory {
            container.persistentStoreDescriptions.first?.url =
                URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data failed to load: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }
}

// MARK: - TaskStoreError

public enum TaskStoreError: Error, LocalizedError {
    case notFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .notFound(let id): "No TaskItem found with id \(id)."
        }
    }
}

// MARK: - TaskStore

public actor TaskStore {
    private let stack: CoreDataStack

    public init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    // MARK: Fetch

    /// All tasks sorted by priority (high → low), then createdAt (oldest first).
    public func fetchAll() async throws -> [TaskItemValue] {
        try await perform { ctx in
            let req = NSFetchRequest<TaskItem>(entityName: "TaskItem")
            req.sortDescriptors = [
                NSSortDescriptor(key: "priority",  ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: true),
            ]
            return try ctx.fetch(req).map(TaskItemValue.init)
        }
    }

    /// Tasks for a single priority level, sorted by createdAt (oldest first).
    public func fetchByPriority(_ priority: TaskItem.Priority) async throws -> [TaskItemValue] {
        try await perform { ctx in
            let req = NSFetchRequest<TaskItem>(entityName: "TaskItem")
            req.predicate       = NSPredicate(format: "priority == %d", priority.rawValue)
            req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try ctx.fetch(req).map(TaskItemValue.init)
        }
    }

    // MARK: Create

    @discardableResult
    public func create(
        title: String,
        notes: String? = nil,
        priority: TaskItem.Priority = .medium
    ) async throws -> TaskItemValue {
        try await saving { ctx in
            let item         = TaskItem(context: ctx)
            item.id          = UUID()
            item.title       = title
            item.notes       = notes
            item.priority    = priority.rawValue
            item.isCompleted = false
            item.createdAt   = Date()
            item.completedAt = nil
            return TaskItemValue(item)
        }
    }

    // MARK: Update

    public func update(
        id: UUID,
        title: String? = nil,
        notes: String? = nil,
        priority: TaskItem.Priority? = nil
    ) async throws {
        try await saving { ctx in
            let item = try Self.find(id: id, in: ctx)
            if let title    { item.title    = title }
            if let notes    { item.notes    = notes }
            if let priority { item.priority = priority.rawValue }
        }
    }

    // MARK: Delete

    public func delete(id: UUID) async throws {
        try await saving { ctx in
            ctx.delete(try Self.find(id: id, in: ctx))
        }
    }

    // MARK: Toggle Complete

    @discardableResult
    public func toggleComplete(id: UUID) async throws -> TaskItemValue {
        try await saving { ctx in
            let item         = try Self.find(id: id, in: ctx)
            item.isCompleted.toggle()
            item.completedAt = item.isCompleted ? Date() : nil
            return TaskItemValue(item)
        }
    }

    // MARK: - Private helpers

    private static func find(id: UUID, in ctx: NSManagedObjectContext) throws -> TaskItem {
        let req = NSFetchRequest<TaskItem>(entityName: "TaskItem")
        req.predicate  = NSPredicate(format: "id == %@", id as CVarArg)
        req.fetchLimit = 1
        guard let item = try ctx.fetch(req).first else {
            throw TaskStoreError.notFound(id)
        }
        return item
    }

    /// Runs `work` on a private-queue context and returns its result.
    private func perform<T: Sendable>(
        _ work: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let ctx = stack.newBackgroundContext()
        return try await ctx.perform { try work(ctx) }
    }

    /// Like `perform`, but saves the context after `work` succeeds.
    @discardableResult
    private func saving<T: Sendable>(
        _ work: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let ctx = stack.newBackgroundContext()
        return try await ctx.perform {
            let result = try work(ctx)
            if ctx.hasChanges { try ctx.save() }
            return result
        }
    }
}
```

---

**Usage example**

```swift
let store = TaskStore()

// Create
let task = try await store.create(title: "Buy groceries", priority: .high)

// Fetch all (priority desc, createdAt asc)
let all = try await store.fetchAll()

// Fetch by priority
let highPri = try await store.fetchByPriority(.high)

// Update
try await store.update(id: task.id, title: "Buy groceries + snacks", notes: "Check coupon app")

// Toggle complete (stamps completedAt automatically)
let updated = try await store.toggleComplete(id: task.id)

// Delete
try await store.delete(id: task.id)
```

---

**Key design notes:**

- **No `.xcdatamodeld`** — `NSManagedObjectModel` is built once via a `static let` computed lazily with a closure, so the model is created exactly once.
- **`TaskItemValue` (Sendable DTO)** — `NSManagedObject` is not `Sendable`, so it can't safely cross actor boundaries. All public APIs return this value-type snapshot instead. It's also what you'd bind to SwiftUI views.
- **`actor TaskStore`** — serialises all writes; background contexts (`newBackgroundContext()`) handle heavy I/O off the main thread via `ctx.perform { }`.
- **`CoreDataStack` is `@unchecked Sendable`** — safe because `container` is set up in `init` and never mutated afterwards.
- **Testing** — pass `CoreDataStack(inMemory: true)` into `TaskStore` for unit tests; the `/dev/null` store keeps nothing on disk.

Here's the complete Core Data stack:

## TaskItem Entity (NSManagedObject subclass)

```swift
import CoreData
import Foundation

@objc(TaskItem)
public class TaskItem: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var notes: String?
    @NSManaged public var priority: Int16
    @NSManaged public var isCompleted: Bool
    @NSManaged public var createdAt: Date
    @NSManaged public var completedAt: Date?
}

extension TaskItem {
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "TaskItem"
        entity.managedObjectClassName = NSStringFromClass(TaskItem.self)

        let id = NSAttributeDescription()
        id.name = "id"
        id.attributeType = .UUIDAttributeType
        id.isOptional = false

        let title = NSAttributeDescription()
        title.name = "title"
        title.attributeType = .stringAttributeType
        title.isOptional = false

        let notes = NSAttributeDescription()
        notes.name = "notes"
        notes.attributeType = .stringAttributeType
        notes.isOptional = true

        let priority = NSAttributeDescription()
        priority.name = "priority"
        priority.attributeType = .integer16AttributeType
        priority.isOptional = false
        priority.defaultValue = Int16(1)

        let isCompleted = NSAttributeDescription()
        isCompleted.name = "isCompleted"
        isCompleted.attributeType = .booleanAttributeType
        isCompleted.isOptional = false
        isCompleted.defaultValue = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false

        let completedAt = NSAttributeDescription()
        completedAt.name = "completedAt"
        completedAt.attributeType = .dateAttributeType
        completedAt.isOptional = true

        entity.properties = [id, title, notes, priority, isCompleted, createdAt, completedAt]
        return entity
    }
}
```

## PersistenceController (Core Data stack)

```swift
import CoreData

actor PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let model = NSManagedObjectModel()
        model.entities = [TaskItem.entityDescription()]

        container = NSPersistentContainer(name: "TaskManager", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data store failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    nonisolated var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    nonisolated func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
```

## TaskStore

```swift
import CoreData
import Foundation

final class TaskStore: Sendable {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Fetch All (sorted by priority desc, then createdAt asc)

    func fetchAll() async throws -> [TaskItem] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<TaskItem>(entityName: "TaskItem")
            request.sortDescriptors = [
                NSSortDescriptor(key: "priority", ascending: false),
                NSSortDescriptor(key: "createdAt", ascending: true)
            ]
            return try context.fetch(request)
        }
    }

    // MARK: - Fetch by Priority

    func fetchByPriority(_ priority: Int16) async throws -> [TaskItem] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = NSFetchRequest<TaskItem>(entityName: "TaskItem")
            request.predicate = NSPredicate(format: "priority == %d", priority)
            request.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: true)
            ]
            return try context.fetch(request)
        }
    }

    // MARK: - Create

    @discardableResult
    func create(
        title: String,
        notes: String? = nil,
        priority: Int16 = 1
    ) async throws -> NSManagedObjectID {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let task = TaskItem(context: context)
            task.id = UUID()
            task.title = title
            task.notes = notes
            task.priority = max(0, min(2, priority))
            task.isCompleted = false
            task.createdAt = Date()
            task.completedAt = nil
            try context.save()
            return task.objectID
        }
    }

    // MARK: - Update

    func update(
        id: NSManagedObjectID,
        title: String? = nil,
        notes: String? = nil,
        priority: Int16? = nil
    ) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let task = try context.existingObject(with: id) as? TaskItem else {
                throw TaskStoreError.notFound
            }
            if let title { task.title = title }
            if let notes { task.notes = notes }
            if let priority { task.priority = max(0, min(2, priority)) }
            try context.save()
        }
    }

    // MARK: - Delete

    func delete(id: NSManagedObjectID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let object = try context.existingObject(with: id)
            context.delete(object)
            try context.save()
        }
    }

    // MARK: - Toggle Complete

    func toggleComplete(id: NSManagedObjectID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let task = try context.existingObject(with: id) as? TaskItem else {
                throw TaskStoreError.notFound
            }
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            try context.save()
        }
    }
}

enum TaskStoreError: Error, LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "Task not found"
        }
    }
}
```

**Key design decisions:**

- **Programmatic model** — `TaskItem.entityDescription()` builds the `NSEntityDescription` at runtime, no `.xcdatamodeld` needed.
- **Actor-based `PersistenceController`** — the container setup is isolated; `viewContext` and `newBackgroundContext()` are `nonisolated` since `NSPersistentContainer` is thread-safe for those accessors.
- **`TaskStore` is `Sendable`** — all mutation happens on background contexts via `context.perform`, so it's safe to call from any concurrency domain.
- **`create` returns `NSManagedObjectID`** — object IDs are thread-safe and can be used to fetch the object on any context (including the view context for UI binding).
- **`toggleComplete` sets `completedAt`** automatically — marking complete stamps the date, unmarking clears it.
- **Priority is clamped** to 0–2 on create/update to enforce the low/medium/high contract.
- **`inMemory` initializer** on `PersistenceController` makes unit testing straightforward — pass `inMemory: true` and each test gets a fresh store.

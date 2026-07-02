Here's the complete Core Data stack:

## TaskItem+CoreData.swift

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

        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false

        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false

        let notesAttr = NSAttributeDescription()
        notesAttr.name = "notes"
        notesAttr.attributeType = .stringAttributeType
        notesAttr.isOptional = true

        let priorityAttr = NSAttributeDescription()
        priorityAttr.name = "priority"
        priorityAttr.attributeType = .integer16AttributeType
        priorityAttr.isOptional = false
        priorityAttr.defaultValue = Int16(1)

        let isCompletedAttr = NSAttributeDescription()
        isCompletedAttr.name = "isCompleted"
        isCompletedAttr.attributeType = .booleanAttributeType
        isCompletedAttr.isOptional = false
        isCompletedAttr.defaultValue = false

        let createdAtAttr = NSAttributeDescription()
        createdAtAttr.name = "createdAt"
        createdAtAttr.attributeType = .dateAttributeType
        createdAtAttr.isOptional = false

        let completedAtAttr = NSAttributeDescription()
        completedAtAttr.name = "completedAt"
        completedAtAttr.attributeType = .dateAttributeType
        completedAtAttr.isOptional = true

        entity.properties = [
            idAttr, titleAttr, notesAttr, priorityAttr,
            isCompletedAttr, createdAtAttr, completedAtAttr
        ]

        return entity
    }
}
```

## PersistenceController.swift

```swift
import CoreData

struct PersistenceController {
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
}
```

## TaskStore.swift

```swift
import CoreData
import Foundation

actor TaskStore {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer = PersistenceController.shared.container) {
        self.container = container
    }

    // MARK: - Fetch All (sorted by priority desc, then createdAt asc)

    func fetchAll() throws -> [TaskItem] {
        let context = container.viewContext
        let request = NSFetchRequest<TaskItem>(entityName: "TaskItem")
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try context.performAndWait {
            try context.fetch(request)
        }
    }

    // MARK: - Create

    @discardableResult
    func create(
        title: String,
        notes: String? = nil,
        priority: Int16 = 1
    ) throws -> NSManagedObjectID {
        let context = container.newBackgroundContext()
        return try context.performAndWait {
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
        objectID: NSManagedObjectID,
        title: String? = nil,
        notes: String? = nil,
        priority: Int16? = nil
    ) throws {
        let context = container.newBackgroundContext()
        try context.performAndWait {
            guard let task = try context.existingObject(with: objectID) as? TaskItem else {
                return
            }
            if let title { task.title = title }
            if let notes { task.notes = notes }
            if let priority { task.priority = max(0, min(2, priority)) }
            try context.save()
        }
    }

    // MARK: - Delete

    func delete(objectID: NSManagedObjectID) throws {
        let context = container.newBackgroundContext()
        try context.performAndWait {
            let object = try context.existingObject(with: objectID)
            context.delete(object)
            try context.save()
        }
    }

    // MARK: - Toggle Complete

    func toggleComplete(objectID: NSManagedObjectID) throws {
        let context = container.newBackgroundContext()
        try context.performAndWait {
            guard let task = try context.existingObject(with: objectID) as? TaskItem else {
                return
            }
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            try context.save()
        }
    }

    // MARK: - Fetch by Priority

    func fetchByPriority(_ priority: Int16) throws -> [TaskItem] {
        let context = container.viewContext
        let request = NSFetchRequest<TaskItem>(entityName: "TaskItem")
        request.predicate = NSPredicate(format: "priority == %d", priority)
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdAt", ascending: true)
        ]
        return try context.performAndWait {
            try context.fetch(request)
        }
    }
}
```

## TaskManagerApp.swift

```swift
import SwiftUI

@main
struct TaskManagerApp: App {
    let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistence.container.viewContext)
        }
    }
}
```

## ContentView.swift

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Task Manager")
    }
}
```

**Design notes:**

- **`TaskStore` is an `actor`** — all mutable state access is serialized, making it safe under Swift concurrency. Callers `await` each method.
- **Writes use `newBackgroundContext()`** so the main thread is never blocked. The view context has `automaticallyMergesChangesFromParent = true` so it picks up changes immediately.
- **Reads use `viewContext`** wrapped in `performAndWait` for thread safety.
- **`create` returns `NSManagedObjectID`** (not the object itself) so it's safe to pass across context boundaries.
- **Priority is clamped** to 0–2 on create and update.
- **`toggleComplete`** automatically sets/clears `completedAt`.

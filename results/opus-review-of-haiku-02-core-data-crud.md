```swift
import CoreData
import Foundation

// MARK: - TaskItem Entity

@objc(TaskItem)
final class TaskItem: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var priority: Int16
    @NSManaged var isCompleted: Bool
    @NSManaged var createdAt: Date
    @NSManaged var completedAt: Date?
}

extension TaskItem {
    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskItem> {
        NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }
}

// MARK: - Core Data Stack

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init() {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "TaskItem"
        entity.managedObjectClassName = "TaskItem"
        entity.properties = [
            Self.attribute("id", type: .UUIDAttributeType),
            Self.attribute("title", type: .stringAttributeType),
            Self.attribute("notes", type: .stringAttributeType, isOptional: true),
            Self.attribute("priority", type: .integer16AttributeType, defaultValue: 0),
            Self.attribute("isCompleted", type: .booleanAttributeType, defaultValue: false),
            Self.attribute("createdAt", type: .dateAttributeType),
            Self.attribute("completedAt", type: .dateAttributeType, isOptional: true),
        ]

        model.entities = [entity]

        container = NSPersistentContainer(name: "TaskManager", managedObjectModel: model)
        container.loadPersistentStores { _, error in
            if let error {
                fatalError("Core Data failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func attribute(
        _ name: String,
        type: NSAttributeType,
        isOptional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = isOptional
        attribute.defaultValue = defaultValue
        return attribute
    }
}

// MARK: - Data Transfer Object

struct TaskItemData: Identifiable, Sendable {
    let id: UUID
    let title: String
    let notes: String?
    let priority: Int16
    let isCompleted: Bool
    let createdAt: Date
    let completedAt: Date?

    init(from taskItem: TaskItem) {
        id = taskItem.id
        title = taskItem.title
        notes = taskItem.notes
        priority = taskItem.priority
        isCompleted = taskItem.isCompleted
        createdAt = taskItem.createdAt
        completedAt = taskItem.completedAt
    }
}

// MARK: - Error Handling

enum TaskStoreError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "Task not found"
        }
    }
}

// MARK: - TaskStore

actor TaskStore {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer = CoreDataStack.shared.container) {
        self.container = container
    }

    private func performInBackground<T: Sendable>(
        _ block: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return try await context.perform { try block(context) }
    }

    private static func fetchOne(id: UUID, in context: NSManagedObjectContext) throws -> TaskItem {
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        guard let item = try context.fetch(request).first else {
            throw TaskStoreError.notFound
        }
        return item
    }

    // MARK: - Create

    func create(title: String, notes: String? = nil, priority: Int16 = 0) async throws -> UUID {
        try await performInBackground { context in
            let task = TaskItem(context: context)
            task.id = UUID()
            task.title = title
            task.notes = notes
            task.priority = priority
            task.isCompleted = false
            task.createdAt = Date()
            try context.save()
            return task.id
        }
    }

    // MARK: - Fetch All

    func fetchAll() async throws -> [TaskItemData] {
        try await performInBackground { context in
            let request = TaskItem.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \TaskItem.priority, ascending: false),
                NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false),
            ]
            return try context.fetch(request).map(TaskItemData.init)
        }
    }

    // MARK: - Fetch by Priority

    func fetchByPriority(_ priority: Int16) async throws -> [TaskItemData] {
        try await performInBackground { context in
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "priority == %d", priority)
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false),
            ]
            return try context.fetch(request).map(TaskItemData.init)
        }
    }

    // MARK: - Update

    func update(id: UUID, title: String? = nil, notes: String? = nil, priority: Int16? = nil) async throws {
        try await performInBackground { context in
            let task = try Self.fetchOne(id: id, in: context)
            if let title { task.title = title }
            if let notes { task.notes = notes }
            if let priority { task.priority = priority }
            try context.save()
        }
    }

    // MARK: - Toggle Complete

    func toggleComplete(id: UUID) async throws {
        try await performInBackground { context in
            let task = try Self.fetchOne(id: id, in: context)
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            try context.save()
        }
    }

    // MARK: - Delete

    func delete(id: UUID) async throws {
        try await performInBackground { context in
            let task = try Self.fetchOne(id: id, in: context)
            context.delete(task)
            try context.save()
        }
    }
}
```

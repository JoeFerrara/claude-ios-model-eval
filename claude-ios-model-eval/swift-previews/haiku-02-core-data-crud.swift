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
        return NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }
}

// MARK: - Core Data Stack
final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init() {
        let model = NSManagedObjectModel()

        let taskItemEntity = NSEntityDescription()
        taskItemEntity.name = "TaskItem"
        taskItemEntity.managedObjectClassName = "TaskItem"

        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false

        let titleAttribute = NSAttributeDescription()
        titleAttribute.name = "title"
        titleAttribute.attributeType = .stringAttributeType
        titleAttribute.isOptional = false

        let notesAttribute = NSAttributeDescription()
        notesAttribute.name = "notes"
        notesAttribute.attributeType = .stringAttributeType
        notesAttribute.isOptional = true

        let priorityAttribute = NSAttributeDescription()
        priorityAttribute.name = "priority"
        priorityAttribute.attributeType = .integer16AttributeType
        priorityAttribute.isOptional = false
        priorityAttribute.defaultValue = NSNumber(value: 0)

        let isCompletedAttribute = NSAttributeDescription()
        isCompletedAttribute.name = "isCompleted"
        isCompletedAttribute.attributeType = .booleanAttributeType
        isCompletedAttribute.isOptional = false
        isCompletedAttribute.defaultValue = NSNumber(value: false)

        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false

        let completedAtAttribute = NSAttributeDescription()
        completedAtAttribute.name = "completedAt"
        completedAtAttribute.attributeType = .dateAttributeType
        completedAtAttribute.isOptional = true

        taskItemEntity.attributes = [
            idAttribute,
            titleAttribute,
            notesAttribute,
            priorityAttribute,
            isCompletedAttribute,
            createdAtAttribute,
            completedAtAttribute
        ]

        model.entities = [taskItemEntity]

        container = NSPersistentContainer(name: "TaskManager", managedObjectModel: model)

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// MARK: - Data Transfer Object
struct TaskItemData: Identifiable {
    let id: UUID
    let title: String
    let notes: String?
    let priority: Int16
    let isCompleted: Bool
    let createdAt: Date
    let completedAt: Date?

    init(from taskItem: TaskItem) {
        self.id = taskItem.id
        self.title = taskItem.title
        self.notes = taskItem.notes
        self.priority = taskItem.priority
        self.isCompleted = taskItem.isCompleted
        self.createdAt = taskItem.createdAt
        self.completedAt = taskItem.completedAt
    }
}

// MARK: - Error Handling
enum TaskStoreError: LocalizedError {
    case notFound
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Task not found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}

// MARK: - TaskStore
actor TaskStore {
    private let container: NSPersistentContainer

    init(container: NSPersistentContainer = CoreDataStack.shared.container) {
        self.container = container
    }

    private nonisolated func performAsync<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func create(title: String, notes: String? = nil, priority: Int16 = 0) async throws -> UUID {
        return try await performAsync { context in
            let taskItem = TaskItem(context: context)
            taskItem.id = UUID()
            taskItem.title = title
            taskItem.notes = notes
            taskItem.priority = priority
            taskItem.isCompleted = false
            taskItem.createdAt = Date()

            try context.save()
            return taskItem.id
        }
    }

    func fetchAll() async throws -> [TaskItemData] {
        return try await performAsync { context in
            let request = TaskItem.fetchRequest()

            let prioritySort = NSSortDescriptor(key: "priority", ascending: false)
            let dateSort = NSSortDescriptor(key: "createdAt", ascending: false)
            request.sortDescriptors = [prioritySort, dateSort]

            let items = try context.fetch(request)
            return items.map { TaskItemData(from: $0) }
        }
    }

    func fetchByPriority(_ priority: Int16) async throws -> [TaskItemData] {
        return try await performAsync { context in
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "priority == %d", priority)

            let dateSort = NSSortDescriptor(key: "createdAt", ascending: false)
            request.sortDescriptors = [dateSort]

            let items = try context.fetch(request)
            return items.map { TaskItemData(from: $0) }
        }
    }

    func update(id: UUID, title: String? = nil, notes: String? = nil, priority: Int16? = nil) async throws {
        return try await performAsync { context in
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let taskItem = try context.fetch(request).first else {
                throw TaskStoreError.notFound
            }

            if let title = title {
                taskItem.title = title
            }
            if let notes = notes {
                taskItem.notes = notes
            }
            if let priority = priority {
                taskItem.priority = priority
            }

            try context.save()
        }
    }

    func toggleComplete(id: UUID) async throws {
        return try await performAsync { context in
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let taskItem = try context.fetch(request).first else {
                throw TaskStoreError.notFound
            }

            taskItem.isCompleted.toggle()
            taskItem.completedAt = taskItem.isCompleted ? Date() : nil

            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        return try await performAsync { context in
            let request = TaskItem.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

            guard let taskItem = try context.fetch(request).first else {
                throw TaskStoreError.notFound
            }

            context.delete(taskItem)
            try context.save()
        }
    }
}

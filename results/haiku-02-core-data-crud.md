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
        return NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }
}

// MARK: - Core Data Stack
final class CoreDataStack {
    static let shared = CoreDataStack()
    
    let container: NSPersistentContainer
    
    private init() {
        // Create managed object model programmatically
        let model = NSManagedObjectModel()
        
        let taskItemEntity = NSEntityDescription()
        taskItemEntity.name = "TaskItem"
        taskItemEntity.managedObjectClassName = "TaskItem"
        
        // ID attribute
        let idAttribute = NSAttributeDescription()
        idAttribute.name = "id"
        idAttribute.attributeType = .UUIDAttributeType
        idAttribute.isOptional = false
        
        // Title attribute
        let titleAttribute = NSAttributeDescription()
        titleAttribute.name = "title"
        titleAttribute.attributeType = .stringAttributeType
        titleAttribute.isOptional = false
        
        // Notes attribute
        let notesAttribute = NSAttributeDescription()
        notesAttribute.name = "notes"
        notesAttribute.attributeType = .stringAttributeType
        notesAttribute.isOptional = true
        
        // Priority attribute
        let priorityAttribute = NSAttributeDescription()
        priorityAttribute.name = "priority"
        priorityAttribute.attributeType = .integer16AttributeType
        priorityAttribute.isOptional = false
        priorityAttribute.defaultValue = NSNumber(value: 0)
        
        // isCompleted attribute
        let isCompletedAttribute = NSAttributeDescription()
        isCompletedAttribute.name = "isCompleted"
        isCompletedAttribute.attributeType = .booleanAttributeType
        isCompletedAttribute.isOptional = false
        isCompletedAttribute.defaultValue = NSNumber(value: false)
        
        // createdAt attribute
        let createdAtAttribute = NSAttributeDescription()
        createdAtAttribute.name = "createdAt"
        createdAtAttribute.attributeType = .dateAttributeType
        createdAtAttribute.isOptional = false
        
        // completedAt attribute
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
        
        // Create persistent container
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
    
    // Helper for async context operations
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
    
    // MARK: - Create
    /// Creates a new task item
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
    
    // MARK: - Fetch All
    /// Fetches all tasks sorted by priority (descending) then createdAt (descending)
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
    
    // MARK: - Fetch by Priority
    /// Fetches all tasks with a specific priority level, sorted by createdAt (descending)
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
    
    // MARK: - Update
    /// Updates an existing task with optional new values
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
    
    // MARK: - Toggle Complete
    /// Toggles the completion status of a task and updates completedAt timestamp
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
    
    // MARK: - Delete
    /// Deletes a task by ID
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
```

**Key features:**

- **TaskItem** — NSManagedObject with all required properties
- **CoreDataStack** — Singleton that builds the Core Data model programmatically without `.xcdatamodeld`
- **TaskStore** — Actor for thread-safe operations using modern Swift concurrency
  - `create()` — Creates tasks with optional notes and priority
  - `fetchAll()` — Returns all tasks sorted by priority (high→low) then creation date (newest first)
  - `fetchByPriority()` — Filters tasks by priority level
  - `update()` — Partially updates task properties
  - `toggleComplete()` — Flips completion status and sets/clears the completion timestamp
  - `delete()` — Removes a task
- **TaskItemData** — Immutable DTO for returning data outside the actor
- **Modern concurrency** — Uses `async/await` with `withCheckedThrowingContinuation` for background context operations

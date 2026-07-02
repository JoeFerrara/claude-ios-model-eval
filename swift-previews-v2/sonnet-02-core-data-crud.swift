import CoreData
import Foundation

@objc(TaskItem)
final class TaskItem: NSManagedObject {
    @NSManaged var id:          UUID
    @NSManaged var title:       String
    @NSManaged var notes:       String?
    @NSManaged var priority:    Int16
    @NSManaged var isCompleted: Bool
    @NSManaged var createdAt:   Date
    @NSManaged var completedAt: Date?

    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskItem> {
        NSFetchRequest<TaskItem>(entityName: "TaskItem")
    }
}

extension TaskItem {
    enum Priority: Int16, CaseIterable {
        case low    = 0
        case medium = 1
        case high   = 2

        var label: String {
            switch self {
            case .low:    "Low"
            case .medium: "Medium"
            case .high:   "High"
            }
        }
    }

    /// Typed accessor over the raw `Int16` attribute.
    var priorityLevel: Priority {
        get { Priority(rawValue: priority) ?? .low }
        set { priority = newValue.rawValue }
    }
}

import CoreData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    // MARK: – Programmatic model (replaces .xcdatamodeld)

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "TaskItem"
        // @objc(TaskItem) makes NSStringFromClass return the bare name "TaskItem",
        // which must match the managedObjectClassName exactly.
        entity.managedObjectClassName = NSStringFromClass(TaskItem.self)

        func attr(
            _ name: String,
            _ type: NSAttributeType,
            optional: Bool = false,
            default defaultValue: Any? = nil
        ) -> NSAttributeDescription {
            let d = NSAttributeDescription()
            d.name = name
            d.attributeType = type
            d.isOptional = optional
            d.defaultValue = defaultValue
            return d
        }

        entity.properties = [
            attr("id",          .UUIDAttributeType),
            attr("title",       .stringAttributeType),
            attr("notes",       .stringAttributeType,    optional: true),
            attr("priority",    .integer16AttributeType, default: Int16(0)),
            attr("isCompleted", .booleanAttributeType,   default: false),
            attr("createdAt",   .dateAttributeType),
            attr("completedAt", .dateAttributeType,      optional: true),
        ]

        model.entities = [entity]
        return model
    }

    // MARK: – Init

    /// - Parameter inMemory: Pass `true` for previews / scratch usage.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "TaskManager",
            managedObjectModel: Self.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first?.url =
                URL(fileURLWithPath: "/dev/null")
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

import CoreData
import Foundation

/// The single source of truth for task data.
///
/// Runs exclusively on the `@MainActor`, which is the same thread as
/// `NSPersistentContainer.viewContext` — no additional locking required.
/// Every mutating method saves the context and refreshes `tasks`.
@MainActor
final class TaskStore: ObservableObject {

    /// Latest snapshot of all tasks, sorted by priority ↓ then createdAt ↑.
    /// Refreshed automatically after every create / update / delete.
    @Published private(set) var tasks: [TaskItem] = []

    private let context: NSManagedObjectContext

    init(controller: PersistenceController = .shared) {
        context = controller.container.viewContext
    }

    // MARK: – Fetch all

    /// Fetches every task sorted by priority (high → low) then createdAt (oldest first).
    /// Updates the `tasks` publisher as a side-effect.
    @discardableResult
    func fetchAll() async throws -> [TaskItem] {
        let request = TaskItem.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "priority",  ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: true),
        ]
        let results = try context.fetch(request)
        tasks = results
        return results
    }

    // MARK: – Fetch by priority

    /// Returns tasks at the given priority level, sorted oldest-first.
    /// Does **not** update the `tasks` publisher.
    func fetchByPriority(_ priority: TaskItem.Priority) async throws -> [TaskItem] {
        let request = TaskItem.fetchRequest()
        request.predicate = NSPredicate(format: "priority == %d", priority.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }

    // MARK: – Create

    @discardableResult
    func create(
        title:    String,
        notes:    String? = nil,
        priority: TaskItem.Priority = .low
    ) async throws -> TaskItem {
        let item = TaskItem(context: context)
        item.id          = UUID()
        item.title       = title
        item.notes       = notes
        item.priority    = priority.rawValue
        item.isCompleted = false
        item.createdAt   = Date()
        item.completedAt = nil
        try context.save()
        try await fetchAll()
        return item
    }

    // MARK: – Update

    /// Omit any parameter to leave it unchanged.
    /// Pass `notes: .some(nil)` to explicitly clear the notes field.
    func update(
        _ item:   TaskItem,
        title:    String? = nil,
        notes:    String?? = nil,   // outer nil = "don't touch"; .some(nil) = "clear"
        priority: TaskItem.Priority? = nil
    ) async throws {
        if let title    { item.title    = title }
        if let notes    { item.notes    = notes }   // `notes` here is the unwrapped String?
        if let priority { item.priority = priority.rawValue }
        try context.save()
        try await fetchAll()
    }

    // MARK: – Delete

    func delete(_ item: TaskItem) async throws {
        context.delete(item)
        try context.save()
        try await fetchAll()
    }

    // MARK: – Toggle complete

    func toggleComplete(_ item: TaskItem) async throws {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        try context.save()
        try await fetchAll()
    }
}


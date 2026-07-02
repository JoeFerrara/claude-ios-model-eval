// TaskItem.swift
import CoreData

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

// CoreDataStack.swift
import CoreData

final class CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    var context: NSManagedObjectContext { container.viewContext }

    private init() {
        container = NSPersistentContainer(name: "TaskManager", managedObjectModel: Self.buildModel())
        container.loadPersistentStores { _, error in
            if let error { fatalError("Failed to load store: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save: \(error)")
        }
    }

    private static func buildModel() -> NSManagedObjectModel {
        let entity = NSEntityDescription()
        entity.name = "TaskItem"
        entity.managedObjectClassName = "TaskItem"
        entity.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("title", .stringAttributeType),
            attribute("notes", .stringAttributeType, optional: true),
            attribute("priority", .integer16AttributeType, defaultValue: 1),
            attribute("isCompleted", .booleanAttributeType, defaultValue: false),
            attribute("createdAt", .dateAttributeType),
            attribute("completedAt", .dateAttributeType, optional: true),
        ]

        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        attr.defaultValue = defaultValue
        return attr
    }
}

// TaskStore.swift
import CoreData

@MainActor
final class TaskStore: NSObject, ObservableObject {
    @Published var tasks: [TaskItem] = []

    private let stack = CoreDataStack.shared
    private let fetchedResultsController: NSFetchedResultsController<TaskItem>

    override init() {
        let request = NSFetchRequest<TaskItem>(entityName: "TaskItem")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskItem.priority, ascending: false),
            NSSortDescriptor(keyPath: \TaskItem.createdAt, ascending: false),
        ]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: stack.context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        super.init()

        fetchedResultsController.delegate = self
        try? fetchedResultsController.performFetch()
        tasks = fetchedResultsController.fetchedObjects ?? []
    }

    func create(title: String, notes: String? = nil, priority: Int16 = 1) {
        let task = TaskItem(context: stack.context)
        task.id = UUID()
        task.title = title
        task.notes = notes
        task.priority = priority
        task.isCompleted = false
        task.createdAt = Date()
        stack.save()
    }

    func update(_ task: TaskItem, title: String? = nil, notes: String? = nil, priority: Int16? = nil) {
        if let title { task.title = title }
        if let notes { task.notes = notes }
        if let priority { task.priority = priority }
        stack.save()
    }

    func delete(_ task: TaskItem) {
        stack.context.delete(task)
        stack.save()
    }

    func toggleComplete(_ task: TaskItem) {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil
        stack.save()
    }
}

extension TaskStore: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tasks = fetchedResultsController.fetchedObjects ?? []
    }
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var showingNewTask = false

    var body: some View {
        NavigationStack {
            Group {
                if store.tasks.isEmpty {
                    ContentUnavailableView(
                        "No Tasks",
                        systemImage: "checkmark.circle",
                        description: Text("Create a new task to get started")
                    )
                } else {
                    List {
                        ForEach(store.tasks, id: \.id) { task in
                            TaskRow(task: task) {
                                store.toggleComplete(task)
                            }
                        }
                        .onDelete { indexSet in
                            let toDelete = indexSet.map { store.tasks[$0] }
                            toDelete.forEach(store.delete)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New Task", systemImage: "plus.circle.fill") {
                        showingNewTask = true
                    }
                }
            }
            .sheet(isPresented: $showingNewTask) {
                NewTaskSheet { title, notes, priority in
                    store.create(title: title, notes: notes, priority: priority)
                }
            }
        }
    }
}

private struct TaskRow: View {
    let task: TaskItem
    var onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .strikethrough(task.isCompleted)

                if let notes = task.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label(priorityLabel, systemImage: "flag")
                        .font(.caption2)
                        .foregroundStyle(priorityColor)

                    Label(task.createdAt.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private var priorityLabel: String {
        switch task.priority {
        case 0: "Low"
        case 2: "High"
        default: "Medium"
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case 0: .blue
        case 2: .red
        default: .orange
        }
    }
}

private struct NewTaskSheet: View {
    var onSave: (String, String?, Int16) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var notes = ""
    @State private var priority: Int16 = 1

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section("Priority") {
                    Picker("Priority", selection: $priority) {
                        Text("Low").tag(Int16(0))
                        Text("Medium").tag(Int16(1))
                        Text("High").tag(Int16(2))
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title, notes.isEmpty ? nil : notes, priority)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

// TaskManagerApp.swift
import SwiftUI

@main
struct TaskManagerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


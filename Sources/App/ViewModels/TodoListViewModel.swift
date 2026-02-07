import CloudKit
import EventKit
import Foundation

protocol TodoStorage {
    func loadItems() async -> [TodoItem]
    func persistItems(_ items: [TodoItem]) async
}

struct LocalTodoStorage: TodoStorage {
    private static let storageFilename = "todos.json"

    func loadItems() async -> [TodoItem] {
        guard let url = Self.storageURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }

    func persistItems(_ items: [TodoItem]) async {
        guard let url = Self.storageURL else { return }
        let directory = url.deletingLastPathComponent()

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(items)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to persist todos:", error.localizedDescription)
        }
    }

    private static var storageURL: URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return baseURL
            .appendingPathComponent("Todolist", isDirectory: true)
            .appendingPathComponent(storageFilename)
    }
}

struct CloudTodoStorage: TodoStorage {
    private let database: CKDatabase
    private static let recordType = "TodoItem"

    private enum Field {
        static let title = "title"
        static let descriptionMarkdown = "descriptionMarkdown"
        static let isCompleted = "isCompleted"
        static let priority = "priority"
        static let dueDate = "dueDate"
        static let createdAt = "createdAt"
    }

    init(container: CKContainer = .default()) {
        database = container.privateCloudDatabase
    }

    func loadItems() async -> [TodoItem] {
        let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))

        do {
            let (matchResults, _) = try await database.records(matching: query)
            return matchResults.compactMap { _, result in
                guard case let .success(record) = result else { return nil }
                return Self.todoItem(from: record)
            }
        } catch {
            print("Failed to load todos from CloudKit:", error.localizedDescription)
            return []
        }
    }

    func persistItems(_ items: [TodoItem]) async {
        let records = items.map { Self.record(from: $0) }
        let itemIDs = Set(items.map { $0.id.uuidString })

        do {
            let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(value: true))
            let (matchResults, _) = try await database.records(matching: query)
            let existingIDs = matchResults.compactMap { _, result -> CKRecord.ID? in
                guard case let .success(record) = result else { return nil }
                return record.recordID
            }
            let toDelete = existingIDs.filter { !itemIDs.contains($0.recordName) }
            _ = try await database.modifyRecords(saving: records, deleting: toDelete)
        } catch {
            print("Failed to persist todos to CloudKit:", error.localizedDescription)
        }
    }

    private static func todoItem(from record: CKRecord) -> TodoItem? {
        guard let title = record[Field.title] as? String else { return nil }
        let description = record[Field.descriptionMarkdown] as? String ?? ""
        let isCompleted = record[Field.isCompleted] as? Bool ?? false
        let priorityRawValue = record[Field.priority] as? String ?? TodoItem.Priority.medium.rawValue
        let priority = TodoItem.Priority(rawValue: priorityRawValue) ?? .medium
        let dueDate = record[Field.dueDate] as? Date
        let createdAt = record[Field.createdAt] as? Date ?? Date()
        let id = UUID(uuidString: record.recordID.recordName) ?? UUID()

        return TodoItem(
            id: id,
            title: title,
            descriptionMarkdown: description,
            isCompleted: isCompleted,
            priority: priority,
            dueDate: dueDate,
            createdAt: createdAt
        )
    }

    private static func record(from item: TodoItem) -> CKRecord {
        let recordID = CKRecord.ID(recordName: item.id.uuidString)
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record[Field.title] = item.title as CKRecordValue
        record[Field.descriptionMarkdown] = item.descriptionMarkdown as CKRecordValue
        record[Field.isCompleted] = item.isCompleted as CKRecordValue
        record[Field.priority] = item.priority.rawValue as CKRecordValue
        if let dueDate = item.dueDate {
            record[Field.dueDate] = dueDate as CKRecordValue
        }
        record[Field.createdAt] = item.createdAt as CKRecordValue
        return record
    }
}

struct DualWriteStorage: TodoStorage {
    let primary: TodoStorage
    let secondary: TodoStorage

    func loadItems() async -> [TodoItem] {
        await primary.loadItems()
    }

    func persistItems(_ items: [TodoItem]) async {
        await primary.persistItems(items)
        await secondary.persistItems(items)
    }
}

struct QuickAddFeedback {
    let created: Bool
    let recognizedTokens: [String]
}

@MainActor
final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

    private let quickAddParser: QuickAddParser
    private let storage: TodoStorage

    private let eventStore = EKEventStore()

    init(
        items: [TodoItem] = [],
        quickAddParser: QuickAddParser = QuickAddParser(),
        storage: TodoStorage = DualWriteStorage(primary: LocalTodoStorage(), secondary: CloudTodoStorage())
    ) {
        self.quickAddParser = quickAddParser
        self.storage = storage

        if items.isEmpty {
            self.items = []
            Task {
                let loaded = await storage.loadItems()
                if !loaded.isEmpty {
                    self.items = loaded
                }
            }
        } else {
            self.items = items
        }
    }

    func addItem(title: String, descriptionMarkdown: String, priority: TodoItem.Priority, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedDescription = descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(
            TodoItem(
                title: trimmed,
                descriptionMarkdown: trimmedDescription,
                priority: priority,
                dueDate: dueDate
            )
        )
        persistItems()
    }

    @discardableResult
    func addQuickItem(rawText: String) -> QuickAddFeedback {
        let parsed = quickAddParser.parse(rawText)
        let fallbackTitle = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = parsed.title.isEmpty ? fallbackTitle : parsed.title

        guard !finalTitle.isEmpty else {
            return QuickAddFeedback(created: false, recognizedTokens: parsed.recognizedTokens)
        }

        addItem(title: finalTitle, descriptionMarkdown: "", priority: parsed.priority, dueDate: parsed.dueDate)
        return QuickAddFeedback(created: true, recognizedTokens: parsed.recognizedTokens)
    }

    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        persistItems()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persistItems()
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
        persistItems()
    }

    func updateItem(
        _ item: TodoItem,
        title: String,
        descriptionMarkdown: String,
        priority: TodoItem.Priority,
        dueDate: Date?
    ) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedDescription = descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].title = trimmed
        items[index].descriptionMarkdown = trimmedDescription
        items[index].priority = priority
        items[index].dueDate = dueDate
        persistItems()
    }

    private func persistItems() {
        let snapshot = items
        Task {
            await storage.persistItems(snapshot)
        }
    }

    func requestEventAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func requestReminderAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            eventStore.requestAccess(to: .reminder) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func exportToCalendar(item: TodoItem, calendar: EKCalendar? = nil) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = item.title
        event.notes = item.descriptionMarkdown
        if let dueDate = item.dueDate {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate)
        } else {
            event.startDate = Date()
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)
        }
        event.calendar = calendar ?? eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
    }

    func exportToReminder(item: TodoItem, reminderList: EKCalendar? = nil) throws {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = item.title
        reminder.notes = item.descriptionMarkdown
        if let dueDate = item.dueDate {
            let components = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
            reminder.dueDateComponents = components
        }
        reminder.calendar = reminderList ?? eventStore.defaultCalendarForNewReminders()
        try eventStore.save(reminder, commit: true)
    }
}

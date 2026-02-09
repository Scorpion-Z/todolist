import CloudKit
import EventKit
import Foundation
import UserNotifications

protocol TodoStorage {
    func loadItems() async -> [TodoItem]
    func persistItems(_ items: [TodoItem]) async
}

struct LocalTodoStorage: TodoStorage {
    private static let storageFilename = "todos.json"
    private static let currentSchemaVersion = 2

    private struct StoredPayload: Codable {
        var schemaVersion: Int
        var items: [TodoItem]
    }

    func loadItems() async -> [TodoItem] {
        guard let url = Self.storageURL,
              let data = try? Data(contentsOf: url) else {
            return []
        }

        if let payload = try? JSONDecoder().decode(StoredPayload.self, from: data) {
            return payload.items
        }

        // Backward compatibility: previous versions persisted a raw [TodoItem].
        if let legacyItems = try? JSONDecoder().decode([TodoItem].self, from: data) {
            return legacyItems
        }

        return []
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
            let payload = StoredPayload(schemaVersion: Self.currentSchemaVersion, items: items)
            let data = try JSONEncoder().encode(payload)
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

    init(container: CKContainer) {
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
    @Published private(set) var tags: [Tag]

    private let quickAddParser: QuickAddParser
    private let notificationCenter: UNUserNotificationCenter
    private let storage: TodoStorage
    private let eventStore = EKEventStore()

    init(
        items: [TodoItem] = [],
        quickAddParser: QuickAddParser = QuickAddParser(),
        storage: TodoStorage = LocalTodoStorage()
    ) {
        self.quickAddParser = quickAddParser
        self.notificationCenter = UNUserNotificationCenter.current()
        self.storage = storage

        if items.isEmpty {
            self.items = []
            self.tags = []
            Task {
                let loaded = await storage.loadItems()
                if !loaded.isEmpty {
                    self.items = loaded
                    self.tags = Self.collectTags(from: loaded)
                    rescheduleNotifications(for: loaded)
                }
            }
        } else {
            self.items = items
            self.tags = Self.collectTags(from: items)
            if !items.isEmpty {
                rescheduleNotifications(for: items)
            }
        }

        requestNotificationAuthorization()
    }

    struct DailyCompletionStat: Identifiable {
        let date: Date
        let completedCount: Int

        var id: Date { date }
    }

    struct TagStat: Identifiable {
        let tag: Tag
        let totalCount: Int
        let completedCount: Int

        var id: UUID { tag.id }
    }

    func addItem(title: String, descriptionMarkdown: String, priority: TodoItem.Priority, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedDescription = descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        let newItem = TodoItem(
            title: trimmed,
            descriptionMarkdown: trimmedDescription,
            priority: priority,
            dueDate: dueDate
        )
        items.append(newItem)
        persistItems()
        scheduleNotification(for: newItem)
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

    func addTemplateItems(_ titles: [String]) {
        let trimmedTitles = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !trimmedTitles.isEmpty else { return }

        trimmedTitles.forEach { title in
            addItem(title: title, descriptionMarkdown: "", priority: .medium, dueDate: nil)
        }
    }

    func deleteItems(at offsets: IndexSet) {
        let removedItems = offsets.compactMap { index in
            items.indices.contains(index) ? items[index] : nil
        }
        items.remove(atOffsets: offsets)
        rebuildTags()
        persistItems()
        removedItems.forEach(cancelNotification(for:))
    }

    func deleteItems(withIDs ids: [TodoItem.ID]) {
        let removedItems = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        rebuildTags()
        persistItems()
        removedItems.forEach(cancelNotification(for:))
    }

    func deleteItem(_ item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items.remove(at: index)
        rebuildTags()
        persistItems()
        cancelNotification(for: item)
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persistItems()
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
        if items[index].isCompleted {
            handleRepeat(for: items[index])
        }
        persistItems()
        updateNotification(for: items[index])
    }

    func updateItem(
        _ item: TodoItem,
        title: String,
        descriptionMarkdown: String,
        priority: TodoItem.Priority,
        dueDate: Date?,
        subtasks: [Subtask],
        tags: [Tag],
        repeatRule: TodoItem.RepeatRule
    ) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let trimmedDescription = descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].title = trimmed
        items[index].descriptionMarkdown = trimmedDescription
        items[index].priority = priority
        items[index].dueDate = dueDate
        items[index].subtasks = subtasks
        items[index].tags = tags
        items[index].repeatRule = repeatRule
        applyTagColors(from: tags)
        rebuildTags()
        persistItems()
        updateNotification(for: items[index])
    }

    func addSubtask(to item: TodoItem, title: String) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].subtasks.append(Subtask(title: trimmed))
        persistItems()
    }

    func toggleSubtask(_ subtask: Subtask, for item: TodoItem) {
        guard let itemIndex = items.firstIndex(of: item),
              let subtaskIndex = items[itemIndex].subtasks.firstIndex(of: subtask) else { return }
        items[itemIndex].subtasks[subtaskIndex].isCompleted.toggle()
        persistItems()
    }

    func deleteSubtasks(at offsets: IndexSet, for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].subtasks.remove(atOffsets: offsets)
        persistItems()
    }

    func addTag(named name: String) -> Tag? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = tags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let tag = Tag(name: trimmed)
        tags.append(tag)
        return tag
    }

    func removeTag(_ tag: Tag, from item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].tags.removeAll { $0.id == tag.id }
        rebuildTags()
        persistItems()
        updateNotification(for: items[index])
    }

    func todayCompletedCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let dayRange = dayRange(for: referenceDate, calendar: calendar)
        return items.filter { item in
            item.isCompleted && dayRange.contains(normalizedDate(for: item))
        }.count
    }

    func overdueCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        return items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return !item.isCompleted && dueDate < startOfToday
        }.count
    }

    func tagStats() -> [TagStat] {
        let groupedTags = Dictionary(grouping: items.flatMap(\.tags)) { tag in
            normalizedTagName(tag.name)
        }

        let normalizedToTag = groupedTags.compactMapValues { tags in
            tags.first
        }

        let stats = normalizedToTag.compactMap { normalizedName, tag -> TagStat? in
            let taggedItems = items.filter { item in
                item.tags.contains { normalizedTagName($0.name) == normalizedName }
            }
            guard !taggedItems.isEmpty else { return nil }
            let completedCount = taggedItems.filter(\.isCompleted).count
            return TagStat(tag: tag, totalCount: taggedItems.count, completedCount: completedCount)
        }

        return stats.sorted {
            if $0.totalCount != $1.totalCount {
                return $0.totalCount > $1.totalCount
            }
            return $0.tag.name.localizedCaseInsensitiveCompare($1.tag.name) == .orderedAscending
        }
    }

    func sevenDayCompletionTrend(referenceDate: Date = Date(), calendar: Calendar = .current) -> [DailyCompletionStat] {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset - 6, to: startOfToday) else { return nil }
            let dayRange = dayRange(for: day, calendar: calendar)
            let completedCount = items.filter { item in
                item.isCompleted && dayRange.contains(normalizedDate(for: item))
            }.count
            return DailyCompletionStat(date: day, completedCount: completedCount)
        }
    }

    func todayCompletionRate(referenceDate: Date = Date(), calendar: Calendar = .current) -> Double {
        let dayRange = dayRange(for: referenceDate, calendar: calendar)
        let totalCount = items.filter { item in
            dayRange.contains(normalizedDate(for: item))
        }.count
        guard totalCount > 0 else { return 0 }
        let completedCount = items.filter { item in
            item.isCompleted && dayRange.contains(normalizedDate(for: item))
        }.count
        return Double(completedCount) / Double(totalCount)
    }

    func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(for item: TodoItem) {
        scheduleNotificationIfNeeded(for: item)
    }

    private func updateNotification(for item: TodoItem) {
        removeNotification(for: item.id)
        scheduleNotificationIfNeeded(for: item)
    }

    private func cancelNotification(for item: TodoItem) {
        removeNotification(for: item.id)
    }

    private func rescheduleNotifications(for items: [TodoItem]) {
        items.forEach { scheduleNotificationIfNeeded(for: $0) }
    }

    private func scheduleNotificationIfNeeded(for item: TodoItem) {
        guard let dueDate = item.dueDate, !item.isCompleted else { return }
        if dueDate <= Date() {
            removeNotification(for: item.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.title", comment: "Todo notification title")
        content.body = item.title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request)
    }

    private func removeNotification(for id: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    private func persistItems() {
        let snapshot = items
        Task {
            await storage.persistItems(snapshot)
        }
    }

    func requestEventAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    func requestReminderAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToReminders { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func rebuildTags() {
        tags = Self.collectTags(from: items)
    }

    private static func collectTags(from items: [TodoItem]) -> [Tag] {
        var seen = Set<String>()
        var collected: [Tag] = []
        for tag in items.flatMap(\.tags) {
            let normalized = normalizedTagName(tag.name)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            collected.append(tag)
        }
        return collected.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func applyTagColors(from tags: [Tag]) {
        let colorMap = Dictionary(uniqueKeysWithValues: tags.map { (normalizedTagName($0.name), $0.color) })
        guard !colorMap.isEmpty else { return }
        for index in items.indices {
            var updated = items[index]
            updated.tags = updated.tags.map { tag in
                let normalized = normalizedTagName(tag.name)
                guard let color = colorMap[normalized] else { return tag }
                return Tag(id: tag.id, name: tag.name, color: color)
            }
            items[index] = updated
        }
    }

    private static func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedTagName(_ name: String) -> String {
        Self.normalizedTagName(name)
    }

    private func handleRepeat(for item: TodoItem) {
        guard item.repeatRule != .none else { return }
        guard let nextDueDate = nextDueDate(for: item) else { return }
        let repeatedSubtasks = item.subtasks.map { subtask in
            Subtask(title: subtask.title)
        }
        let newItem = TodoItem(
            title: item.title,
            priority: item.priority,
            dueDate: nextDueDate,
            subtasks: repeatedSubtasks,
            tags: item.tags,
            repeatRule: item.repeatRule
        )
        items.append(newItem)
        if newItem.dueDate != nil, !newItem.isCompleted {
            scheduleNotification(for: newItem)
        }
        rebuildTags()
    }

    private func nextDueDate(for item: TodoItem) -> Date? {
        let calendar = Calendar.current
        let baseDate = item.dueDate ?? Date()
        switch item.repeatRule {
        case .none:
            return nil
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: baseDate)
        case .weekly:
            return calendar.date(byAdding: .day, value: 7, to: baseDate)
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: baseDate)
        }
    }

    func exportToCalendar(item: TodoItem, calendar: EKCalendar? = nil) throws {
        let event = EKEvent(eventStore: eventStore)
        event.title = item.title
        event.notes = item.descriptionMarkdown
        let startDate = item.dueDate ?? Date()
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
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

    private func normalizedDate(for item: TodoItem) -> Date {
        item.dueDate ?? item.createdAt
    }

    private func dayRange(for date: Date, calendar: Calendar) -> Range<Date> {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return startOfDay..<endOfDay
    }
}

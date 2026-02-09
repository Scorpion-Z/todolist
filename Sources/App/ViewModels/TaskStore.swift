import Foundation
import Combine
import UserNotifications

struct TaskDraft {
    var title: String
    var descriptionMarkdown: String
    var priority: TodoItem.Priority
    var dueDate: Date?
    var isImportant: Bool
    var myDayDate: Date?
    var tags: [Tag]
    var subtasks: [Subtask]
    var repeatRule: TodoItem.RepeatRule

    init(
        title: String,
        descriptionMarkdown: String = "",
        priority: TodoItem.Priority = .medium,
        dueDate: Date? = nil,
        isImportant: Bool = false,
        myDayDate: Date? = nil,
        tags: [Tag] = [],
        subtasks: [Subtask] = [],
        repeatRule: TodoItem.RepeatRule = .none
    ) {
        self.title = title
        self.descriptionMarkdown = descriptionMarkdown
        self.priority = priority
        self.dueDate = dueDate
        self.isImportant = isImportant
        self.myDayDate = myDayDate
        self.tags = tags
        self.subtasks = subtasks
        self.repeatRule = repeatRule
    }
}

struct TaskQuickAddResult {
    let created: Bool
    let recognizedTokens: [String]
    let createdTaskID: UUID?
}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var items: [TodoItem]
    @Published private(set) var tags: [Tag]

    private let storage: TodoStorage
    private let quickAddParser: QuickAddParser
    private let notificationCenter: UNUserNotificationCenter

    init(
        items: [TodoItem] = [],
        storage: TodoStorage = LocalTodoStorage(),
        quickAddParser: QuickAddParser = QuickAddParser(),
        notificationCenter: UNUserNotificationCenter = .current()
    ) {
        self.items = items
        self.tags = []
        self.storage = storage
        self.quickAddParser = quickAddParser
        self.notificationCenter = notificationCenter

        rebuildTags()
        if items.isEmpty {
            Task {
                let loaded = await storage.loadItems()
                if !loaded.isEmpty {
                    self.items = loaded
                    rebuildTags()
                    rescheduleNotifications(for: loaded)
                }
            }
        } else {
            rescheduleNotifications(for: items)
        }

        requestNotificationAuthorization()
    }

    func createTask(_ draft: TaskDraft) {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let item = TodoItem(
            title: trimmedTitle,
            descriptionMarkdown: draft.descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: draft.priority,
            dueDate: draft.dueDate,
            isImportant: draft.isImportant,
            myDayDate: normalizeToStartOfDay(draft.myDayDate),
            subtasks: draft.subtasks,
            tags: draft.tags,
            repeatRule: draft.repeatRule
        )

        items.append(item)
        rebuildTags()
        persistItems()
        scheduleNotification(for: item)
    }

    @discardableResult
    func createQuickTask(rawText: String, preferredMyDayDate: Date? = nil) -> TaskQuickAddResult {
        let parsed = quickAddParser.parse(rawText)
        let fallbackTitle = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = parsed.title.isEmpty ? fallbackTitle : parsed.title

        guard !finalTitle.isEmpty else {
            return TaskQuickAddResult(created: false, recognizedTokens: parsed.recognizedTokens, createdTaskID: nil)
        }

        let item = TodoItem(
            title: finalTitle,
            priority: parsed.priority,
            dueDate: parsed.dueDate,
            myDayDate: normalizeToStartOfDay(preferredMyDayDate)
        )

        items.append(item)
        rebuildTags()
        persistItems()
        scheduleNotification(for: item)

        return TaskQuickAddResult(created: true, recognizedTokens: parsed.recognizedTokens, createdTaskID: item.id)
    }

    func updateTask(id: UUID, mutate: (inout TodoItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
        items[index].myDayDate = normalizeToStartOfDay(items[index].myDayDate)
        rebuildTags()
        persistItems()
        updateNotification(for: items[index])
    }

    func deleteTasks(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        rebuildTags()
        persistItems()
        removed.forEach(cancelNotification(for:))
    }

    func toggleCompletion(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()

        if items[index].isCompleted {
            items[index].completedAt = Date()
            handleRepeat(for: items[index])
        } else {
            items[index].completedAt = nil
        }

        persistItems()
        updateNotification(for: items[index])
    }

    func toggleImportant(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isImportant.toggle()
        persistItems()
    }

    func addToMyDay(id: UUID, date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].myDayDate = normalizeToStartOfDay(date)
        persistItems()
    }

    func removeFromMyDay(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].myDayDate = nil
        persistItems()
    }

    func item(withID id: UUID?) -> TodoItem? {
        guard let id else { return nil }
        return items.first(where: { $0.id == id })
    }

    func addTemplateItems(_ titles: [String], preferredMyDayDate: Date? = nil) {
        let cleaned = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleaned.isEmpty else { return }

        for title in cleaned {
            createTask(
                TaskDraft(
                    title: title,
                    myDayDate: preferredMyDayDate
                )
            )
        }
    }

    func allTagNames() -> [String] {
        tags.map(\.name)
    }

    func myDaySuggestions(limit: Int = 5, referenceDate: Date = Date(), calendar: Calendar = .current) -> [TodoItem] {
        let todayStart = calendar.startOfDay(for: referenceDate)

        let candidates = items.filter { item in
            guard !item.isCompleted else { return false }
            if let myDayDate = item.myDayDate, calendar.isDate(myDayDate, inSameDayAs: referenceDate) {
                return false
            }

            if item.isImportant {
                return true
            }

            if let dueDate = item.dueDate {
                return dueDate < todayStart || calendar.isDate(dueDate, inSameDayAs: referenceDate)
            }

            return false
        }

        return candidates
            .sorted {
                if $0.isImportant != $1.isImportant {
                    return $0.isImportant
                }
                let lhsDue = $0.dueDate ?? .distantFuture
                let rhsDue = $1.dueDate ?? .distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return $0.createdAt > $1.createdAt
            }
            .prefix(limit)
            .map { $0 }
    }

    var totalCount: Int {
        items.count
    }

    var openCount: Int {
        items.filter { !$0.isCompleted }.count
    }

    func overdueCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: referenceDate)
        return items.filter { item in
            guard let dueDate = item.dueDate else { return false }
            return !item.isCompleted && dueDate < startOfToday
        }.count
    }

    func completedTodayCount(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        items.filter { item in
            guard item.isCompleted, let completedAt = item.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: referenceDate)
        }.count
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(for item: TodoItem) {
        guard let dueDate = item.dueDate, !item.isCompleted else { return }
        if dueDate <= Date() {
            removeNotification(for: item.id)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.title", comment: "Todo notification title")
        content.body = item.title
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)

        notificationCenter.add(request)
    }

    private func updateNotification(for item: TodoItem) {
        removeNotification(for: item.id)
        scheduleNotification(for: item)
    }

    private func cancelNotification(for item: TodoItem) {
        removeNotification(for: item.id)
    }

    private func removeNotification(for id: UUID) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    private func rescheduleNotifications(for items: [TodoItem]) {
        items.forEach { scheduleNotification(for: $0) }
    }

    private func persistItems() {
        let snapshot = items
        Task {
            await storage.persistItems(snapshot)
        }
    }

    private func rebuildTags() {
        var seen = Set<String>()
        var collected: [Tag] = []

        for tag in items.flatMap(\.tags) {
            let normalized = normalizedTagName(tag.name)
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            collected.append(tag)
        }

        tags = collected.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeToStartOfDay(_ date: Date?) -> Date? {
        guard let date else { return nil }
        return Calendar.current.startOfDay(for: date)
    }

    private func handleRepeat(for item: TodoItem) {
        guard item.repeatRule != .none else { return }
        guard let nextDueDate = nextDueDate(for: item) else { return }

        let repeatedSubtasks = item.subtasks.map { Subtask(title: $0.title) }

        let repeatedItem = TodoItem(
            title: item.title,
            descriptionMarkdown: item.descriptionMarkdown,
            priority: item.priority,
            dueDate: nextDueDate,
            isImportant: item.isImportant,
            subtasks: repeatedSubtasks,
            tags: item.tags,
            repeatRule: item.repeatRule
        )

        items.append(repeatedItem)
        rebuildTags()
        scheduleNotification(for: repeatedItem)
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
}

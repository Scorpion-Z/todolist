import Foundation
import SwiftUI
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

struct MyDaySuggestion: Identifiable {
    enum Reason {
        case overdue
        case dueToday
        case important

        var priority: Int {
            switch self {
            case .overdue: return 0
            case .dueToday: return 1
            case .important: return 2
            }
        }

        var titleKey: LocalizedStringKey {
            switch self {
            case .overdue:
                return "myday.reason.overdue"
            case .dueToday:
                return "myday.reason.today"
            case .important:
                return "myday.reason.important"
            }
        }
    }

    let item: TodoItem
    let reason: Reason

    var id: UUID { item.id }
}

struct MyDayProgress {
    let completedCount: Int
    let totalCount: Int

    var completionRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var isAllDone: Bool {
        totalCount > 0 && completedCount == totalCount
    }
}

struct WeeklyReviewSnapshot {
    let startDate: Date
    let endDate: Date
    let createdCount: Int
    let completedCount: Int
    let carriedOverCompletedCount: Int
    let importantCompletedCount: Int
    let overdueResolvedCount: Int
}

@MainActor
final class TaskStore: ObservableObject {
    @Published private(set) var items: [TodoItem]
    @Published private(set) var tags: [Tag]

    private let storage: TodoStorage
    private let quickAddParser: QuickAddParser
    private let notificationCenter: UNUserNotificationCenter?

    private var persistTask: Task<Void, Never>?

    init(
        items: [TodoItem] = [],
        storage: TodoStorage = LocalTodoStorage(),
        quickAddParser: QuickAddParser = QuickAddParser(),
        notificationCenter: UNUserNotificationCenter? = nil
    ) {
        self.items = items
        self.tags = []
        self.storage = storage
        self.quickAddParser = quickAddParser
        self.notificationCenter = notificationCenter ?? Self.makeNotificationCenter()

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

        let now = Date()
        let item = TodoItem(
            title: trimmedTitle,
            descriptionMarkdown: draft.descriptionMarkdown.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: draft.priority,
            dueDate: draft.dueDate,
            isImportant: draft.isImportant,
            myDayDate: normalizeToStartOfDay(draft.myDayDate),
            updatedAt: now,
            createdAt: now,
            subtasks: draft.subtasks,
            tags: draft.tags,
            repeatRule: draft.repeatRule
        )

        items.append(item)
        rebuildTags()
        schedulePersist()
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

        let now = Date()
        let item = TodoItem(
            title: finalTitle,
            priority: parsed.priority,
            dueDate: parsed.dueDate,
            myDayDate: normalizeToStartOfDay(preferredMyDayDate),
            updatedAt: now,
            createdAt: now,
            repeatRule: parsed.repeatRule
        )

        items.append(item)
        rebuildTags()
        schedulePersist()
        scheduleNotification(for: item)

        return TaskQuickAddResult(created: true, recognizedTokens: parsed.recognizedTokens, createdTaskID: item.id)
    }

    func updateTask(id: UUID, mutate: (inout TodoItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])

        items[index].myDayDate = normalizeToStartOfDay(items[index].myDayDate)
        if items[index].isCompleted, items[index].completedAt == nil {
            items[index].completedAt = Date()
        }
        if !items[index].isCompleted {
            items[index].completedAt = nil
        }
        items[index].updatedAt = Date()

        rebuildTags()
        schedulePersist()
        updateNotification(for: items[index])
    }

    func deleteTasks(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        let removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        rebuildTags()
        schedulePersist()
        removed.forEach(cancelNotification(for:))
    }

    func toggleCompletion(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isCompleted.toggle()

        if items[index].isCompleted {
            items[index].completedAt = Date()
            items[index].updatedAt = Date()
            handleRepeat(for: items[index])
        } else {
            items[index].completedAt = nil
            items[index].updatedAt = Date()
        }

        schedulePersist()
        updateNotification(for: items[index])
    }

    func toggleImportant(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isImportant.toggle()
        items[index].updatedAt = Date()
        schedulePersist()
    }

    func addToMyDay(id: UUID, date: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].myDayDate = normalizeToStartOfDay(date)
        items[index].updatedAt = Date()
        schedulePersist()
    }

    func removeFromMyDay(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].myDayDate = nil
        items[index].updatedAt = Date()
        schedulePersist()
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

    func myDaySuggestions(limit: Int = 5, referenceDate: Date = Date(), calendar: Calendar = .current) -> [MyDaySuggestion] {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        let candidates = items.compactMap { item -> MyDaySuggestion? in
            guard !item.isCompleted else { return nil }
            if let myDayDate = item.myDayDate, calendar.isDate(myDayDate, inSameDayAs: referenceDate) {
                return nil
            }

            if let dueDate = item.dueDate, dueDate < todayStart {
                return MyDaySuggestion(item: item, reason: .overdue)
            }

            if let dueDate = item.dueDate, dueDate >= todayStart && dueDate < tomorrowStart {
                return MyDaySuggestion(item: item, reason: .dueToday)
            }

            if item.isImportant {
                return MyDaySuggestion(item: item, reason: .important)
            }

            return nil
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.reason.priority != rhs.reason.priority {
                    return lhs.reason.priority < rhs.reason.priority
                }
                let lhsDue = lhs.item.dueDate ?? .distantFuture
                let rhsDue = rhs.item.dueDate ?? .distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return lhs.item.updatedAt > rhs.item.updatedAt
            }
            .prefix(limit)
            .map { $0 }
    }

    func myDayProgress(referenceDate: Date = Date(), calendar: Calendar = .current) -> MyDayProgress {
        let todaysItems = items.filter { item in
            guard let myDayDate = item.myDayDate else { return false }
            return calendar.isDate(myDayDate, inSameDayAs: referenceDate)
        }

        let completedCount = todaysItems.filter(\.isCompleted).count
        return MyDayProgress(completedCount: completedCount, totalCount: todaysItems.count)
    }

    func completionStreak(referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let completionDays = Set(items.compactMap { item -> Date? in
            guard let completedAt = item.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        })

        guard !completionDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let anchor: Date

        if completionDays.contains(today) {
            anchor = today
        } else if completionDays.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        var streak = 0
        var cursor = anchor
        while completionDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    func weeklyReview(referenceDate: Date = Date(), calendar: Calendar = .current) -> WeeklyReviewSnapshot {
        let endDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate

        let createdCount = items.filter { $0.createdAt >= startDate && $0.createdAt < endDate }.count
        let completedItems = items.filter {
            guard let completedAt = $0.completedAt else { return false }
            return completedAt >= startDate && completedAt < endDate
        }

        let completedCount = completedItems.count
        let carriedOverCompletedCount = completedItems.filter { $0.createdAt < startDate }.count
        let importantCompletedCount = completedItems.filter(\.isImportant).count
        let overdueResolvedCount = completedItems.filter { item in
            guard let dueDate = item.dueDate, let completedAt = item.completedAt else { return false }
            return dueDate < completedAt
        }.count

        return WeeklyReviewSnapshot(
            startDate: startDate,
            endDate: endDate,
            createdCount: createdCount,
            completedCount: completedCount,
            carriedOverCompletedCount: carriedOverCompletedCount,
            importantCompletedCount: importantCompletedCount,
            overdueResolvedCount: overdueResolvedCount
        )
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
        guard let notificationCenter else { return }
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func scheduleNotification(for item: TodoItem) {
        guard let notificationCenter else { return }
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
        guard let notificationCenter else { return }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    private func rescheduleNotifications(for items: [TodoItem]) {
        items.forEach { scheduleNotification(for: $0) }
    }

    private func schedulePersist() {
        let snapshot = items
        persistTask?.cancel()
        persistTask = Task { [storage] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
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
            myDayDate: item.myDayDate,
            updatedAt: Date(),
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

    private static func makeNotificationCenter() -> UNUserNotificationCenter? {
        guard Bundle.main.bundleURL.pathExtension == "app" else { return nil }
        return UNUserNotificationCenter.current()
    }
}

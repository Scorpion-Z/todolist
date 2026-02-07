import Foundation
import UserNotifications

struct QuickAddFeedback {
    let created: Bool
    let recognizedTokens: [String]
}

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]
    @Published private(set) var tags: [Tag]

    private let quickAddParser: QuickAddParser
    private let notificationCenter: UNUserNotificationCenter
    private static let storageFilename = "todos.json"

    init(items: [TodoItem] = [], quickAddParser: QuickAddParser = QuickAddParser()) {
        self.quickAddParser = quickAddParser
        self.notificationCenter = UNUserNotificationCenter.current()

        if items.isEmpty {
            self.items = Self.loadItems()
        } else {
            self.items = items
        }

        requestNotificationAuthorization()
        rescheduleNotifications(for: self.items)
    }

    func addItem(title: String, priority: TodoItem.Priority, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = TodoItem(title: trimmed, priority: priority, dueDate: dueDate)
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

        addItem(title: finalTitle, priority: parsed.priority, dueDate: parsed.dueDate)
        return QuickAddFeedback(created: true, recognizedTokens: parsed.recognizedTokens)
    }

    func deleteItems(at offsets: IndexSet) {
        let removedItems = offsets.compactMap { index in
            items.indices.contains(index) ? items[index] : nil
        }
        items.remove(atOffsets: offsets)
        rebuildTags()
        persistItems()
        removedItems.forEach(cancelNotification)
    }

    func deleteItems(withIDs ids: [TodoItem.ID]) {
        let removedItems = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        persistItems()
        removedItems.forEach(cancelNotification)
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
        priority: TodoItem.Priority,
        dueDate: Date?,
        subtasks: [Subtask],
        tags: [Tag],
        repeatRule: TodoItem.RepeatRule
    ) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
        items[index].subtasks = subtasks
        items[index].tags = tags
        items[index].repeatRule = repeatRule
        rebuildTags()
        persistItems()
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

    private func persistItems() {
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

    private static func loadItems() -> [TodoItem] {
        guard let url = storageURL,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }

    private func rebuildTags() {
        tags = Self.collectTags(from: items)
    }

    private static func collectTags(from items: [TodoItem]) -> [Tag] {
        var seen = Set<String>()
        var collected: [Tag] = []
        for tag in items.flatMap(\.tags) {
            let normalized = tag.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            collected.append(tag)
        }
        return collected.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    private static var storageURL: URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return baseURL
            .appendingPathComponent("Todolist", isDirectory: true)
            .appendingPathComponent(storageFilename)
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotification(for item: TodoItem) {
        guard let dueDate = item.dueDate, !item.isCompleted, dueDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = String(localized: "notification.body")
        content.sound = .default

        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationIdentifier(for: item),
            content: content,
            trigger: trigger
        )
        notificationCenter.add(request)
    }

    private func cancelNotification(for item: TodoItem) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: item)])
    }

    private func updateNotification(for item: TodoItem) {
        cancelNotification(for: item)
        scheduleNotification(for: item)
    }

    private func rescheduleNotifications(for items: [TodoItem]) {
        let identifiers = items.map(notificationIdentifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        items.forEach(scheduleNotification)
    }

    private func notificationIdentifier(for item: TodoItem) -> String {
        "todo-reminder-\(item.id.uuidString)"
    }
}

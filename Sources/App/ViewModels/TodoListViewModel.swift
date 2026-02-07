import Foundation
import UserNotifications

struct QuickAddFeedback {
    let created: Bool
    let recognizedTokens: [String]
}

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

    private let quickAddParser: QuickAddParser
    private static let storageFilename = "todos.json"
    private let notificationCenter = UNUserNotificationCenter.current()

    init(items: [TodoItem] = [], quickAddParser: QuickAddParser = QuickAddParser()) {
        self.quickAddParser = quickAddParser

        if items.isEmpty {
            self.items = Self.loadItems()
        } else {
            self.items = items
        }
    }

    func addItem(
        title: String,
        priority: TodoItem.Priority,
        dueDate: Date?,
        tags: [String] = [],
        subtasks: [TodoItem.Subtask] = [],
        repeatRule: TodoItem.RepeatRule = .none
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = TodoItem(
            title: trimmed,
            priority: priority,
            dueDate: dueDate,
            tags: tags,
            subtasks: subtasks,
            repeatRule: repeatRule
        )
        items.append(newItem)
        scheduleNotificationIfNeeded(for: newItem)
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

        addItem(title: finalTitle, priority: parsed.priority, dueDate: parsed.dueDate)
        return QuickAddFeedback(created: true, recognizedTokens: parsed.recognizedTokens)
    }

    @discardableResult
    func deleteItems(at offsets: IndexSet) -> [TodoItem] {
        let deleted = offsets.compactMap { index in
            items.indices.contains(index) ? items[index] : nil
        }
        deleted.forEach { removeNotification(for: $0.id) }
        items.remove(atOffsets: offsets)
        persistItems()
        return deleted
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persistItems()
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
        if items[index].isCompleted {
            removeNotification(for: items[index].id)
        } else {
            scheduleNotificationIfNeeded(for: items[index])
        }
        persistItems()
    }

    func updateItem(
        _ item: TodoItem,
        title: String,
        priority: TodoItem.Priority,
        dueDate: Date?,
        tags: [String],
        subtasks: [TodoItem.Subtask],
        repeatRule: TodoItem.RepeatRule
    ) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
        items[index].tags = tags
        items[index].subtasks = subtasks
        items[index].repeatRule = repeatRule
        if items[index].isCompleted {
            removeNotification(for: items[index].id)
        } else {
            scheduleNotificationIfNeeded(for: items[index])
        }
        persistItems()
    }

    func restoreItems(_ deletedItems: [TodoItem], at offsets: IndexSet) {
        for (offset, item) in zip(offsets, deletedItems) {
            let insertIndex = min(offset, items.count)
            items.insert(item, at: insertIndex)
            scheduleNotificationIfNeeded(for: item)
        }
        persistItems()
    }

    func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
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

    private static var storageURL: URL? {
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        return baseURL
            .appendingPathComponent("Todolist", isDirectory: true)
            .appendingPathComponent(storageFilename)
    }
}

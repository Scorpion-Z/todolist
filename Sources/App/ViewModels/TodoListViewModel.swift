import Foundation
import UserNotifications

struct QuickAddFeedback {
    let created: Bool
    let recognizedTokens: [String]
}

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

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
        persistItems()
        updateNotification(for: items[index])
    }

    func updateItem(_ item: TodoItem, title: String, priority: TodoItem.Priority, dueDate: Date?) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
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

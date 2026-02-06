import Foundation
import UserNotifications

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]
    @Published private(set) var notificationStatus: UNAuthorizationStatus = .notDetermined

    private let storageKey = "todo_items"
    private let notificationService: NotificationService

    init(items: [TodoItem] = [], notificationService: NotificationService = NotificationService()) {
        self.notificationService = notificationService
        if items.isEmpty {
            self.items = Self.loadItems(from: storageKey)
        } else {
            self.items = items
        }
        refreshNotificationStatus()
    }

    func addItem(
        title: String,
        priority: TodoItem.Priority,
        dueDate: Date?,
        remindAt: Date?
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = TodoItem(
            title: trimmed,
            priority: priority,
            dueDate: dueDate,
            remindAt: remindAt
        )
        items.append(newItem)
        persistItems()
        syncReminder(for: newItem)
    }

    func deleteItems(at offsets: IndexSet) {
        let removedItems = offsets.compactMap { index in
            items.indices.contains(index) ? items[index] : nil
        }
        items.remove(atOffsets: offsets)
        persistItems()
        removedItems.forEach { notificationService.cancelReminder(for: $0.id) }
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        persistItems()
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
        persistItems()
        syncReminder(for: items[index])
    }

    func updateItem(
        _ item: TodoItem,
        title: String,
        priority: TodoItem.Priority,
        dueDate: Date?,
        remindAt: Date?
    ) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
        items[index].remindAt = remindAt
        persistItems()
        syncReminder(for: items[index])
    }

    func refreshNotificationStatus() {
        notificationService.fetchAuthorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                self?.notificationStatus = status
            }
        }
    }

    func requestNotificationAuthorization() {
        notificationService.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.notificationStatus = status
            }
        }
    }

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func syncReminder(for item: TodoItem) {
        notificationService.fetchAuthorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                self?.notificationStatus = status
            }
            guard status == .authorized else {
                self?.notificationService.cancelReminder(for: item.id)
                return
            }
            guard !item.isCompleted, item.remindAt != nil else {
                self?.notificationService.cancelReminder(for: item.id)
                return
            }
            self?.notificationService.updateReminder(for: item)
        }
    }

    private static func loadItems(from key: String) -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }
}

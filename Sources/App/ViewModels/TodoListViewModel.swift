import Foundation

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

    private let storageKey = "todo_items"

    init(items: [TodoItem] = []) {
        if items.isEmpty {
            self.items = Self.loadItems(from: storageKey)
        } else {
            self.items = items
        }
    }

    func addItem(title: String, priority: TodoItem.Priority, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed, priority: priority, dueDate: dueDate))
        persistItems()
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

    func completeItems(ids: [UUID]) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        for index in items.indices where idSet.contains(items[index].id) {
            items[index].isCompleted = true
        }
        persistItems()
    }

    func deleteItems(ids: [UUID]) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        items.removeAll { idSet.contains($0.id) }
        persistItems()
    }

    func assignTag(ids: [UUID], tag: String) {
        let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        for index in items.indices where idSet.contains(items[index].id) {
            if !items[index].tags.contains(trimmed) {
                items[index].tags.append(trimmed)
            }
        }
        persistItems()
    }

    func updateItem(_ item: TodoItem, title: String, priority: TodoItem.Priority, dueDate: Date?) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
        persistItems()
    }

    private func persistItems() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func loadItems(from key: String) -> [TodoItem] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            return []
        }
        return decoded
    }
}

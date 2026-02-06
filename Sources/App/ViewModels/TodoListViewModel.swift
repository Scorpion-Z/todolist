import Foundation

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

    private let repository: TodoRepository

    init(repository: TodoRepository) {
        self.repository = repository
        self.items = (try? repository.fetchItems()) ?? []
    }

    func addItem(title: String, priority: TodoItem.Priority, dueDate: Date?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextSortOrder = (items.map(\.sortOrder).max() ?? -1) + 1
        let newItem = TodoItem(
            title: trimmed,
            priority: priority,
            dueDate: dueDate,
            sortOrder: nextSortOrder
        )
        items.append(newItem)
        persist(newItem)
    }

    func deleteItems(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            items.indices.contains(index) ? items[index].id : nil
        }
        items.remove(atOffsets: offsets)
        persistDeletion(ids)
        resequenceSortOrder()
    }

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        resequenceSortOrder()
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
        persistUpdate(items[index])
    }

    func updateItem(_ item: TodoItem, title: String, priority: TodoItem.Priority, dueDate: Date?) {
        guard let index = items.firstIndex(of: item) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items[index].title = trimmed
        items[index].priority = priority
        items[index].dueDate = dueDate
        persistUpdate(items[index])
    }

    private func persist(_ item: TodoItem) {
        try? repository.addItem(item)
    }

    private func persistUpdate(_ item: TodoItem) {
        try? repository.updateItem(item)
    }

    private func persistDeletion(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        try? repository.deleteItems(ids: ids)
    }

    private func resequenceSortOrder() {
        for (index, item) in items.enumerated() {
            items[index].sortOrder = index
        }
        try? repository.updateSortOrder(for: items)
    }
}

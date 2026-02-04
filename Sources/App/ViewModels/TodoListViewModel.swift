import Foundation

final class TodoListViewModel: ObservableObject {
    @Published private(set) var items: [TodoItem]

    init(items: [TodoItem] = []) {
        self.items = items
    }

    func addItem(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.append(TodoItem(title: trimmed))
    }

    func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }

    func toggleCompletion(for item: TodoItem) {
        guard let index = items.firstIndex(of: item) else { return }
        items[index].isCompleted.toggle()
    }
}

import Foundation
import SwiftData

@Model
final class TodoEntity {
    @Attribute(.unique) var id: UUID
    var title: String
    @Attribute(.indexed) var isCompleted: Bool
    var priorityRaw: String
    @Attribute(.indexed) var dueDate: Date?
    @Attribute(.indexed) var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        priorityRaw: String = TodoItem.Priority.medium.rawValue,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priorityRaw = priorityRaw
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }
}

extension TodoEntity {
    convenience init(from item: TodoItem) {
        self.init(
            id: item.id,
            title: item.title,
            isCompleted: item.isCompleted,
            priorityRaw: item.priority.rawValue,
            dueDate: item.dueDate,
            createdAt: item.createdAt,
            sortOrder: item.sortOrder
        )
    }

    func applyChanges(from item: TodoItem) {
        title = item.title
        isCompleted = item.isCompleted
        priorityRaw = item.priority.rawValue
        dueDate = item.dueDate
        createdAt = item.createdAt
        sortOrder = item.sortOrder
    }

    func toTodoItem() -> TodoItem {
        TodoItem(
            id: id,
            title: title,
            isCompleted: isCompleted,
            priority: TodoItem.Priority(rawValue: priorityRaw) ?? .medium,
            dueDate: dueDate,
            createdAt: createdAt,
            sortOrder: sortOrder
        )
    }
}

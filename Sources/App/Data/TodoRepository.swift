import Foundation
import SwiftData

protocol TodoRepository {
    func fetchItems() throws -> [TodoItem]
    func addItem(_ item: TodoItem) throws
    func updateItem(_ item: TodoItem) throws
    func deleteItems(ids: [UUID]) throws
    func updateSortOrder(for items: [TodoItem]) throws
}

final class SwiftDataTodoRepository: TodoRepository {
    private let modelContext: ModelContext
    private let legacyStorageKey = "todo_items"
    private let migrationFlagKey = "todo_items_migrated"

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        migrateLegacyItemsIfNeeded()
    }

    func fetchItems() throws -> [TodoItem] {
        let descriptor = FetchDescriptor<TodoEntity>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        return try modelContext.fetch(descriptor).map { $0.toTodoItem() }
    }

    func addItem(_ item: TodoItem) throws {
        modelContext.insert(TodoEntity(from: item))
        try modelContext.save()
    }

    func updateItem(_ item: TodoItem) throws {
        if let entity = try fetchEntity(id: item.id) {
            entity.applyChanges(from: item)
            try modelContext.save()
        }
    }

    func deleteItems(ids: [UUID]) throws {
        for id in ids {
            if let entity = try fetchEntity(id: id) {
                modelContext.delete(entity)
            }
        }
        try modelContext.save()
    }

    func updateSortOrder(for items: [TodoItem]) throws {
        for item in items {
            if let entity = try fetchEntity(id: item.id) {
                entity.sortOrder = item.sortOrder
            }
        }
        try modelContext.save()
    }

    private func fetchEntity(id: UUID) throws -> TodoEntity? {
        let descriptor = FetchDescriptor<TodoEntity>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func migrateLegacyItemsIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: migrationFlagKey) else { return }

        let existingCount = (try? modelContext.fetchCount(FetchDescriptor<TodoEntity>())) ?? 0
        if existingCount > 0 {
            defaults.removeObject(forKey: legacyStorageKey)
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        guard let data = defaults.data(forKey: legacyStorageKey),
              let legacyItems = try? JSONDecoder().decode([TodoItem].self, from: data) else {
            defaults.set(true, forKey: migrationFlagKey)
            return
        }

        for (index, item) in legacyItems.enumerated() {
            var migrated = item
            migrated.sortOrder = index
            modelContext.insert(TodoEntity(from: migrated))
        }

        do {
            try modelContext.save()
            defaults.removeObject(forKey: legacyStorageKey)
            defaults.set(true, forKey: migrationFlagKey)
        } catch {
            // Leave the legacy key so migration can retry later.
        }
    }
}

import Foundation
import SwiftUI

enum SmartListID: String, CaseIterable, Hashable, Codable, Identifiable {
    case inbox
    case myDay
    case important
    case planned
    case completed
    case all

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .inbox:
            return "smart.inbox"
        case .myDay:
            return "smart.myDay"
        case .important:
            return "smart.important"
        case .planned:
            return "smart.planned"
        case .completed:
            return "smart.completed"
        case .all:
            return "smart.all"
        }
    }

    var systemImage: String {
        switch self {
        case .inbox:
            return "tray"
        case .myDay:
            return "sun.max"
        case .important:
            return "star"
        case .planned:
            return "calendar"
        case .completed:
            return "checkmark.circle"
        case .all:
            return "list.bullet"
        }
    }
}

enum TaskSortOption: String, CaseIterable, Codable, Identifiable {
    case manual
    case dueDate
    case priority
    case createdAt
    case completedAt

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .manual:
            return "sort.manual"
        case .dueDate:
            return "sort.duedate"
        case .priority:
            return "sort.priority"
        case .createdAt:
            return "sort.created"
        case .completedAt:
            return "sort.completedAt"
        }
    }
}

struct TaskQuery: Equatable, Codable {
    var searchText: String
    var sort: TaskSortOption
    var tagFilter: Set<String>
    var showCompleted: Bool

    init(
        searchText: String = "",
        sort: TaskSortOption = .manual,
        tagFilter: Set<String> = [],
        showCompleted: Bool = true
    ) {
        self.searchText = searchText
        self.sort = sort
        self.tagFilter = tagFilter
        self.showCompleted = showCompleted
    }
}

final class ListQueryEngine {
    private struct SortCacheKey: Hashable {
        let option: TaskSortOption
        let signature: String
    }

    private var sortCache: [SortCacheKey: [TodoItem]] = [:]
    private var sortCacheOrder: [SortCacheKey] = []
    private let maxSortCacheEntries = 20

    func tasks(
        from items: [TodoItem],
        list: SmartListID,
        query: TaskQuery,
        selectedTag: String?,
        useGlobalSearch: Bool,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> [TodoItem] {
        let normalizedSearch = query.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let globalSearchEnabled = useGlobalSearch && !normalizedSearch.isEmpty

        var filtered = items.filter { item in
            if globalSearchEnabled {
                return true
            }
            return matchesSmartList(item: item, list: list, referenceDate: referenceDate, calendar: calendar)
        }

        filtered = filtered.filter { item in
            if !query.showCompleted && item.isCompleted {
                return false
            }

            if let selectedTag, !selectedTag.isEmpty {
                let itemTagSet = Set(item.tags.map { normalizedTagName($0.name) })
                if !itemTagSet.contains(normalizedTagName(selectedTag)) {
                    return false
                }
            }

            if !query.tagFilter.isEmpty {
                let itemTagSet = Set(item.tags.map { normalizedTagName($0.name) })
                if itemTagSet.isDisjoint(with: query.tagFilter) {
                    return false
                }
            }

            if normalizedSearch.isEmpty {
                return true
            }

            if item.title.localizedCaseInsensitiveContains(normalizedSearch) {
                return true
            }

            if item.descriptionMarkdown.localizedCaseInsensitiveContains(normalizedSearch) {
                return true
            }

            return item.tags.contains { $0.name.localizedCaseInsensitiveContains(normalizedSearch) }
        }

        return sort(items: filtered, by: query.sort)
    }

    func groupedPlannedTasks(
        _ items: [TodoItem],
        calendar: Calendar = .current
    ) -> [(date: Date?, items: [TodoItem])] {
        let grouped = Dictionary(grouping: items) { item -> Date? in
            guard let dueDate = item.dueDate else { return nil }
            return calendar.startOfDay(for: dueDate)
        }

        let keys = grouped.keys.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (left?, right?):
                return left < right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return false
            }
        }

        return keys.compactMap { key in
            guard let values = grouped[key] else { return nil }
            return (key, sort(items: values, by: .dueDate))
        }
    }

    func isInMyDay(_ item: TodoItem, referenceDate: Date, calendar: Calendar = .current) -> Bool {
        guard let myDayDate = item.myDayDate else { return false }
        return calendar.isDate(myDayDate, inSameDayAs: referenceDate)
    }

    private func matchesSmartList(
        item: TodoItem,
        list: SmartListID,
        referenceDate: Date,
        calendar: Calendar
    ) -> Bool {
        switch list {
        case .inbox:
            return !item.isCompleted
                && item.dueDate == nil
                && !isInMyDay(item, referenceDate: referenceDate, calendar: calendar)
        case .myDay:
            return !item.isCompleted && isInMyDay(item, referenceDate: referenceDate, calendar: calendar)
        case .important:
            return !item.isCompleted && item.isImportant
        case .planned:
            return !item.isCompleted && item.dueDate != nil
        case .completed:
            return item.isCompleted
        case .all:
            return true
        }
    }

    private func sort(items: [TodoItem], by option: TaskSortOption) -> [TodoItem] {
        let signature = buildSortSignature(for: items)
        let key = SortCacheKey(option: option, signature: signature)

        if let cached = sortCache[key] {
            return cached
        }

        let sorted: [TodoItem]
        switch option {
        case .manual:
            sorted = items
        case .dueDate:
            sorted = items.sorted { lhs, rhs in
                let lhsDue = lhs.dueDate ?? .distantFuture
                let rhsDue = rhs.dueDate ?? .distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                if lhs.isImportant != rhs.isImportant {
                    return lhs.isImportant
                }
                if priorityRank(lhs.priority) != priorityRank(rhs.priority) {
                    return priorityRank(lhs.priority) > priorityRank(rhs.priority)
                }
                return lhs.createdAt > rhs.createdAt
            }
        case .priority:
            sorted = items.sorted { lhs, rhs in
                if lhs.isImportant != rhs.isImportant {
                    return lhs.isImportant
                }
                if priorityRank(lhs.priority) != priorityRank(rhs.priority) {
                    return priorityRank(lhs.priority) > priorityRank(rhs.priority)
                }
                let lhsDue = lhs.dueDate ?? .distantFuture
                let rhsDue = rhs.dueDate ?? .distantFuture
                if lhsDue != rhsDue {
                    return lhsDue < rhsDue
                }
                return lhs.createdAt > rhs.createdAt
            }
        case .createdAt:
            sorted = items.sorted { $0.createdAt > $1.createdAt }
        case .completedAt:
            sorted = items.sorted { lhs, rhs in
                let lhsCompleted = lhs.completedAt ?? .distantPast
                let rhsCompleted = rhs.completedAt ?? .distantPast
                return lhsCompleted > rhsCompleted
            }
        }

        sortCache[key] = sorted
        sortCacheOrder.append(key)
        if sortCacheOrder.count > maxSortCacheEntries {
            let dropCount = sortCacheOrder.count - maxSortCacheEntries
            let dropped = sortCacheOrder.prefix(dropCount)
            sortCacheOrder.removeFirst(dropCount)
            for oldKey in dropped {
                sortCache.removeValue(forKey: oldKey)
            }
        }

        return sorted
    }

    private func buildSortSignature(for items: [TodoItem]) -> String {
        items.map { item in
            "\(item.id.uuidString)-\(item.updatedAt.timeIntervalSince1970)-\(item.isCompleted ? 1 : 0)-\(item.isImportant ? 1 : 0)"
        }
        .joined(separator: "|")
    }

    private func priorityRank(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }

    private func normalizedTagName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

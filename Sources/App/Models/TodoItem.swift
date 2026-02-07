import Foundation
import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    struct Subtask: Identifiable, Codable, Equatable {
        let id: UUID
        var title: String
        var isCompleted: Bool

        init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
            self.id = id
            self.title = title
            self.isCompleted = isCompleted
        }
    }

    enum Priority: String, Codable, CaseIterable, Identifiable {
        case low
        case medium
        case high

        var id: String { rawValue }

        var displayNameKey: LocalizedStringKey {
            switch self {
            case .low:
                return "priority.low"
            case .medium:
                return "priority.medium"
            case .high:
                return "priority.high"
            }
        }
    }

    enum RepeatRule: String, Codable, CaseIterable, Identifiable {
        case none
        case daily
        case weekly
        case monthly

        var id: String { rawValue }

        var titleKey: LocalizedStringKey {
            switch self {
            case .none:
                return "repeat.none"
            case .daily:
                return "repeat.daily"
            case .weekly:
                return "repeat.weekly"
            case .monthly:
                return "repeat.monthly"
            }
        }
    }

    let id: UUID
    var title: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var tags: [String]
    var subtasks: [Subtask]
    var repeatRule: RepeatRule
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        tags: [String] = [],
        subtasks: [Subtask] = [],
        repeatRule: RepeatRule = .none,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.tags = tags
        self.subtasks = subtasks
        self.repeatRule = repeatRule
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        priority = try container.decode(Priority.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(tags, forKey: .tags)
        try container.encode(subtasks, forKey: .subtasks)
        try container.encode(repeatRule, forKey: .repeatRule)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

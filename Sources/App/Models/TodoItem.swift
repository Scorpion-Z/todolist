import Foundation
import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
    enum RepeatRule: String, Codable, CaseIterable, Identifiable {
        case none
        case daily
        case weekly
        case monthly

        var id: String { rawValue }

        var displayNameKey: LocalizedStringKey {
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

    let id: UUID
    var title: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var createdAt: Date
    var subtasks: [Subtask]
    var tags: [Tag]
    var repeatRule: RepeatRule

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        subtasks: [Subtask] = [],
        tags: [Tag] = [],
        repeatRule: RepeatRule = .none
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.subtasks = subtasks
        self.tags = tags
        self.repeatRule = repeatRule
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isCompleted
        case priority
        case dueDate
        case createdAt
        case subtasks
        case tags
        case repeatRule
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        priority = try container.decode(Priority.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        tags = try container.decodeIfPresent([Tag].self, forKey: .tags) ?? []
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
    }
}

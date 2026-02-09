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
    var descriptionMarkdown: String
    var isCompleted: Bool
    var priority: Priority
    var dueDate: Date?
    var tags: [Tag]
    var subtasks: [Subtask]
    var repeatRule: RepeatRule
    var isImportant: Bool
    var myDayDate: Date?
    var completedAt: Date?
    var updatedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        descriptionMarkdown: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        isImportant: Bool = false,
        myDayDate: Date? = nil,
        completedAt: Date? = nil,
        updatedAt: Date? = nil,
        createdAt: Date = Date(),
        subtasks: [Subtask] = [],
        tags: [Tag] = [],
        repeatRule: RepeatRule = .none
    ) {
        self.id = id
        self.title = title
        self.descriptionMarkdown = descriptionMarkdown
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.isImportant = isImportant
        self.myDayDate = myDayDate
        self.completedAt = completedAt
        self.updatedAt = updatedAt ?? createdAt
        self.createdAt = createdAt
        self.subtasks = subtasks
        self.tags = tags
        self.repeatRule = repeatRule
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case descriptionMarkdown
        case isCompleted
        case priority
        case dueDate
        case tags
        case subtasks
        case repeatRule
        case isImportant
        case myDayDate
        case completedAt
        case updatedAt
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        descriptionMarkdown = try container.decodeIfPresent(String.self, forKey: .descriptionMarkdown) ?? ""
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        priority = try container.decodeIfPresent(Priority.self, forKey: .priority) ?? .medium
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        isImportant = try container.decodeIfPresent(Bool.self, forKey: .isImportant) ?? false
        myDayDate = try container.decodeIfPresent(Date.self, forKey: .myDayDate)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        subtasks = try container.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        if let decodedTags = try? container.decode([Tag].self, forKey: .tags) {
            tags = decodedTags
        } else if let legacyTags = try? container.decode([String].self, forKey: .tags) {
            tags = legacyTags.map { Tag(name: $0) }
        } else {
            tags = []
        }
        repeatRule = try container.decodeIfPresent(RepeatRule.self, forKey: .repeatRule) ?? .none
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(descriptionMarkdown, forKey: .descriptionMarkdown)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(isImportant, forKey: .isImportant)
        try container.encodeIfPresent(myDayDate, forKey: .myDayDate)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(tags, forKey: .tags)
        try container.encode(subtasks, forKey: .subtasks)
        try container.encode(repeatRule, forKey: .repeatRule)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

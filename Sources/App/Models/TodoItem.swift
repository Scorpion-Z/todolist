import Foundation
import SwiftUI

struct TodoItem: Identifiable, Codable, Equatable {
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
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        descriptionMarkdown: String = "",
        isCompleted: Bool = false,
        priority: Priority = .medium,
        dueDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.descriptionMarkdown = descriptionMarkdown
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case descriptionMarkdown
        case isCompleted
        case priority
        case dueDate
        case createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        descriptionMarkdown = try container.decodeIfPresent(String.self, forKey: .descriptionMarkdown) ?? ""
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        priority = try container.decode(Priority.self, forKey: .priority)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(descriptionMarkdown, forKey: .descriptionMarkdown)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encode(createdAt, forKey: .createdAt)
    }
}

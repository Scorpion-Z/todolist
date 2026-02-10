import Foundation
import SwiftUI

enum ListThemeStyle: String, Codable, CaseIterable, Identifiable {
    case graphite
    case ocean
    case forest
    case sunrise
    case violet

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .graphite: return "theme.graphite"
        case .ocean: return "theme.ocean"
        case .forest: return "theme.forest"
        case .sunrise: return "theme.sunrise"
        case .violet: return "theme.violet"
        }
    }
}

struct TodoListEntity: Identifiable, Codable, Equatable {
    static let defaultTasksListID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    let id: UUID
    var title: String
    var groupID: UUID?
    var icon: String
    var theme: ListThemeStyle
    var manualOrder: Double
    var isSystem: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        groupID: UUID? = nil,
        icon: String = "list.bullet",
        theme: ListThemeStyle = .graphite,
        manualOrder: Double = 0,
        isSystem: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.groupID = groupID
        self.icon = icon
        self.theme = theme
        self.manualOrder = manualOrder
        self.isSystem = isSystem
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    static let defaultTasks = TodoListEntity(
        id: TodoListEntity.defaultTasksListID,
        title: String(localized: "smart.tasks"),
        groupID: nil,
        icon: "house",
        theme: .graphite,
        manualOrder: -1,
        isSystem: true
    )
}

struct ListGroupEntity: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var manualOrder: Double
    var isCollapsed: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        manualOrder: Double = 0,
        isCollapsed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.manualOrder = manualOrder
        self.isCollapsed = isCollapsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}

struct ProfileSettings: Codable, Equatable {
    var displayName: String
    var email: String
    var avatarSystemImage: String
    var updatedAt: Date

    init(
        displayName: String = "Super KaKa",
        email: String = "me@example.com",
        avatarSystemImage: String = "person.crop.circle.fill",
        updatedAt: Date = Date()
    ) {
        self.displayName = displayName
        self.email = email
        self.avatarSystemImage = avatarSystemImage
        self.updatedAt = updatedAt
    }
}

struct AppPreferences: Codable, Equatable {
    var showCompletedSection: Bool
    var updatedAt: Date

    init(showCompletedSection: Bool = true, updatedAt: Date = Date()) {
        self.showCompletedSection = showCompletedSection
        self.updatedAt = updatedAt
    }
}

struct TodoAppSnapshot: Codable, Equatable {
    var schemaVersion: Int
    var tasks: [TodoItem]
    var lists: [TodoListEntity]
    var groups: [ListGroupEntity]
    var profile: ProfileSettings
    var appPrefs: AppPreferences

    init(
        schemaVersion: Int = 3,
        tasks: [TodoItem] = [],
        lists: [TodoListEntity] = [TodoListEntity.defaultTasks],
        groups: [ListGroupEntity] = [],
        profile: ProfileSettings = ProfileSettings(),
        appPrefs: AppPreferences = AppPreferences()
    ) {
        self.schemaVersion = schemaVersion
        self.tasks = tasks
        self.lists = lists
        self.groups = groups
        self.profile = profile
        self.appPrefs = appPrefs
    }
}

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
    var listID: UUID
    var manualOrder: Double
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
        listID: UUID = TodoListEntity.defaultTasksListID,
        manualOrder: Double = 0,
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
        self.listID = listID
        self.manualOrder = manualOrder
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
        case listID
        case manualOrder
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
        listID = try container.decodeIfPresent(UUID.self, forKey: .listID) ?? TodoListEntity.defaultTasksListID
        manualOrder = try container.decodeIfPresent(Double.self, forKey: .manualOrder) ?? 0
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
        try container.encode(listID, forKey: .listID)
        try container.encode(manualOrder, forKey: .manualOrder)
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

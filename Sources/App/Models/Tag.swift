import Foundation
import SwiftUI

struct Tag: Identifiable, Codable, Equatable {
    enum TagColor: String, Codable, CaseIterable, Identifiable {
        case red
        case orange
        case yellow
        case green
        case teal
        case blue
        case purple
        case pink
        case gray

        var id: String { rawValue }

        var displayNameKey: LocalizedStringKey {
            switch self {
            case .red:
                return "tag.color.red"
            case .orange:
                return "tag.color.orange"
            case .yellow:
                return "tag.color.yellow"
            case .green:
                return "tag.color.green"
            case .teal:
                return "tag.color.teal"
            case .blue:
                return "tag.color.blue"
            case .purple:
                return "tag.color.purple"
            case .pink:
                return "tag.color.pink"
            case .gray:
                return "tag.color.gray"
            }
        }

        var tint: Color {
            switch self {
            case .red:
                return .red
            case .orange:
                return .orange
            case .yellow:
                return .yellow
            case .green:
                return .green
            case .teal:
                return .teal
            case .blue:
                return .blue
            case .purple:
                return .purple
            case .pink:
                return .pink
            case .gray:
                return .gray
            }
        }
    }

    let id: UUID
    var name: String
    var color: TagColor

    init(id: UUID = UUID(), name: String, color: TagColor = .blue) {
        self.id = id
        self.name = name
        self.color = color
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(TagColor.self, forKey: .color) ?? .blue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(color, forKey: .color)
    }
}

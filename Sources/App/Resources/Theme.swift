import SwiftUI
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

enum AppTheme {
    static let background: Color = {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(.systemGroupedBackground)
#endif
    }()

    static let cardBackground: Color = {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(.secondarySystemBackground)
#endif
    }()

    static let divider: Color = {
#if os(macOS)
        Color(nsColor: .separatorColor)
#else
        Color(.separator)
#endif
    }()

    static let cardBorder: Color = divider.opacity(0.5)
    static let secondaryText: Color = Color.primary.opacity(0.65)
    static let tertiaryText: Color = Color.primary.opacity(0.5)
    static let pillBackground: Color = cardBackground.opacity(0.9)
    static let cardCornerRadius: CGFloat = 16

    static let surface0: Color = {
#if os(macOS)
        Color(nsColor: .windowBackgroundColor)
#else
        Color(.systemBackground)
#endif
    }()

    static let surface1: Color = {
#if os(macOS)
        Color(nsColor: .controlBackgroundColor)
#else
        Color(.secondarySystemBackground)
#endif
    }()

    static let surface2: Color = {
#if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
#else
        Color(.tertiarySystemBackground)
#endif
    }()

    static let sidebarBackground: Color = surface2
    static let strokeSubtle: Color = divider.opacity(0.45)
    static let focusRing: Color = Color.accentColor.opacity(0.55)
    static let accentStrong: Color = Color.accentColor
    static let accentSoft: Color = Color.accentColor.opacity(0.15)
    static let selectionBackground: Color = accentSoft
    static let glassSurface: Color = surface1.opacity(0.92)

    static func color(for style: ListThemeStyle) -> Color {
        switch style {
        case .graphite: return Color.gray
        case .ocean: return Color.cyan
        case .forest: return Color.green
        case .sunrise: return Color.orange
        case .violet: return Color.indigo
        }
    }

    static func gradient(for style: ListThemeStyle) -> [Color] {
        switch style {
        case .graphite:
            return [Color(red: 0.12, green: 0.13, blue: 0.16), Color(red: 0.18, green: 0.20, blue: 0.24)]
        case .ocean:
            return [Color(red: 0.15, green: 0.44, blue: 0.51), Color(red: 0.45, green: 0.67, blue: 0.73)]
        case .forest:
            return [Color(red: 0.13, green: 0.28, blue: 0.19), Color(red: 0.28, green: 0.44, blue: 0.28)]
        case .sunrise:
            return [Color(red: 0.47, green: 0.25, blue: 0.12), Color(red: 0.78, green: 0.49, blue: 0.26)]
        case .violet:
            return [Color(red: 0.20, green: 0.17, blue: 0.37), Color(red: 0.45, green: 0.37, blue: 0.66)]
        }
    }

    static func backgroundAssetName(for style: ListThemeStyle) -> String {
        switch style {
        case .graphite:
            return "ToDoBackgroundGraphite"
        case .ocean:
            return "ToDoBackgroundOcean"
        case .forest:
            return "ToDoBackgroundForest"
        case .sunrise:
            return "ToDoBackgroundSunrise"
        case .violet:
            return "ToDoBackgroundViolet"
        }
    }

    static func backgroundImage(for style: ListThemeStyle) -> Image? {
        let assetName = backgroundAssetName(for: style)
#if os(macOS)
        guard NSImage(named: NSImage.Name(assetName)) != nil else { return nil }
#elseif canImport(UIKit)
        guard UIImage(named: assetName) != nil else { return nil }
#endif
        return Image(assetName)
    }

    static func titleColor(for style: ListThemeStyle) -> Color {
        switch style {
        case .graphite: return Color.blue.opacity(0.88)
        case .ocean: return Color.white
        case .forest: return Color.green.opacity(0.9)
        case .sunrise: return Color.orange.opacity(0.9)
        case .violet: return Color.indigo.opacity(0.9)
        }
    }
}

enum AppTypography {
    static let title = Font.system(size: 22, weight: .semibold)
    static let sectionTitle = Font.system(size: 16, weight: .semibold)
    static let subtitle = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 14, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let metricLabel = Font.system(size: 12, weight: .medium)
    static let metricValue = Font.system(size: 20, weight: .semibold)
}

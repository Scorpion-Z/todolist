import SwiftUI

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

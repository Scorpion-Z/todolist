import SwiftUI

enum ToDoWebMetrics {
    static let sidebarMinWidth: CGFloat = 264
    static let sidebarIdealWidth: CGFloat = 280
    static let sidebarMaxWidth: CGFloat = 312

    static let contentPadding: CGFloat = 16
    static let titleTopPadding: CGFloat = 20
    static let titleBottomPadding: CGFloat = 12
    static let titleHorizontalPadding: CGFloat = 20
    static let titleSpacing: CGFloat = 4
    static let titleFontSize: CGFloat = 46
    static let subtitleFontSize: CGFloat = 23

    static let taskRowMinHeight: CGFloat = 52
    static let taskRowCornerRadius: CGFloat = 8
    static let taskRowHorizontalPadding: CGFloat = 12
    static let taskRowVerticalPadding: CGFloat = 10

    static let quickAddHeight: CGFloat = 52
    static let quickAddCornerRadius: CGFloat = 8
    static let quickAddHorizontalPadding: CGFloat = 14
    static let quickAddVerticalPadding: CGFloat = 12

    static let detailDefaultWidth: CGFloat = 400
    static let detailMinWidth: CGFloat = 360
    static let detailMaxWidth: CGFloat = 520
    static let detailMaxWidthRatio: CGFloat = 0.46
    static let inlineDetailThreshold: CGFloat = 1240
    static let detailResizeHandleWidth: CGFloat = 10
    static let detailResizeLineWidth: CGFloat = 1

    static let toolbarButtonSize: CGFloat = 32
    static let toolbarButtonSpacing: CGFloat = 8

    static let sidebarSearchHeight: CGFloat = 36
    static let sidebarSearchCornerRadius: CGFloat = 8
    static let sidebarRowHeight: CGFloat = 37
    static let sidebarFooterHeight: CGFloat = 44

    static let detailFieldSpacing: CGFloat = 12
    static let detailSectionSpacing: CGFloat = 14
}

enum ToDoWebColors {
    static let backgroundOverlay = Color.black.opacity(0.30)
    static let panelFill = Color.black.opacity(0.24)

    static let rowDefaultBackground = Color.black.opacity(0.22)
    static let rowHoverBackground = Color.black.opacity(0.28)
    static let rowSelectedBackground = Color.white.opacity(0.18)
    static let rowDefaultBorder = Color.white.opacity(0.12)
    static let rowSelectedBorder = Color.white.opacity(0.38)

    static let quickAddBackground = Color.black.opacity(0.30)
    static let quickAddBorder = Color.white.opacity(0.12)
    static let quickAddFocusBorder = Color.white.opacity(0.28)

    static let secondaryText = Color.white.opacity(0.75)
    static let subtitleText = Color.white.opacity(0.82)
    static let handleLine = Color.white.opacity(0.20)
}

enum ToDoWebMotion {
    static let hoverFadeDuration: Double = 0.12
    static let standardDuration: Double = 0.16

    static let hoverFade: Animation = .easeOut(duration: hoverFadeDuration)
    static let standard: Animation = .easeOut(duration: standardDuration)
}

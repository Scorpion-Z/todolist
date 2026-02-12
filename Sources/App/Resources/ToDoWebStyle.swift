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
    static let quickAddActionMinWidth: CGFloat = 80

    static let detailDefaultWidth: CGFloat = 400
    static let detailMinWidth: CGFloat = 360
    static let detailMaxWidth: CGFloat = 520
    static let detailMaxWidthRatio: CGFloat = 0.46
    static let inlineDetailThreshold: CGFloat = 1240
    static let detailResizeHandleWidth: CGFloat = 10
    static let detailResizeLineWidth: CGFloat = 1

    static let toolbarIconHitArea: CGFloat = 36
    static let toolbarIconVisualSize: CGFloat = 32
    static let toolbarIconGlyphSize: CGFloat = 16
    static let toolbarIconSpacing: CGFloat = 8

    static let sidebarSearchHeight: CGFloat = 36
    static let sidebarSearchCornerRadius: CGFloat = 8
    static let sidebarRowHeight: CGFloat = 37
    static let sidebarFooterHeight: CGFloat = 44

    static let detailFieldSpacing: CGFloat = 12
    static let detailSectionSpacing: CGFloat = 14

    static func scaleFactor(for contentWidth: CGFloat) -> CGFloat {
        let minScale: CGFloat = 0.86
        let maxScale: CGFloat = 1.0
        let minWidth: CGFloat = 760
        let idealWidth: CGFloat = 1320

        guard contentWidth.isFinite else { return maxScale }
        if contentWidth <= minWidth { return minScale }
        if contentWidth >= idealWidth { return maxScale }

        let progress = (contentWidth - minWidth) / (idealWidth - minWidth)
        return minScale + progress * (maxScale - minScale)
    }
}

struct ToDoWebAdaptiveMetrics {
    let scale: CGFloat
    let contentPadding: CGFloat
    let titleTopPadding: CGFloat
    let titleBottomPadding: CGFloat
    let titleHorizontalPadding: CGFloat
    let titleFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let quickAddTopPadding: CGFloat
    let quickAddBottomPadding: CGFloat

    init(contentWidth: CGFloat) {
        let factor = ToDoWebMetrics.scaleFactor(for: contentWidth)
        scale = factor
        contentPadding = max(12, ToDoWebMetrics.contentPadding * factor)
        titleTopPadding = max(12, ToDoWebMetrics.titleTopPadding * factor)
        titleBottomPadding = max(8, ToDoWebMetrics.titleBottomPadding * factor)
        titleHorizontalPadding = max(14, ToDoWebMetrics.titleHorizontalPadding * factor)
        titleFontSize = max(34, ToDoWebMetrics.titleFontSize * factor)
        subtitleFontSize = max(18, ToDoWebMetrics.subtitleFontSize * factor)
        quickAddTopPadding = max(8, 10 * factor)
        quickAddBottomPadding = max(10, 14 * factor)
    }
}

enum ToDoWebColors {
    struct Palette {
        let isDark: Bool
        let backgroundOverlayOpacity: Double
        let panelFillOpacity: Double
        let rowDefaultBackgroundOpacity: Double
        let rowHoverBackgroundOpacity: Double
        let rowSelectedBackgroundOpacity: Double
        let separatorPrimaryOpacity: Double
        let separatorSecondaryOpacity: Double
        let separatorBorderOpacity: Double
        let rowSelectedBorderOpacity: Double
        let quickAddBackgroundOpacity: Double
        let quickAddFocusBorderOpacity: Double
        let primaryTextOpacity: Double
        let secondaryTextOpacity: Double
        let subtitleTextOpacity: Double
        let toolbarHoverFillOpacity: Double
        let sidebarBackgroundOpacity: Double
        let sidebarRowBackgroundOpacity: Double
        let sidebarSearchBackgroundOpacity: Double
        let sidebarSelectionBackgroundOpacity: Double
        let sidebarTextPrimaryOpacity: Double
        let sidebarTextSecondaryOpacity: Double

        private var foregroundBase: Color { isDark ? .white : .black }
        private var surfaceBase: Color { isDark ? .black : .white }

        var backgroundOverlay: Color {
            surfaceBase.opacity(backgroundOverlayOpacity)
        }

        var panelFill: Color {
            surfaceBase.opacity(panelFillOpacity)
        }

        var rowDefaultBackground: Color {
            surfaceBase.opacity(rowDefaultBackgroundOpacity)
        }

        var rowHoverBackground: Color {
            surfaceBase.opacity(rowHoverBackgroundOpacity)
        }

        var rowSelectedBackground: Color {
            surfaceBase.opacity(rowSelectedBackgroundOpacity)
        }

        var separatorPrimary: Color {
            foregroundBase.opacity(separatorPrimaryOpacity)
        }

        var separatorSecondary: Color {
            foregroundBase.opacity(separatorSecondaryOpacity)
        }

        var separatorBorder: Color {
            foregroundBase.opacity(separatorBorderOpacity)
        }

        var rowSelectedBorder: Color {
            foregroundBase.opacity(rowSelectedBorderOpacity)
        }

        var panelBorder: Color {
            separatorBorder
        }

        var quickAddBackground: Color {
            surfaceBase.opacity(quickAddBackgroundOpacity)
        }

        var quickAddBorder: Color {
            separatorBorder
        }

        var quickAddFocusBorder: Color {
            if isDark {
                return foregroundBase.opacity(quickAddFocusBorderOpacity)
            }
            return Color.accentColor.opacity(quickAddFocusBorderOpacity)
        }

        var primaryText: Color {
            foregroundBase.opacity(primaryTextOpacity)
        }

        var secondaryText: Color {
            foregroundBase.opacity(secondaryTextOpacity)
        }

        var subtitleText: Color {
            foregroundBase.opacity(subtitleTextOpacity)
        }

        var toolbarHoverFill: Color {
            foregroundBase.opacity(toolbarHoverFillOpacity)
        }

        var handleLine: Color {
            separatorPrimary
        }

        var overdueTint: Color {
            Color.red.opacity(isDark ? 0.95 : 0.85)
        }

        var sidebarBackground: Color {
            if isDark {
                return surfaceBase.opacity(sidebarBackgroundOpacity)
            }
            return Color(red: 0.95, green: 0.96, blue: 0.97).opacity(sidebarBackgroundOpacity)
        }

        var sidebarRowBackground: Color {
            if isDark {
                return surfaceBase.opacity(sidebarRowBackgroundOpacity)
            }
            return .black.opacity(sidebarRowBackgroundOpacity)
        }

        var sidebarSearchBackground: Color {
            if isDark {
                return surfaceBase.opacity(sidebarSearchBackgroundOpacity)
            }
            return .white.opacity(sidebarSearchBackgroundOpacity)
        }

        var sidebarSelectionBackground: Color {
            if isDark {
                return .white.opacity(sidebarSelectionBackgroundOpacity)
            }
            return Color.accentColor.opacity(sidebarSelectionBackgroundOpacity)
        }

        var sidebarSelectionBorder: Color {
            if isDark {
                return Color.white.opacity(0.28)
            }
            return Color.accentColor.opacity(0.28)
        }

        var sidebarTextPrimary: Color {
            foregroundBase.opacity(sidebarTextPrimaryOpacity)
        }

        var sidebarTextSecondary: Color {
            foregroundBase.opacity(sidebarTextSecondaryOpacity)
        }
    }

    static let dark = Palette(
        isDark: true,
        backgroundOverlayOpacity: 0.30,
        panelFillOpacity: 0.24,
        rowDefaultBackgroundOpacity: 0.22,
        rowHoverBackgroundOpacity: 0.28,
        rowSelectedBackgroundOpacity: 0.18,
        separatorPrimaryOpacity: 0.22,
        separatorSecondaryOpacity: 0.14,
        separatorBorderOpacity: 0.12,
        rowSelectedBorderOpacity: 0.38,
        quickAddBackgroundOpacity: 0.30,
        quickAddFocusBorderOpacity: 0.28,
        primaryTextOpacity: 0.95,
        secondaryTextOpacity: 0.75,
        subtitleTextOpacity: 0.82,
        toolbarHoverFillOpacity: 0.08,
        sidebarBackgroundOpacity: 0.88,
        sidebarRowBackgroundOpacity: 0.16,
        sidebarSearchBackgroundOpacity: 0.24,
        sidebarSelectionBackgroundOpacity: 0.18,
        sidebarTextPrimaryOpacity: 0.94,
        sidebarTextSecondaryOpacity: 0.68
    )

    static let light = Palette(
        isDark: false,
        backgroundOverlayOpacity: 0.16,
        panelFillOpacity: 0.64,
        rowDefaultBackgroundOpacity: 0.38,
        rowHoverBackgroundOpacity: 0.46,
        rowSelectedBackgroundOpacity: 0.62,
        separatorPrimaryOpacity: 0.16,
        separatorSecondaryOpacity: 0.10,
        separatorBorderOpacity: 0.09,
        rowSelectedBorderOpacity: 0.26,
        quickAddBackgroundOpacity: 0.64,
        quickAddFocusBorderOpacity: 0.48,
        primaryTextOpacity: 0.92,
        secondaryTextOpacity: 0.68,
        subtitleTextOpacity: 0.74,
        toolbarHoverFillOpacity: 0.10,
        sidebarBackgroundOpacity: 0.98,
        sidebarRowBackgroundOpacity: 0.02,
        sidebarSearchBackgroundOpacity: 0.94,
        sidebarSelectionBackgroundOpacity: 0.20,
        sidebarTextPrimaryOpacity: 0.88,
        sidebarTextSecondaryOpacity: 0.56
    )

    static func palette(for colorScheme: ColorScheme) -> Palette {
        colorScheme == .dark ? dark : light
    }

    static let backgroundOverlay = dark.backgroundOverlay
    static let panelFill = dark.panelFill
    static let rowDefaultBackground = dark.rowDefaultBackground
    static let rowHoverBackground = dark.rowHoverBackground
    static let rowSelectedBackground = dark.rowSelectedBackground
    static let separatorPrimary = dark.separatorPrimary
    static let separatorSecondary = dark.separatorSecondary
    static let separatorBorder = dark.separatorBorder
    static let rowSelectedBorder = dark.rowSelectedBorder
    static let quickAddBackground = dark.quickAddBackground
    static let quickAddBorder = dark.quickAddBorder
    static let quickAddFocusBorder = dark.quickAddFocusBorder
    static let secondaryText = dark.secondaryText
    static let subtitleText = dark.subtitleText
    static let handleLine = dark.handleLine
}

enum ToDoWebMotion {
    static let hoverFadeDuration: Double = 0.12
    static let standardDuration: Double = 0.16

    static let hoverBezier: Animation = .timingCurve(0.2, 0.0, 0.0, 1.0, duration: hoverFadeDuration)
    static let standard: Animation = .easeOut(duration: standardDuration)
}

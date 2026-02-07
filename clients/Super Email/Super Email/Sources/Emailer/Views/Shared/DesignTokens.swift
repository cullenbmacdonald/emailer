import SwiftUI

// MARK: - Account Colors

extension Color {
    /// Work account color — Blue
    static let accountWork = Color(light: .init(hex: 0x3B82F6), dark: .init(hex: 0x60A5FA))
    /// Personal 1 account color — Green
    static let accountPersonal1 = Color(light: .init(hex: 0x22C55E), dark: .init(hex: 0x4ADE80))
    /// Personal 2 account color — Orange
    static let accountPersonal2 = Color(light: .init(hex: 0xF97316), dark: .init(hex: 0xFB923C))
}

// MARK: - Semantic Colors

extension Color {
    /// Snooze — Purple
    static let snooze = Color(light: .init(hex: 0x8B5CF6), dark: .init(hex: 0xA78BFA))
    /// Newsletter — Cyan
    static let newsletter = Color(light: .init(hex: 0x06B6D4), dark: .init(hex: 0x22D3EE))
    /// Filtered — Gray
    static let filtered = Color(light: .init(hex: 0x6B7280), dark: .init(hex: 0x9CA3AF))
    /// Success — Green
    static let success = Color(light: .init(hex: 0x22C55E), dark: .init(hex: 0x4ADE80))
    /// Destructive — System red
    static let destructive = Color.red
}

// MARK: - Recommendation Type Colors

extension Color {
    /// Book — Purple
    static let recBook = Color(light: .init(hex: 0x8B5CF6), dark: .init(hex: 0xA78BFA))
    /// Movie/TV — Red
    static let recMovie = Color(light: .init(hex: 0xEF4444), dark: .init(hex: 0xF87171))
    /// Music — Pink
    static let recMusic = Color(light: .init(hex: 0xEC4899), dark: .init(hex: 0xF472B6))
    /// Article — Blue
    static let recArticle = Color(light: .init(hex: 0x3B82F6), dark: .init(hex: 0x60A5FA))
    /// Podcast — Orange
    static let recPodcast = Color(light: .init(hex: 0xF97316), dark: .init(hex: 0xFB923C))
    /// Other — Gray
    static let recOther = Color(light: .init(hex: 0x6B7280), dark: .init(hex: 0x9CA3AF))
}

// MARK: - Color Initializer Helpers

private extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                NSColor(dark)
            default:
                NSColor(light)
            }
        })
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Spacing Scale

/// Spacing constants based on a 4pt grid.
enum Spacing {
    /// 4pt — Icon-to-text gap, tight padding
    static let xs: CGFloat = 4
    /// 8pt — List row internal padding, compact gaps
    static let sm: CGFloat = 8
    /// 12pt — Standard element spacing
    static let md: CGFloat = 12
    /// 16pt — Section padding, card margins
    static let lg: CGFloat = 16
    /// 20pt — Between major sections
    static let xl: CGFloat = 20
    /// 24pt — Large section gaps, reader margins (macOS)
    static let xxl: CGFloat = 24
    /// 32pt — View-level padding
    static let xxxl: CGFloat = 32
    /// 48pt — Empty state vertical spacing
    static let xxxxl: CGFloat = 48
}

// MARK: - List Row Dimensions

/// Layout constants for email list rows on macOS.
enum ListRowMetrics {
    /// macOS row height: 64pt
    static let rowHeight: CGFloat = 64
    /// macOS horizontal padding: 12pt
    static let horizontalPadding: CGFloat = 12
    /// macOS vertical padding: 8pt
    static let verticalPadding: CGFloat = 8
    /// Account dot diameter: 8pt
    static let accountDotSize: CGFloat = 8
    /// Snooze badge height: 20pt
    static let snoozeBadgeHeight: CGFloat = 20
}

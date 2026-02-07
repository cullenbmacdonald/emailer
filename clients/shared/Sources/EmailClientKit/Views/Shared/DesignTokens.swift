import SwiftUI

// MARK: - Spacing Scale

/// Spacing constants based on a 4pt grid.
public enum Spacing {
    /// 4pt -- Icon-to-text gap, tight padding
    public static let xs: CGFloat = 4
    /// 8pt -- List row internal padding, compact gaps
    public static let sm: CGFloat = 8
    /// 12pt -- Standard element spacing
    public static let md: CGFloat = 12
    /// 16pt -- Section padding, card margins
    public static let lg: CGFloat = 16
    /// 20pt -- Between major sections
    public static let xl: CGFloat = 20
    /// 24pt -- Large section gaps, reader margins (macOS)
    public static let xxl: CGFloat = 24
    /// 32pt -- View-level padding
    public static let xxxl: CGFloat = 32
    /// 48pt -- Empty state vertical spacing
    public static let xxxxl: CGFloat = 48
}

// MARK: - List Row Dimensions

/// Layout constants for email list rows, adaptive per platform.
public enum ListRowMetrics {
    #if os(macOS)
    /// macOS row height: 64pt
    public static let rowHeight: CGFloat = 64
    /// macOS horizontal padding: 12pt
    public static let horizontalPadding: CGFloat = 12
    /// macOS vertical padding: 8pt
    public static let verticalPadding: CGFloat = 8
    /// Account dot diameter: 8pt
    public static let accountDotSize: CGFloat = 8
    /// Snooze badge height: 20pt
    public static let snoozeBadgeHeight: CGFloat = 20
    /// Badge min height: 20pt
    public static let badgeHeight: CGFloat = 20
    /// Empty state icon size: 48pt
    public static let emptyStateIconSize: CGFloat = 48
    /// Empty state max width: 320pt
    public static let emptyStateMaxWidth: CGFloat = 320
    #else
    /// iOS row height: 72pt
    public static let rowHeight: CGFloat = 72
    /// iOS horizontal padding: 16pt
    public static let horizontalPadding: CGFloat = 16
    /// iOS vertical padding: 10pt
    public static let verticalPadding: CGFloat = 10
    /// Account dot diameter: 10pt
    public static let accountDotSize: CGFloat = 10
    /// Snooze badge height: 22pt
    public static let snoozeBadgeHeight: CGFloat = 22
    /// Badge min height: 22pt
    public static let badgeHeight: CGFloat = 22
    /// Empty state icon size: 56pt
    public static let emptyStateIconSize: CGFloat = 56
    /// Empty state max width: 320pt
    public static let emptyStateMaxWidth: CGFloat = 320
    #endif
}

// MARK: - Account Colors

public extension Color {
    /// Work account color -- Blue
    static let accountWork = Color(light: Color(hex: 0x3B82F6), dark: Color(hex: 0x60A5FA))
    /// Personal 1 account color -- Green
    static let accountPersonal1 = Color(light: Color(hex: 0x22C55E), dark: Color(hex: 0x4ADE80))
    /// Personal 2 account color -- Orange
    static let accountPersonal2 = Color(light: Color(hex: 0xF97316), dark: Color(hex: 0xFB923C))
}

// MARK: - Semantic Colors

public extension Color {
    /// Snooze -- Purple
    static let snooze = Color(light: Color(hex: 0x8B5CF6), dark: Color(hex: 0xA78BFA))
    /// Newsletter -- Cyan
    static let newsletter = Color(light: Color(hex: 0x06B6D4), dark: Color(hex: 0x22D3EE))
    /// Filtered -- Gray
    static let filteredColor = Color(light: Color(hex: 0x6B7280), dark: Color(hex: 0x9CA3AF))
    /// Success -- Green
    static let success = Color(light: Color(hex: 0x22C55E), dark: Color(hex: 0x4ADE80))
    /// Destructive -- System red
    static let destructive = Color.red
}

// MARK: - Recommendation Type Colors

public extension Color {
    /// Book -- Purple
    static let recBook = Color(light: Color(hex: 0x8B5CF6), dark: Color(hex: 0xA78BFA))
    /// Movie/TV -- Red
    static let recMovie = Color(light: Color(hex: 0xEF4444), dark: Color(hex: 0xF87171))
    /// Music -- Pink
    static let recMusic = Color(light: Color(hex: 0xEC4899), dark: Color(hex: 0xF472B6))
    /// Article -- Blue
    static let recArticle = Color(light: Color(hex: 0x3B82F6), dark: Color(hex: 0x60A5FA))
    /// Podcast -- Orange
    static let recPodcast = Color(light: Color(hex: 0xF97316), dark: Color(hex: 0xFB923C))
    /// Other -- Gray
    static let recOther = Color(light: Color(hex: 0x6B7280), dark: Color(hex: 0x9CA3AF))
}

// MARK: - Color Initializer Helpers

public extension Color {
    /// Create a Color from a UInt32 hex value (e.g. 0x3B82F6).
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }

    /// Create a Color from a hex string (e.g. "#3B82F6" or "3B82F6").
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard let hex = UInt32(cleaned, radix: 16) else {
            self = .gray
            return
        }
        self.init(hex: hex)
    }
}

// MARK: - Adaptive Light/Dark Color

private extension Color {
    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua:
                NSColor(dark)
            default:
                NSColor(light)
            }
        })
        #else
        self.init(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                UIColor(dark)
            default:
                UIColor(light)
            }
        })
        #endif
    }
}

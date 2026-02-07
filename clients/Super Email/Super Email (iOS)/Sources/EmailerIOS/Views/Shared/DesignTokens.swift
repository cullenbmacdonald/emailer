import SwiftUI

// MARK: - iOS Spacing Tokens (4pt grid)

/// iOS-specific spacing and sizing tokens per design-system.md.
public enum IOSDesignTokens {
    // MARK: Spacing scale

    public static let spaceXS: CGFloat = 4
    public static let spaceSM: CGFloat = 8
    public static let spaceMD: CGFloat = 12
    public static let spaceLG: CGFloat = 16
    public static let spaceXL: CGFloat = 20
    public static let space2XL: CGFloat = 24
    public static let space3XL: CGFloat = 32
    public static let space4XL: CGFloat = 48

    // MARK: iOS list row dimensions

    public static let rowHeight: CGFloat = 72
    public static let rowHorizontalPadding: CGFloat = 16
    public static let rowVerticalPadding: CGFloat = 10
    public static let accountDotDiameter: CGFloat = 10
    public static let snoozeBadgeHeight: CGFloat = 22
    public static let badgeHeight: CGFloat = 22

    // MARK: Empty state

    public static let emptyStateIconSize: CGFloat = 56
    public static let emptyStateMaxWidth: CGFloat = 320
}

// MARK: - Semantic Colors

public extension Color {
    // Account colors
    static let accountWork = Color("accountWork", bundle: nil)
    static let accountPersonal1 = Color("accountPersonal1", bundle: nil)
    static let accountPersonal2 = Color("accountPersonal2", bundle: nil)

    // Semantic colors
    static let destructive = Color.red
    static let snooze = Color("snooze", bundle: nil)
    static let newsletter = Color("newsletter", bundle: nil)
    static let filtered = Color("filtered", bundle: nil)
    static let success = Color("success", bundle: nil)

    // Recommendation type colors
    static let recBook = Color("recBook", bundle: nil)
    static let recMovie = Color("recMovie", bundle: nil)
    static let recMusic = Color("recMusic", bundle: nil)
    static let recArticle = Color("recArticle", bundle: nil)
    static let recPodcast = Color("recPodcast", bundle: nil)
    static let recOther = Color("recOther", bundle: nil)
}

// MARK: - Fallback Color Initializers

/// When asset catalogs aren't available (SPM builds), provide hex fallbacks.
/// These will be replaced by asset catalog colors in the Xcode project.
public extension Color {
    /// Create a Color from a hex string (e.g. "#3B82F6").
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let green = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Hardcoded Fallback Colors (used until asset catalogs exist)

public extension Color {
    static let accountWorkFallback = Color(hex: "#3B82F6")
    static let accountPersonal1Fallback = Color(hex: "#22C55E")
    static let accountPersonal2Fallback = Color(hex: "#F97316")
    static let snoozeFallback = Color(hex: "#8B5CF6")
    static let newsletterFallback = Color(hex: "#06B6D4")
    static let filteredFallback = Color(hex: "#6B7280")
    static let successFallback = Color(hex: "#22C55E")
    static let recBookFallback = Color(hex: "#8B5CF6")
    static let recMovieFallback = Color(hex: "#EF4444")
    static let recMusicFallback = Color(hex: "#EC4899")
    static let recArticleFallback = Color(hex: "#3B82F6")
    static let recPodcastFallback = Color(hex: "#F97316")
    static let recOtherFallback = Color(hex: "#6B7280")
}

import SwiftUI

/// Represents each navigable view in the iPad sidebar.
/// Mirrors macOS SidebarDestination — iPad uses the same sidebar as macOS
/// for consistency across platforms.
public enum IOSSidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case actionQueue
    case readingQueue
    case recommendations
    case filtered
    case allInboxes
    case dailyDigest

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .actionQueue: "Action Queue"
        case .readingQueue: "Reading Queue"
        case .recommendations: "Recommendations"
        case .filtered: "Filtered"
        case .allInboxes: "All Inboxes"
        case .dailyDigest: "Daily Digest"
        }
    }

    public var iconName: String {
        switch self {
        case .actionQueue: "tray.and.arrow.down.fill"
        case .readingQueue: "book.fill"
        case .recommendations: "star.fill"
        case .filtered: "xmark.shield"
        case .allInboxes: "tray.full.fill"
        case .dailyDigest: "newspaper.fill"
        }
    }

    /// The main five views shown above the separator in the sidebar.
    public static var mainViews: [IOSSidebarDestination] {
        [.actionQueue, .readingQueue, .recommendations, .filtered, .allInboxes]
    }

    /// Whether this destination shows in the group below the separator.
    public var isBelowSeparator: Bool {
        self == .dailyDigest
    }
}

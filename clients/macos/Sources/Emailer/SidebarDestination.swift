import SwiftUI

/// Represents each navigable view in the sidebar.
enum SidebarDestination: String, CaseIterable, Identifiable, Sendable {
    case actionQueue
    case readingQueue
    case recommendations
    case filtered
    case allInboxes
    case dailyDigest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .actionQueue: "Action Queue"
        case .readingQueue: "Reading Queue"
        case .recommendations: "Recommendations"
        case .filtered: "Filtered"
        case .allInboxes: "All Inboxes"
        case .dailyDigest: "Daily Digest"
        }
    }

    var iconName: String {
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
    static var mainViews: [SidebarDestination] {
        [.actionQueue, .readingQueue, .recommendations, .filtered, .allInboxes]
    }

    /// Whether this destination shows in the group below the separator.
    var isBelowSeparator: Bool {
        self == .dailyDigest
    }
}

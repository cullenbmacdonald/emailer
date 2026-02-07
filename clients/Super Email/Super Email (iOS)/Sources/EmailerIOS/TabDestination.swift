import SwiftUI

/// Represents each tab in the iOS app's TabView.
public enum TabDestination: String, CaseIterable, Identifiable, Sendable {
    case actionQueue
    case readingQueue
    case recommendations
    case more

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .actionQueue: "Action"
        case .readingQueue: "Reading"
        case .recommendations: "Recs"
        case .more: "More"
        }
    }

    public var iconName: String {
        switch self {
        case .actionQueue: "exclamationmark.circle"
        case .readingQueue: "book"
        case .recommendations: "star"
        case .more: "ellipsis.circle"
        }
    }
}

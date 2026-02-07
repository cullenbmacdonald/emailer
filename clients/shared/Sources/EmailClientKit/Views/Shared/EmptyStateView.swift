import SwiftUI

/// Shown when a view has zero items.
/// Vertically centered with a large icon, title, and subtitle.
public struct EmptyStateView: View {
    public let iconName: String
    public let title: String
    public let subtitle: String

    public init(iconName: String, title: String, subtitle: String) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: iconName)
                .font(.system(size: ListRowMetrics.emptyStateIconSize))
                .foregroundStyle(.tertiary)

            VStack(spacing: Spacing.sm) {
                Text(title)
                    .font(.title2)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: ListRowMetrics.emptyStateMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Per-View Factory Methods

public extension EmptyStateView {
    static var actionQueue: EmptyStateView {
        EmptyStateView(
            iconName: "checkmark.circle",
            title: "All caught up",
            subtitle: "No emails need your response"
        )
    }

    static var readingQueue: EmptyStateView {
        EmptyStateView(
            iconName: "book.closed",
            title: "Nothing to read",
            subtitle: "Newsletters will appear here"
        )
    }

    static var recommendations: EmptyStateView {
        EmptyStateView(
            iconName: "star.circle",
            title: "No recommendations yet",
            subtitle: "As you read newsletters, recommendations will be extracted automatically"
        )
    }

    static var filteredView: EmptyStateView {
        EmptyStateView(
            iconName: "xmark.shield",
            title: "Nothing filtered",
            subtitle: "Spam and marketing will appear here for review"
        )
    }

    static var allInboxes: EmptyStateView {
        EmptyStateView(
            iconName: "tray",
            title: "No emails",
            subtitle: "Your inbox is empty"
        )
    }

    static var digest: EmptyStateView {
        EmptyStateView(
            iconName: "sun.horizon",
            title: "No digest yet",
            subtitle: "Your first digest will be generated at 6:00 AM"
        )
    }
}

#Preview("EmptyStateView - Action Queue") {
    EmptyStateView.actionQueue
}

#Preview("EmptyStateView - Reading Queue") {
    EmptyStateView.readingQueue
}

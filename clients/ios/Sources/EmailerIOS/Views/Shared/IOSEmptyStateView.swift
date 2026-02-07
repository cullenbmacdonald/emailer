import SwiftUI

/// Shown when a view has zero items.
/// Centered with a large SF Symbol icon (56pt for iOS vs 48pt macOS).
public struct IOSEmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String

    public init(iconName: String, title: String, subtitle: String) {
        self.iconName = iconName
        self.title = title
        self.subtitle = subtitle
    }

    public var body: some View {
        VStack(spacing: IOSDesignTokens.spaceXL) {
            Image(systemName: iconName)
                .font(.system(size: IOSDesignTokens.emptyStateIconSize))
                .foregroundStyle(.tertiary)
            VStack(spacing: IOSDesignTokens.spaceSM) {
                Text(title)
                    .font(.title2)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: IOSDesignTokens.emptyStateMaxWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }
}

// MARK: - Per-View Factory Methods

public extension IOSEmptyStateView {
    static var actionQueue: IOSEmptyStateView {
        IOSEmptyStateView(
            iconName: "checkmark.circle",
            title: "All caught up",
            subtitle: "No emails need your response"
        )
    }

    static var readingQueue: IOSEmptyStateView {
        IOSEmptyStateView(
            iconName: "book.closed",
            title: "Nothing to read",
            subtitle: "Newsletters will appear here"
        )
    }

    static var recommendations: IOSEmptyStateView {
        IOSEmptyStateView(
            iconName: "star.circle",
            title: "No recommendations yet",
            subtitle: "As you read newsletters, recommendations will be extracted automatically"
        )
    }

    static var filteredView: IOSEmptyStateView {
        IOSEmptyStateView(
            iconName: "xmark.shield",
            title: "Nothing filtered",
            subtitle: "Spam and marketing will appear here for review"
        )
    }

    static var allInboxes: IOSEmptyStateView {
        IOSEmptyStateView(
            iconName: "tray",
            title: "No emails",
            subtitle: "Your inbox is empty"
        )
    }

    static var digest: IOSEmptyStateView {
        IOSEmptyStateView(
            iconName: "sun.horizon",
            title: "No digest yet",
            subtitle: "Your first digest will be generated at 6:00 AM"
        )
    }
}

#Preview("Empty States") {
    ScrollView {
        VStack(spacing: 40) {
            IOSEmptyStateView.actionQueue
                .frame(height: 200)
            Divider()
            IOSEmptyStateView.readingQueue
                .frame(height: 200)
            Divider()
            IOSEmptyStateView.recommendations
                .frame(height: 200)
        }
    }
}

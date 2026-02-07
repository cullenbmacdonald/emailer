import SwiftUI

/// Shown when a view has zero items.
/// Vertically centered with a large icon, title, and subtitle.
struct EmptyStateView: View {
    let iconName: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: iconName)
                .font(.system(size: Spacing.xxxxl))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.title2)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 320)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("EmptyStateView - Action Queue") {
    EmptyStateView(
        iconName: "checkmark.circle",
        title: "All caught up",
        subtitle: "No emails need your response"
    )
}

#Preview("EmptyStateView - Reading Queue") {
    EmptyStateView(
        iconName: "book.closed",
        title: "Nothing to read",
        subtitle: "Newsletters will appear here"
    )
}

import SwiftUI

/// A capsule badge showing the classification type of an email.
///
/// Used in All Inboxes to show at a glance where each email appears.
/// Colors match the design system: accent for action required, cyan for newsletter,
/// gray for transactional, muted gray for filtered.
public struct ClassificationBadge: View {
    public let classificationType: ClassificationType

    public init(classificationType: ClassificationType) {
        self.classificationType = classificationType
    }

    public var body: some View {
        Text(abbreviatedLabel)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(badgeColor)
            .clipShape(Capsule())
            .accessibilityLabel("Classification: \(fullLabel)")
    }

    /// Full label for accessibility.
    public var fullLabel: String {
        switch classificationType {
        case .actionRequired: "Action Required"
        case .newsletter: "Newsletter"
        case .transactional: "Transactional"
        case .filtered: "Filtered"
        }
    }

    /// Abbreviated label for narrow screens.
    public var abbreviatedLabel: String {
        switch classificationType {
        case .actionRequired: "Action"
        case .newsletter: "News."
        case .transactional: "Trans."
        case .filtered: "Filt."
        }
    }

    /// Background color per classification type.
    public var badgeColor: Color {
        switch classificationType {
        case .actionRequired: .accentColor
        case .newsletter: .newsletter
        case .transactional: .gray
        case .filtered: .filteredColor
        }
    }
}

#Preview("Classification Badges") {
    VStack(spacing: 8) {
        ClassificationBadge(classificationType: .actionRequired)
        ClassificationBadge(classificationType: .newsletter)
        ClassificationBadge(classificationType: .transactional)
        ClassificationBadge(classificationType: .filtered)
    }
    .padding()
}

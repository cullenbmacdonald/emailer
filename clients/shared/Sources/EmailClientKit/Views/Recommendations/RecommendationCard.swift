import SwiftUI

/// A card displaying a single recommendation with inline actions.
public struct RecommendationCard: View {
    public let recommendation: Recommendation
    public let isSelected: Bool
    public var onSave: (() -> Void)?
    public var onDone: (() -> Void)?
    public var onDismiss: (() -> Void)?

    public init(
        recommendation: Recommendation,
        isSelected: Bool = false,
        onSave: (() -> Void)? = nil,
        onDone: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.recommendation = recommendation
        self.isSelected = isSelected
        self.onSave = onSave
        self.onDone = onDone
        self.onDismiss = onDismiss
    }

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            // Type icon
            Image(systemName: recommendation.type.iconName)
                .font(.system(size: 20))
                .foregroundStyle(recommendation.type.color)
                .frame(width: 24)
                .accessibilityHidden(true)

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title
                Text(recommendation.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                // Creator
                if let creator = recommendation.creator {
                    Text("by \(creator)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Context snippet
                if !recommendation.contextSnippet.isEmpty {
                    Text("\"\(recommendation.contextSnippet)\"")
                        .font(.callout)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Footer: source + date + duplicate badge
                HStack {
                    Text("From \(recommendation.sourceNewsletterName) -- \(formattedDate)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    if recommendation.duplicateCount > 1 {
                        Text("Rec'd by \(recommendation.duplicateCount) sources")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }

                // Action buttons (macOS only; iOS uses swipe)
                #if os(macOS)
                actionButtons
                #endif
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(selectionBorder)
        .overlay(darkModeBorder)
        .shadow(color: colorScheme == .light ? .black.opacity(0.08) : .clear, radius: 2, y: 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Action Buttons

    #if os(macOS)
    private var actionButtons: some View {
        HStack(spacing: Spacing.sm) {
            actionPill("Save", icon: "bookmark.fill", color: .accentColor) { onSave?() }
            actionPill("Done", icon: "checkmark.circle.fill", color: .success) { onDone?() }
            actionPill("Dismiss", icon: "xmark", color: .filteredColor) { onDismiss?() }
        }
        .padding(.top, Spacing.xs)
    }

    private func actionPill(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule().fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) recommendation")
    }
    #endif

    // MARK: - Styling

    @ViewBuilder
    private var cardBackground: some View {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    @ViewBuilder
    private var selectionBorder: some View {
        if isSelected {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                Spacer()
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var darkModeBorder: some View {
        if colorScheme == .dark {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: recommendation.sourceDate)
    }

    private var accessibilityDescription: String {
        var parts = ["\(recommendation.type.singularLabel): \(recommendation.title)"]
        if let creator = recommendation.creator {
            parts.append("by \(creator)")
        }
        parts.append("from \(recommendation.sourceNewsletterName)")
        parts.append("status: \(recommendation.status.rawValue)")
        if recommendation.duplicateCount > 1 {
            parts.append("recommended by \(recommendation.duplicateCount) sources")
        }
        return parts.joined(separator: ", ")
    }
}

#Preview("RecommendationCard") {
    VStack(spacing: 12) {
        RecommendationCard(
            recommendation: .preview,
            isSelected: true
        )
        RecommendationCard(
            recommendation: .previewArticle,
            isSelected: false
        )
    }
    .padding()
    .frame(width: 400)
}

// MARK: - Preview Data

public extension Recommendation {
    static let preview = Recommendation(
        id: "rec-1",
        type: .book,
        title: "The Innovator's Dilemma",
        creator: "Clayton Christensen",
        sourceNewsletterName: "Stratechery",
        sourceDate: Date(),
        contextSnippet: "Ben called it 'the best explanation of modularity theory I've read'",
        status: .new,
        duplicateCount: 3
    )

    static let previewArticle = Recommendation(
        id: "rec-2",
        type: .article,
        title: "How Stripe Built Billing",
        creator: "Patrick Collison",
        sourceNewsletterName: "Pragmatic Engineer",
        sourceDate: Date().addingTimeInterval(-86400),
        contextSnippet: "A masterclass in systems thinking and API design",
        status: .new,
        duplicateCount: 1
    )

    static let previewPodcast = Recommendation(
        id: "rec-3",
        type: .podcast,
        title: "Acquired: Stripe Episode",
        creator: "Ben Gilbert & David Rosenthal",
        sourceNewsletterName: "Hacker Newsletter",
        sourceDate: Date().addingTimeInterval(-172_800),
        contextSnippet: "The definitive history of Stripe's founding",
        status: .saved,
        duplicateCount: 1
    )
}

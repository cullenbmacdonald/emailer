import SwiftUI

/// Type filter pills and status filter for recommendations.
public struct RecommendationFilterBar: View {
    @Binding public var typeFilter: RecommendationType?
    @Binding public var statusFilter: RecommendationStatus?
    public var newCount: Int

    public init(
        typeFilter: Binding<RecommendationType?>,
        statusFilter: Binding<RecommendationStatus?>,
        newCount: Int = 0
    ) {
        self._typeFilter = typeFilter
        self._statusFilter = statusFilter
        self.newCount = newCount
    }

    /// Type filter options: nil means "All".
    private static let typeOptions: [(RecommendationType?, String, String)] = [
        (nil, "All", "star.fill"),
        (.book, "Books", "book.fill"),
        (.movie, "Movies/TV", "film.fill"),
        (.music, "Music", "music.note"),
        (.article, "Articles", "doc.text.fill"),
        (.podcast, "Podcasts", "mic.fill"),
        (.recipe, "Recipes", "fork.knife"),
        (.other, "Other", "star.fill")
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            typeFilterRow
            statusFilterRow
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Type Filter

    private var typeFilterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(Self.typeOptions, id: \.1) { option in
                    typeFilterPill(type: option.0, label: option.1, icon: option.2)
                }
            }
        }
    }

    private func typeFilterPill(type: RecommendationType?, label: String, icon: String) -> some View {
        let isActive = typeFilter == type
        let tintColor: Color = type?.color ?? .accentColor

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                typeFilter = type
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.callout)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(isActive ? tintColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? tintColor : Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .foregroundStyle(isActive ? tintColor : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter by \(label), \(isActive ? "active" : "inactive")")
    }

    // MARK: - Status Filter

    private var statusFilterRow: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(statusOptions, id: \.0) { option in
                statusButton(status: option.0, label: option.1)
            }
            Spacer()
        }
    }

    private var statusOptions: [(RecommendationStatus?, String)] {
        [
            (.new, "New (\(newCount))"),
            (.saved, "Saved"),
            (.done, "Done"),
            (.dismissed, "Dismissed"),
            (nil, "All")
        ]
    }

    private func statusButton(status: RecommendationStatus?, label: String) -> some View {
        let isActive = statusFilter == status

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                statusFilter = status
            }
        } label: {
            Text(label)
                .font(.caption)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundStyle(isActive ? .primary : .secondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    isActive
                        ? AnyShape(Capsule()).fill(Color.secondary.opacity(0.15))
                        : AnyShape(Capsule()).fill(Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show \(label) recommendations")
    }
}

#Preview("RecommendationFilterBar") {
    RecommendationFilterBar(
        typeFilter: .constant(nil),
        statusFilter: .constant(.new),
        newCount: 12
    )
    .frame(width: 400)
}

import SwiftUI

// MARK: - RecommendationType UI Helpers

public extension RecommendationType {
    /// SF Symbol name for this recommendation type.
    var iconName: String {
        switch self {
        case .book: "book.fill"
        case .movie: "film.fill"
        case .tv: "tv.fill"
        case .music: "music.note"
        case .article: "doc.text.fill"
        case .podcast: "mic.fill"
        case .other: "star.fill"
        }
    }

    /// The color token for this recommendation type.
    var color: Color {
        switch self {
        case .book: .recBook
        case .movie, .tv: .recMovie
        case .music: .recMusic
        case .article: .recArticle
        case .podcast: .recPodcast
        case .other: .recOther
        }
    }

    /// Display label.
    var label: String {
        switch self {
        case .book: "Books"
        case .movie: "Movies"
        case .tv: "TV"
        case .music: "Music"
        case .article: "Articles"
        case .podcast: "Podcasts"
        case .other: "Other"
        }
    }

    /// Singular display label.
    var singularLabel: String {
        switch self {
        case .book: "Book"
        case .movie: "Movie"
        case .tv: "TV Show"
        case .music: "Music"
        case .article: "Article"
        case .podcast: "Podcast"
        case .other: "Other"
        }
    }
}

// MARK: - Type Badge View

/// A small badge showing the recommendation type icon and label.
public struct TypeBadge: View {
    public let type: RecommendationType

    public init(type: RecommendationType) {
        self.type = type
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: type.iconName)
                .font(.system(size: 12))
            Text(type.singularLabel)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(type.color)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Type: \(type.singularLabel)")
    }
}

#Preview("TypeBadge") {
    VStack(spacing: 8) {
        ForEach(RecommendationType.allCases, id: \.self) { type in
            TypeBadge(type: type)
        }
    }
    .padding()
}

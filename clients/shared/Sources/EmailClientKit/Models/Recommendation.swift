import Foundation

/// The type/category of a recommendation.
public enum RecommendationType: String, Codable, Sendable, Equatable, CaseIterable {
    case book
    case movie
    case tv
    case music
    case article
    case podcast
    case other
}

/// User-managed status of a recommendation.
public enum RecommendationStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case new
    case saved
    case done
    case dismissed
}

/// A recommendation extracted from a newsletter.
public struct Recommendation: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let type: RecommendationType
    public let title: String
    public let creator: String?
    public let sourceNewsletterName: String
    public let sourceEmailId: String?
    public let sourceDate: Date
    public let contextSnippet: String
    public let status: RecommendationStatus
    public let duplicateCount: Int
    public let isUserAdded: Bool?
    public let createdAt: Date?

    public init(
        id: String,
        type: RecommendationType,
        title: String,
        creator: String? = nil,
        sourceNewsletterName: String,
        sourceEmailId: String? = nil,
        sourceDate: Date,
        contextSnippet: String,
        status: RecommendationStatus,
        duplicateCount: Int,
        isUserAdded: Bool? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.creator = creator
        self.sourceNewsletterName = sourceNewsletterName
        self.sourceEmailId = sourceEmailId
        self.sourceDate = sourceDate
        self.contextSnippet = contextSnippet
        self.status = status
        self.duplicateCount = duplicateCount
        self.isUserAdded = isUserAdded
        self.createdAt = createdAt
    }
}

/// Detail view of a recommendation with duplicate sources.
public struct RecommendationDetail: Codable, Sendable, Equatable {
    public let recommendation: Recommendation
    public let fullContext: String?
    public let duplicateSources: [DuplicateSource]

    public init(
        recommendation: Recommendation,
        fullContext: String? = nil,
        duplicateSources: [DuplicateSource]
    ) {
        self.recommendation = recommendation
        self.fullContext = fullContext
        self.duplicateSources = duplicateSources
    }
}

/// A source that recommended the same item.
public struct DuplicateSource: Codable, Sendable, Equatable {
    public let newsletterName: String
    public let emailId: String?
    public let date: Date
    public let contextSnippet: String

    public init(
        newsletterName: String,
        emailId: String? = nil,
        date: Date,
        contextSnippet: String
    ) {
        self.newsletterName = newsletterName
        self.emailId = emailId
        self.date = date
        self.contextSnippet = contextSnippet
    }
}

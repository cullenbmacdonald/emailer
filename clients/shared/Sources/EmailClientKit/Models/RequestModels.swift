import Foundation

/// Request body for updating email metadata.
public struct EmailUpdateRequest: Codable, Sendable, Equatable {
    public let isRead: Bool?
    public let isArchived: Bool?
    public let readProgress: Double?

    public init(isRead: Bool? = nil, isArchived: Bool? = nil, readProgress: Double? = nil) {
        self.isRead = isRead
        self.isArchived = isArchived
        self.readProgress = readProgress
    }
}

/// Request body for reclassifying an email.
public struct ReclassifyRequest: Codable, Sendable, Equatable {
    public let newClassification: ClassificationType
    public let confirm: Bool?

    public init(newClassification: ClassificationType, confirm: Bool? = nil) {
        self.newClassification = newClassification
        self.confirm = confirm
    }
}

/// Request body for snoozing an email.
public struct SnoozeRequest: Codable, Sendable, Equatable {
    public let returnAt: Date

    public init(returnAt: Date) {
        self.returnAt = returnAt
    }
}

/// Request body for creating a recommendation.
public struct RecommendationCreateRequest: Codable, Sendable, Equatable {
    public let type: RecommendationType
    public let title: String
    public let creator: String?
    public let contextSnippet: String?

    public init(
        type: RecommendationType,
        title: String,
        creator: String? = nil,
        contextSnippet: String? = nil
    ) {
        self.type = type
        self.title = title
        self.creator = creator
        self.contextSnippet = contextSnippet
    }
}

/// Request body for updating a recommendation's status.
public struct RecommendationUpdateRequest: Codable, Sendable, Equatable {
    public let status: RecommendationStatus

    public init(status: RecommendationStatus) {
        self.status = status
    }
}

/// Request body for updating a digest.
public struct DigestUpdateRequest: Codable, Sendable, Equatable {
    public let isRead: Bool

    public init(isRead: Bool) {
        self.isRead = isRead
    }
}

/// Request body for creating a VIP sender.
public struct VIPCreateRequest: Codable, Sendable, Equatable {
    public let email: String
    public let name: String?

    public init(email: String, name: String? = nil) {
        self.email = email
        self.name = name
    }
}

/// The view/queue parameter for email listing.
public enum EmailView: String, Codable, Sendable, Equatable, CaseIterable {
    case actionQueue = "action_queue"
    case readingQueue = "reading_queue"
    case filtered
    case allInboxes = "all_inboxes"
}

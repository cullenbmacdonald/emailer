import Foundation

/// Types of WebSocket events.
public enum WebSocketEventType: String, Codable, Sendable, Equatable, CaseIterable {
    case emailNew = "email.new"
    case emailUpdated = "email.updated"
    case emailDeleted = "email.deleted"
    case classificationChanged = "classification.changed"
    case snoozeCreated = "snooze.created"
    case snoozeReturned = "snooze.returned"
    case snoozeCancelled = "snooze.cancelled"
    case recommendationNew = "recommendation.new"
    case recommendationUpdated = "recommendation.updated"
    case digestAvailable = "digest.available"
    case accountStatus = "account.status"
    case pong
    /// Synthetic client-side event emitted when the connection is lost.
    case connectionLost = "connection.lost"
}

/// A WebSocket event from the server.
public struct WebSocketEvent: Sendable, Equatable {
    public let type: WebSocketEventType
    public let payload: WebSocketPayload
    public let timestamp: Date?

    public init(type: WebSocketEventType, payload: WebSocketPayload, timestamp: Date? = nil) {
        self.type = type
        self.payload = payload
        self.timestamp = timestamp
    }
}

/// The payload of a WebSocket event, discriminated by event type.
public enum WebSocketPayload: Sendable, Equatable {
    case emailNew(EmailNewPayload)
    case emailUpdated(EmailUpdatedPayload)
    case emailDeleted(EmailDeletedPayload)
    case classificationChanged(ClassificationChangedPayload)
    case snoozeCreated(SnoozeCreatedPayload)
    case snoozeReturned(SnoozeReturnedPayload)
    case snoozeCancelled(SnoozeCancelledPayload)
    case recommendationNew(RecommendationNewPayload)
    case recommendationUpdated(RecommendationUpdatedPayload)
    case digestAvailable(DigestAvailablePayload)
    case accountStatus(AccountStatusPayload)
    case pong
    /// Synthetic payload emitted when the WebSocket connection drops.
    case connectionLost(ConnectionLostPayload)
}

// MARK: - Payload Types

public struct EmailNewPayload: Codable, Sendable, Equatable {
    public let email: Email

    public init(email: Email) {
        self.email = email
    }
}

public struct EmailUpdatedPayload: Codable, Sendable, Equatable {
    public let email: Email

    public init(email: Email) {
        self.email = email
    }
}

public struct EmailDeletedPayload: Codable, Sendable, Equatable {
    public let emailId: String

    public init(emailId: String) {
        self.emailId = emailId
    }
}

public struct ClassificationChangedPayload: Codable, Sendable, Equatable {
    public let emailId: String
    public let previousClassification: ClassificationType
    public let newClassification: ClassificationType
    public let email: Email?

    public init(
        emailId: String,
        previousClassification: ClassificationType,
        newClassification: ClassificationType,
        email: Email? = nil
    ) {
        self.emailId = emailId
        self.previousClassification = previousClassification
        self.newClassification = newClassification
        self.email = email
    }
}

public struct SnoozeCreatedPayload: Codable, Sendable, Equatable {
    public let emailId: String
    public let snooze: SnoozeState

    public init(emailId: String, snooze: SnoozeState) {
        self.emailId = emailId
        self.snooze = snooze
    }
}

public struct SnoozeReturnedPayload: Codable, Sendable, Equatable {
    public let emailId: String
    public let email: Email

    public init(emailId: String, email: Email) {
        self.emailId = emailId
        self.email = email
    }
}

public struct SnoozeCancelledPayload: Codable, Sendable, Equatable {
    public let emailId: String
    public let email: Email

    public init(emailId: String, email: Email) {
        self.emailId = emailId
        self.email = email
    }
}

public struct RecommendationNewPayload: Codable, Sendable, Equatable {
    public let recommendation: Recommendation

    public init(recommendation: Recommendation) {
        self.recommendation = recommendation
    }
}

public struct RecommendationUpdatedPayload: Codable, Sendable, Equatable {
    public let recommendation: Recommendation

    public init(recommendation: Recommendation) {
        self.recommendation = recommendation
    }
}

public struct DigestAvailablePayload: Codable, Sendable, Equatable {
    public let digestId: String
    public let digestType: DigestType
    public let generatedAt: Date

    public init(digestId: String, digestType: DigestType, generatedAt: Date) {
        self.digestId = digestId
        self.digestType = digestType
        self.generatedAt = generatedAt
    }
}

public struct AccountStatusPayload: Codable, Sendable, Equatable {
    public let accountId: String
    public let status: AccountStatus
    public let statusMessage: String?

    public init(accountId: String, status: AccountStatus, statusMessage: String? = nil) {
        self.accountId = accountId
        self.status = status
        self.statusMessage = statusMessage
    }
}

public struct ConnectionLostPayload: Codable, Sendable, Equatable {
    public let reason: String?

    public init(reason: String? = nil) {
        self.reason = reason
    }
}

// MARK: - Custom Codable for WebSocketEvent

extension WebSocketEvent: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case payload
        case timestamp
    }

    // swiftlint:disable:next cyclomatic_complexity
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(WebSocketEventType.self, forKey: .type)
        self.type = type
        self.timestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp)

        switch type {
        case .emailNew:
            let data = try container.decode(EmailNewPayload.self, forKey: .payload)
            self.payload = .emailNew(data)
        case .emailUpdated:
            let data = try container.decode(EmailUpdatedPayload.self, forKey: .payload)
            self.payload = .emailUpdated(data)
        case .emailDeleted:
            let data = try container.decode(EmailDeletedPayload.self, forKey: .payload)
            self.payload = .emailDeleted(data)
        case .classificationChanged:
            let data = try container.decode(ClassificationChangedPayload.self, forKey: .payload)
            self.payload = .classificationChanged(data)
        case .snoozeCreated:
            let data = try container.decode(SnoozeCreatedPayload.self, forKey: .payload)
            self.payload = .snoozeCreated(data)
        case .snoozeReturned:
            let data = try container.decode(SnoozeReturnedPayload.self, forKey: .payload)
            self.payload = .snoozeReturned(data)
        case .snoozeCancelled:
            let data = try container.decode(SnoozeCancelledPayload.self, forKey: .payload)
            self.payload = .snoozeCancelled(data)
        case .recommendationNew:
            let data = try container.decode(RecommendationNewPayload.self, forKey: .payload)
            self.payload = .recommendationNew(data)
        case .recommendationUpdated:
            let data = try container.decode(RecommendationUpdatedPayload.self, forKey: .payload)
            self.payload = .recommendationUpdated(data)
        case .digestAvailable:
            let data = try container.decode(DigestAvailablePayload.self, forKey: .payload)
            self.payload = .digestAvailable(data)
        case .accountStatus:
            let data = try container.decode(AccountStatusPayload.self, forKey: .payload)
            self.payload = .accountStatus(data)
        case .pong:
            self.payload = .pong
        case .connectionLost:
            let data = try container.decode(ConnectionLostPayload.self, forKey: .payload)
            self.payload = .connectionLost(data)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)

        switch payload {
        case let .emailNew(data):
            try container.encode(data, forKey: .payload)
        case let .emailUpdated(data):
            try container.encode(data, forKey: .payload)
        case let .emailDeleted(data):
            try container.encode(data, forKey: .payload)
        case let .classificationChanged(data):
            try container.encode(data, forKey: .payload)
        case let .snoozeCreated(data):
            try container.encode(data, forKey: .payload)
        case let .snoozeReturned(data):
            try container.encode(data, forKey: .payload)
        case let .snoozeCancelled(data):
            try container.encode(data, forKey: .payload)
        case let .recommendationNew(data):
            try container.encode(data, forKey: .payload)
        case let .recommendationUpdated(data):
            try container.encode(data, forKey: .payload)
        case let .digestAvailable(data):
            try container.encode(data, forKey: .payload)
        case let .accountStatus(data):
            try container.encode(data, forKey: .payload)
        case .pong:
            try container.encode([String: String](), forKey: .payload)
        case let .connectionLost(data):
            try container.encode(data, forKey: .payload)
        }
    }
}

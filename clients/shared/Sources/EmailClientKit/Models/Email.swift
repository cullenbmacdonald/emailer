import Foundation

/// An email list item (without body content).
public struct Email: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let accountId: String
    public let messageId: String?
    public let threadId: String?
    public let from: Contact
    public let to: [Contact]
    public let cc: [Contact]?
    public let subject: String
    public let snippet: String
    public let receivedAt: Date
    public let classification: Classification
    public let isRead: Bool
    public let isArchived: Bool
    public let hasAttachments: Bool
    public let snooze: SnoozeState?
    public let labels: [String]?
    public let accountColor: String?
    public let accountName: String?
    public let recommendationCount: Int?
    public let lastReadAt: Date?
    public let readProgress: Double?
    public let daysUntilExpiry: Int?

    public init(
        id: String,
        accountId: String,
        messageId: String? = nil,
        threadId: String? = nil,
        from: Contact,
        to: [Contact],
        cc: [Contact]? = nil,
        subject: String,
        snippet: String,
        receivedAt: Date,
        classification: Classification,
        isRead: Bool,
        isArchived: Bool,
        hasAttachments: Bool,
        snooze: SnoozeState? = nil,
        labels: [String]? = nil,
        accountColor: String? = nil,
        accountName: String? = nil,
        recommendationCount: Int? = nil,
        lastReadAt: Date? = nil,
        readProgress: Double? = nil,
        daysUntilExpiry: Int? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.messageId = messageId
        self.threadId = threadId
        self.from = from
        self.to = to
        self.cc = cc
        self.subject = subject
        self.snippet = snippet
        self.receivedAt = receivedAt
        self.classification = classification
        self.isRead = isRead
        self.isArchived = isArchived
        self.hasAttachments = hasAttachments
        self.snooze = snooze
        self.labels = labels
        self.accountColor = accountColor
        self.accountName = accountName
        self.recommendationCount = recommendationCount
        self.lastReadAt = lastReadAt
        self.readProgress = readProgress
        self.daysUntilExpiry = daysUntilExpiry
    }
}

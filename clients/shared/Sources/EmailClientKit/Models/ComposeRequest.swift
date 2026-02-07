import Foundation

/// Request body for sending an email.
public struct ComposeRequest: Codable, Sendable, Equatable {
    public let accountId: String
    public let to: [String]
    public let cc: [String]?
    public let bcc: [String]?
    public let subject: String
    public let body: String
    public let htmlBody: String?
    public let inReplyTo: String?
    public let forwardOf: String?

    public init(
        accountId: String,
        to: [String],
        cc: [String]? = nil,
        bcc: [String]? = nil,
        subject: String,
        body: String,
        htmlBody: String? = nil,
        inReplyTo: String? = nil,
        forwardOf: String? = nil
    ) {
        self.accountId = accountId
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.htmlBody = htmlBody
        self.inReplyTo = inReplyTo
        self.forwardOf = forwardOf
    }
}

/// Response from sending an email.
public struct ComposeSendResponse: Codable, Sendable, Equatable {
    public let messageId: String

    public init(messageId: String) {
        self.messageId = messageId
    }
}

/// A saved draft.
public struct Draft: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let accountId: String
    public let to: [String]?
    public let cc: [String]?
    public let bcc: [String]?
    public let subject: String?
    public let body: String?
    public let htmlBody: String?
    public let inReplyTo: String?
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String,
        accountId: String,
        to: [String]? = nil,
        cc: [String]? = nil,
        bcc: [String]? = nil,
        subject: String? = nil,
        body: String? = nil,
        htmlBody: String? = nil,
        inReplyTo: String? = nil,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.accountId = accountId
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
        self.htmlBody = htmlBody
        self.inReplyTo = inReplyTo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

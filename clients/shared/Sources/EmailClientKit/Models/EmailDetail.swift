import Foundation

/// Full email detail including body content and attachments.
public struct EmailDetail: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let email: Email
    public let htmlBody: String
    public let textBody: String?
    public let attachments: [Attachment]

    public init(
        id: String,
        email: Email,
        htmlBody: String,
        textBody: String? = nil,
        attachments: [Attachment]
    ) {
        self.id = id
        self.email = email
        self.htmlBody = htmlBody
        self.textBody = textBody
        self.attachments = attachments
    }
}

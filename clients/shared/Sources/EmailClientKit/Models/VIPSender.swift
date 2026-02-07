import Foundation

/// A VIP sender whose emails always bypass filtering.
public struct VIPSender: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let email: String
    public let name: String?
    public let addedAt: Date

    public init(
        id: String,
        email: String,
        name: String? = nil,
        addedAt: Date
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.addedAt = addedAt
    }
}

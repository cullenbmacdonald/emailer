import Foundation

/// Snooze state for an email.
public struct SnoozeState: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let emailId: String
    public let snoozedAt: Date
    public let returnAt: Date
    public let snoozeCount: Int
    public let isActive: Bool

    public init(
        id: String,
        emailId: String,
        snoozedAt: Date,
        returnAt: Date,
        snoozeCount: Int,
        isActive: Bool
    ) {
        self.id = id
        self.emailId = emailId
        self.snoozedAt = snoozedAt
        self.returnAt = returnAt
        self.snoozeCount = snoozeCount
        self.isActive = isActive
    }
}

import Foundation

/// The type of an email account.
public enum AccountType: String, Codable, Sendable, Equatable, CaseIterable {
    case work
    case personal
}

/// The connection status of an email account.
public enum AccountStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case online
    case offline
    case error
    case syncing
}

/// An email account.
public struct Account: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let emailAddress: String
    public let accountType: AccountType
    public let color: String
    public let status: AccountStatus
    public let statusMessage: String?
    public let counts: AccountCounts?

    public init(
        id: String,
        name: String,
        emailAddress: String,
        accountType: AccountType,
        color: String,
        status: AccountStatus,
        statusMessage: String? = nil,
        counts: AccountCounts? = nil
    ) {
        self.id = id
        self.name = name
        self.emailAddress = emailAddress
        self.accountType = accountType
        self.color = color
        self.status = status
        self.statusMessage = statusMessage
        self.counts = counts
    }
}

/// Email counts per view for an account.
public struct AccountCounts: Codable, Sendable, Equatable {
    public let actionQueue: Int?
    public let readingQueue: Int?
    public let filtered: Int?
    public let filteredBorderline: Int?
    public let allInboxes: Int?

    public init(
        actionQueue: Int? = nil,
        readingQueue: Int? = nil,
        filtered: Int? = nil,
        filteredBorderline: Int? = nil,
        allInboxes: Int? = nil
    ) {
        self.actionQueue = actionQueue
        self.readingQueue = readingQueue
        self.filtered = filtered
        self.filteredBorderline = filteredBorderline
        self.allInboxes = allInboxes
    }
}

import Foundation

/// The type of daily digest.
public enum DigestType: String, Codable, Sendable, Equatable, CaseIterable {
    case morning
    case evening
}

/// A daily digest with sections.
public struct DailyDigest: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let digestType: DigestType
    public let generatedAt: Date
    public let isRead: Bool?
    public let sections: [DigestSection]

    public init(
        id: String,
        digestType: DigestType,
        generatedAt: Date,
        isRead: Bool? = nil,
        sections: [DigestSection]
    ) {
        self.id = id
        self.digestType = digestType
        self.generatedAt = generatedAt
        self.isRead = isRead
        self.sections = sections
    }
}

/// The type of a digest section.
public enum DigestSectionType: String, Codable, Sendable, Equatable, CaseIterable {
    case actionQueueSummary = "action_queue_summary"
    case returningToday = "returning_today"
    case readingQueueSummary = "reading_queue_summary"
    case borderlineItems = "borderline_items"
    case notableTransactional = "notable_transactional"
    case todayStats = "today_stats"
    case stillPending = "still_pending"
    case newslettersToday = "newsletters_today"
    case snoozeNudges = "snooze_nudges"
}

/// A section within a daily digest.
public struct DigestSection: Codable, Sendable, Equatable {
    public let type: DigestSectionType
    public let title: String
    public let subtitle: String?
    public let count: Int?
    public let accountBreakdown: [AccountCount]?
    public let items: [DigestItem]?
    public let sentCount: Int?
    public let archivedCount: Int?

    public init(
        type: DigestSectionType,
        title: String,
        subtitle: String? = nil,
        count: Int? = nil,
        accountBreakdown: [AccountCount]? = nil,
        items: [DigestItem]? = nil,
        sentCount: Int? = nil,
        archivedCount: Int? = nil
    ) {
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.count = count
        self.accountBreakdown = accountBreakdown
        self.items = items
        self.sentCount = sentCount
        self.archivedCount = archivedCount
    }
}

/// Per-account email count used in digest sections.
public struct AccountCount: Codable, Sendable, Equatable {
    public let accountId: String
    public let accountName: String
    public let accountColor: String
    public let count: Int

    public init(
        accountId: String,
        accountName: String,
        accountColor: String,
        count: Int
    ) {
        self.accountId = accountId
        self.accountName = accountName
        self.accountColor = accountColor
        self.count = count
    }
}

/// The type of a digest item.
public enum DigestItemType: String, Codable, Sendable, Equatable, CaseIterable {
    case snoozedReturn = "snoozed_return"
    case borderlineEmail = "borderline_email"
    case notableTransactional = "notable_transactional"
    case newsletterArrival = "newsletter_arrival"
    case snoozeNudge = "snooze_nudge"
}

/// The type of a transactional highlight.
public enum HighlightType: String, Codable, Sendable, Equatable, CaseIterable {
    case packageArriving = "package_arriving"
    case largeCharge = "large_charge"
    case calendarEvent = "calendar_event"
}

/// An actionable item within a digest section.
public struct DigestItem: Codable, Sendable, Equatable {
    public let type: DigestItemType
    public let emailId: String
    public let subject: String?
    public let from: String?
    public let returnAt: Date?
    public let snoozeCount: Int?
    public let confidence: Double?
    public let explanation: String?
    public let highlightType: HighlightType?
    public let displayText: String?
    public let newsletterName: String?
    public let daysSinceFirstSnooze: Int?

    public init(
        type: DigestItemType,
        emailId: String,
        subject: String? = nil,
        from: String? = nil,
        returnAt: Date? = nil,
        snoozeCount: Int? = nil,
        confidence: Double? = nil,
        explanation: String? = nil,
        highlightType: HighlightType? = nil,
        displayText: String? = nil,
        newsletterName: String? = nil,
        daysSinceFirstSnooze: Int? = nil
    ) {
        self.type = type
        self.emailId = emailId
        self.subject = subject
        self.from = from
        self.returnAt = returnAt
        self.snoozeCount = snoozeCount
        self.confidence = confidence
        self.explanation = explanation
        self.highlightType = highlightType
        self.displayText = displayText
        self.newsletterName = newsletterName
        self.daysSinceFirstSnooze = daysSinceFirstSnooze
    }
}

/// Summary of a digest for list views.
public struct DigestSummary: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let digestType: DigestType
    public let generatedAt: Date
    public let isRead: Bool

    public init(
        id: String,
        digestType: DigestType,
        generatedAt: Date,
        isRead: Bool
    ) {
        self.id = id
        self.digestType = digestType
        self.generatedAt = generatedAt
        self.isRead = isRead
    }
}

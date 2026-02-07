import SwiftUI

/// The standard email list row used across Action Queue, Filtered, and All Inboxes.
///
/// Layout:
/// ```
/// [dot] Sender Name                    2:34 PM
///       Subject line of the email...
///       Snippet text in secondary...   [snz 3x]
/// ```
///
/// Uses `ListRowMetrics` for platform-adaptive sizing (64pt macOS, 72pt iOS).
public struct EmailRowView: View {
    public let email: Email
    public let isSelected: Bool
    public var isSnoozeReturn: Bool = false

    #if os(macOS)
    @State private var isHovering = false
    #endif

    public init(email: Email, isSelected: Bool, isSnoozeReturn: Bool = false) {
        self.email = email
        self.isSelected = isSelected
        self.isSnoozeReturn = isSnoozeReturn
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            leadingContent
            mainContent
        }
        .padding(.horizontal, ListRowMetrics.horizontalPadding)
        .padding(.vertical, ListRowMetrics.verticalPadding)
        .frame(minHeight: ListRowMetrics.rowHeight)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if isSnoozeReturn {
                Rectangle()
                    .fill(Color.snooze)
                    .frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Leading Content

    @ViewBuilder
    private var leadingContent: some View {
        AccountDot(
            color: accountColor,
            accountName: email.accountName ?? "Unknown"
        )
        .padding(.top, Spacing.xs)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            firstLine
            secondLine
            thirdLine
        }
    }

    /// Sender name + timestamp on the first line.
    private var firstLine: some View {
        HStack {
            Text(senderDisplayName)
                .font(email.isRead ? .subheadline : .headline)
                .foregroundStyle(email.isRead ? .secondary : .primary)
                .lineLimit(1)

            Spacer()

            if email.hasAttachments {
                Image(systemName: "paperclip")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Has attachments")
            }

            Text(relativeTimestamp)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Subject line on the second line.
    private var secondLine: some View {
        Text(email.subject)
            .font(email.isRead ? .subheadline : .headline)
            .fontWeight(email.isRead ? .regular : .semibold)
            .foregroundStyle(email.isRead ? .secondary : .primary)
            .lineLimit(1)
    }

    /// Snippet or snooze return indicator on the third line.
    private var thirdLine: some View {
        HStack {
            if isSnoozeReturn {
                Text("Returning")
                    .font(.caption2)
                    .foregroundStyle(Color.snooze)
            } else {
                Text(email.snippet)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            SnoozeCountBadge(snoozeCount: snoozeCount)
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var rowBackground: some View {
        #if os(macOS)
        if isSelected {
            Color.accentColor.opacity(0.15)
        } else if isHovering {
            Color(nsColor: .quaternarySystemFill)
        } else if isSnoozeReturn {
            Color.snooze.opacity(0.05)
        } else {
            Color.clear
        }
        #else
        if isSnoozeReturn {
            Color.snooze.opacity(0.05)
        } else {
            Color.clear
        }
        #endif
    }

    // MARK: - Helpers

    /// Display name for the sender (name if available, otherwise email).
    private var senderDisplayName: String {
        email.from.name ?? email.from.email
    }

    /// The snooze count from the snooze state, or 0 if not snoozed.
    private var snoozeCount: Int {
        email.snooze?.snoozeCount ?? 0
    }

    /// Account color derived from the email's accountColor hex string.
    private var accountColor: Color {
        guard let hex = email.accountColor else { return .gray }
        return Color(hexString: hex)
    }

    /// Relative timestamp for the email's receivedAt date.
    private var relativeTimestamp: String {
        let now = Date.now
        let interval = now.timeIntervalSince(email.receivedAt)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400, Calendar.current.isDateInToday(email.receivedAt) {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if Calendar.current.isDateInYesterday(email.receivedAt) {
            return "Yesterday"
        } else {
            return email.receivedAt.formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// Full accessibility description for VoiceOver.
    private var accessibilityDescription: String {
        var parts: [String] = []

        if !email.isRead {
            parts.append("Unread")
        }
        if isSnoozeReturn {
            parts.append("Returning from snooze")
        }

        parts.append("Email from \(senderDisplayName)")
        parts.append("about \(email.subject)")
        parts.append("received \(relativeTimestamp)")

        if let accountName = email.accountName {
            parts.append("\(accountName) account")
        }

        if snoozeCount >= 2 {
            parts.append("snoozed \(snoozeCount) times")
        }

        if email.hasAttachments {
            parts.append("has attachments")
        }

        return parts.joined(separator: ", ")
    }
}

// MARK: - Preview Data

public extension Email {
    static var previewUnread: Email {
        Email(
            id: "preview-1",
            accountId: "acc-work",
            from: Contact(name: "Jane Smith", email: "jane@company.com"),
            to: [Contact(name: "You", email: "you@work.com")],
            subject: "Re: Q3 budget review",
            snippet: "Can you sign off on the Q3 budget before Friday?",
            receivedAt: Date().addingTimeInterval(-120),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .rules
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            accountColor: "#3B82F6",
            accountName: "Work"
        )
    }

    static var previewRead: Email {
        Email(
            id: "preview-2",
            accountId: "acc-personal",
            from: Contact(name: "Bob Lee", email: "bob@example.com"),
            to: [Contact(name: "You", email: "you@personal.com")],
            subject: "Project Falcon update",
            snippet: "What do you think about the new timeline?",
            receivedAt: Date().addingTimeInterval(-3600),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.88,
                classifiedBy: .features
            ),
            isRead: true,
            isArchived: false,
            hasAttachments: false,
            accountColor: "#22C55E",
            accountName: "Personal"
        )
    }

    static var previewSnoozedReturn: Email {
        Email(
            id: "preview-3",
            accountId: "acc-work",
            from: Contact(name: "Sarah M.", email: "sarah@company.com"),
            to: [Contact(name: "You", email: "you@work.com")],
            subject: "Dinner Saturday?",
            snippet: "Are you free tomorrow evening?",
            receivedAt: Date().addingTimeInterval(-7200),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.92,
                classifiedBy: .rules
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            snooze: SnoozeState(
                id: "snz-1",
                emailId: "preview-3",
                snoozedAt: Date().addingTimeInterval(-86400),
                returnAt: Date().addingTimeInterval(-120),
                snoozeCount: 3,
                isActive: false
            ),
            accountColor: "#3B82F6",
            accountName: "Work"
        )
    }

    static var previewWithAttachment: Email {
        Email(
            id: "preview-4",
            accountId: "acc-personal2",
            from: Contact(name: "Charlie D.", email: "charlie@example.com"),
            to: [Contact(name: "You", email: "you@other.com")],
            subject: "Photos from the trip",
            snippet: "Here are the photos we took last weekend",
            receivedAt: Date().addingTimeInterval(-86400),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.85,
                classifiedBy: .features
            ),
            isRead: true,
            isArchived: false,
            hasAttachments: true,
            accountColor: "#F97316",
            accountName: "Personal 2"
        )
    }
}

#Preview("EmailRowView - Unread") {
    EmailRowView(email: .previewUnread, isSelected: false)
        .frame(width: 340)
}

#Preview("EmailRowView - Read") {
    EmailRowView(email: .previewRead, isSelected: false)
        .frame(width: 340)
}

#Preview("EmailRowView - Snooze Return") {
    EmailRowView(email: .previewSnoozedReturn, isSelected: false, isSnoozeReturn: true)
        .frame(width: 340)
}

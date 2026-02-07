import SwiftUI
import EmailClientKit

/// The standard email list row used across Action Queue, Filtered, and All Inboxes.
///
/// Layout (64pt height):
/// ```
/// [dot] Sender Name                    2:34 PM
///       Subject line of the email...
///       Snippet text in secondary...   [snz 3x]
/// ```
struct EmailRowView: View {
    let email: Email
    let isSelected: Bool
    var isSnoozeReturn: Bool = false

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            leadingContent
            mainContent
        }
        .padding(.horizontal, ListRowMetrics.horizontalPadding)
        .padding(.vertical, ListRowMetrics.verticalPadding)
        .frame(height: ListRowMetrics.rowHeight)
        .background(rowBackground)
        .overlay(alignment: .leading) {
            if isSnoozeReturn {
                Rectangle()
                    .fill(Color.snooze)
                    .frame(width: 2)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
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

            Text(relativeTimestamp)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    /// Subject line on the second line, with optional attachment indicator.
    private var secondLine: some View {
        HStack(spacing: Spacing.xs) {
            Text(email.subject)
                .font(email.isRead ? .subheadline : .headline)
                .fontWeight(email.isRead ? .regular : .semibold)
                .foregroundStyle(email.isRead ? .secondary : .primary)
                .lineLimit(1)

            if email.hasAttachments {
                Image(systemName: "paperclip")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Has attachments")
            }
        }
    }

    /// Snippet or snooze return indicator on the third line.
    private var thirdLine: some View {
        HStack {
            if isSnoozeReturn {
                SnoozeReturnIndicator()
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
        if isSelected {
            Color.accentColor.opacity(0.15)
        } else if isHovering {
            Color(nsColor: .quaternarySystemFill)
        } else if isSnoozeReturn {
            Color.snooze.opacity(0.05)
        } else {
            Color.clear
        }
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

// MARK: - Color hex parsing

private extension Color {
    init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: .init(charactersIn: "#"))
        guard let hex = UInt32(cleaned, radix: 16) else {
            self = .gray
            return
        }
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Preview

#Preview("EmailRowView - Unread") {
    let email = Email(
        id: "1",
        accountId: "acc-1",
        from: Contact(name: "Jane Smith", email: "jane@company.com"),
        to: [Contact(email: "you@work.com")],
        subject: "Re: Q3 budget review",
        snippet: "Can you sign off on the Q3 budget before Friday?",
        receivedAt: Date().addingTimeInterval(-120),
        classification: Classification(
            classification: .actionRequired, confidence: 0.95, classifiedBy: .llm
        ),
        isRead: false,
        isArchived: false,
        hasAttachments: false,
        accountColor: "#3B82F6",
        accountName: "Work"
    )
    EmailRowView(email: email, isSelected: false)
        .frame(width: 340)
}

#Preview("EmailRowView - Read") {
    let email = Email(
        id: "2",
        accountId: "acc-1",
        from: Contact(name: "Bob Lee", email: "bob@company.com"),
        to: [Contact(email: "you@work.com")],
        subject: "Project Falcon update",
        snippet: "What do you think about the new timeline?",
        receivedAt: Date().addingTimeInterval(-3600),
        classification: Classification(
            classification: .actionRequired, confidence: 0.90, classifiedBy: .llm
        ),
        isRead: true,
        isArchived: false,
        hasAttachments: true,
        accountColor: "#3B82F6",
        accountName: "Work"
    )
    EmailRowView(email: email, isSelected: false)
        .frame(width: 340)
}

#Preview("EmailRowView - Selected") {
    let email = Email(
        id: "3",
        accountId: "acc-2",
        from: Contact(name: "Sarah M.", email: "sarah@gmail.com"),
        to: [Contact(email: "you@gmail.com")],
        subject: "Dinner Saturday?",
        snippet: "Are you free tomorrow evening?",
        receivedAt: Date().addingTimeInterval(-7200),
        classification: Classification(
            classification: .actionRequired, confidence: 0.88, classifiedBy: .llm
        ),
        isRead: false,
        isArchived: false,
        hasAttachments: false,
        accountColor: "#22C55E",
        accountName: "Personal"
    )
    EmailRowView(email: email, isSelected: true)
        .frame(width: 340)
}

#Preview("EmailRowView - Snooze Return") {
    let email = Email(
        id: "4",
        accountId: "acc-1",
        from: Contact(name: "Jane Smith", email: "jane@company.com"),
        to: [Contact(email: "you@work.com")],
        subject: "Re: Q3 budget review",
        snippet: "Can you sign off on the Q3 budget before Friday?",
        receivedAt: Date().addingTimeInterval(-86400),
        classification: Classification(
            classification: .actionRequired, confidence: 0.95, classifiedBy: .llm
        ),
        isRead: false,
        isArchived: false,
        hasAttachments: false,
        snooze: SnoozeState(
            id: "snz-1", emailId: "4",
            snoozedAt: Date().addingTimeInterval(-172800),
            returnAt: Date().addingTimeInterval(-120),
            snoozeCount: 3, isActive: false
        ),
        accountColor: "#3B82F6",
        accountName: "Work"
    )
    EmailRowView(email: email, isSelected: false, isSnoozeReturn: true)
        .frame(width: 340)
}

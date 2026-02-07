import SwiftUI
import EmailClientKit

/// An email list row optimized for iOS touch interactions.
///
/// 72pt height, 16pt horizontal padding, three-line layout:
/// 1. AccountDot + Sender Name + Timestamp
/// 2. Subject (bold if unread)
/// 3. Snippet + SnoozeCountBadge + Attachment indicator
public struct IOSEmailRowView: View {
    let email: Email
    var isReturning: Bool = false

    public var body: some View {
        HStack(alignment: .center, spacing: IOSDesignTokens.spaceSM) {
            if isReturning {
                IOSSnoozeReturnIndicator()
            }

            IOSAccountDot(
                color: accountColor,
                accountName: email.accountName ?? "Unknown"
            )

            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Sender + Timestamp
                HStack {
                    Text(senderDisplayName)
                        .font(.subheadline)
                        .fontWeight(email.isRead ? .regular : .semibold)
                        .foregroundStyle(email.isRead ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    if email.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    Text(relativeTimestamp)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Line 2: Subject
                Text(email.subject)
                    .font(.subheadline)
                    .fontWeight(email.isRead ? .regular : .medium)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                // Line 3: Snippet + Snooze badge
                HStack {
                    if isReturning {
                        Text("Returning")
                            .font(.caption2)
                            .foregroundStyle(Color.snoozeFallback)
                    } else {
                        Text(email.snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    IOSSnoozeCountBadge(snoozeCount: snoozeCount)
                }
            }
        }
        .padding(.horizontal, IOSDesignTokens.rowHorizontalPadding)
        .padding(.vertical, IOSDesignTokens.rowVerticalPadding)
        .frame(minHeight: IOSDesignTokens.rowHeight)
        .contentShape(Rectangle())
        .background(isReturning ? Color.snoozeFallback.opacity(0.05) : Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Computed Properties

    private var senderDisplayName: String {
        email.from.name ?? email.from.email
    }

    private var snoozeCount: Int {
        email.snooze?.snoozeCount ?? 0
    }

    private var accountColor: Color {
        guard let colorString = email.accountColor else {
            return .accountWorkFallback
        }
        switch colorString {
        case "blue", "#3B82F6":
            return .accountWorkFallback
        case "green", "#22C55E":
            return .accountPersonal1Fallback
        case "orange", "#F97316":
            return .accountPersonal2Fallback
        default:
            return Color(hex: colorString)
        }
    }

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: email.receivedAt, relativeTo: Date())
    }

    private var accessibilityText: String {
        var parts: [String] = []
        if !email.isRead {
            parts.append("Unread")
        }
        if isReturning {
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

// MARK: - Preview

#Preview("Email Row - Unread") {
    List {
        IOSEmailRowView(
            email: .previewUnread
        )
        IOSEmailRowView(
            email: .previewRead
        )
        IOSEmailRowView(
            email: .previewSnoozedReturn,
            isReturning: true
        )
        IOSEmailRowView(
            email: .previewWithAttachment
        )
    }
    .listStyle(.plain)
}

// MARK: - Preview Data

extension Email {
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
            accountColor: "blue",
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
            accountColor: "green",
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
            accountColor: "blue",
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
            accountColor: "orange",
            accountName: "Personal 2"
        )
    }
}

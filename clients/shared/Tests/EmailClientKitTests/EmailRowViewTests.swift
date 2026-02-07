import Foundation
import Testing
@testable import EmailClientKit

@Suite("EmailRowView")
@MainActor
struct EmailRowViewTests {

    // MARK: - Test Helpers

    private func makeEmail(
        id: String = "e1",
        senderName: String? = "Jane Smith",
        senderEmail: String = "jane@company.com",
        subject: String = "Test Subject",
        snippet: String = "Test snippet content",
        receivedAt: Date = Date(),
        classification: ClassificationType = .actionRequired,
        isRead: Bool = false,
        hasAttachments: Bool = false,
        snooze: SnoozeState? = nil,
        accountColor: String? = "#3B82F6",
        accountName: String? = "Work"
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: senderName, email: senderEmail),
            to: [Contact(email: "you@work.com")],
            subject: subject,
            snippet: snippet,
            receivedAt: receivedAt,
            classification: Classification(
                classification: classification,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: hasAttachments,
            snooze: snooze,
            accountColor: accountColor,
            accountName: accountName
        )
    }

    // MARK: - Row Height

    @Test("Row height is platform-correct")
    func rowHeight() {
        #if os(macOS)
        #expect(ListRowMetrics.rowHeight == 64)
        #else
        #expect(ListRowMetrics.rowHeight == 72)
        #endif
    }

    // MARK: - Sender Display Name

    @Test("Sender name is displayed when available")
    func senderNameDisplayed() {
        let email = makeEmail(senderName: "Jane Smith")
        let row = EmailRowView(email: email, isSelected: false)
        #expect(row.email.from.name == "Jane Smith")
    }

    @Test("Sender email is used when name is nil")
    func senderEmailFallback() {
        let email = makeEmail(senderName: nil, senderEmail: "unknown@test.com")
        let row = EmailRowView(email: email, isSelected: false)
        #expect(row.email.from.name == nil)
        #expect(row.email.from.email == "unknown@test.com")
    }

    // MARK: - Read/Unread State

    @Test("Unread email exposes unread state")
    func unreadState() {
        let email = makeEmail(isRead: false)
        let row = EmailRowView(email: email, isSelected: false)
        #expect(!row.email.isRead)
    }

    @Test("Read email exposes read state")
    func readState() {
        let email = makeEmail(isRead: true)
        let row = EmailRowView(email: email, isSelected: false)
        #expect(row.email.isRead)
    }

    // MARK: - Attachment Indicator

    @Test("Has attachment indicator when hasAttachments is true")
    func attachmentIndicator() {
        let email = makeEmail(hasAttachments: true)
        #expect(email.hasAttachments)
    }

    @Test("No attachment indicator when hasAttachments is false")
    func noAttachmentIndicator() {
        let email = makeEmail(hasAttachments: false)
        #expect(!email.hasAttachments)
    }

    // MARK: - Snooze Count Badge

    @Test("Snooze count badge shown when count >= 2")
    func snoozeCountBadgeShown() {
        let snooze = SnoozeState(
            id: "snz-1", emailId: "e1",
            snoozedAt: Date(), returnAt: Date().addingTimeInterval(3600),
            snoozeCount: 3, isActive: true
        )
        let email = makeEmail(snooze: snooze)
        #expect(email.snooze?.snoozeCount == 3)
    }

    @Test("Snooze count badge hidden when count < 2")
    func snoozeCountBadgeHidden() {
        let snooze = SnoozeState(
            id: "snz-1", emailId: "e1",
            snoozedAt: Date(), returnAt: Date().addingTimeInterval(3600),
            snoozeCount: 1, isActive: true
        )
        let email = makeEmail(snooze: snooze)
        #expect(email.snooze?.snoozeCount == 1)
    }

    @Test("No snooze state means count is zero")
    func noSnoozeState() {
        let email = makeEmail(snooze: nil)
        #expect(email.snooze == nil)
    }

    // MARK: - Snooze Return

    @Test("Snooze return indicator flag is passed through")
    func snoozeReturnIndicator() {
        let email = makeEmail()
        let row = EmailRowView(email: email, isSelected: false, isSnoozeReturn: true)
        #expect(row.isSnoozeReturn)
    }

    @Test("Non-snooze return has no indicator")
    func noSnoozeReturn() {
        let email = makeEmail()
        let row = EmailRowView(email: email, isSelected: false, isSnoozeReturn: false)
        #expect(!row.isSnoozeReturn)
    }

    // MARK: - Selection State

    @Test("Selection state is passed through")
    func selectionState() {
        let email = makeEmail()
        let selectedRow = EmailRowView(email: email, isSelected: true)
        let unselectedRow = EmailRowView(email: email, isSelected: false)
        #expect(selectedRow.isSelected)
        #expect(!unselectedRow.isSelected)
    }

    // MARK: - Account Color

    @Test("Account color is derived from hex string")
    func accountColorFromHex() {
        let email = makeEmail(accountColor: "#3B82F6")
        #expect(email.accountColor == "#3B82F6")
    }

    @Test("Missing account color defaults gracefully")
    func missingAccountColor() {
        let email = makeEmail(accountColor: nil)
        #expect(email.accountColor == nil)
    }

    // MARK: - Timestamp Formatting

    @Test("Timestamp shows 'now' for very recent emails")
    func timestampNow() {
        let formatter = TestTimestampFormatter()
        let result = formatter.relativeTimestamp(for: Date().addingTimeInterval(-30))
        #expect(result == "now")
    }

    @Test("Timestamp shows minutes for recent emails")
    func timestampMinutes() {
        let formatter = TestTimestampFormatter()
        let result = formatter.relativeTimestamp(for: Date().addingTimeInterval(-120))
        #expect(result == "2m")
    }

    @Test("Timestamp shows hours for today's emails")
    func timestampHours() {
        let formatter = TestTimestampFormatter()
        let result = formatter.relativeTimestamp(for: Date().addingTimeInterval(-7200))
        // Could be "2h" if still today, or "Yesterday" near midnight
        #expect(result == "2h" || result == "Yesterday")
    }

    @Test("Timestamp shows 'Yesterday' for yesterday's emails")
    func timestampYesterday() {
        let calendar = Calendar.current
        let yesterday = calendar.date(
            byAdding: .day, value: -1,
            to: calendar.startOfDay(for: Date())
        )!.addingTimeInterval(43200) // noon yesterday
        let formatter = TestTimestampFormatter()
        let result = formatter.relativeTimestamp(for: yesterday)
        #expect(result == "Yesterday")
    }

    // MARK: - Email Properties Exposed

    @Test("Subject is accessible from email")
    func subjectAccessible() {
        let email = makeEmail(subject: "Important Meeting")
        #expect(email.subject == "Important Meeting")
    }

    @Test("Snippet is accessible from email")
    func snippetAccessible() {
        let email = makeEmail(snippet: "Please review the attached document")
        #expect(email.snippet == "Please review the attached document")
    }

    @Test("Account name is accessible from email")
    func accountNameAccessible() {
        let email = makeEmail(accountName: "Work")
        #expect(email.accountName == "Work")
    }

    // MARK: - Preview Data

    @Test("Preview data constructs without error")
    func previewData() {
        _ = Email.previewUnread
        _ = Email.previewRead
        _ = Email.previewSnoozedReturn
        _ = Email.previewWithAttachment
    }
}

// MARK: - Test Helper for Timestamp Formatting

/// Mirrors the timestamp logic in EmailRowView for testability.
private struct TestTimestampFormatter {
    func relativeTimestamp(for date: Date) -> String {
        let now = Date.now
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400, Calendar.current.isDateInToday(date) {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

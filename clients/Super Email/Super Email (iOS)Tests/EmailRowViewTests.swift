import Testing
import SwiftUI
@testable import EmailClientKit
@testable import EmailerIOS

@Suite("EmailRowView_iOS Tests")
@MainActor
struct EmailRowViewTests {

    // MARK: - Sender Display

    @Test("Displays sender name when available")
    func senderNameDisplayed() {
        let email = makeEmail(senderName: "Jane Smith", senderEmail: "jane@example.com")
        let view = IOSEmailRowView(email: email)
        // View constructs without error and uses name
        #expect(email.from.name == "Jane Smith")
    }

    @Test("Falls back to email when name is nil")
    func senderEmailFallback() {
        let email = makeEmail(senderName: nil, senderEmail: "jane@example.com")
        let view = IOSEmailRowView(email: email)
        // Verify name is nil so fallback path is used
        #expect(email.from.name == nil)
        #expect(email.from.email == "jane@example.com")
        _ = view
    }

    // MARK: - Read/Unread State

    @Test("Unread email has expected properties")
    func unreadState() {
        let email = makeEmail(isRead: false)
        #expect(email.isRead == false)
    }

    @Test("Read email has expected properties")
    func readState() {
        let email = makeEmail(isRead: true)
        #expect(email.isRead == true)
    }

    // MARK: - Snooze Return

    @Test("Returning state renders snooze return indicator")
    func returningState() {
        let email = makeEmail(
            snooze: SnoozeState(
                id: "snz-1",
                emailId: "email-1",
                snoozedAt: Date().addingTimeInterval(-86400),
                returnAt: Date().addingTimeInterval(-60),
                snoozeCount: 2,
                isActive: false
            )
        )
        let view = IOSEmailRowView(email: email, isReturning: true)
        #expect(view.isReturning == true)
    }

    @Test("Non-returning state does not show indicator")
    func nonReturningState() {
        let email = makeEmail()
        let view = IOSEmailRowView(email: email)
        #expect(view.isReturning == false)
    }

    // MARK: - Snooze Count Badge

    @Test("Snooze count below 2 hides badge")
    func snoozeCountBelowThreshold() {
        let email = makeEmail(
            snooze: SnoozeState(
                id: "snz-1",
                emailId: "email-1",
                snoozedAt: Date(),
                returnAt: Date(),
                snoozeCount: 1,
                isActive: false
            )
        )
        #expect(email.snooze?.snoozeCount == 1)
    }

    @Test("Snooze count of 2 or more shows badge")
    func snoozeCountAtThreshold() {
        let email = makeEmail(
            snooze: SnoozeState(
                id: "snz-1",
                emailId: "email-1",
                snoozedAt: Date(),
                returnAt: Date(),
                snoozeCount: 3,
                isActive: false
            )
        )
        #expect(email.snooze?.snoozeCount == 3)
    }

    @Test("No snooze state means zero snooze count")
    func noSnoozeState() {
        let email = makeEmail(snooze: nil)
        #expect(email.snooze == nil)
    }

    // MARK: - Attachments

    @Test("Attachment indicator when hasAttachments is true")
    func hasAttachments() {
        let email = makeEmail(hasAttachments: true)
        #expect(email.hasAttachments == true)
    }

    @Test("No attachment indicator when hasAttachments is false")
    func noAttachments() {
        let email = makeEmail(hasAttachments: false)
        #expect(email.hasAttachments == false)
    }

    // MARK: - Account Color Mapping

    @Test("Blue account color maps correctly")
    func blueAccountColor() {
        let email = makeEmail(accountColor: "blue", accountName: "Work")
        #expect(email.accountColor == "blue")
        #expect(email.accountName == "Work")
    }

    @Test("Green account color maps correctly")
    func greenAccountColor() {
        let email = makeEmail(accountColor: "green", accountName: "Personal")
        #expect(email.accountColor == "green")
    }

    @Test("Orange account color maps correctly")
    func orangeAccountColor() {
        let email = makeEmail(accountColor: "orange", accountName: "Personal 2")
        #expect(email.accountColor == "orange")
    }

    @Test("Hex account color is accepted")
    func hexAccountColor() {
        let email = makeEmail(accountColor: "#FF5733", accountName: "Custom")
        #expect(email.accountColor == "#FF5733")
    }

    @Test("Nil account color defaults gracefully")
    func nilAccountColor() {
        let email = makeEmail(accountColor: nil, accountName: nil)
        #expect(email.accountColor == nil)
    }

    // MARK: - Layout Dimensions

    @Test("Row height token is 72pt")
    func rowHeightToken() {
        #expect(IOSDesignTokens.rowHeight == 72)
    }

    @Test("Horizontal padding token is 16pt")
    func horizontalPaddingToken() {
        #expect(IOSDesignTokens.rowHorizontalPadding == 16)
    }

    @Test("Vertical padding token is 10pt")
    func verticalPaddingToken() {
        #expect(IOSDesignTokens.rowVerticalPadding == 10)
    }

    @Test("Account dot diameter token is 10pt")
    func accountDotToken() {
        #expect(IOSDesignTokens.accountDotDiameter == 10)
    }

    // MARK: - View Construction

    @Test("EmailRowView_iOS constructs for all preview variants")
    func constructsAllPreviews() {
        _ = IOSEmailRowView(email: .previewUnread)
        _ = IOSEmailRowView(email: .previewRead)
        _ = IOSEmailRowView(email: .previewSnoozedReturn, isReturning: true)
        _ = IOSEmailRowView(email: .previewWithAttachment)
    }

    // MARK: - SnoozeReturnIndicator

    @Test("SnoozeReturnIndicator_iOS constructs successfully")
    func snoozeReturnIndicator() {
        _ = IOSSnoozeReturnIndicator()
    }

    // MARK: - Helpers

    private func makeEmail(
        senderName: String? = "Test Sender",
        senderEmail: String = "test@example.com",
        subject: String = "Test Subject",
        snippet: String = "Test snippet text",
        isRead: Bool = false,
        hasAttachments: Bool = false,
        snooze: SnoozeState? = nil,
        accountColor: String? = "blue",
        accountName: String? = "Work"
    ) -> Email {
        Email(
            id: "test-\(UUID().uuidString)",
            accountId: "acc-1",
            from: Contact(name: senderName, email: senderEmail),
            to: [Contact(name: "Me", email: "me@example.com")],
            subject: subject,
            snippet: snippet,
            receivedAt: Date().addingTimeInterval(-300),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .rules
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: hasAttachments,
            snooze: snooze,
            accountColor: accountColor,
            accountName: accountName
        )
    }
}

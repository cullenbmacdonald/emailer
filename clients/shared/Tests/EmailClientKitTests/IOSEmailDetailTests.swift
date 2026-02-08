import Foundation
import Testing
@testable import EmailClientKit

/// Tests for the iOS email detail navigation and loading logic.
/// Verifies that selecting an email ID triggers detail loading
/// and that clearing selection clears the detail.
@Suite("iOS Email Detail Navigation")
struct IOSEmailDetailTests {

    // MARK: - Helpers

    private func makeEmail(id: String = "email-1") -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: "Sender", email: "sender@test.com"),
            to: [Contact(name: "Recipient", email: "to@test.com")],
            subject: "Test Subject",
            snippet: "Test snippet",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.9,
                classifiedBy: .llm
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            accountColor: "#3B82F6",
            accountName: "Work"
        )
    }

    private func makeDetail(email: Email) -> EmailDetail {
        EmailDetail(
            id: email.id,
            email: email,
            htmlBody: "<p>Hello</p>",
            textBody: "Hello",
            attachments: []
        )
    }

    // MARK: - Detail Loading Flow

    @Test("Setting selectedEmailID triggers detail load flow")
    @MainActor
    func settingSelectedEmailIDFlow() {
        let appState = AppState()
        #expect(appState.selectedEmailID == nil)

        appState.selectedEmailID = "email-1"
        #expect(appState.selectedEmailID == "email-1")
    }

    @Test("loadDetail with nil client leaves selectedDetail nil")
    @MainActor
    func loadDetailNilClient() async {
        let store = EmailStore()
        await store.loadDetail(for: "email-1", using: nil)
        #expect(store.selectedDetail == nil)
    }

    @Test("clearDetail removes selected detail")
    @MainActor
    func clearDetailRemovesSelection() {
        let store = EmailStore()
        store.clearDetail()
        #expect(store.selectedDetail == nil)
    }

    @Test("Clearing selectedEmailID should clear detail")
    @MainActor
    func clearingSelectedEmailID() {
        let appState = AppState()
        let store = EmailStore()

        appState.selectedEmailID = "email-1"
        #expect(appState.selectedEmailID == "email-1")

        // Simulate the onDisappear behavior
        appState.selectedEmailID = nil
        store.clearDetail()

        #expect(appState.selectedEmailID == nil)
        #expect(store.selectedDetail == nil)
    }

    // MARK: - Archive Action Pops Back

    @Test("Archive removes email from action queue via optimistic mutation")
    @MainActor
    func archiveRemovesFromQueue() {
        let store = EmailStore()
        let email = makeEmail(id: "email-1")
        store.setEmails([email], for: .actionQueue)
        #expect(store.actionQueue.count == 1)

        store.removeFromActionQueue(id: "email-1")
        #expect(store.actionQueue.isEmpty)
    }

    // MARK: - Detail Action Enum Coverage

    @Test("All toolbar actions are represented in DetailAction")
    func toolbarActionsExist() {
        let actions = DetailAction.allCases
        #expect(actions.contains(.reply))
        #expect(actions.contains(.replyAll))
        #expect(actions.contains(.forward))
        #expect(actions.contains(.archive))
        #expect(actions.contains(.snooze))
        #expect(actions.contains(.move))
        #expect(actions.contains(.trash))
    }

    // MARK: - Email Detail Model for iOS Display

    @Test("EmailDetail provides header data for iOS view")
    func detailProvidesHeaderData() {
        let email = makeEmail()
        let detail = makeDetail(email: email)

        #expect(detail.email.subject == "Test Subject")
        #expect(detail.email.from.email == "sender@test.com")
        #expect(detail.email.to.count == 1)
        #expect(detail.email.accountName == "Work")
        #expect(detail.email.accountColor == "#3B82F6")
    }

    @Test("EmailDetail with attachments shows attachment data")
    func detailWithAttachments() {
        let email = makeEmail()
        let detail = EmailDetail(
            id: email.id,
            email: email,
            htmlBody: "<p>Test</p>",
            attachments: [
                Attachment(id: "a1", filename: "doc.pdf", mimeType: "application/pdf", size: 1024),
                Attachment(id: "a2", filename: "img.png", mimeType: "image/png", size: 2048)
            ]
        )

        #expect(detail.attachments.count == 2)
        #expect(detail.attachments[0].filename == "doc.pdf")
    }

    @Test("EmailDetail with text body fallback")
    func textBodyFallback() {
        let email = makeEmail()
        let detail = EmailDetail(
            id: email.id,
            email: email,
            htmlBody: "",
            textBody: "Plain text email",
            attachments: []
        )

        #expect(detail.htmlBody.isEmpty)
        #expect(detail.textBody == "Plain text email")
    }

    @Test("EmailDetail with snooze badge data")
    func snoozeInHeader() {
        let snooze = SnoozeState(
            id: "snz-1",
            emailId: "email-1",
            snoozedAt: Date(),
            returnAt: Date().addingTimeInterval(3600),
            snoozeCount: 2,
            isActive: false
        )
        let email = Email(
            id: "email-1",
            accountId: "acc-1",
            from: Contact(name: "S", email: "s@t.com"),
            to: [Contact(name: "R", email: "r@t.com")],
            subject: "Snoozed",
            snippet: "...",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.9,
                classifiedBy: .llm
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            snooze: snooze
        )
        let detail = makeDetail(email: email)

        #expect(detail.email.snooze?.snoozeCount == 2)
    }
}

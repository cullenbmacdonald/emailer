import Foundation
import Testing
@testable import EmailClientKit

@Suite("EmailDetailView Tests")
struct EmailDetailViewTests {

    // MARK: - Test Helpers

    private func makeContact(name: String? = "Test Sender", email: String = "test@example.com") -> Contact {
        Contact(name: name, email: email)
    }

    private func makeEmail(
        id: String = "email-1",
        isRead: Bool = false,
        hasAttachments: Bool = false,
        snooze: SnoozeState? = nil
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: makeContact(),
            to: [makeContact(name: "Recipient", email: "to@example.com")],
            cc: [makeContact(name: "CC Person", email: "cc@example.com")],
            subject: "Test Subject",
            snippet: "Test snippet",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: hasAttachments,
            snooze: snooze,
            accountColor: "#3B82F6",
            accountName: "Work"
        )
    }

    private func makeDetail(
        email: Email? = nil,
        htmlBody: String = "<p>Hello</p>",
        textBody: String? = nil
    ) -> EmailDetail {
        let emailObj = email ?? makeEmail()
        return EmailDetail(
            id: emailObj.id,
            email: emailObj,
            htmlBody: htmlBody,
            textBody: textBody,
            attachments: []
        )
    }

    private func makeDetailWithAttachments(email: Email) -> EmailDetail {
        // Use .init to let Swift infer the Attachment type from the EmailDetail parameter
        EmailDetail(
            id: email.id,
            email: email,
            htmlBody: "<p>Test</p>",
            attachments: [
                .init(id: "att-1", filename: "file.pdf", mimeType: "application/pdf", size: 2048),
                .init(id: "att-2", filename: "photo.jpg", mimeType: "image/jpeg", size: 4096)
            ]
        )
    }

    // MARK: - EmailDetail Model Tests

    @Test("EmailDetail contains email and body")
    func detailContainsEmailAndBody() {
        let detail = makeDetail(htmlBody: "<h1>Test</h1>")
        #expect(detail.id == "email-1")
        #expect(detail.htmlBody == "<h1>Test</h1>")
        #expect(detail.email.subject == "Test Subject")
    }

    @Test("EmailDetail with text body fallback")
    func detailWithTextBody() {
        let detail = makeDetail(htmlBody: "", textBody: "Plain text content")
        #expect(detail.htmlBody.isEmpty)
        #expect(detail.textBody == "Plain text content")
    }

    @Test("EmailDetail with attachments")
    func detailWithAttachments() {
        let email = makeEmail(hasAttachments: true)
        let detail = makeDetailWithAttachments(email: email)
        #expect(detail.attachments.count == 2)
        #expect(detail.attachments[0].filename == "file.pdf")
        #expect(detail.attachments[1].filename == "photo.jpg")
    }

    @Test("EmailDetail with no attachments")
    func detailNoAttachments() {
        let detail = makeDetail()
        #expect(detail.attachments.isEmpty)
    }

    // MARK: - DetailAction Tests

    @Test("DetailAction has all expected cases")
    func detailActionCases() {
        let actions = DetailAction.allCases
        #expect(actions.count == 7)
        #expect(actions.contains(.reply))
        #expect(actions.contains(.replyAll))
        #expect(actions.contains(.forward))
        #expect(actions.contains(.archive))
        #expect(actions.contains(.snooze))
        #expect(actions.contains(.move))
        #expect(actions.contains(.trash))
    }

    // MARK: - EmailStore Detail Loading Tests

    @Test("EmailStore selectedDetail starts nil")
    @MainActor
    func storeDetailStartsNil() {
        let store = EmailStore()
        #expect(store.selectedDetail == nil)
    }

    @Test("EmailStore clearDetail sets nil")
    @MainActor
    func storeClearDetail() {
        let store = EmailStore()
        store.clearDetail()
        #expect(store.selectedDetail == nil)
    }

    // MARK: - Snooze State in Header

    @Test("Email with snooze state includes snooze data")
    func emailWithSnoozeState() {
        let snooze = SnoozeState(
            id: "snz-1",
            emailId: "email-1",
            snoozedAt: Date(),
            returnAt: Date().addingTimeInterval(3600),
            snoozeCount: 3,
            isActive: false
        )
        let email = makeEmail(snooze: snooze)
        #expect(email.snooze?.snoozeCount == 3)
    }

    // MARK: - Contact Display

    @Test("Contact with name formats as name + email")
    func contactWithName() {
        let contact = makeContact(name: "John Doe", email: "john@example.com")
        #expect(contact.name == "John Doe")
        #expect(contact.email == "john@example.com")
    }

    @Test("Contact without name uses email only")
    func contactWithoutName() {
        let contact = makeContact(name: nil, email: "john@example.com")
        #expect(contact.name == nil)
        #expect(contact.email == "john@example.com")
    }

    // MARK: - Attachment Model Tests

    @Test("Attachment model stores all fields")
    func attachmentModel() {
        let detail = makeDetailWithAttachments(email: makeEmail())
        let att = detail.attachments[0]
        #expect(att.id == "att-1")
        #expect(att.filename == "file.pdf")
        #expect(att.size == 2048)
    }
}

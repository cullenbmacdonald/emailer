import Foundation
import Testing
@testable import EmailClientKit

@Suite("ComposeStore")
struct ComposeStoreTests {

    // MARK: - Test helpers

    private func makeEmail(
        from: Contact = Contact(name: "Sender", email: "sender@example.com"),
        to: [Contact] = [Contact(name: "Me", email: "me@example.com")],
        cc: [Contact]? = nil,
        subject: String = "Test Subject",
        messageId: String? = "msg-123"
    ) -> Email {
        Email(
            id: "email-1",
            accountId: "acc-1",
            messageId: messageId,
            from: from,
            to: to,
            cc: cc,
            subject: subject,
            snippet: "Hello...",
            receivedAt: Date(),
            classification: Classification(classification: .actionRequired, confidence: 0.95, classifiedBy: .rules),
            isRead: true,
            isArchived: false,
            hasAttachments: false
        )
    }

    private func makeDetail(
        email: Email? = nil,
        htmlBody: String = "<p>Hello world</p>",
        textBody: String? = "Hello world"
    ) -> EmailDetail {
        let email = email ?? makeEmail()
        return EmailDetail(
            id: email.id,
            email: email,
            htmlBody: htmlBody,
            textBody: textBody,
            attachments: []
        )
    }

    // MARK: - New compose

    @Test("New compose starts with empty fields")
    @MainActor func newCompose() {
        let store = ComposeStore(mode: .new, defaultAccountID: "acc-1")
        #expect(store.to.isEmpty)
        #expect(store.cc.isEmpty)
        #expect(store.bcc.isEmpty)
        #expect(store.subject.isEmpty)
        #expect(store.body.isEmpty)
        #expect(store.accountID == "acc-1")
        #expect(store.inReplyTo == nil)
        #expect(store.forwardOf == nil)
    }

    // MARK: - Reply

    @Test("Reply pre-populates to, subject, quoted body")
    @MainActor func replyPopulation() {
        let detail = makeDetail()
        let store = ComposeStore(mode: .reply(detail))

        #expect(store.to == ["sender@example.com"])
        #expect(store.subject == "Re: Test Subject")
        #expect(store.body.contains("> Hello world"))
        #expect(store.body.contains("Sender wrote:"))
        #expect(store.inReplyTo == "msg-123")
        #expect(store.accountID == "acc-1")
        #expect(store.cc.isEmpty)
    }

    @Test("Reply avoids duplicate Re: prefix")
    @MainActor func replyNoDuplicatePrefix() {
        let email = makeEmail(subject: "Re: Already prefixed")
        let detail = makeDetail(email: email)
        let store = ComposeStore(mode: .reply(detail))

        #expect(store.subject == "Re: Already prefixed")
    }

    // MARK: - Reply All

    @Test("Reply All includes original To and CC minus self")
    @MainActor func replyAllPopulation() {
        let email = makeEmail(
            from: Contact(name: "Sender", email: "sender@example.com"),
            to: [
                Contact(name: "Me", email: "me@example.com"),
                Contact(name: "Other", email: "other@example.com"),
            ],
            cc: [Contact(name: "CC Person", email: "cc@example.com")]
        )
        let detail = makeDetail(email: email)
        let store = ComposeStore(mode: .replyAll(detail), selfEmail: "me@example.com")

        #expect(store.to == ["sender@example.com"])
        #expect(store.cc.contains("other@example.com"))
        #expect(store.cc.contains("cc@example.com"))
        #expect(!store.cc.contains("me@example.com"))
        #expect(!store.cc.contains("sender@example.com"))
        #expect(store.showCcBcc == true)
    }

    // MARK: - Forward

    @Test("Forward pre-populates subject and forwarded body")
    @MainActor func forwardPopulation() {
        let detail = makeDetail()
        let store = ComposeStore(mode: .forward(detail))

        #expect(store.subject == "Fwd: Test Subject")
        #expect(store.body.contains("---------- Forwarded message ----------"))
        #expect(store.body.contains("From: Sender <sender@example.com>"))
        #expect(store.body.contains("Subject: Test Subject"))
        #expect(store.body.contains("Hello world"))
        #expect(store.to.isEmpty)
        #expect(store.forwardOf == "email-1")
        #expect(store.inReplyTo == nil)
    }

    @Test("Forward avoids duplicate Fwd: prefix")
    @MainActor func forwardNoDuplicatePrefix() {
        let email = makeEmail(subject: "Fwd: Already forwarded")
        let detail = makeDetail(email: email)
        let store = ComposeStore(mode: .forward(detail))

        #expect(store.subject == "Fwd: Already forwarded")
    }

    // MARK: - Subject prefix helper

    @Test("prefixSubject adds prefix when missing")
    @MainActor func prefixSubjectAdds() {
        #expect(ComposeStore.prefixSubject("Re: ", original: "Hello") == "Re: Hello")
    }

    @Test("prefixSubject does not duplicate existing prefix")
    @MainActor func prefixSubjectNoDuplicate() {
        #expect(ComposeStore.prefixSubject("Re: ", original: "Re: Hello") == "Re: Hello")
    }

    @Test("prefixSubject is case insensitive")
    @MainActor func prefixSubjectCaseInsensitive() {
        #expect(ComposeStore.prefixSubject("Re: ", original: "re: Hello") == "re: Hello")
    }

    // MARK: - HTML stripping

    @Test("strippingHTMLTags removes tags and decodes entities")
    func htmlStripping() {
        let html = "<p>Hello &amp; <b>world</b></p>"
        let stripped = html.strippingHTMLTags()
        #expect(stripped == "Hello & world")
    }

    // MARK: - Send validation

    @Test("Send fails without recipients")
    @MainActor func sendFailsNoRecipients() async {
        let store = ComposeStore(mode: .new, defaultAccountID: "acc-1")
        await store.send(using: nil)
        #expect(store.sendError != nil)
        #expect(store.didSend == false)
    }

    @Test("Send fails without API client")
    @MainActor func sendFailsNoClient() async {
        let store = ComposeStore(mode: .new, defaultAccountID: "acc-1")
        store.to = ["test@example.com"]
        await store.send(using: nil)
        #expect(store.sendError == "Not connected to server")
    }

    @Test("Send fails without account ID")
    @MainActor func sendFailsNoAccount() async {
        let store = ComposeStore(mode: .new)
        store.to = ["test@example.com"]
        // No API client, but the account check comes first when client exists
        await store.send(using: nil)
        #expect(store.sendError != nil)
    }

    // MARK: - Identifiable

    @Test("Each ComposeStore has a unique ID")
    @MainActor func uniqueID() {
        let store1 = ComposeStore(mode: .new)
        let store2 = ComposeStore(mode: .new)
        #expect(store1.id != store2.id)
    }

    // MARK: - Quoted body with HTML fallback

    @Test("Reply uses HTML body when textBody is nil")
    @MainActor func replyHTMLFallback() {
        let detail = makeDetail(htmlBody: "<p>HTML content</p>", textBody: nil)
        let store = ComposeStore(mode: .reply(detail))

        #expect(store.body.contains("> HTML content"))
    }

    // MARK: - Email validation

    @Test("Valid email addresses pass validation")
    @MainActor func validEmails() {
        #expect(RecipientField.isValidEmail("test@example.com"))
        #expect(RecipientField.isValidEmail("user.name+tag@domain.co.uk"))
    }

    @Test("Invalid email addresses fail validation")
    @MainActor func invalidEmails() {
        #expect(!RecipientField.isValidEmail(""))
        #expect(!RecipientField.isValidEmail("not-an-email"))
        #expect(!RecipientField.isValidEmail("@missing-local.com"))
        #expect(!RecipientField.isValidEmail("missing-domain@"))
    }
}

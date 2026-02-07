import Foundation
import Testing
import EmailClientKit
@testable import Emailer

@Suite("EmailStore")
@MainActor
struct EmailStoreTests {
    private func makeEmail(
        id: String = "e1",
        classification: ClassificationType = .actionRequired,
        confidence: Double = 0.95
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(email: "a@b.com"),
            to: [],
            subject: "Test",
            snippet: "",
            receivedAt: Date(),
            classification: Classification(
                classification: classification,
                confidence: confidence,
                classifiedBy: .llm
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false
        )
    }

    private func makeEvent(
        type: WebSocketEventType,
        payload: WebSocketPayload
    ) -> WebSocketEvent {
        WebSocketEvent(type: type, payload: payload)
    }

    // MARK: - Initial State

    @Test("Initial state has empty arrays")
    func initialState() {
        let store = EmailStore()
        #expect(store.actionQueue.isEmpty)
        #expect(store.readingQueue.isEmpty)
        #expect(store.filtered.isEmpty)
        #expect(store.allInboxes.isEmpty)
        #expect(store.actionQueueCount == 0)
        #expect(store.filteredBorderlineCount == 0)
    }

    // MARK: - setEmails

    @Test("setEmails replaces view array")
    func setEmails() {
        let store = EmailStore()
        let emails = [makeEmail(id: "e1"), makeEmail(id: "e2")]
        store.setEmails(emails, for: .actionQueue)
        #expect(store.actionQueue.count == 2)
        #expect(store.readingQueue.isEmpty)
    }

    // MARK: - handleEvent: emailNew

    @Test("emailNew inserts action_required email into actionQueue and allInboxes")
    func emailNewActionRequired() {
        let store = EmailStore()
        let email = makeEmail(id: "e1", classification: .actionRequired)
        let event = makeEvent(
            type: .emailNew,
            payload: .emailNew(EmailNewPayload(email: email))
        )
        store.handleEvent(event)
        #expect(store.actionQueue.count == 1)
        #expect(store.allInboxes.count == 1)
        #expect(store.readingQueue.isEmpty)
        #expect(store.filtered.isEmpty)
    }

    @Test("emailNew inserts newsletter email into readingQueue")
    func emailNewNewsletter() {
        let store = EmailStore()
        let email = makeEmail(id: "e1", classification: .newsletter)
        let event = makeEvent(
            type: .emailNew,
            payload: .emailNew(EmailNewPayload(email: email))
        )
        store.handleEvent(event)
        #expect(store.readingQueue.count == 1)
        #expect(store.allInboxes.count == 1)
        #expect(store.actionQueue.isEmpty)
    }

    @Test("emailNew inserts filtered email into filtered")
    func emailNewFiltered() {
        let store = EmailStore()
        let email = makeEmail(id: "e1", classification: .filtered)
        let event = makeEvent(
            type: .emailNew,
            payload: .emailNew(EmailNewPayload(email: email))
        )
        store.handleEvent(event)
        #expect(store.filtered.count == 1)
        #expect(store.allInboxes.count == 1)
        #expect(store.actionQueue.isEmpty)
    }

    // MARK: - handleEvent: emailUpdated

    @Test("emailUpdated updates existing email in place")
    func emailUpdated() {
        let store = EmailStore()
        let email = makeEmail(id: "e1", classification: .actionRequired)
        store.setEmails([email], for: .actionQueue)
        store.setEmails([email], for: .allInboxes)

        let updated = Email(
            id: "e1", accountId: "acc-1",
            from: Contact(email: "a@b.com"), to: [],
            subject: "Updated Subject", snippet: "",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired, confidence: 0.95, classifiedBy: .llm
            ),
            isRead: true, isArchived: false, hasAttachments: false
        )
        let event = makeEvent(
            type: .emailUpdated,
            payload: .emailUpdated(EmailUpdatedPayload(email: updated))
        )
        store.handleEvent(event)
        #expect(store.actionQueue.first?.subject == "Updated Subject")
        #expect(store.actionQueue.first?.isRead == true)
    }

    // MARK: - handleEvent: emailDeleted

    @Test("emailDeleted removes email from all lists")
    func emailDeleted() {
        let store = EmailStore()
        let email = makeEmail(id: "e1")
        store.setEmails([email], for: .actionQueue)
        store.setEmails([email], for: .allInboxes)

        let event = makeEvent(
            type: .emailDeleted,
            payload: .emailDeleted(EmailDeletedPayload(emailId: "e1"))
        )
        store.handleEvent(event)
        #expect(store.actionQueue.isEmpty)
        #expect(store.allInboxes.isEmpty)
    }

    // MARK: - handleEvent: snoozeCreated

    @Test("snoozeCreated removes email from lists")
    func snoozeCreated() {
        let store = EmailStore()
        let email = makeEmail(id: "e1")
        store.setEmails([email], for: .actionQueue)

        let event = makeEvent(
            type: .snoozeCreated,
            payload: .snoozeCreated(SnoozeCreatedPayload(
                emailId: "e1",
                snooze: SnoozeState(
                    id: "snz-1", emailId: "e1",
                    snoozedAt: Date(), returnAt: Date().addingTimeInterval(3600),
                    snoozeCount: 1, isActive: true
                )
            ))
        )
        store.handleEvent(event)
        #expect(store.actionQueue.isEmpty)
    }

    // MARK: - handleEvent: snoozeReturned

    @Test("snoozeReturned re-inserts email")
    func snoozeReturned() {
        let store = EmailStore()
        let email = makeEmail(id: "e1")
        let event = makeEvent(
            type: .snoozeReturned,
            payload: .snoozeReturned(SnoozeReturnedPayload(
                emailId: "e1", email: email
            ))
        )
        store.handleEvent(event)
        #expect(store.actionQueue.count == 1)
    }

    // MARK: - Badge Counts

    @Test("actionQueueCount reflects array count")
    func actionQueueCount() {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1"), makeEmail(id: "e2")], for: .actionQueue)
        #expect(store.actionQueueCount == 2)
    }

    @Test("filteredBorderlineCount counts emails with confidence < 0.80")
    func filteredBorderlineCount() {
        let store = EmailStore()
        store.setEmails([
            makeEmail(id: "e1", classification: .filtered, confidence: 0.75),
            makeEmail(id: "e2", classification: .filtered, confidence: 0.85),
            makeEmail(id: "e3", classification: .filtered, confidence: 0.50),
        ], for: .filtered)
        #expect(store.filteredBorderlineCount == 2)
    }

    // MARK: - Unhandled events are ignored

    @Test("Non-email events are ignored")
    func ignoresNonEmailEvents() {
        let store = EmailStore()
        let event = makeEvent(type: .pong, payload: .pong)
        store.handleEvent(event)
        #expect(store.actionQueue.isEmpty)
    }
}

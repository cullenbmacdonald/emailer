import Foundation
import Testing
@testable import EmailClientKit

@Suite("ReadingQueueView Logic")
@MainActor
struct ReadingQueueViewTests {

    // MARK: - Test Helpers

    private func makeNewsletter(
        id: String = "e1",
        accountId: String = "acc-1",
        accountName: String? = "Personal",
        receivedAt: Date = Date(),
        isRead: Bool = false
    ) -> Email {
        Email(
            id: id,
            accountId: accountId,
            from: Contact(name: "Stratechery", email: "ben@stratechery.com"),
            to: [Contact(email: "you@personal.com")],
            subject: "Newsletter \(id)",
            snippet: "Snippet \(id)",
            receivedAt: receivedAt,
            classification: Classification(
                classification: .newsletter,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: false,
            accountName: accountName
        )
    }

    // MARK: - EmailStore Reading Queue Tests

    @Test("setEmails populates readingQueue")
    func setEmailsPopulatesReadingQueue() {
        let store = EmailStore()
        let emails = [makeNewsletter(id: "n1"), makeNewsletter(id: "n2")]
        store.setEmails(emails, for: .readingQueue)
        #expect(store.readingQueue.count == 2)
        #expect(store.readingQueue[0].id == "n1")
    }

    @Test("removeFromReadingQueue removes and returns email")
    func removeFromReadingQueue() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1")
        store.setEmails([email], for: .readingQueue)

        let removed = store.removeFromReadingQueue(id: "n1")
        #expect(removed?.id == "n1")
        #expect(store.readingQueue.isEmpty)
    }

    @Test("removeFromReadingQueue returns nil for missing email")
    func removeFromReadingQueueMissing() {
        let store = EmailStore()
        let removed = store.removeFromReadingQueue(id: "missing")
        #expect(removed == nil)
    }

    @Test("restoreToReadingQueue re-inserts email")
    func restoreToReadingQueue() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1")
        store.setEmails([email], for: .readingQueue)

        let removed = store.removeFromReadingQueue(id: "n1")!
        #expect(store.readingQueue.isEmpty)

        store.restoreToReadingQueue(removed)
        #expect(store.readingQueue.count == 1)
        #expect(store.readingQueue[0].id == "n1")
    }

    @Test("removeFromReadingQueue also removes from allInboxes")
    func removeFromReadingQueueAlsoRemovesFromAllInboxes() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1")
        store.setEmails([email], for: .readingQueue)
        store.setEmails([email], for: .allInboxes)

        store.removeFromReadingQueue(id: "n1")
        #expect(store.allInboxes.isEmpty)
    }

    @Test("restoreToReadingQueue also restores to allInboxes")
    func restoreToReadingQueueAlsoRestoresToAllInboxes() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1")
        store.setEmails([email], for: .readingQueue)
        store.setEmails([email], for: .allInboxes)

        let removed = store.removeFromReadingQueue(id: "n1")!
        store.restoreToReadingQueue(removed)
        #expect(store.allInboxes.count == 1)
    }

    @Test("WebSocket newsletter event inserts into readingQueue")
    func webSocketNewsletterInsert() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1")
        let event = WebSocketEvent(
            type: .emailNew,
            payload: .emailNew(EmailNewPayload(email: email))
        )
        store.handleEvent(event)
        #expect(store.readingQueue.count == 1)
        #expect(store.readingQueue[0].id == "n1")
    }

    @Test("WebSocket email deleted removes from readingQueue")
    func webSocketDeleteRemovesFromReadingQueue() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1")
        store.setEmails([email], for: .readingQueue)

        let event = WebSocketEvent(
            type: .emailDeleted,
            payload: .emailDeleted(EmailDeletedPayload(emailId: "n1"))
        )
        store.handleEvent(event)
        #expect(store.readingQueue.isEmpty)
    }

    @Test("updateReadState updates reading queue emails")
    func updateReadStateInReadingQueue() {
        let store = EmailStore()
        let email = makeNewsletter(id: "n1", isRead: false)
        store.setEmails([email], for: .readingQueue)

        store.updateReadState(id: "n1", isRead: true)
        #expect(store.readingQueue[0].isRead == true)
    }

    // MARK: - Sorting Logic (tested via computed property simulation)

    @Test("Sorting: unread emails come before read emails")
    func sortingUnreadBeforeRead() {
        let unread = makeNewsletter(id: "n1", receivedAt: Date().addingTimeInterval(-3600), isRead: false)
        let read = makeNewsletter(id: "n2", receivedAt: Date(), isRead: true)
        let emails = [read, unread]

        let unreadEmails = emails.filter { !$0.isRead }.sorted { $0.receivedAt > $1.receivedAt }
        let readEmails = emails.filter { $0.isRead }.sorted { $0.receivedAt > $1.receivedAt }
        let sorted = unreadEmails + readEmails

        #expect(sorted[0].id == "n1") // unread first
        #expect(sorted[1].id == "n2") // read second
    }

    @Test("Sorting: within unread, newest first")
    func sortingNewestFirst() {
        let older = makeNewsletter(id: "n1", receivedAt: Date().addingTimeInterval(-7200), isRead: false)
        let newer = makeNewsletter(id: "n2", receivedAt: Date().addingTimeInterval(-60), isRead: false)
        let emails = [older, newer]

        let sorted = emails.sorted { $0.receivedAt > $1.receivedAt }
        #expect(sorted[0].id == "n2") // newer first
        #expect(sorted[1].id == "n1")
    }
}

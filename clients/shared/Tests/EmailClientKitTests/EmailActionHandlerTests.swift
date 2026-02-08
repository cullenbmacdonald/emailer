import Foundation
import Testing
@testable import EmailClientKit

@Suite("EmailActionHandler")
@MainActor
struct EmailActionHandlerTests {

    // MARK: - Test Helpers

    private func makeEmail(
        id: String = "e1",
        isRead: Bool = false,
        accountName: String? = "Work"
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: "Jane", email: "jane@co.com"),
            to: [Contact(email: "you@co.com")],
            subject: "Test",
            snippet: "Snippet",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: false,
            accountName: accountName
        )
    }

    private func makePopulatedStore(emails: [Email]? = nil) -> EmailStore {
        let store = EmailStore()
        let list = emails ?? [makeEmail(id: "e1"), makeEmail(id: "e2"), makeEmail(id: "e3")]
        store.setEmails(list, for: .actionQueue)
        return store
    }

    // MARK: - Archive

    @Test("Archive removes email from action queue optimistically")
    func archiveRemovesEmail() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        #expect(store.actionQueue.count == 3)
        handler.archive(emailID: "e1", emailStore: store, apiClient: nil)
        #expect(store.actionQueue.count == 2)
        #expect(!store.actionQueue.contains { $0.id == "e1" })
    }

    @Test("Archive sets undo toast")
    func archiveSetsUndoToast() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.archive(emailID: "e1", emailStore: store, apiClient: nil)
        #expect(handler.undoToast != nil)
        #expect(handler.undoToast?.message == "Email archived")
    }

    @Test("Archive undo restores email")
    func archiveUndoRestores() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.archive(emailID: "e1", emailStore: store, apiClient: nil)
        #expect(store.actionQueue.count == 2)

        handler.undoToast?.undoAction()
        #expect(store.actionQueue.count == 3)
        #expect(store.actionQueue.contains { $0.id == "e1" })
    }

    // MARK: - Trash

    @Test("Trash removes email from action queue optimistically")
    func trashRemovesEmail() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.trash(emailID: "e2", emailStore: store, apiClient: nil)
        #expect(store.actionQueue.count == 2)
        #expect(!store.actionQueue.contains { $0.id == "e2" })
    }

    @Test("Trash sets undo toast with correct message")
    func trashSetsUndoToast() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.trash(emailID: "e1", emailStore: store, apiClient: nil)
        #expect(handler.undoToast?.message == "Email deleted")
    }

    // MARK: - Toggle Read

    @Test("Toggle read changes unread to read")
    func toggleReadUnreadToRead() {
        let email = makeEmail(id: "e1", isRead: false)
        let store = makePopulatedStore(emails: [email])
        let handler = EmailActionHandler()

        handler.toggleRead(
            emailID: "e1",
            isCurrentlyRead: false,
            emailStore: store,
            apiClient: nil
        )
        #expect(store.actionQueue.first?.isRead == true)
    }

    @Test("Toggle read changes read to unread")
    func toggleReadReadToUnread() {
        let email = makeEmail(id: "e1", isRead: true)
        let store = makePopulatedStore(emails: [email])
        let handler = EmailActionHandler()

        handler.toggleRead(
            emailID: "e1",
            isCurrentlyRead: true,
            emailStore: store,
            apiClient: nil
        )
        #expect(store.actionQueue.first?.isRead == false)
    }

    // MARK: - Snooze

    @Test("Begin snooze sets target email and shows picker")
    func beginSnooze() {
        let handler = EmailActionHandler()

        handler.beginSnooze(emailID: "e1")
        #expect(handler.snoozeTargetEmailID == "e1")
        #expect(handler.showSnoozePicker == true)
    }

    // MARK: - Dismiss

    @Test("Dismiss undo toast clears it")
    func dismissUndoToast() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.archive(emailID: "e1", emailStore: store, apiClient: nil)
        #expect(handler.undoToast != nil)

        handler.dismissUndoToast()
        #expect(handler.undoToast == nil)
    }
}

// MARK: - EmailStore Optimistic Mutation Tests

@Suite("EmailStore Optimistic Mutations")
@MainActor
struct EmailStoreOptimisticMutationTests {

    private func makeEmail(id: String, isRead: Bool = false) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: "Test", email: "test@co.com"),
            to: [Contact(email: "you@co.com")],
            subject: "Subject \(id)",
            snippet: "Snippet",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: false
        )
    }

    @Test("removeFromActionQueue removes and returns email")
    func removeFromActionQueue() {
        let store = EmailStore()
        let emails = [makeEmail(id: "e1"), makeEmail(id: "e2")]
        store.setEmails(emails, for: .actionQueue)

        let removed = store.removeFromActionQueue(id: "e1")
        #expect(removed?.id == "e1")
        #expect(store.actionQueue.count == 1)
        #expect(store.actionQueue[0].id == "e2")
    }

    @Test("removeFromActionQueue returns nil for unknown ID")
    func removeUnknownID() {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1")], for: .actionQueue)

        let removed = store.removeFromActionQueue(id: "nonexistent")
        #expect(removed == nil)
        #expect(store.actionQueue.count == 1)
    }

    @Test("restoreToActionQueue re-inserts email")
    func restoreToActionQueue() {
        let store = EmailStore()
        let email = makeEmail(id: "e1")
        store.setEmails([email, makeEmail(id: "e2")], for: .actionQueue)

        let removed = store.removeFromActionQueue(id: "e1")!
        #expect(store.actionQueue.count == 1)

        store.restoreToActionQueue(removed)
        #expect(store.actionQueue.count == 2)
        #expect(store.actionQueue.contains { $0.id == "e1" })
    }

    @Test("updateReadState changes read state in action queue")
    func updateReadState() {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1", isRead: false)], for: .actionQueue)

        store.updateReadState(id: "e1", isRead: true)
        #expect(store.actionQueue.first?.isRead == true)

        store.updateReadState(id: "e1", isRead: false)
        #expect(store.actionQueue.first?.isRead == false)
    }

    @Test("updateReadState does nothing for unknown ID")
    func updateReadStateUnknown() {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1", isRead: false)], for: .actionQueue)

        store.updateReadState(id: "nonexistent", isRead: true)
        #expect(store.actionQueue.first?.isRead == false)
    }
}

// MARK: - Email.withReadState Tests

@Suite("Email.withReadState")
struct EmailWithReadStateTests {

    @Test("withReadState creates copy with new read state")
    func withReadState() {
        let email = Email(
            id: "e1",
            accountId: "acc-1",
            from: Contact(name: "Test", email: "test@co.com"),
            to: [Contact(email: "you@co.com")],
            subject: "Test",
            snippet: "Snippet",
            receivedAt: Date(),
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: true,
            accountName: "Work"
        )

        let readEmail = email.withReadState(true)
        #expect(readEmail.isRead == true)
        #expect(readEmail.id == email.id)
        #expect(readEmail.subject == email.subject)
        #expect(readEmail.hasAttachments == email.hasAttachments)
        #expect(readEmail.accountName == email.accountName)
    }
}

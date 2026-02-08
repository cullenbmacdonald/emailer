import Foundation
import Testing
@testable import EmailClientKit

@Suite("Filtered View Tests")
struct FilteredViewTests {

    // MARK: - EmailStore Filtered Methods

    @Test("removeFromFiltered removes email and returns it")
    @MainActor
    func removeFromFiltered() {
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.95)
        store.setEmails([email], for: .filtered)
        store.setEmails([email], for: .allInboxes)

        let removed = store.removeFromFiltered(id: "f1")
        #expect(removed != nil)
        #expect(removed?.id == "f1")
        #expect(store.filtered.isEmpty)
        #expect(store.allInboxes.isEmpty)
    }

    @Test("removeFromFiltered returns nil for missing email")
    @MainActor
    func removeFromFilteredMissing() {
        let store = EmailStore()
        let removed = store.removeFromFiltered(id: "nonexistent")
        #expect(removed == nil)
    }

    @Test("restoreToFiltered re-inserts email")
    @MainActor
    func restoreToFiltered() {
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.95)

        store.restoreToFiltered(email)
        #expect(store.filtered.count == 1)
        #expect(store.allInboxes.count == 1)
    }

    @Test("filteredBorderlineCount returns count of items with confidence < 0.80")
    @MainActor
    func filteredBorderlineCount() {
        let store = EmailStore()
        let emails = [
            makeFilteredEmail(id: "f1", confidence: 0.68),
            makeFilteredEmail(id: "f2", confidence: 0.72),
            makeFilteredEmail(id: "f3", confidence: 0.85),
            makeFilteredEmail(id: "f4", confidence: 0.95),
        ]
        store.setEmails(emails, for: .filtered)

        #expect(store.filteredBorderlineCount == 2)
    }

    @Test("filteredBorderlineCount is zero when no borderline items")
    @MainActor
    func filteredBorderlineCountZero() {
        let store = EmailStore()
        let emails = [
            makeFilteredEmail(id: "f1", confidence: 0.85),
            makeFilteredEmail(id: "f2", confidence: 0.95),
        ]
        store.setEmails(emails, for: .filtered)

        #expect(store.filteredBorderlineCount == 0)
    }

    // MARK: - RescueDestination

    @Test("RescueDestination has correct target classifications")
    func rescueDestinationClassifications() {
        #expect(RescueDestination.actionQueue.targetClassification == .actionRequired)
        #expect(RescueDestination.readingQueue.targetClassification == .newsletter)
        #expect(RescueDestination.allInboxes.targetClassification == .transactional)
    }

    @Test("RescueDestination has labels, icons, and shortcut keys")
    func rescueDestinationProperties() {
        for destination in RescueDestination.allCases {
            #expect(!destination.label.isEmpty)
            #expect(!destination.icon.isEmpty)
            #expect(!destination.shortcutKey.isEmpty)
        }
    }

    // MARK: - FilteredActionHandler

    @Test("rescue removes email from filtered optimistically")
    @MainActor
    func rescueOptimistic() {
        let handler = FilteredActionHandler()
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.68)
        store.setEmails([email], for: .filtered)

        handler.rescue(
            emailID: "f1",
            to: .actionQueue,
            emailStore: store,
            apiClient: nil
        )

        #expect(store.filtered.isEmpty)
        #expect(handler.undoToast != nil)
        #expect(handler.undoToast?.message.contains("Action Queue") == true)
    }

    @Test("rescue undo restores email")
    @MainActor
    func rescueUndo() {
        let handler = FilteredActionHandler()
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.68)
        store.setEmails([email], for: .filtered)

        handler.rescue(
            emailID: "f1",
            to: .readingQueue,
            emailStore: store,
            apiClient: nil
        )

        #expect(store.filtered.isEmpty)

        // Undo
        handler.undoToast?.undoAction()

        #expect(store.filtered.count == 1)
        #expect(store.filtered.first?.id == "f1")
    }

    @Test("confirmSpam removes email and shows toast")
    @MainActor
    func confirmSpam() {
        let handler = FilteredActionHandler()
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.95)
        store.setEmails([email], for: .filtered)

        handler.confirmSpam(
            emailID: "f1",
            emailStore: store,
            apiClient: nil
        )

        #expect(store.filtered.isEmpty)
        #expect(handler.undoToast?.message == "Confirmed as spam")
    }

    @Test("deleteNow removes email and shows toast")
    @MainActor
    func deleteNow() {
        let handler = FilteredActionHandler()
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.95)
        store.setEmails([email], for: .filtered)

        handler.deleteNow(
            emailID: "f1",
            emailStore: store,
            apiClient: nil
        )

        #expect(store.filtered.isEmpty)
        #expect(handler.undoToast?.message == "Email deleted")
    }

    @Test("dismissUndoToast clears the toast")
    @MainActor
    func dismissUndoToast() {
        let handler = FilteredActionHandler()
        let store = EmailStore()
        let email = makeFilteredEmail(id: "f1", confidence: 0.95)
        store.setEmails([email], for: .filtered)

        handler.confirmSpam(emailID: "f1", emailStore: store, apiClient: nil)
        #expect(handler.undoToast != nil)

        handler.dismissUndoToast()
        #expect(handler.undoToast == nil)
    }

    // MARK: - Helpers

    private func makeFilteredEmail(id: String, confidence: Double) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: nil, email: "spam@example.com"),
            to: [Contact(name: "User", email: "user@test.com")],
            subject: "Test filtered email",
            snippet: "This is a test filtered email",
            receivedAt: Date(),
            classification: Classification(
                classification: .filtered,
                confidence: confidence,
                classifiedBy: .features,
                reason: "Marketing language detected"
            ),
            isRead: false,
            isArchived: false,
            hasAttachments: false,
            daysUntilExpiry: 14
        )
    }
}

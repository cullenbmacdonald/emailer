import Foundation
import Testing
@testable import EmailClientKit

/// Tests for the iOS snooze picker integration flow.
/// Verifies that the snooze picker presentation and completion
/// works correctly when triggered from the detail view toolbar.
@Suite("iOS Snooze Picker Integration")
@MainActor
struct IOSSnoozePickerIntegrationTests {

    private func makeEmail(id: String = "e1") -> Email {
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
            isRead: false,
            isArchived: false,
            hasAttachments: false
        )
    }

    private func makePopulatedStore() -> EmailStore {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1"), makeEmail(id: "e2")], for: .actionQueue)
        return store
    }

    @Test("beginSnooze from detail sets picker state for that email")
    func beginSnoozeFromDetail() {
        let handler = EmailActionHandler()
        handler.beginSnooze(emailID: "e1")

        #expect(handler.showSnoozePicker == true)
        #expect(handler.snoozeTargetEmailID == "e1")
    }

    @Test("Completing snooze from picker dismisses and removes email")
    func completeSnoozeDismissesAndRemoves() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        // Simulate the flow: begin snooze -> select preset -> complete
        handler.beginSnooze(emailID: "e1")
        #expect(handler.showSnoozePicker == true)

        let future = Date().addingTimeInterval(2 * 60 * 60)
        handler.snooze(emailID: "e1", until: future, emailStore: store, apiClient: nil)

        #expect(handler.showSnoozePicker == false)
        #expect(handler.snoozeTargetEmailID == nil)
        #expect(store.actionQueue.count == 1)
        #expect(handler.undoToast != nil)
    }

    @Test("Cancelling snooze picker resets state without removing email")
    func cancelSnoozeResetsState() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.beginSnooze(emailID: "e1")
        #expect(handler.showSnoozePicker == true)

        // Simulate cancel: just reset state
        handler.showSnoozePicker = false
        handler.snoozeTargetEmailID = nil

        #expect(handler.showSnoozePicker == false)
        #expect(handler.snoozeTargetEmailID == nil)
        #expect(store.actionQueue.count == 2) // No change
        #expect(handler.undoToast == nil)
    }

    @Test("Snooze preset options compute future dates")
    func presetOptionsAreFuture() {
        for option in SnoozeOption.presets {
            #expect(option.targetDate > Date())
        }
    }

    @Test("Snooze undo after picker flow restores email")
    func undoAfterPickerFlowRestores() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        handler.beginSnooze(emailID: "e1")
        let future = Date().addingTimeInterval(3600)
        handler.snooze(emailID: "e1", until: future, emailStore: store, apiClient: nil)

        #expect(store.actionQueue.count == 1)

        // Undo
        handler.undoToast?.undoAction()
        #expect(store.actionQueue.count == 2)
        #expect(store.actionQueue.contains { $0.id == "e1" })
    }

    @Test("Sequential snooze operations on different emails work independently")
    func sequentialSnoozeOperations() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()

        // Snooze first email
        handler.beginSnooze(emailID: "e1")
        handler.snooze(
            emailID: "e1",
            until: Date().addingTimeInterval(3600),
            emailStore: store,
            apiClient: nil
        )
        #expect(store.actionQueue.count == 1)

        // Snooze second email
        handler.beginSnooze(emailID: "e2")
        handler.snooze(
            emailID: "e2",
            until: Date().addingTimeInterval(7200),
            emailStore: store,
            apiClient: nil
        )
        #expect(store.actionQueue.count == 0)
    }
}

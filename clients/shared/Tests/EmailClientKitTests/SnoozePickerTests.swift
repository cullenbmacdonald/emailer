import Foundation
import Testing
@testable import EmailClientKit

// MARK: - SnoozeOption Tests

@Suite("SnoozeOption")
struct SnoozeOptionTests {

    @Test("Presets returns three options")
    func presetsCount() {
        let presets = SnoozeOption.presets
        #expect(presets.count == 3)
        #expect(presets[0].id == "2hours")
        #expect(presets[1].id == "tomorrow")
        #expect(presets[2].id == "nextweek")
    }

    @Test("Two hours option is approximately 2 hours from now")
    func twoHoursDate() {
        let option = SnoozeOption.twoHours
        let expected = Date().addingTimeInterval(2 * 60 * 60)
        let diff = abs(option.targetDate.timeIntervalSince(expected))
        #expect(diff < 2) // Within 2 seconds tolerance
    }

    @Test("Tomorrow 9am is tomorrow at 9:00")
    func tomorrowMorningDate() {
        let date = SnoozeOption.tomorrowMorning.targetDate
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        #expect(hour == 9)
        #expect(minute == 0)

        // Should be tomorrow
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let isTomorrow = calendar.isDate(date, inSameDayAs: tomorrow)
        #expect(isTomorrow)
    }

    @Test("Next week is a Monday at 9:00")
    func nextWeekDate() {
        let date = SnoozeOption.nextWeek.targetDate
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        #expect(weekday == 2) // Monday
        #expect(hour == 9)
        #expect(minute == 0)
        #expect(date > Date()) // Must be in the future
    }

    @Test("Next week is at least 1 day in the future")
    func nextWeekIsFuture() {
        let date = SnoozeOption.nextWeek.targetDate
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: date).day!
        #expect(days >= 1)
        #expect(days <= 7)
    }

    @Test("formattedDate returns non-empty string")
    func formattedDateNotEmpty() {
        let formatted = SnoozeOption.formattedDate(Date())
        #expect(!formatted.isEmpty)
    }

    @Test("Each preset has an icon")
    func presetsHaveIcons() {
        for preset in SnoozeOption.presets {
            #expect(!preset.icon.isEmpty)
        }
    }

    @Test("Each preset has a label")
    func presetsHaveLabels() {
        for preset in SnoozeOption.presets {
            #expect(!preset.label.isEmpty)
        }
    }
}

// MARK: - EmailActionHandler Snooze Tests

@Suite("EmailActionHandler Snooze")
@MainActor
struct EmailActionHandlerSnoozeTests {

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

    @Test("Snooze removes email from action queue optimistically")
    func snoozeRemovesEmail() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()
        let future = Date().addingTimeInterval(3600)

        handler.snooze(emailID: "e1", until: future, emailStore: store, apiClient: nil)
        #expect(store.actionQueue.count == 1)
        #expect(!store.actionQueue.contains { $0.id == "e1" })
    }

    @Test("Snooze sets undo toast with time message")
    func snoozeSetsUndoToast() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()
        let future = Date().addingTimeInterval(3600)

        handler.snooze(emailID: "e1", until: future, emailStore: store, apiClient: nil)
        #expect(handler.undoToast != nil)
        #expect(handler.undoToast?.message.hasPrefix("Email snoozed until") == true)
    }

    @Test("Snooze dismisses picker and clears target")
    func snoozeDismissesPicker() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()
        handler.beginSnooze(emailID: "e1")
        #expect(handler.showSnoozePicker == true)
        #expect(handler.snoozeTargetEmailID == "e1")

        let future = Date().addingTimeInterval(3600)
        handler.snooze(emailID: "e1", until: future, emailStore: store, apiClient: nil)
        #expect(handler.showSnoozePicker == false)
        #expect(handler.snoozeTargetEmailID == nil)
    }

    @Test("Snooze undo restores email to action queue")
    func snoozeUndoRestores() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()
        let future = Date().addingTimeInterval(3600)

        handler.snooze(emailID: "e1", until: future, emailStore: store, apiClient: nil)
        #expect(store.actionQueue.count == 1)

        handler.undoToast?.undoAction()
        #expect(store.actionQueue.count == 2)
        #expect(store.actionQueue.contains { $0.id == "e1" })
    }

    @Test("Snooze with unknown email ID does not crash")
    func snoozeUnknownEmail() {
        let store = makePopulatedStore()
        let handler = EmailActionHandler()
        let future = Date().addingTimeInterval(3600)

        handler.snooze(emailID: "nonexistent", until: future, emailStore: store, apiClient: nil)
        #expect(store.actionQueue.count == 2) // No change
        #expect(handler.undoToast != nil) // Toast still shown
    }
}

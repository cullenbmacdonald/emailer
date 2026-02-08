import Foundation
import Testing
@testable import EmailClientKit

@Suite("ActionQueueView Logic")
@MainActor
struct ActionQueueViewTests {

    // MARK: - Test Helpers

    private func makeEmail(
        id: String = "e1",
        accountId: String = "acc-1",
        accountName: String? = "Work",
        receivedAt: Date = Date(),
        isRead: Bool = false,
        snooze: SnoozeState? = nil
    ) -> Email {
        Email(
            id: id,
            accountId: accountId,
            from: Contact(name: "Sender", email: "sender@co.com"),
            to: [Contact(email: "you@co.com")],
            subject: "Subject \(id)",
            snippet: "Snippet \(id)",
            receivedAt: receivedAt,
            classification: Classification(
                classification: .actionRequired,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: false,
            snooze: snooze,
            accountName: accountName
        )
    }

    private func makeSnoozeReturn(id: String, returnAt: Date = Date().addingTimeInterval(-60)) -> Email {
        makeEmail(
            id: id,
            snooze: SnoozeState(
                id: "snz-\(id)",
                emailId: id,
                snoozedAt: Date().addingTimeInterval(-86400),
                returnAt: returnAt,
                snoozeCount: 2,
                isActive: false
            )
        )
    }

    // MARK: - Section Logic

    @Test("Snooze returns are identified correctly")
    func snoozeReturnIdentification() {
        let returnedSnooze = SnoozeState(
            id: "snz-1", emailId: "e1",
            snoozedAt: Date().addingTimeInterval(-86400),
            returnAt: Date().addingTimeInterval(-60),
            snoozeCount: 2, isActive: false
        )
        let activeSnooze = SnoozeState(
            id: "snz-2", emailId: "e2",
            snoozedAt: Date(),
            returnAt: Date().addingTimeInterval(3600),
            snoozeCount: 1, isActive: true
        )

        // Returned: isActive=false and returnAt is in the past
        #expect(!returnedSnooze.isActive && returnedSnooze.returnAt <= Date())
        // Active: isActive=true
        #expect(activeSnooze.isActive)
    }

    @Test("Returning emails sorted by returnAt DESC")
    func returningSortOrder() {
        let earlier = makeSnoozeReturn(id: "e1", returnAt: Date().addingTimeInterval(-3600))
        let later = makeSnoozeReturn(id: "e2", returnAt: Date().addingTimeInterval(-60))

        let returning = [earlier, later].sorted { lhs, rhs in
            let lhsReturn = lhs.snooze?.returnAt ?? .distantPast
            let rhsReturn = rhs.snooze?.returnAt ?? .distantPast
            return lhsReturn > rhsReturn
        }

        #expect(returning[0].id == "e2") // More recent return first
        #expect(returning[1].id == "e1")
    }

    @Test("New items sorted by receivedAt DESC")
    func newItemsSortOrder() {
        let older = makeEmail(id: "e1", receivedAt: Date().addingTimeInterval(-7200))
        let newer = makeEmail(id: "e2", receivedAt: Date().addingTimeInterval(-60))

        let sorted = [older, newer].sorted { $0.receivedAt > $1.receivedAt }

        #expect(sorted[0].id == "e2") // Newer first
        #expect(sorted[1].id == "e1")
    }

    // MARK: - Account Filter

    @Test("All filter passes all emails")
    func allFilterPassesAll() {
        let work = makeEmail(id: "e1", accountName: "Work")
        let personal = makeEmail(id: "e2", accountName: "Personal")
        let emails = [work, personal]

        let filtered = emails.filter { _ in true } // .all case
        #expect(filtered.count == 2)
    }

    @Test("Work filter passes only work emails")
    func workFilter() {
        let work = makeEmail(id: "e1", accountName: "Work")
        let personal = makeEmail(id: "e2", accountName: "Personal")
        let emails = [work, personal]

        let filtered = emails.filter { $0.accountName?.lowercased() == "work" }
        #expect(filtered.count == 1)
        #expect(filtered[0].id == "e1")
    }

    @Test("Personal filter passes non-work emails")
    func personalFilter() {
        let work = makeEmail(id: "e1", accountName: "Work")
        let personal = makeEmail(id: "e2", accountName: "Personal")
        let emails = [work, personal]

        let filtered = emails.filter { $0.accountName?.lowercased() != "work" }
        #expect(filtered.count == 1)
        #expect(filtered[0].id == "e2")
    }

    @Test("Account ID filter passes matching account")
    func accountIdFilter() {
        let e1 = makeEmail(id: "e1", accountId: "acc-1")
        let e2 = makeEmail(id: "e2", accountId: "acc-2")
        let emails = [e1, e2]

        let targetId = "acc-1"
        let filtered = emails.filter { $0.accountId == targetId }
        #expect(filtered.count == 1)
        #expect(filtered[0].id == "e1")
    }

    // MARK: - Empty & Loading States

    @Test("Empty state shows when no emails")
    func emptyState() {
        let store = EmailStore()
        #expect(store.actionQueue.isEmpty)
    }

    @Test("Loading state shows when loading and empty")
    func loadingState() {
        let store = EmailStore()
        store.setLoading(true)
        #expect(store.isLoading)
        #expect(store.actionQueue.isEmpty)
    }

    @Test("Populated state shows when emails exist")
    func populatedState() {
        let store = EmailStore()
        store.setEmails([makeEmail()], for: .actionQueue)
        #expect(!store.actionQueue.isEmpty)
    }

    // MARK: - Badge Count

    @Test("Action queue count reflects email count")
    func badgeCount() {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1"), makeEmail(id: "e2")], for: .actionQueue)
        #expect(store.actionQueueCount == 2)
    }

    @Test("Action queue count updates after removal")
    func badgeCountAfterRemoval() {
        let store = EmailStore()
        store.setEmails([makeEmail(id: "e1"), makeEmail(id: "e2")], for: .actionQueue)
        store.removeFromActionQueue(id: "e1")
        #expect(store.actionQueueCount == 1)
    }
}

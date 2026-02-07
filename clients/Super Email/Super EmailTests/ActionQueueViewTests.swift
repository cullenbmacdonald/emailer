import Foundation
import Testing
import EmailClientKit
@testable import Emailer

@Suite("ActionQueueView")
@MainActor
struct ActionQueueViewTests {

    // MARK: - Helpers

    private func makeEmail(
        id: String = "e1",
        classification: ClassificationType = .actionRequired,
        receivedAt: Date = Date(),
        isRead: Bool = false,
        accountName: String? = "Work",
        snooze: SnoozeState? = nil
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: "Sender", email: "sender@test.com"),
            to: [Contact(email: "you@test.com")],
            subject: "Subject \(id)",
            snippet: "Snippet \(id)",
            receivedAt: receivedAt,
            classification: Classification(
                classification: classification,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: false,
            snooze: snooze,
            accountColor: "#3B82F6",
            accountName: accountName
        )
    }

    private func makeSnoozeReturn(
        id: String,
        returnAt: Date = Date().addingTimeInterval(-60),
        snoozeCount: Int = 2
    ) -> Email {
        makeEmail(
            id: id,
            snooze: SnoozeState(
                id: "snz-\(id)",
                emailId: id,
                snoozedAt: Date().addingTimeInterval(-86400),
                returnAt: returnAt,
                snoozeCount: snoozeCount,
                isActive: false
            )
        )
    }

    // MARK: - AppState New Properties

    @Test("AppState has selectedEmailID default nil")
    func selectedEmailIDDefault() {
        let state = AppState()
        #expect(state.selectedEmailID == nil)
    }

    @Test("AppState has accountFilter default .all")
    func accountFilterDefault() {
        let state = AppState()
        #expect(state.accountFilter == .all)
    }

    @Test("AppState selectedEmailID can be set")
    func selectedEmailIDSet() {
        let state = AppState()
        state.selectedEmailID = "e1"
        #expect(state.selectedEmailID == "e1")
    }

    @Test("AppState accountFilter can be changed")
    func accountFilterChange() {
        let state = AppState()
        state.accountFilter = .work
        #expect(state.accountFilter == .work)
        state.accountFilter = .personal
        #expect(state.accountFilter == .personal)
    }

    // MARK: - EmailStore Loading State

    @Test("EmailStore isLoading defaults to false")
    func isLoadingDefault() {
        let store = EmailStore()
        #expect(!store.isLoading)
    }

    @Test("EmailStore setLoading updates state")
    func setLoading() {
        let store = EmailStore()
        store.setLoading(true)
        #expect(store.isLoading)
        store.setLoading(false)
        #expect(!store.isLoading)
    }

    // MARK: - Pagination

    @Test("EmailStore pagination defaults")
    func paginationDefaults() {
        let store = EmailStore()
        #expect(store.actionQueueCursor == nil)
        #expect(!store.actionQueueHasMore)
    }

    @Test("EmailStore setActionQueuePagination updates state")
    func setPagination() {
        let store = EmailStore()
        store.setActionQueuePagination(cursor: "abc123", hasMore: true)
        #expect(store.actionQueueCursor == "abc123")
        #expect(store.actionQueueHasMore)
    }

    @Test("EmailStore appendActionQueueEmails adds without duplicates")
    func appendEmails() {
        let store = EmailStore()
        let email1 = makeEmail(id: "e1")
        let email2 = makeEmail(id: "e2")
        store.setEmails([email1], for: .actionQueue)
        store.appendActionQueueEmails([email1, email2])
        #expect(store.actionQueue.count == 2)
    }

    // MARK: - Detail Loading

    @Test("EmailStore selectedDetail defaults to nil")
    func selectedDetailDefault() {
        let store = EmailStore()
        #expect(store.selectedDetail == nil)
    }

    @Test("EmailStore clearDetail sets nil")
    func clearDetail() {
        let store = EmailStore()
        store.clearDetail()
        #expect(store.selectedDetail == nil)
    }

    @Test("EmailStore loadDetail with nil client does nothing")
    func loadDetailNilClient() async {
        let store = EmailStore()
        await store.loadDetail(for: "e1", using: nil)
        #expect(store.selectedDetail == nil)
    }

    // MARK: - Snooze Return Detection

    @Test("Snooze return is identified correctly")
    func snoozeReturnDetection() {
        let returning = makeSnoozeReturn(id: "e1")
        #expect(returning.snooze != nil)
        #expect(returning.snooze?.isActive == false)
        #expect(returning.snooze!.returnAt <= Date())
    }

    @Test("Active snooze is not a return")
    func activeSnoozeNotReturn() {
        let email = makeEmail(
            id: "e1",
            snooze: SnoozeState(
                id: "snz-1", emailId: "e1",
                snoozedAt: Date(),
                returnAt: Date().addingTimeInterval(3600),
                snoozeCount: 1, isActive: true
            )
        )
        #expect(email.snooze?.isActive == true)
    }

    @Test("No snooze state is not a return")
    func noSnoozeNotReturn() {
        let email = makeEmail(id: "e1", snooze: nil)
        #expect(email.snooze == nil)
    }

    // MARK: - Account Filter Logic

    @Test("Account filter .all matches all emails")
    func filterAllMatches() {
        let work = makeEmail(id: "e1", accountName: "Work")
        let personal = makeEmail(id: "e2", accountName: "Personal")
        #expect(matchesFilter(work, filter: .all))
        #expect(matchesFilter(personal, filter: .all))
    }

    @Test("Account filter .work matches only work emails")
    func filterWorkMatches() {
        let work = makeEmail(id: "e1", accountName: "Work")
        let personal = makeEmail(id: "e2", accountName: "Personal")
        #expect(matchesFilter(work, filter: .work))
        #expect(!matchesFilter(personal, filter: .work))
    }

    @Test("Account filter .personal matches non-work emails")
    func filterPersonalMatches() {
        let work = makeEmail(id: "e1", accountName: "Work")
        let personal = makeEmail(id: "e2", accountName: "Personal")
        #expect(!matchesFilter(work, filter: .personal))
        #expect(matchesFilter(personal, filter: .personal))
    }

    /// Mirrors the filter logic in ActionQueueView.
    private func matchesFilter(_ email: Email, filter: AccountFilter) -> Bool {
        switch filter {
        case .all: true
        case .work: email.accountName?.lowercased() == "work"
        case .personal: email.accountName?.lowercased() != "work"
        }
    }

    // MARK: - Sorting

    @Test("New items sorted by receivedAt descending")
    func newItemsSorting() {
        let store = EmailStore()
        let older = makeEmail(id: "e1", receivedAt: Date().addingTimeInterval(-3600))
        let newer = makeEmail(id: "e2", receivedAt: Date().addingTimeInterval(-60))
        store.setEmails([older, newer], for: .actionQueue)

        let sorted = store.actionQueue
            .filter { $0.snooze == nil }
            .sorted { $0.receivedAt > $1.receivedAt }
        #expect(sorted.first?.id == "e2")
        #expect(sorted.last?.id == "e1")
    }

    @Test("Returning items sorted by returnAt descending")
    func returningItemsSorting() {
        let olderReturn = makeSnoozeReturn(
            id: "e1",
            returnAt: Date().addingTimeInterval(-3600)
        )
        let newerReturn = makeSnoozeReturn(
            id: "e2",
            returnAt: Date().addingTimeInterval(-60)
        )
        let store = EmailStore()
        store.setEmails([olderReturn, newerReturn], for: .actionQueue)

        let returning = store.actionQueue
            .filter { $0.snooze != nil && !($0.snooze?.isActive ?? true) }
            .sorted {
                ($0.snooze?.returnAt ?? .distantPast) > ($1.snooze?.returnAt ?? .distantPast)
            }
        #expect(returning.first?.id == "e2")
    }

    // MARK: - Badge Count

    @Test("Badge count matches total action queue count")
    func badgeCountMatchesTotal() {
        let store = EmailStore()
        store.setEmails([
            makeEmail(id: "e1"),
            makeEmail(id: "e2"),
            makeEmail(id: "e3"),
        ], for: .actionQueue)
        #expect(store.actionQueueCount == 3)
    }
}

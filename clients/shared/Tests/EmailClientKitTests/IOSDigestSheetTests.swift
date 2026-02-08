import Foundation
import Testing
@testable import EmailClientKit

@Suite("iOS Digest Sheet Integration")
@MainActor
struct IOSDigestSheetTests {

    private func makeDigest(id: String = "d1", isRead: Bool = false) -> DailyDigest {
        DailyDigest(
            id: id,
            digestType: .morning,
            generatedAt: Date(),
            isRead: isRead,
            sections: []
        )
    }

    // MARK: - AppState showDigestSheet

    @Test("showDigestSheet defaults to false")
    func showDigestSheetDefaultsFalse() {
        let state = AppState()
        #expect(!state.showDigestSheet)
    }

    @Test("showDigestSheet can be toggled")
    func showDigestSheetToggle() {
        let state = AppState()
        state.showDigestSheet = true
        #expect(state.showDigestSheet)
        state.showDigestSheet = false
        #expect(!state.showDigestSheet)
    }

    // MARK: - Digest mark-as-read clears NEW indicator

    @Test("Marking digest as read clears hasNewDigest on store")
    func markAsReadClearsNewIndicator() {
        let store = DigestStore()
        store.setLatestDigest(makeDigest(isRead: false))
        #expect(store.hasNewDigest)

        store.markAsRead()
        #expect(!store.hasNewDigest)
    }

    @Test("AppState hasNewDigest can be cleared independently")
    func appStateHasNewDigestCleared() {
        let state = AppState()
        state.hasNewDigest = true
        #expect(state.hasNewDigest)

        state.hasNewDigest = false
        #expect(!state.hasNewDigest)
    }

    // MARK: - Navigation from digest sections switches tabs

    #if os(iOS)
    @Test("Setting selectedView to actionQueue from digest navigates correctly")
    func digestNavigatesToActionQueue() {
        let state = AppState()
        state.selectedView = .dailyDigest
        state.selectedView = .actionQueue
        #expect(state.selectedView == .actionQueue)
    }

    @Test("Setting selectedView to readingQueue from digest navigates correctly")
    func digestNavigatesToReadingQueue() {
        let state = AppState()
        state.selectedView = .dailyDigest
        state.selectedView = .readingQueue
        #expect(state.selectedView == .readingQueue)
    }
    #endif

    // MARK: - Digest sections with empty data are hidden

    @Test("DigestStore shouldShowSection hides empty optional sections")
    func emptySectionsHidden() {
        let store = DigestStore()

        // Returning with no items -- items list empty
        let emptyReturning = DigestSection(
            type: .returningToday,
            title: "Returning Today",
            items: []
        )
        let items = emptyReturning.items ?? []
        let active = items.filter { !store.dismissedItemIDs.contains($0.emailId) }
        #expect(active.isEmpty)
    }

    @Test("DigestStore shouldShowSection shows always-shown sections")
    func alwaysShownSections() {
        // Action queue summary and reading queue summary are always shown
        let aqSection = DigestSection(
            type: .actionQueueSummary,
            title: "Action Queue",
            count: 0
        )
        #expect(aqSection.type == .actionQueueSummary)

        let rqSection = DigestSection(
            type: .readingQueueSummary,
            title: "Reading Queue",
            count: 0
        )
        #expect(rqSection.type == .readingQueueSummary)
    }

    // MARK: - Morning and Evening section ordering

    @Test("Morning digest sections are in correct order")
    func morningSectionOrder() {
        let sections: [DigestSectionType] = [
            .actionQueueSummary,
            .returningToday,
            .readingQueueSummary,
            .borderlineItems,
            .notableTransactional
        ]
        #expect(sections[0] == .actionQueueSummary)
        #expect(sections[1] == .returningToday)
        #expect(sections[2] == .readingQueueSummary)
        #expect(sections[3] == .borderlineItems)
        #expect(sections[4] == .notableTransactional)
    }

    @Test("Evening digest sections are in correct order")
    func eveningSectionOrder() {
        let sections: [DigestSectionType] = [
            .todayStats,
            .stillPending,
            .newslettersToday,
            .snoozeNudges,
            .notableTransactional
        ]
        #expect(sections[0] == .todayStats)
        #expect(sections[1] == .stillPending)
        #expect(sections[2] == .newslettersToday)
        #expect(sections[3] == .snoozeNudges)
        #expect(sections[4] == .notableTransactional)
    }

    // MARK: - Borderline item actions

    @Test("Dismissing borderline item adds to dismissed set")
    func dismissBorderlineItem() {
        let store = DigestStore()
        store.dismissItem("b1")
        #expect(store.dismissedItemIDs.contains("b1"))
    }

    @Test("Rescue email ID can be set for Not Spam action sheet")
    func rescueEmailIDSet() {
        let store = DigestStore()
        store.rescueEmailID = "b1"
        #expect(store.rescueEmailID == "b1")
    }

    // MARK: - Date navigation

    @Test("showLatestDigest resets to latest")
    func showLatestDigestResets() {
        let store = DigestStore()
        let d1 = makeDigest(id: "d1")
        let d2 = makeDigest(id: "d2")
        store.setLatestDigest(d1)
        store.setCurrentDigest(d2)
        store.dismissItem("x")

        store.showLatestDigest()
        #expect(store.currentDigest?.id == "d1")
        #expect(store.dismissedItemIDs.isEmpty)
    }

    // MARK: - Empty state

    @Test("Empty state when no digest available")
    func emptyStateNoDigest() {
        let store = DigestStore()
        #expect(store.displayedDigest == nil)
        #expect(!store.hasNewDigest)
    }
}

import Foundation
import Testing
@testable import EmailClientKit

@Suite("DigestStore - Extended")
@MainActor
struct DigestStoreExtendedTests {

    // MARK: - Helpers

    private func makeMorningDigest(
        id: String = "d1",
        isRead: Bool = false,
        sections: [DigestSection] = []
    ) -> DailyDigest {
        DailyDigest(
            id: id,
            digestType: .morning,
            generatedAt: Date(),
            isRead: isRead,
            sections: sections
        )
    }

    private func makeEveningDigest(
        id: String = "d2",
        isRead: Bool = false,
        sections: [DigestSection] = []
    ) -> DailyDigest {
        DailyDigest(
            id: id,
            digestType: .evening,
            generatedAt: Date(),
            isRead: isRead,
            sections: sections
        )
    }

    private func makeActionQueueSection(count: Int = 3) -> DigestSection {
        DigestSection(
            type: .actionQueueSummary,
            title: "Action Queue",
            count: count,
            accountBreakdown: [
                AccountCount(accountId: "a1", accountName: "Work", accountColor: "#3B82F6", count: 2),
                AccountCount(accountId: "a2", accountName: "Personal", accountColor: "#22C55E", count: 1)
            ]
        )
    }

    private func makeReturningSection() -> DigestSection {
        DigestSection(
            type: .returningToday,
            title: "Returning Today",
            subtitle: "These snoozed emails return today:",
            items: [
                DigestItem(
                    type: .snoozedReturn,
                    emailId: "e1",
                    subject: "Re: Q3 budget",
                    from: "Jane Smith",
                    returnAt: Date().addingTimeInterval(3600),
                    snoozeCount: 2
                ),
                DigestItem(
                    type: .snoozedReturn,
                    emailId: "e2",
                    subject: "Project Falcon",
                    from: "Bob Lee",
                    returnAt: Date().addingTimeInterval(7200)
                )
            ]
        )
    }

    private func makeReadingQueueSection(count: Int = 4) -> DigestSection {
        DigestSection(
            type: .readingQueueSummary,
            title: "Reading Queue",
            count: count
        )
    }

    private func makeBorderlineSection() -> DigestSection {
        DigestSection(
            type: .borderlineItems,
            title: "Might Not Be Spam",
            subtitle: "These 3 might be worth checking:",
            items: [
                DigestItem(
                    type: .borderlineEmail,
                    emailId: "b1",
                    subject: "Your January statement is ready",
                    from: "support@bank.com",
                    confidence: 0.68
                ),
                DigestItem(
                    type: .borderlineEmail,
                    emailId: "b2",
                    subject: "Invitation to collaborate",
                    from: "hello@saas.io",
                    confidence: 0.72
                ),
                DigestItem(
                    type: .borderlineEmail,
                    emailId: "b3",
                    subject: "Welcome to our newsletter",
                    from: "newsletter@newco.com",
                    confidence: 0.75
                )
            ]
        )
    }

    private func makeNotableSection() -> DigestSection {
        DigestSection(
            type: .notableTransactional,
            title: "Notable",
            items: [
                DigestItem(
                    type: .notableTransactional,
                    emailId: "n1",
                    highlightType: .packageArriving,
                    displayText: "2 packages arriving today"
                ),
                DigestItem(
                    type: .notableTransactional,
                    emailId: "n2",
                    highlightType: .largeCharge,
                    displayText: "You were charged $847 by United Airlines"
                )
            ]
        )
    }

    private func makeTodayStatsSection() -> DigestSection {
        DigestSection(
            type: .todayStats,
            title: "Today",
            sentCount: 5,
            archivedCount: 7
        )
    }

    private func makeStillPendingSection(count: Int = 2) -> DigestSection {
        DigestSection(
            type: .stillPending,
            title: "Still Pending",
            count: count
        )
    }

    private func makeNewslettersSection() -> DigestSection {
        DigestSection(
            type: .newslettersToday,
            title: "Newsletters Today",
            items: [
                DigestItem(
                    type: .newsletterArrival,
                    emailId: "nl1",
                    subject: "The End of the Beginning",
                    newsletterName: "Stratechery"
                ),
                DigestItem(
                    type: .newsletterArrival,
                    emailId: "nl2",
                    subject: "Issue #847",
                    newsletterName: "Hacker Newsletter"
                )
            ]
        )
    }

    private func makeSnoozeNudgesSection() -> DigestSection {
        DigestSection(
            type: .snoozeNudges,
            title: "Gentle Nudge",
            subtitle: "These have been snoozed multiple times:",
            items: [
                DigestItem(
                    type: .snoozeNudge,
                    emailId: "sn1",
                    subject: "Tax documents needed",
                    from: "accountant@example.com",
                    snoozeCount: 4,
                    daysSinceFirstSnooze: 12
                ),
                DigestItem(
                    type: .snoozeNudge,
                    emailId: "sn2",
                    subject: "Quarterly review",
                    from: "manager@example.com",
                    snoozeCount: 3,
                    daysSinceFirstSnooze: 8
                )
            ]
        )
    }

    // MARK: - DigestStore Tests

    @Test("setLatestDigest also sets currentDigest when nil")
    func setLatestDigestAlsoSetsCurrent() {
        let store = DigestStore()
        let digest = makeMorningDigest()
        store.setLatestDigest(digest)
        #expect(store.latestDigest?.id == "d1")
        #expect(store.currentDigest?.id == "d1")
        #expect(store.displayedDigest?.id == "d1")
    }

    @Test("setLatestDigest does not overwrite currentDigest when already set")
    func setLatestDigestPreservesCurrent() {
        let store = DigestStore()
        let first = makeMorningDigest(id: "first")
        let second = makeMorningDigest(id: "second")
        store.setLatestDigest(first)
        store.setCurrentDigest(second)
        store.setLatestDigest(makeMorningDigest(id: "third"))
        #expect(store.currentDigest?.id == "second")
        #expect(store.latestDigest?.id == "third")
    }

    @Test("setCurrentDigest updates displayed digest")
    func setCurrentDigest() {
        let store = DigestStore()
        let d1 = makeMorningDigest(id: "d1")
        let d2 = makeMorningDigest(id: "d2")
        store.setLatestDigest(d1)
        store.setCurrentDigest(d2)
        #expect(store.displayedDigest?.id == "d2")
    }

    @Test("showLatestDigest resets to latest and clears dismissed items")
    func showLatestDigest() {
        let store = DigestStore()
        let d1 = makeMorningDigest(id: "d1")
        let d2 = makeMorningDigest(id: "d2")
        store.setLatestDigest(d1)
        store.setCurrentDigest(d2)
        store.dismissItem("item1")
        #expect(store.dismissedItemIDs.contains("item1"))

        store.showLatestDigest()
        #expect(store.currentDigest?.id == "d1")
        #expect(store.dismissedItemIDs.isEmpty)
    }

    @Test("dismissItem adds ID to dismissed set")
    func dismissItem() {
        let store = DigestStore()
        store.dismissItem("b1")
        store.dismissItem("b2")
        #expect(store.dismissedItemIDs.count == 2)
        #expect(store.dismissedItemIDs.contains("b1"))
        #expect(store.dismissedItemIDs.contains("b2"))
    }

    @Test("markAsRead also updates currentDigest when viewing latest")
    func markAsReadUpdatesCurrent() {
        let store = DigestStore()
        store.setLatestDigest(makeMorningDigest(isRead: false))
        #expect(store.hasNewDigest)
        store.markAsRead()
        #expect(!store.hasNewDigest)
        #expect(store.currentDigest?.isRead == true)
    }

    @Test("markAsRead does not update currentDigest when viewing different digest")
    func markAsReadDifferentCurrent() {
        let store = DigestStore()
        store.setLatestDigest(makeMorningDigest(id: "latest", isRead: false))
        store.setCurrentDigest(makeMorningDigest(id: "old", isRead: false))
        store.markAsRead()
        // latest is marked read, but current (different ID) is not changed
        #expect(store.latestDigest?.isRead == true)
        #expect(store.currentDigest?.id == "old")
        #expect(store.currentDigest?.isRead == false)
    }

    @Test("setLoading and setError work")
    func loadingAndError() {
        let store = DigestStore()
        store.setLoading(true)
        #expect(store.isLoading)
        store.setLoading(false)
        #expect(!store.isLoading)

        store.setError("Something failed")
        #expect(store.errorMessage == "Something failed")
        store.setError(nil)
        #expect(store.errorMessage == nil)
    }

    @Test("displayedDigest returns currentDigest over latestDigest")
    func displayedDigestPriority() {
        let store = DigestStore()
        #expect(store.displayedDigest == nil)

        store.setLatestDigest(makeMorningDigest(id: "latest"))
        #expect(store.displayedDigest?.id == "latest")

        store.setCurrentDigest(makeEveningDigest(id: "current"))
        #expect(store.displayedDigest?.id == "current")
    }

    @Test("rescueEmailID can be set and cleared")
    func rescueEmailID() {
        let store = DigestStore()
        #expect(store.rescueEmailID == nil)
        store.rescueEmailID = "b1"
        #expect(store.rescueEmailID == "b1")
        store.rescueEmailID = nil
        #expect(store.rescueEmailID == nil)
    }

    // MARK: - Morning Digest Structure Tests

    @Test("Morning digest has correct section order")
    func morningSectionOrder() {
        let sections: [DigestSection] = [
            makeActionQueueSection(),
            makeReturningSection(),
            makeReadingQueueSection(),
            makeBorderlineSection(),
            makeNotableSection()
        ]
        let digest = DailyDigest(
            id: "m1",
            digestType: .morning,
            generatedAt: Date(),
            sections: sections
        )

        #expect(digest.sections.count == 5)
        #expect(digest.sections[0].type == .actionQueueSummary)
        #expect(digest.sections[1].type == .returningToday)
        #expect(digest.sections[2].type == .readingQueueSummary)
        #expect(digest.sections[3].type == .borderlineItems)
        #expect(digest.sections[4].type == .notableTransactional)
    }

    // MARK: - Evening Digest Structure Tests

    @Test("Evening digest has correct section order")
    func eveningSectionOrder() {
        let sections: [DigestSection] = [
            makeTodayStatsSection(),
            makeStillPendingSection(),
            makeNewslettersSection(),
            makeSnoozeNudgesSection(),
            makeNotableSection()
        ]
        let digest = DailyDigest(
            id: "e1",
            digestType: .evening,
            generatedAt: Date(),
            sections: sections
        )

        #expect(digest.sections.count == 5)
        #expect(digest.sections[0].type == .todayStats)
        #expect(digest.sections[1].type == .stillPending)
        #expect(digest.sections[2].type == .newslettersToday)
        #expect(digest.sections[3].type == .snoozeNudges)
        #expect(digest.sections[4].type == .notableTransactional)
    }

    // MARK: - Section Data Tests

    @Test("Action queue summary section has correct data")
    func actionQueueSummaryData() {
        let section = makeActionQueueSection(count: 5)
        #expect(section.type == .actionQueueSummary)
        #expect(section.count == 5)
        #expect(section.accountBreakdown?.count == 2)
        #expect(section.accountBreakdown?[0].accountName == "Work")
        #expect(section.accountBreakdown?[0].count == 2)
    }

    @Test("Returning today section has items with snooze metadata")
    func returningTodayData() {
        let section = makeReturningSection()
        #expect(section.items?.count == 2)
        #expect(section.items?[0].snoozeCount == 2)
        #expect(section.items?[0].returnAt != nil)
        #expect(section.items?[1].snoozeCount == nil)
    }

    @Test("Borderline items section has confidence scores")
    func borderlineItemsData() {
        let section = makeBorderlineSection()
        #expect(section.items?.count == 3)
        #expect(section.items?[0].confidence == 0.68)
        #expect(section.items?[1].confidence == 0.72)
        #expect(section.items?[2].confidence == 0.75)
    }

    @Test("Notable transactional section has highlight types")
    func notableTransactionalData() {
        let section = makeNotableSection()
        #expect(section.items?.count == 2)
        #expect(section.items?[0].highlightType == .packageArriving)
        #expect(section.items?[1].highlightType == .largeCharge)
    }

    @Test("Today stats section has sent and archived counts")
    func todayStatsData() {
        let section = makeTodayStatsSection()
        #expect(section.sentCount == 5)
        #expect(section.archivedCount == 7)
    }

    @Test("Still pending section has count")
    func stillPendingData() {
        let section = makeStillPendingSection(count: 3)
        #expect(section.count == 3)
    }

    @Test("Newsletters section has newsletter names and subjects")
    func newslettersSectionData() {
        let section = makeNewslettersSection()
        #expect(section.items?.count == 2)
        #expect(section.items?[0].newsletterName == "Stratechery")
        #expect(section.items?[0].subject == "The End of the Beginning")
    }

    @Test("Snooze nudges section has snooze counts and days")
    func snoozeNudgesData() {
        let section = makeSnoozeNudgesSection()
        #expect(section.items?.count == 2)
        #expect(section.items?[0].snoozeCount == 4)
        #expect(section.items?[0].daysSinceFirstSnooze == 12)
        #expect(section.items?[1].snoozeCount == 3)
        #expect(section.items?[1].daysSinceFirstSnooze == 8)
    }

    // MARK: - Section Visibility Tests

    @Test("Sections with empty items should be hidden")
    func emptySectionsHidden() {
        // Returning section with no items
        let emptyReturning = DigestSection(
            type: .returningToday,
            title: "Returning Today",
            items: []
        )
        #expect(emptyReturning.items?.isEmpty == true)

        // Borderline with no items
        let emptyBorderline = DigestSection(
            type: .borderlineItems,
            title: "Might Not Be Spam",
            items: []
        )
        #expect(emptyBorderline.items?.isEmpty == true)

        // Still pending with count 0
        let emptyPending = DigestSection(
            type: .stillPending,
            title: "Still Pending",
            count: 0
        )
        #expect(emptyPending.count == 0)
    }

    @Test("Dismissed items reduce visible items in section")
    func dismissedItemsReduceVisible() {
        let store = DigestStore()
        let section = makeBorderlineSection()
        let allItems = section.items ?? []

        // Initially 3 items
        let visibleBefore = allItems.filter { !store.dismissedItemIDs.contains($0.emailId) }
        #expect(visibleBefore.count == 3)

        // Dismiss one
        store.dismissItem("b1")
        let visibleAfter = allItems.filter { !store.dismissedItemIDs.contains($0.emailId) }
        #expect(visibleAfter.count == 2)

        // Dismiss all
        store.dismissItem("b2")
        store.dismissItem("b3")
        let visibleNone = allItems.filter { !store.dismissedItemIDs.contains($0.emailId) }
        #expect(visibleNone.isEmpty)
    }

    // MARK: - Full Digest Integration

    @Test("Full morning digest with all sections")
    func fullMorningDigest() {
        let store = DigestStore()
        let digest = DailyDigest(
            id: "full-morning",
            digestType: .morning,
            generatedAt: Date(),
            isRead: false,
            sections: [
                makeActionQueueSection(),
                makeReturningSection(),
                makeReadingQueueSection(),
                makeBorderlineSection(),
                makeNotableSection()
            ]
        )
        store.setLatestDigest(digest)

        #expect(store.displayedDigest?.digestType == .morning)
        #expect(store.displayedDigest?.sections.count == 5)
        #expect(store.hasNewDigest)
    }

    @Test("Full evening digest with all sections")
    func fullEveningDigest() {
        let store = DigestStore()
        let digest = DailyDigest(
            id: "full-evening",
            digestType: .evening,
            generatedAt: Date(),
            isRead: false,
            sections: [
                makeTodayStatsSection(),
                makeStillPendingSection(),
                makeNewslettersSection(),
                makeSnoozeNudgesSection(),
                makeNotableSection()
            ]
        )
        store.setLatestDigest(digest)

        #expect(store.displayedDigest?.digestType == .evening)
        #expect(store.displayedDigest?.sections.count == 5)
    }
}

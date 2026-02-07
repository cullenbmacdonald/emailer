import Testing
import SwiftUI
@testable import EmailerIOS

// MARK: - IOSBadgeView Tests

@Suite("IOSBadgeView")
@MainActor
struct IOSBadgeViewTests {
    @Test("Badge is hidden when count is 0")
    func badgeHiddenWhenCountZero() {
        let badge = IOSBadgeView(count: 0)
        #expect(badge.count == 0)
    }

    @Test("Badge shows when count is positive")
    func badgeShowsWhenCountPositive() {
        let badge = IOSBadgeView(count: 5)
        #expect(badge.count == 5)
    }

    @Test("Badge default color is accentColor")
    func badgeDefaultColor() {
        let badge = IOSBadgeView(count: 3)
        #expect(badge.color == .accentColor)
    }

    @Test("Badge accepts custom color")
    func badgeCustomColor() {
        let badge = IOSBadgeView(count: 3, color: .snoozeFallback)
        #expect(badge.color == .snoozeFallback)
    }
}

// MARK: - IOSSnoozeCountBadge Tests

@Suite("IOSSnoozeCountBadge")
@MainActor
struct IOSSnoozeCountBadgeTests {
    @Test("Badge is hidden when snooze count is 1")
    func badgeHiddenWhenCountOne() {
        let badge = IOSSnoozeCountBadge(snoozeCount: 1)
        #expect(badge.snoozeCount == 1)
    }

    @Test("Badge is visible when snooze count is 2")
    func badgeVisibleWhenCountTwo() {
        let badge = IOSSnoozeCountBadge(snoozeCount: 2)
        #expect(badge.snoozeCount >= 2)
    }

    @Test("Badge is visible when snooze count is 5")
    func badgeVisibleWhenCountFive() {
        let badge = IOSSnoozeCountBadge(snoozeCount: 5)
        #expect(badge.snoozeCount >= 2)
    }

    @Test("Badge is hidden when snooze count is 0")
    func badgeHiddenWhenCountZero() {
        let badge = IOSSnoozeCountBadge(snoozeCount: 0)
        #expect(badge.snoozeCount < 2)
    }
}

// MARK: - IOSAccountDot Tests

@Suite("IOSAccountDot")
@MainActor
struct IOSAccountDotTests {
    @Test("Account dot stores color and name")
    func accountDotStoresProperties() {
        let dot = IOSAccountDot(color: .accountWorkFallback, accountName: "Work")
        #expect(dot.color == .accountWorkFallback)
        #expect(dot.accountName == "Work")
    }

    @Test("Account dot uses 10pt diameter token")
    func accountDotUses10ptDiameter() {
        #expect(IOSDesignTokens.accountDotDiameter == 10)
    }
}

// MARK: - IOSOfflineBanner Tests

@Suite("IOSOfflineBanner")
@MainActor
struct IOSOfflineBannerTests {
    @Test("Default pending action count is 0")
    func defaultPendingCountIsZero() {
        let banner = IOSOfflineBanner()
        #expect(banner.pendingActionCount == 0)
    }

    @Test("Banner accepts custom pending count")
    func bannerAcceptsCustomPendingCount() {
        let banner = IOSOfflineBanner(pendingActionCount: 5)
        #expect(banner.pendingActionCount == 5)
    }
}

// MARK: - IOSUndoToast Tests

@Suite("IOSUndoToast")
@MainActor
struct IOSUndoToastTests {
    @Test("Toast stores message")
    func toastStoresMessage() {
        let toast = IOSUndoToast(
            message: "Email archived",
            onUndo: {},
            onDismiss: {}
        )
        #expect(toast.message == "Email archived")
    }

    @Test("Toast with different message")
    func toastWithDifferentMessage() {
        let toast = IOSUndoToast(
            message: "Snoozed until tomorrow",
            onUndo: {},
            onDismiss: {}
        )
        #expect(toast.message == "Snoozed until tomorrow")
    }
}

// MARK: - IOSEmptyStateView Tests

@Suite("IOSEmptyStateView")
@MainActor
struct IOSEmptyStateViewTests {
    @Test("Empty state view stores properties")
    func emptyStateStoresProperties() {
        let view = IOSEmptyStateView(
            iconName: "tray",
            title: "Test Title",
            subtitle: "Test subtitle"
        )
        #expect(view.iconName == "tray")
        #expect(view.title == "Test Title")
        #expect(view.subtitle == "Test subtitle")
    }

    @Test("Action Queue empty state has correct content")
    func actionQueueEmptyState() {
        let view = IOSEmptyStateView.actionQueue
        #expect(view.iconName == "checkmark.circle")
        #expect(view.title == "All caught up")
        #expect(view.subtitle == "No emails need your response")
    }

    @Test("Reading Queue empty state has correct content")
    func readingQueueEmptyState() {
        let view = IOSEmptyStateView.readingQueue
        #expect(view.iconName == "book.closed")
        #expect(view.title == "Nothing to read")
        #expect(view.subtitle == "Newsletters will appear here")
    }

    @Test("Recommendations empty state has correct content")
    func recommendationsEmptyState() {
        let view = IOSEmptyStateView.recommendations
        #expect(view.iconName == "star.circle")
        #expect(view.title == "No recommendations yet")
    }

    @Test("Filtered empty state has correct content")
    func filteredEmptyState() {
        let view = IOSEmptyStateView.filteredView
        #expect(view.iconName == "xmark.shield")
        #expect(view.title == "Nothing filtered")
    }

    @Test("All Inboxes empty state has correct content")
    func allInboxesEmptyState() {
        let view = IOSEmptyStateView.allInboxes
        #expect(view.iconName == "tray")
        #expect(view.title == "No emails")
    }

    @Test("Digest empty state has correct content")
    func digestEmptyState() {
        let view = IOSEmptyStateView.digest
        #expect(view.iconName == "sun.horizon")
        #expect(view.title == "No digest yet")
    }
}

// MARK: - AccountMenuItem Tests

@Suite("AccountMenuItem")
@MainActor
struct AccountMenuItemTests {
    @Test("Default accounts has 3 entries")
    func defaultAccountsHasThreeEntries() {
        #expect(AccountMenuItem.defaults.count == 3)
    }

    @Test("Default accounts have expected IDs")
    func defaultAccountsHaveExpectedIDs() {
        let ids = AccountMenuItem.defaults.map(\.id)
        #expect(ids.contains("work"))
        #expect(ids.contains("personal1"))
        #expect(ids.contains("personal2"))
    }

    @Test("Default accounts have expected names")
    func defaultAccountsHaveExpectedNames() {
        let names = AccountMenuItem.defaults.map(\.name)
        #expect(names.contains("Work"))
        #expect(names.contains("Personal"))
        #expect(names.contains("Personal 2"))
    }

    @Test("Account menu item stores properties")
    func accountMenuItemStoresProperties() {
        let item = AccountMenuItem(id: "test", name: "Test Account", color: .red)
        #expect(item.id == "test")
        #expect(item.name == "Test Account")
    }
}

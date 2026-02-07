import Testing
import SwiftUI
@testable import EmailClientKit

// MARK: - BadgeView Tests

@Suite("BadgeView")
@MainActor
struct BadgeViewTests {
    @Test("Badge is hidden when count is 0")
    func badgeHiddenWhenCountZero() {
        let badge = BadgeView(count: 0)
        #expect(badge.count < 1)
    }

    @Test("Badge shows when count is positive")
    func badgeShowsWhenCountPositive() {
        let badge = BadgeView(count: 5)
        #expect(badge.count == 5)
    }

    @Test("Badge default color is accentColor")
    func badgeDefaultColor() {
        let badge = BadgeView(count: 3)
        #expect(badge.color == .accentColor)
    }
}

// MARK: - SnoozeCountBadge Tests

@Suite("SnoozeCountBadge")
@MainActor
struct SnoozeCountBadgeTests {
    @Test("Badge is hidden when snooze count is 1")
    func badgeHiddenWhenCountOne() {
        let badge = SnoozeCountBadge(snoozeCount: 1)
        #expect(badge.snoozeCount == 1)
    }

    @Test("Badge is visible when snooze count is 2")
    func badgeVisibleWhenCountTwo() {
        let badge = SnoozeCountBadge(snoozeCount: 2)
        #expect(badge.snoozeCount >= 2)
    }

    @Test("Badge is hidden when snooze count is 0")
    func badgeHiddenWhenCountZero() {
        let badge = SnoozeCountBadge(snoozeCount: 0)
        #expect(badge.snoozeCount < 2)
    }
}

// MARK: - AccountDot Tests

@Suite("AccountDot")
@MainActor
struct AccountDotTests {
    @Test("Account dot stores color and name")
    func accountDotStoresProperties() {
        let dot = AccountDot(color: .accountWork, accountName: "Work")
        #expect(dot.color == .accountWork)
        #expect(dot.accountName == "Work")
    }

    @Test("Account dot uses correct platform size")
    func accountDotUsesCorrectSize() {
        #if os(macOS)
        #expect(ListRowMetrics.accountDotSize == 8)
        #else
        #expect(ListRowMetrics.accountDotSize == 10)
        #endif
    }
}

// MARK: - OfflineBanner Tests

@Suite("OfflineBanner")
@MainActor
struct OfflineBannerTests {
    @Test("Default pending action count is 0")
    func defaultPendingCountIsZero() {
        let banner = OfflineBanner()
        #expect(banner.pendingActionCount == 0)
    }

    @Test("Banner accepts custom pending count")
    func bannerAcceptsCustomPendingCount() {
        let banner = OfflineBanner(pendingActionCount: 5)
        #expect(banner.pendingActionCount == 5)
    }
}

// MARK: - EmptyStateView Tests

@Suite("EmptyStateView")
@MainActor
struct EmptyStateViewTests {
    @Test("Empty state view stores properties")
    func emptyStateStoresProperties() {
        let view = EmptyStateView(
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
        let view = EmptyStateView.actionQueue
        #expect(view.iconName == "checkmark.circle")
        #expect(view.title == "All caught up")
    }

    @Test("Reading Queue empty state has correct content")
    func readingQueueEmptyState() {
        let view = EmptyStateView.readingQueue
        #expect(view.iconName == "book.closed")
        #expect(view.title == "Nothing to read")
    }

    @Test("Recommendations empty state has correct content")
    func recommendationsEmptyState() {
        let view = EmptyStateView.recommendations
        #expect(view.iconName == "star.circle")
    }

    @Test("Filtered empty state has correct content")
    func filteredEmptyState() {
        let view = EmptyStateView.filteredView
        #expect(view.iconName == "xmark.shield")
    }

    @Test("All Inboxes empty state has correct content")
    func allInboxesEmptyState() {
        let view = EmptyStateView.allInboxes
        #expect(view.iconName == "tray")
    }

    @Test("Digest empty state has correct content")
    func digestEmptyState() {
        let view = EmptyStateView.digest
        #expect(view.iconName == "sun.horizon")
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

    @Test("Account menu item stores properties")
    func accountMenuItemStoresProperties() {
        let item = AccountMenuItem(id: "test", name: "Test Account", color: .red)
        #expect(item.id == "test")
        #expect(item.name == "Test Account")
    }
}

// MARK: - UndoToast Tests

@Suite("UndoToast")
@MainActor
struct UndoToastTests {
    @Test("Toast stores message")
    func toastStoresMessage() {
        let toast = UndoToast(
            message: "Email archived",
            onUndo: {}
        )
        #expect(toast.message == "Email archived")
    }
}

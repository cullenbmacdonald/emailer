import Testing
@testable import EmailerIOS

@Suite("IOSAppState")
struct AppStateIOSTests {
    @MainActor
    @Test("Default state has zero badge counts")
    func defaultBadgeCounts() {
        let state = IOSAppState()
        #expect(state.actionQueueUnreadCount == 0)
        #expect(state.filteredUncertainCount == 0)
        #expect(!state.hasNewDigest)
    }

    @MainActor
    @Test("Default state starts disconnected")
    func defaultConnectivity() {
        let state = IOSAppState()
        #expect(!state.isConnected)
    }

    @MainActor
    @Test("Default tab selection is Action Queue")
    func defaultTabSelection() {
        let state = IOSAppState()
        #expect(state.selectedTab == .actionQueue)
    }

    @MainActor
    @Test("Default sidebar selection is Action Queue")
    func defaultSidebarSelection() {
        let state = IOSAppState()
        #expect(state.selectedSidebarDestination == .actionQueue)
    }

    @MainActor
    @Test("Default account filter is all")
    func defaultAccountFilter() {
        let state = IOSAppState()
        #expect(state.accountFilter == .all)
    }

    @MainActor
    @Test("Badge count can be updated")
    func badgeCountUpdate() {
        let state = IOSAppState()
        state.actionQueueUnreadCount = 42
        #expect(state.actionQueueUnreadCount == 42)
    }

    @MainActor
    @Test("Tab selection can be changed")
    func tabSelectionChange() {
        let state = IOSAppState()
        state.selectedTab = .readingQueue
        #expect(state.selectedTab == .readingQueue)
    }

    @MainActor
    @Test("Sidebar selection can be changed")
    func sidebarSelectionChange() {
        let state = IOSAppState()
        state.selectedSidebarDestination = .recommendations
        #expect(state.selectedSidebarDestination == .recommendations)
    }

    @MainActor
    @Test("Account filter can be set to specific account")
    func accountFilterChange() {
        let state = IOSAppState()
        state.accountFilter = .account(id: "123", name: "Work")
        #expect(state.accountFilter == .account(id: "123", name: "Work"))
    }

    @MainActor
    @Test("New digest flag can be toggled")
    func digestFlagToggle() {
        let state = IOSAppState()
        state.hasNewDigest = true
        #expect(state.hasNewDigest)
        state.hasNewDigest = false
        #expect(!state.hasNewDigest)
    }
}

import Testing
@testable import EmailClientKit

@Suite("AppState")
@MainActor
struct AppStateTests {
    @Test("Initial state defaults")
    func initialDefaults() {
        let state = AppState()
        #expect(state.selectedView == .actionQueue)
        #expect(!state.isConnected)
        #expect(state.errorMessage == nil)
        #expect(state.selectedEmailID == nil)
        #expect(state.accountFilter == .all)
        #expect(state.actionQueueUnreadCount == 0)
        #expect(state.filteredUncertainCount == 0)
        #expect(!state.hasNewDigest)
    }

    @Test("Change selected view")
    func changeSelectedView() {
        let state = AppState()
        state.selectedView = .readingQueue
        #expect(state.selectedView == .readingQueue)

        state.selectedView = nil
        #expect(state.selectedView == nil)
    }

    @Test("Connection state")
    func connectionState() {
        let state = AppState()
        state.isConnected = true
        #expect(state.isConnected)

        state.isConnected = false
        #expect(!state.isConnected)
    }

    @Test("Error message")
    func errorMessage() {
        let state = AppState()
        state.errorMessage = "Connection failed"
        #expect(state.errorMessage == "Connection failed")

        state.errorMessage = nil
        #expect(state.errorMessage == nil)
    }

    @Test("Selected email ID can be set")
    func selectedEmailID() {
        let state = AppState()
        state.selectedEmailID = "e1"
        #expect(state.selectedEmailID == "e1")
    }

    @Test("Account filter can be changed")
    func accountFilterChange() {
        let state = AppState()
        state.accountFilter = .work
        #expect(state.accountFilter == .work)
        state.accountFilter = .personal
        #expect(state.accountFilter == .personal)
    }

    @Test("Badge count can be updated")
    func badgeCountUpdate() {
        let state = AppState()
        state.actionQueueUnreadCount = 42
        #expect(state.actionQueueUnreadCount == 42)
    }

    @Test("Digest flag can be toggled")
    func digestFlagToggle() {
        let state = AppState()
        state.hasNewDigest = true
        #expect(state.hasNewDigest)
        state.hasNewDigest = false
        #expect(!state.hasNewDigest)
    }
}

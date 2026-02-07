import Testing
@testable import Emailer

@Suite("AppState")
@MainActor
struct AppStateTests {
    @Test("Initial state defaults")
    func initialDefaults() {
        let state = AppState()
        #expect(state.selectedView == .actionQueue)
        #expect(!state.isConnected)
        #expect(state.errorMessage == nil)
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
}

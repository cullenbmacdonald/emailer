import Testing
@testable import EmailerLib

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

    @Test("Selected view can be changed")
    func changeSelectedView() {
        let state = AppState()
        state.selectedView = .readingQueue
        #expect(state.selectedView == .readingQueue)

        state.selectedView = nil
        #expect(state.selectedView == nil)
    }

    @Test("Connection state can be toggled")
    func connectionState() {
        let state = AppState()
        state.isConnected = true
        #expect(state.isConnected)

        state.isConnected = false
        #expect(!state.isConnected)
    }

    @Test("Error message can be set and cleared")
    func errorMessage() {
        let state = AppState()
        state.errorMessage = "Connection failed"
        #expect(state.errorMessage == "Connection failed")

        state.errorMessage = nil
        #expect(state.errorMessage == nil)
    }
}

import Testing
@testable import EmailerIOS

@Suite("IOSAppCoordinator")
struct AppCoordinatorIOSTests {
    @MainActor
    @Test("Coordinator sets connected state on start")
    func startSetsConnected() async {
        let state = IOSAppState()
        let coordinator = IOSAppCoordinator(appState: state)
        #expect(!state.isConnected)
        await coordinator.start()
        #expect(state.isConnected)
    }

    @MainActor
    @Test("Coordinator holds reference to app state")
    func coordinatorHoldsState() {
        let state = IOSAppState()
        let coordinator = IOSAppCoordinator(appState: state)
        #expect(coordinator.appState === state)
    }
}

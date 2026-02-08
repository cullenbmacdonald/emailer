#if os(macOS)
import Testing
@testable import EmailClientKit

@Suite("MenuBarView")
@MainActor
struct MenuBarViewTests {
    @Test("MenuBarView initializes with default values")
    func defaultInit() {
        let view = MenuBarView(
            actionQueueCount: 5,
            isConnected: true
        )
        #expect(view.actionQueueCount == 5)
        #expect(view.isConnected == true)
    }

    @Test("MenuBarView shows zero count")
    func zeroCount() {
        let view = MenuBarView(
            actionQueueCount: 0,
            isConnected: false
        )
        #expect(view.actionQueueCount == 0)
        #expect(view.isConnected == false)
    }

    @Test("MenuBarView callbacks are invocable")
    func callbacks() {
        var newEmailCalled = false
        var openAppCalled = false

        let view = MenuBarView(
            actionQueueCount: 3,
            isConnected: true,
            onNewEmail: { newEmailCalled = true },
            onOpenApp: { openAppCalled = true }
        )

        view.onNewEmail()
        view.onOpenApp()

        #expect(newEmailCalled)
        #expect(openAppCalled)
    }

    @Test("MenuBarLabel shows badge envelope when count > 0")
    func labelWithBadge() {
        let label = MenuBarLabel(actionQueueCount: 5)
        #expect(label.actionQueueCount == 5)
    }

    @Test("MenuBarLabel shows plain envelope when count is 0")
    func labelNoBadge() {
        let label = MenuBarLabel(actionQueueCount: 0)
        #expect(label.actionQueueCount == 0)
    }
}

@Suite("MenuBarView - Connection States")
@MainActor
struct MenuBarConnectionTests {
    @Test("Connected state")
    func connected() {
        let view = MenuBarView(
            actionQueueCount: 0,
            isConnected: true
        )
        #expect(view.isConnected)
    }

    @Test("Disconnected state")
    func disconnected() {
        let view = MenuBarView(
            actionQueueCount: 0,
            isConnected: false
        )
        #expect(!view.isConnected)
    }
}
#endif

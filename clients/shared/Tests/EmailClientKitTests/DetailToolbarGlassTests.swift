import SwiftUI
import Testing
@testable import EmailClientKit

@Suite("DetailToolbar Glass Polish")
struct DetailToolbarGlassTests {
    @Test("DetailAction has all expected cases")
    func allActions() {
        let actions = DetailAction.allCases
        #expect(actions.count == 7)
        #expect(actions.contains(.reply))
        #expect(actions.contains(.replyAll))
        #expect(actions.contains(.forward))
        #expect(actions.contains(.archive))
        #expect(actions.contains(.snooze))
        #expect(actions.contains(.move))
        #expect(actions.contains(.trash))
    }

    @MainActor
    @Test("DetailToolbar calls onAction with correct action")
    func onActionCallback() {
        var receivedAction: DetailAction?
        let toolbar = DetailToolbar { action in
            receivedAction = action
        }
        toolbar.onAction(.archive)
        #expect(receivedAction == .archive)
    }

    @MainActor
    @Test("GlassToolbarGroup can be instantiated")
    func glassGroupCreation() {
        let _ = GlassToolbarGroup {
            EmptyView()
        }
    }
}

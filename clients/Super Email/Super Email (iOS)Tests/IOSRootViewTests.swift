import Testing
import EmailClientKit
@testable import EmailerIOS

@Suite("iOS Root Views")
@MainActor
struct IOSRootViewTests {
    @Test("IOSRootView can be initialized")
    func rootViewInit() {
        let view = IOSRootView()
        _ = view
    }

    @Test("MoreView can be initialized")
    func moreViewInit() {
        let view = MoreView()
        _ = view
    }

    @Test("IOSPlaceholderView displays correct title")
    func placeholderView() {
        let view = IOSPlaceholderView(title: "Test", icon: "star", phase: "Phase 2")
        #expect(view.title == "Test")
        #expect(view.icon == "star")
        #expect(view.phase == "Phase 2")
    }
}

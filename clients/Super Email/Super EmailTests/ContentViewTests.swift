import Testing
import EmailClientKit
@testable import Emailer

@Suite("ContentView")
@MainActor
struct ContentViewTests {
    @Test("ContentView can be initialized")
    func contentViewInit() {
        let view = ContentView()
        _ = view // Should not crash
    }

    @Test("PlaceholderListView shows destination info")
    func placeholderListView() {
        let view = PlaceholderListView(destination: .readingQueue)
        #expect(view.destination == .readingQueue)
        #expect(view.destination.title == "Reading Queue")
    }

    @Test("PlaceholderListView works for all destinations")
    func placeholderAllDestinations() {
        for destination in SidebarDestination.allCases {
            let view = PlaceholderListView(destination: destination)
            #expect(!view.destination.title.isEmpty)
        }
    }
}

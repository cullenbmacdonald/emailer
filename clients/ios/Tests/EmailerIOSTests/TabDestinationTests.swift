import Testing
@testable import EmailerIOSLib

@Suite("TabDestination")
struct TabDestinationTests {
    @Test("All four tabs are present")
    func tabCount() {
        #expect(TabDestination.allCases.count == 4)
    }

    @Test("Tab titles match expected values")
    func tabTitles() {
        #expect(TabDestination.actionQueue.title == "Action")
        #expect(TabDestination.readingQueue.title == "Reading")
        #expect(TabDestination.recommendations.title == "Recs")
        #expect(TabDestination.more.title == "More")
    }

    @Test("Tab icons are non-empty")
    func tabIcons() {
        for tab in TabDestination.allCases {
            #expect(!tab.iconName.isEmpty)
        }
    }

    @Test("Each tab has a unique id")
    func tabIds() {
        let ids = TabDestination.allCases.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test("Action queue icon is exclamationmark.circle")
    func actionQueueIcon() {
        #expect(TabDestination.actionQueue.iconName == "exclamationmark.circle")
    }

    @Test("Reading queue icon is book")
    func readingQueueIcon() {
        #expect(TabDestination.readingQueue.iconName == "book")
    }

    @Test("Recommendations icon is star")
    func recommendationsIcon() {
        #expect(TabDestination.recommendations.iconName == "star")
    }

    @Test("More icon is ellipsis.circle")
    func moreIcon() {
        #expect(TabDestination.more.iconName == "ellipsis.circle")
    }
}

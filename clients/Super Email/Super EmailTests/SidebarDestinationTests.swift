import Testing
@testable import Emailer

@Suite("SidebarDestination")
@MainActor
struct SidebarDestinationTests {
    @Test("All main views are present")
    func mainViewsCount() {
        let mainViews = SidebarDestination.mainViews
        #expect(mainViews.count == 5)
        #expect(mainViews.contains(.actionQueue))
        #expect(mainViews.contains(.readingQueue))
        #expect(mainViews.contains(.recommendations))
        #expect(mainViews.contains(.filtered))
        #expect(mainViews.contains(.allInboxes))
    }

    @Test("Daily Digest is below separator")
    func dailyDigestBelowSeparator() {
        #expect(SidebarDestination.dailyDigest.isBelowSeparator)
        for destination in SidebarDestination.mainViews {
            #expect(!destination.isBelowSeparator)
        }
    }

    @Test("Each destination has a title")
    func destinationTitles() {
        for destination in SidebarDestination.allCases {
            #expect(!destination.title.isEmpty)
        }
    }

    @Test("Each destination has an icon")
    func destinationIcons() {
        for destination in SidebarDestination.allCases {
            #expect(!destination.iconName.isEmpty)
        }
    }

    @Test("Each destination has a unique id")
    func destinationIds() {
        let ids = SidebarDestination.allCases.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test("Specific destination titles match expected values")
    func specificTitles() {
        #expect(SidebarDestination.actionQueue.title == "Action Queue")
        #expect(SidebarDestination.readingQueue.title == "Reading Queue")
        #expect(SidebarDestination.recommendations.title == "Recommendations")
        #expect(SidebarDestination.filtered.title == "Filtered")
        #expect(SidebarDestination.allInboxes.title == "All Inboxes")
        #expect(SidebarDestination.dailyDigest.title == "Daily Digest")
    }
}

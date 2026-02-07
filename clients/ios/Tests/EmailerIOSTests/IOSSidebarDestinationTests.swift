import Testing
@testable import EmailerIOSLib

@Suite("IOSSidebarDestination")
struct SidebarDestinationIOSTests {
    @Test("All six destinations are present")
    func destinationCount() {
        #expect(IOSSidebarDestination.allCases.count == 6)
    }

    @Test("Main views contain exactly 5 items")
    func mainViewsCount() {
        let mainViews = IOSSidebarDestination.mainViews
        #expect(mainViews.count == 5)
        #expect(mainViews.contains(.actionQueue))
        #expect(mainViews.contains(.readingQueue))
        #expect(mainViews.contains(.recommendations))
        #expect(mainViews.contains(.filtered))
        #expect(mainViews.contains(.allInboxes))
    }

    @Test("Daily Digest is below separator")
    func dailyDigestBelowSeparator() {
        #expect(IOSSidebarDestination.dailyDigest.isBelowSeparator)
        for destination in IOSSidebarDestination.mainViews {
            #expect(!destination.isBelowSeparator)
        }
    }

    @Test("Each destination has a title")
    func destinationTitles() {
        for destination in IOSSidebarDestination.allCases {
            #expect(!destination.title.isEmpty)
        }
    }

    @Test("Each destination has an icon")
    func destinationIcons() {
        for destination in IOSSidebarDestination.allCases {
            #expect(!destination.iconName.isEmpty)
        }
    }

    @Test("Each destination has a unique id")
    func destinationIds() {
        let ids = IOSSidebarDestination.allCases.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }

    @Test("Specific titles match macOS sidebar titles")
    func specificTitles() {
        #expect(IOSSidebarDestination.actionQueue.title == "Action Queue")
        #expect(IOSSidebarDestination.readingQueue.title == "Reading Queue")
        #expect(IOSSidebarDestination.recommendations.title == "Recommendations")
        #expect(IOSSidebarDestination.filtered.title == "Filtered")
        #expect(IOSSidebarDestination.allInboxes.title == "All Inboxes")
        #expect(IOSSidebarDestination.dailyDigest.title == "Daily Digest")
    }

    @Test("Icons use filled variants")
    func iconsAreFilledVariants() {
        #expect(IOSSidebarDestination.actionQueue.iconName.hasSuffix(".fill"))
        #expect(IOSSidebarDestination.readingQueue.iconName.hasSuffix(".fill"))
        #expect(IOSSidebarDestination.recommendations.iconName.hasSuffix(".fill"))
        #expect(IOSSidebarDestination.allInboxes.iconName.hasSuffix(".fill"))
        #expect(IOSSidebarDestination.dailyDigest.iconName.hasSuffix(".fill"))
    }
}

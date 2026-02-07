import SwiftUI

/// The root TabView for iPhone. Four tabs: Action, Reading, Recs, More.
public struct MainTabView: View {
    @State private var selectedTab: TabDestination = .actionQueue

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            Tab(TabDestination.actionQueue.title, systemImage: TabDestination.actionQueue.iconName,
                value: .actionQueue) {
                NavigationStack {
                    ActionQueuePlaceholder()
                }
            }

            Tab(TabDestination.readingQueue.title, systemImage: TabDestination.readingQueue.iconName,
                value: .readingQueue) {
                NavigationStack {
                    ReadingQueuePlaceholder()
                }
            }

            Tab(TabDestination.recommendations.title, systemImage: TabDestination.recommendations.iconName,
                value: .recommendations) {
                NavigationStack {
                    RecommendationsPlaceholder()
                }
            }

            Tab(TabDestination.more.title, systemImage: TabDestination.more.iconName,
                value: .more) {
                NavigationStack {
                    MoreView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}

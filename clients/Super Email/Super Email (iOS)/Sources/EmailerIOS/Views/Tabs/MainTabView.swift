import SwiftUI

/// The root TabView for iPhone. Four tabs: Action, Reading, Recs, More.
/// Action Queue tab shows a badge with unread count from AppState.
/// Reading Queue has NO badge (ADHD-friendly design).
public struct MainTabView: View {
    @Environment(IOSAppState.self) private var appState

    public init() {}

    public var body: some View {
        @Bindable var appState = appState
        TabView(selection: $appState.selectedTab) {
            Tab(
                TabDestination.actionQueue.title,
                systemImage: TabDestination.actionQueue.iconName,
                value: .actionQueue
            ) {
                NavigationStack {
                    ActionQueuePlaceholder()
                }
            }
            .badge(appState.actionQueueUnreadCount)

            Tab(
                TabDestination.readingQueue.title,
                systemImage: TabDestination.readingQueue.iconName,
                value: .readingQueue
            ) {
                NavigationStack {
                    ReadingQueuePlaceholder()
                }
            }
            // No badge — Reading Queue should not create urgency

            Tab(
                TabDestination.recommendations.title,
                systemImage: TabDestination.recommendations.iconName,
                value: .recommendations
            ) {
                NavigationStack {
                    RecommendationsPlaceholder()
                }
            }

            Tab(
                TabDestination.more.title,
                systemImage: TabDestination.more.iconName,
                value: .more
            ) {
                NavigationStack {
                    MoreView()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .environment(IOSAppState())
}

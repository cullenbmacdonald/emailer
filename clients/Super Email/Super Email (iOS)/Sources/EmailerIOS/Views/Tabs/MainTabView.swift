import SwiftUI
import EmailClientKit

#if os(iOS)
/// The root TabView for iPhone. Four tabs: Action, Reading, Recs, More.
/// Action Queue tab shows a badge with unread count from AppState.
/// Reading Queue has NO badge (ADHD-friendly design).
public struct MainTabView: View {
    @Environment(AppState.self) private var appState

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
                    ActionQueueView()
                        .navigationDestination(for: String.self) { emailID in
                            IOSEmailDetailView(emailID: emailID)
                        }
                }
            }
            .badge(appState.actionQueueUnreadCount)

            Tab(
                TabDestination.readingQueue.title,
                systemImage: TabDestination.readingQueue.iconName,
                value: .readingQueue
            ) {
                NavigationStack {
                    IOSPlaceholderView(title: "Reading Queue", icon: "book", phase: "Phase 2")
                }
            }
            // No badge -- Reading Queue should not create urgency

            Tab(
                TabDestination.recommendations.title,
                systemImage: TabDestination.recommendations.iconName,
                value: .recommendations
            ) {
                NavigationStack {
                    IOSPlaceholderView(title: "Recommendations", icon: "star", phase: "Phase 3")
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
#endif

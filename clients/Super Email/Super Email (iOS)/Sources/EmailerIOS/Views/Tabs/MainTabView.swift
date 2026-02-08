import SwiftUI
import EmailClientKit

#if os(iOS)
/// The root TabView for iPhone. Four tabs: Action, Reading, Recs, More.
/// Action Queue tab shows a badge with unread count from AppState.
/// Reading Queue has NO badge (ADHD-friendly design).
/// A newspaper toolbar button in each tab presents the Daily Digest as a sheet.
public struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore

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
                        .toolbar { digestToolbarItem }
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
                        .toolbar { digestToolbarItem }
                }
            }
            // No badge -- Reading Queue should not create urgency

            Tab(
                TabDestination.recommendations.title,
                systemImage: TabDestination.recommendations.iconName,
                value: .recommendations
            ) {
                NavigationStack {
                    IOSRecommendationListView()
                        .navigationDestination(for: String.self) { recID in
                            IOSRecommendationDetailView(recommendationID: recID)
                        }
                        .toolbar { digestToolbarItem }
                }
            }

            Tab(
                TabDestination.more.title,
                systemImage: TabDestination.more.iconName,
                value: .more
            ) {
                NavigationStack {
                    MoreView()
                        .toolbar { digestToolbarItem }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .safeAreaInset(edge: .top) {
            if appState.isOffline {
                OfflineBanner(pendingActionCount: appState.pendingActionCount)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.isOffline)
        .sheet(isPresented: $appState.showDigestSheet) {
            DigestSheetView()
                .environment(appState as AppState)
                .environment(digestStore as DigestStore)
        }
    }

    private var digestToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                appState.showDigestSheet = true
            } label: {
                Image(systemName: digestStore.hasNewDigest ? "newspaper.fill" : "newspaper")
            }
            .accessibilityLabel("Daily Digest")
        }
    }
}

/// Sheet wrapper for DigestView on iPhone.
/// Presented with .large detent. Marks digest as read on appear.
struct DigestSheetView: View {
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            DigestView()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        .onAppear {
            digestStore.markAsRead()
            appState.hasNewDigest = false
        }
    }
}
#endif

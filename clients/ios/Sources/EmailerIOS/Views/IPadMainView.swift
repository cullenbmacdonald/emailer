import SwiftUI

/// The root view for iPad, using a three-column NavigationSplitView.
/// Sidebar shows all 5 views + Digest (same as macOS).
struct IPadMainView: View {
    @Environment(IOSAppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            IOSSidebarView(
                selection: $appState.selectedSidebarDestination,
                actionQueueCount: appState.actionQueueUnreadCount,
                filteredCount: appState.filteredUncertainCount,
                hasNewDigest: appState.hasNewDigest
            )
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let destination = appState.selectedSidebarDestination {
            sidebarContent(for: destination)
        } else {
            ContentUnavailableView(
                "Select a View",
                systemImage: "sidebar.left",
                description: Text("Choose a view from the sidebar")
            )
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        ContentUnavailableView(
            "Select an Email",
            systemImage: "envelope.open",
            description: Text("Choose an email to read it")
        )
    }

    @ViewBuilder
    private func sidebarContent(for destination: IOSSidebarDestination) -> some View {
        switch destination {
        case .actionQueue:
            ActionQueuePlaceholder()
        case .readingQueue:
            ReadingQueuePlaceholder()
        case .recommendations:
            RecommendationsPlaceholder()
        case .filtered:
            FilteredPlaceholder()
        case .allInboxes:
            AllInboxesPlaceholder()
        case .dailyDigest:
            DailyDigestPlaceholder()
        }
    }
}

#Preview("iPad Layout") {
    IPadMainView()
        .environment(IOSAppState())
}

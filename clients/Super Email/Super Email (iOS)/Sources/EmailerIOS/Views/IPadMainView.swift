import SwiftUI
import EmailClientKit

/// The root view for iPad, using a three-column NavigationSplitView.
/// Sidebar shows all 5 views + Digest (same as macOS).
struct IPadMainView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore
    @Environment(DigestStore.self) private var digestStore

    var body: some View {
        @Bindable var appState = appState
        NavigationSplitView {
            SidebarView(
                selection: $appState.selectedView,
                actionQueueCount: emailStore.actionQueueCount,
                filteredCount: emailStore.filteredBorderlineCount,
                hasNewDigest: digestStore.hasNewDigest
            )
        } content: {
            contentColumn
        } detail: {
            detailColumn
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let destination = appState.selectedView {
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
    private func sidebarContent(for destination: SidebarDestination) -> some View {
        switch destination {
        case .actionQueue:
            ActionQueueView()
        case .readingQueue:
            IOSPlaceholderView(title: "Reading Queue", icon: "book", phase: "Phase 2")
        case .recommendations:
            IOSPlaceholderView(title: "Recommendations", icon: "star", phase: "Phase 3")
        case .filtered:
            IOSPlaceholderView(title: "Filtered", icon: "shield", phase: "Phase 3")
        case .allInboxes:
            IOSPlaceholderView(title: "All Inboxes", icon: "tray.2", phase: "Phase 3")
        case .dailyDigest:
            IOSPlaceholderView(title: "Daily Digest", icon: "newspaper", phase: "Phase 3")
        }
    }
}

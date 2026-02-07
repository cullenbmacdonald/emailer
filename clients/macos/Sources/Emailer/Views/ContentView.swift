import SwiftUI
import EmailClientKit

/// The root view of the macOS app.
///
/// Uses a three-column `NavigationSplitView` with:
/// - Sidebar: view selection (5 queues + digest)
/// - Content: email list / recommendations / digest
/// - Detail: email body / recommendation detail
public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore
    @Environment(DigestStore.self) private var digestStore

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        NavigationSplitView(
            columnVisibility: .constant(.all)
        ) {
            SidebarView(
                selection: $state.selectedView,
                actionQueueCount: emailStore.actionQueueCount,
                filteredCount: emailStore.filteredBorderlineCount,
                hasNewDigest: digestStore.hasNewDigest
            )
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        } content: {
            contentColumn
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
        } detail: {
            detailColumn
        }
    }

    @ViewBuilder
    private var contentColumn: some View {
        if let destination = appState.selectedView {
            PlaceholderListView(destination: destination)
        } else {
            Text("Select a view from the sidebar")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        DetailPlaceholderView()
    }
}

/// Placeholder for the content column until each view is implemented.
struct PlaceholderListView: View {
    let destination: SidebarDestination

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: destination.iconName)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("\(destination.title)")
                .font(.title2)
                .foregroundStyle(.primary)
            Text("Coming soon")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(destination.title)
    }
}

/// Placeholder for the detail column when no email is selected.
struct DetailPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select an email to read it.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

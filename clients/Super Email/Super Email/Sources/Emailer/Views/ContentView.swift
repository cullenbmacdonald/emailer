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
            switch destination {
            case .actionQueue:
                ActionQueueView()
            default:
                PlaceholderListView(destination: destination)
            }
        } else {
            Text("Select a view from the sidebar")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        EmailDetailView { action, detail in
            handleDetailAction(action, detail: detail)
        }
        .onChange(of: appState.selectedEmailID) { _, newID in
            if let id = newID {
                Task {
                    await emailStore.loadDetail(for: id, using: nil)
                }
            } else {
                emailStore.clearDetail()
            }
        }
    }

    private func handleDetailAction(_ action: DetailAction, detail: EmailDetail) {
        // Toolbar actions will be wired to stores in subsequent tasks (M-2.4, M-2.5, M-2.6)
        switch action {
        case .reply, .replyAll, .forward:
            break // Compose (M-2.6)
        case .archive:
            break // Archive with undo (M-2.4)
        case .snooze:
            break // Snooze picker (M-2.5)
        case .move:
            break // Reclassify
        case .trash:
            break // Delete
        }
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

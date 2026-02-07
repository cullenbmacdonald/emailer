import SwiftUI

/// The root view of the macOS app.
///
/// Uses a three-column `NavigationSplitView` with:
/// - Sidebar: view selection (5 queues + digest)
/// - Content: email list / recommendations / digest
/// - Detail: email body / recommendation detail
public struct ContentView: View {
    @State private var selectedDestination: SidebarDestination? = .actionQueue

    // Placeholder counts until stores are wired up
    @State private var actionQueueCount: Int = 0
    @State private var filteredCount: Int = 0
    @State private var hasNewDigest: Bool = false

    public init() {}

    public var body: some View {
        NavigationSplitView(
            columnVisibility: .constant(.all)
        ) {
            SidebarView(
                selection: $selectedDestination,
                actionQueueCount: actionQueueCount,
                filteredCount: filteredCount,
                hasNewDigest: hasNewDigest
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
        if let destination = selectedDestination {
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

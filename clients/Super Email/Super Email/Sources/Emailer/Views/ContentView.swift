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
    @Environment(FocusCoordinator.self) private var focusCoordinator

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        ZStack {
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
            #if os(macOS)
            .onKeyPress { keyPress in
                keyHandler.handleKeyPress(keyPress.key)
            }
            #endif

            // Overlays
            #if os(macOS)
            if focusCoordinator.isCommandPaletteVisible {
                overlayDimmer
                CommandPaletteView(commands: paletteCommands)
            }

            if focusCoordinator.isShortcutHelpVisible {
                overlayDimmer
                ShortcutHelpView()
            }
            #endif
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
                    await emailStore.loadDetail(for: id, using: appState.apiClient)
                }
            } else {
                emailStore.clearDetail()
            }
        }
    }

    private func handleDetailAction(_ action: DetailAction, detail: EmailDetail) {
        switch action {
        case .reply:
            handleReply()
        case .replyAll:
            handleReplyAll()
        case .forward:
            handleForward()
        case .archive:
            handleArchive()
        case .snooze:
            handleSnooze()
        case .move:
            handleMove()
        case .trash:
            handleTrash()
        }
    }

    // MARK: - Action Handlers (stubs wired to keyboard + toolbar)

    private func handleReply() {
        // Will open compose with reply context (M-2.6)
    }

    private func handleReplyAll() {
        // Will open compose with reply-all context (M-2.6)
    }

    private func handleForward() {
        // Will open compose with forward context (M-2.6)
    }

    private func handleArchive() {
        guard let emailID = appState.selectedEmailID else { return }
        Task {
            _ = try? await appState.apiClient?.updateEmail(id: emailID, isArchived: true)
        }
    }

    private func handleSnooze() {
        // Will open snooze picker (M-2.5)
    }

    private func handleMove() {
        // Will open reclassify picker
    }

    private func handleTrash() {
        guard let emailID = appState.selectedEmailID else { return }
        Task {
            try? await appState.apiClient?.deleteEmail(id: emailID)
        }
    }

    private func handleToggleRead() {
        guard let emailID = appState.selectedEmailID,
              let detail = emailStore.selectedDetail else { return }
        Task {
            _ = try? await appState.apiClient?.updateEmail(id: emailID, isRead: !detail.email.isRead)
        }
    }

    private func handleCompose() {
        NotificationCenter.default.post(name: .composeNewEmail, object: nil)
    }

    private func handleSearch() {
        focusCoordinator.activeFocus = .searchField
    }

    // MARK: - Keyboard (macOS)

    #if os(macOS)
    private var keyHandler: EmailListKeyHandler {
        EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator,
            onReply: handleReply,
            onReplyAll: handleReplyAll,
            onForward: handleForward,
            onArchive: handleArchive,
            onSnooze: handleSnooze,
            onMove: handleMove,
            onTrash: handleTrash,
            onToggleRead: handleToggleRead,
            onSearch: handleSearch,
            onCompose: handleCompose
        )
    }

    private var paletteCommands: [PaletteCommand] {
        PaletteCommandBuilder.buildCommands(
            appState: appState,
            focusCoordinator: focusCoordinator,
            onCompose: handleCompose,
            onReply: handleReply,
            onReplyAll: handleReplyAll,
            onForward: handleForward,
            onArchive: handleArchive,
            onSnooze: handleSnooze,
            onTrash: handleTrash,
            onToggleRead: handleToggleRead
        )
    }

    private var overlayDimmer: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .onTapGesture {
                focusCoordinator.dismissCommandPalette()
                focusCoordinator.dismissShortcutHelp()
            }
    }
    #endif
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

import SwiftUI
import EmailClientKit

/// The root view for iPad, using a three-column NavigationSplitView.
/// Sidebar shows all 5 views + Digest (same as macOS).
///
/// Layout behavior:
/// - Landscape: all three columns visible (sidebar + content + detail)
/// - Portrait: sidebar collapses, content + detail visible
/// - Standard SwiftUI column collapse/expand via swipe or button
/// - Supports Split View and Slide Over multitasking
struct IPadMainView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore
    @Environment(DigestStore.self) private var digestStore
    @State private var composeStore: ComposeStore?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        @Bindable var appState = appState
        VStack(spacing: 0) {
            if appState.isOffline {
                OfflineBanner(pendingActionCount: appState.pendingActionCount)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            NavigationSplitView(columnVisibility: $columnVisibility) {
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
        .animation(.easeInOut(duration: 0.3), value: appState.isOffline)
        .sheet(item: $composeStore) { store in
            ComposeView(
                store: store,
                accounts: appState.accounts,
                apiClient: appState.apiClient
            )
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
        case .archive:
            guard let emailID = appState.selectedEmailID else { return }
            Task {
                _ = try? await appState.apiClient?.updateEmail(id: emailID, isArchived: true)
            }
        case .trash:
            guard let emailID = appState.selectedEmailID else { return }
            Task {
                try? await appState.apiClient?.deleteEmail(id: emailID)
            }
        case .reply:
            let selfEmail = appState.accounts.first(where: { $0.id == detail.email.accountId })?.emailAddress
            composeStore = ComposeStore(mode: .reply(detail), selfEmail: selfEmail, defaultAccountID: appState.accounts.first?.id)
        case .replyAll:
            let selfEmail = appState.accounts.first(where: { $0.id == detail.email.accountId })?.emailAddress
            composeStore = ComposeStore(mode: .replyAll(detail), selfEmail: selfEmail, defaultAccountID: appState.accounts.first?.id)
        case .forward:
            composeStore = ComposeStore(mode: .forward(detail), defaultAccountID: appState.accounts.first?.id)
        case .snooze, .move:
            break
        }
    }

    @ViewBuilder
    private func sidebarContent(for destination: SidebarDestination) -> some View {
        switch destination {
        case .actionQueue:
            ActionQueueView()
        case .readingQueue:
            ReadingQueueView()
                .navigationDestination(for: String.self) { emailID in
                    IOSEmailDetailView(emailID: emailID)
                }
        case .recommendations:
            IOSRecommendationListView()
                .navigationDestination(for: String.self) { recID in
                    IOSRecommendationDetailView(recommendationID: recID)
                }
        case .filtered:
            FilteredView()
                .navigationDestination(for: String.self) { emailID in
                    IOSFilteredDetailView(emailID: emailID)
                }
        case .allInboxes:
            AllInboxesView()
                .navigationDestination(for: String.self) { emailID in
                    IOSEmailDetailView(emailID: emailID)
                }
        case .dailyDigest:
            DigestView()
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .onAppear {
                    digestStore.markAsRead()
                    appState.hasNewDigest = false
                }
        }
    }
}

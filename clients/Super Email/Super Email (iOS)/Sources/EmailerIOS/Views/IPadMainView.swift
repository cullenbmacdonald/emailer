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
        VStack(spacing: 0) {
            if appState.isOffline {
                OfflineBanner(pendingActionCount: appState.pendingActionCount)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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
        .animation(.easeInOut(duration: 0.3), value: appState.isOffline)
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
        case .reply, .replyAll, .forward, .snooze, .move:
            // Will be wired in later tasks
            break
        }
    }

    @ViewBuilder
    private func sidebarContent(for destination: SidebarDestination) -> some View {
        switch destination {
        case .actionQueue:
            ActionQueueView()
        case .readingQueue:
            IOSPlaceholderView(title: "Reading Queue", icon: "book", phase: "Phase 2")
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
                .onAppear {
                    digestStore.markAsRead()
                    appState.hasNewDigest = false
                }
        }
    }
}

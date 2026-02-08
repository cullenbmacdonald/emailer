import SwiftUI
import EmailClientKit

#if os(iOS)
/// The Recommendations list view for iPhone.
/// Shows type/status filters at top, cards in a LazyVGrid, with swipe actions and context menus.
struct IOSRecommendationListView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecommendationStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            // Filter bar
            RecommendationFilterBar(
                typeFilter: $store.typeFilter,
                statusFilter: $store.statusFilter,
                newCount: store.newCount
            )

            Divider()

            // Content
            if store.isLoading && store.recommendations.isEmpty {
                loadingState
            } else if store.filteredRecommendations.isEmpty {
                emptyState
            } else {
                cardGrid
            }
        }
        .navigationTitle("Recommendations")
        .task {
            await store.loadRecommendations(using: appState.apiClient)
        }
        .refreshable {
            await store.loadRecommendations(using: appState.apiClient)
        }
        .onChange(of: store.typeFilter) {
            Task { await store.loadRecommendations(using: appState.apiClient) }
        }
        .onChange(of: store.statusFilter) {
            Task { await store.loadRecommendations(using: appState.apiClient) }
        }
        .overlay(alignment: .bottom) {
            if let undo = store.undoState {
                UndoToast(message: undo.message) {
                    Task { await store.undoLastStatusChange(using: appState.apiClient) }
                } onDismiss: {
                    store.clearUndo()
                }
                .padding(.bottom, Spacing.lg)
            }
        }
    }

    // MARK: - Card Grid

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 300), spacing: Spacing.sm)],
                spacing: Spacing.sm
            ) {
                ForEach(store.filteredRecommendations) { rec in
                    NavigationLink(destination: IOSRecommendationDetailView(recommendationID: rec.id)) {
                        RecommendationCard(recommendation: rec)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        contextMenuItems(for: rec)
                    }
                    .swipeActions(edge: .leading) {
                        Button {
                            saveAction(rec)
                        } label: {
                            Label("Save", systemImage: "bookmark.fill")
                        }
                        .tint(Color.accentColor)
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            dismissAction(rec)
                        } label: {
                            Label("Dismiss", systemImage: "xmark")
                        }
                        .tint(Color.filteredColor)

                        Button {
                            doneAction(rec)
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .tint(Color.success)
                    }
                    .onAppear {
                        if rec.id == store.filteredRecommendations.last?.id {
                            Task { await store.loadMore(using: appState.apiClient) }
                        }
                    }
                }
            }
            .padding(Spacing.sm)
        }
        .animation(.default, value: store.filteredRecommendations.map(\.id))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuItems(for rec: Recommendation) -> some View {
        Button {
            saveAction(rec)
        } label: {
            Label("Save", systemImage: "bookmark.fill")
        }

        Button {
            doneAction(rec)
        } label: {
            Label("Mark as Done", systemImage: "checkmark.circle.fill")
        }

        Button(role: .destructive) {
            dismissAction(rec)
        } label: {
            Label("Dismiss", systemImage: "xmark")
        }

        if rec.sourceEmailId != nil {
            Button {
                appState.selectedView = .readingQueue
            } label: {
                Label("Open Source Newsletter", systemImage: "newspaper.fill")
            }
        }

        ShareLink(item: rec.title) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading recommendations...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.typeFilter != nil || store.statusFilter != .new {
            EmptyStateView(
                iconName: "line.3.horizontal.decrease.circle",
                title: "No matching recommendations",
                subtitle: "Try a different filter or check back after reading more newsletters"
            )
        } else {
            EmptyStateView.recommendations
        }
    }

    // MARK: - Actions

    private func saveAction(_ rec: Recommendation) {
        Task {
            await store.updateStatus(id: rec.id, to: .saved, using: appState.apiClient)
        }
    }

    private func doneAction(_ rec: Recommendation) {
        Task {
            await store.updateStatus(id: rec.id, to: .done, using: appState.apiClient)
        }
    }

    private func dismissAction(_ rec: Recommendation) {
        Task {
            await store.updateStatus(id: rec.id, to: .dismissed, using: appState.apiClient)
        }
    }
}
#endif

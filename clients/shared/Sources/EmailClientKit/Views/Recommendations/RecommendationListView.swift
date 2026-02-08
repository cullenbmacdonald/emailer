import SwiftUI

/// The content column for the Recommendations view.
/// Shows type/status filters and a scrollable list of recommendation cards.
public struct RecommendationListView: View {
    @Environment(AppState.self) private var appState
    @Environment(RecommendationStore.self) private var store

    public init() {}

    public var body: some View {
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
                cardList
            }
        }
        .frame(minWidth: 280, idealWidth: 340, maxWidth: 420)
        .task {
            await store.loadRecommendations(using: appState.apiClient)
        }
        .onChange(of: store.typeFilter) {
            Task { await store.loadRecommendations(using: appState.apiClient) }
        }
        .onChange(of: store.statusFilter) {
            Task { await store.loadRecommendations(using: appState.apiClient) }
        }
        #if os(macOS)
        .onKeyPress(keys: [
            .init("j"), .init("k"), .init("s"), .init("d"), .init("x"),
            .init("1"), .init("2"), .init("3"), .init("4"), .init("5"), .init("6"), .init("7")
        ]) { press in
            handleKeyPress(press)
        }
        #endif
    }

    // MARK: - Card List

    private var cardList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(store.filteredRecommendations) { rec in
                    RecommendationCard(
                        recommendation: rec,
                        isSelected: store.selectedRecommendationID == rec.id,
                        onSave: { saveAction(rec) },
                        onDone: { doneAction(rec) },
                        onDismiss: { dismissAction(rec) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectRecommendation(rec)
                    }
                    #if os(iOS)
                    .swipeActions(edge: .trailing) {
                        Button { dismissAction(rec) } label: {
                            Label("Dismiss", systemImage: "xmark")
                        }
                        .tint(Color.filteredColor)

                        Button { doneAction(rec) } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .tint(Color.success)
                    }
                    .swipeActions(edge: .leading) {
                        Button { saveAction(rec) } label: {
                            Label("Save", systemImage: "bookmark.fill")
                        }
                        .tint(Color.accentColor)
                    }
                    #endif
                    .onAppear {
                        // Load more when nearing end
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

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading recommendations...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.typeFilter != nil || store.statusFilter != .new {
            // Filtered empty state
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

    private func selectRecommendation(_ rec: Recommendation) {
        store.selectedRecommendationID = rec.id
        Task {
            await store.loadDetail(for: rec.id, using: appState.apiClient)
        }
    }

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

    // MARK: - Keyboard (macOS)

    #if os(macOS)
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        let filtered = store.filteredRecommendations
        guard !filtered.isEmpty else { return .ignored }

        switch press.characters {
        case "j":
            navigateDown(in: filtered)
            return .handled
        case "k":
            navigateUp(in: filtered)
            return .handled
        case "s":
            if let id = store.selectedRecommendationID {
                Task { await store.updateStatus(id: id, to: .saved, using: appState.apiClient) }
                return .handled
            }
        case "d":
            if let id = store.selectedRecommendationID {
                Task { await store.updateStatus(id: id, to: .done, using: appState.apiClient) }
                return .handled
            }
        case "x":
            if let id = store.selectedRecommendationID {
                Task { await store.updateStatus(id: id, to: .dismissed, using: appState.apiClient) }
                return .handled
            }
        case "1": store.typeFilter = nil; return .handled
        case "2": store.typeFilter = .book; return .handled
        case "3": store.typeFilter = .movie; return .handled
        case "4": store.typeFilter = .music; return .handled
        case "5": store.typeFilter = .article; return .handled
        case "6": store.typeFilter = .podcast; return .handled
        case "7": store.typeFilter = .other; return .handled
        default:
            break
        }
        return .ignored
    }

    private func navigateDown(in list: [Recommendation]) {
        guard let currentID = store.selectedRecommendationID,
              let currentIndex = list.firstIndex(where: { $0.id == currentID }),
              currentIndex + 1 < list.count else {
            // Select first if none selected
            if store.selectedRecommendationID == nil, let first = list.first {
                selectRecommendation(first)
            }
            return
        }
        selectRecommendation(list[currentIndex + 1])
    }

    private func navigateUp(in list: [Recommendation]) {
        guard let currentID = store.selectedRecommendationID,
              let currentIndex = list.firstIndex(where: { $0.id == currentID }),
              currentIndex > 0 else { return }
        selectRecommendation(list[currentIndex - 1])
    }
    #endif
}

#Preview("RecommendationListView") {
    let appState = AppState()
    let store = RecommendationStore()

    RecommendationListView()
        .environment(appState)
        .environment(store)
        .frame(width: 360, height: 600)
}

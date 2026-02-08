import SwiftUI
import EmailClientKit

#if os(iOS)
/// Detail view for a recommendation, pushed via NavigationStack on iPhone.
/// Shows full context, duplicate sources, and action buttons at the bottom.
struct IOSRecommendationDetailView: View {
    let recommendationID: String

    @Environment(AppState.self) private var appState
    @Environment(RecommendationStore.self) private var store

    var body: some View {
        Group {
            if let detail = store.selectedDetail,
               detail.recommendation.id == recommendationID {
                detailContent(detail)
            } else {
                ProgressView("Loading recommendation...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            await store.loadDetail(for: recommendationID, using: appState.apiClient)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let detail = store.selectedDetail,
                   detail.recommendation.id == recommendationID {
                    toolbarActions(detail.recommendation)
                }
            }
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

    // MARK: - Detail Content

    private func detailContent(_ detail: RecommendationDetail) -> some View {
        let rec = detail.recommendation

        return ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                headerSection(rec)

                Divider()

                contextSection(detail)

                Divider()

                sourceSection(rec)

                if !detail.duplicateSources.isEmpty {
                    Divider()
                    duplicateSourcesSection(detail.duplicateSources)
                }

                Divider()

                bottomActions(rec)
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Header

    private func headerSection(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: rec.type.iconName)
                .font(.system(size: 40))
                .foregroundStyle(rec.type.color)

            Text(rec.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if let creator = rec.creator {
                Text("by \(creator)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: Spacing.md) {
                TypeBadge(type: rec.type)

                Text("Status: \(rec.status.rawValue.capitalized)")
                    .font(.caption)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        Capsule().fill(statusColor(rec.status).opacity(0.15))
                    )
                    .foregroundStyle(statusColor(rec.status))
            }
        }
    }

    // MARK: - Context

    private func contextSection(_ detail: RecommendationDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Context")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)

            Text("\"\(detail.fullContext ?? detail.recommendation.contextSnippet)\"")
                .font(.body)
                .italic()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Source

    private func sourceSection(_ rec: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Source: \(rec.sourceNewsletterName)")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Text(formattedFullDate(rec.sourceDate))
                .font(.caption)
                .foregroundStyle(.tertiary)

            if let sourceID = rec.sourceEmailId {
                Button("Open source newsletter") {
                    appState.selectedView = .allInboxes
                    appState.selectedEmailID = sourceID
                }
                .font(.caption)
                .foregroundColor(.accentColor)
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Duplicate Sources

    private func duplicateSourcesSection(_ sources: [DuplicateSource]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("ALSO RECOMMENDED BY:")
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.tertiary)

            ForEach(Array(sources.prefix(3).enumerated()), id: \.offset) { _, source in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text(source.newsletterName)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("-- \(formattedFullDate(source.date))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if !source.contextSnippet.isEmpty {
                        Text("\"\(source.contextSnippet)\"")
                            .font(.callout)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Spacing.xs)

                if source.newsletterName != sources.prefix(3).last?.newsletterName {
                    Divider()
                }
            }

            if sources.count > 3 {
                Text("Show \(sources.count - 3) more")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
        }
    }

    // MARK: - Bottom Actions

    private func bottomActions(_ rec: Recommendation) -> some View {
        HStack(spacing: Spacing.lg) {
            actionButton("Save", icon: "bookmark.fill", color: .accentColor) {
                Task { await store.updateStatus(id: rec.id, to: .saved, using: appState.apiClient) }
            }

            actionButton("Done", icon: "checkmark.circle.fill", color: .success) {
                Task { await store.updateStatus(id: rec.id, to: .done, using: appState.apiClient) }
            }

            actionButton("Dismiss", icon: "xmark.circle.fill", color: .filteredColor) {
                Task { await store.updateStatus(id: rec.id, to: .dismissed, using: appState.apiClient) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func actionButton(_ label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) recommendation")
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func toolbarActions(_ rec: Recommendation) -> some View {
        Menu {
            Button {
                Task { await store.updateStatus(id: rec.id, to: .saved, using: appState.apiClient) }
            } label: {
                Label("Save", systemImage: "bookmark.fill")
            }

            Button {
                Task { await store.updateStatus(id: rec.id, to: .done, using: appState.apiClient) }
            } label: {
                Label("Done", systemImage: "checkmark.circle.fill")
            }

            Button(role: .destructive) {
                Task { await store.updateStatus(id: rec.id, to: .dismissed, using: appState.apiClient) }
            } label: {
                Label("Dismiss", systemImage: "xmark.circle.fill")
            }

            if let sourceID = rec.sourceEmailId {
                Divider()
                Button {
                    appState.selectedView = .allInboxes
                    appState.selectedEmailID = sourceID
                } label: {
                    Label("Open Source", systemImage: "newspaper.fill")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Helpers

    private func formattedFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }

    private func statusColor(_ status: RecommendationStatus) -> Color {
        switch status {
        case .new: .accentColor
        case .saved: .accentColor
        case .done: .success
        case .dismissed: .filteredColor
        }
    }
}
#endif

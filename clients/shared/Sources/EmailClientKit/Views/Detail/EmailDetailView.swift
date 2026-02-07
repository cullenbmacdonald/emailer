import SwiftUI

/// The email detail view showing header, body (WKWebView), and toolbar.
/// Used by Action Queue, Filtered, and All Inboxes.
public struct EmailDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    /// Optional callback when a toolbar action is performed.
    public var onAction: ((DetailAction, EmailDetail) -> Void)?

    public init(onAction: ((DetailAction, EmailDetail) -> Void)? = nil) {
        self.onAction = onAction
    }

    public var body: some View {
        Group {
            if let detail = emailStore.selectedDetail {
                detailContent(detail)
            } else if appState.selectedEmailID != nil {
                loadingState
            } else {
                emptyState
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ detail: EmailDetail) -> some View {
        VStack(spacing: 0) {
            // Header
            EmailHeaderView(detail: detail)

            Divider()

            // Email body
            EmailWebView(
                htmlBody: detail.htmlBody,
                textBody: detail.textBody
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                DetailToolbar { action in
                    onAction?(action, detail)
                }
            }
        }
        .task(id: detail.id) {
            await markAsRead(detail)
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading email...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            iconName: "envelope.open",
            title: "Select an email",
            subtitle: "Select an email to read it."
        )
    }

    // MARK: - Mark as Read

    private func markAsRead(_ detail: EmailDetail) async {
        guard !detail.email.isRead else { return }
        // Find the coordinator's API client from the environment indirectly
        // via the email store's loadDetail mechanism. We call updateEmail directly.
        // For now, we rely on the parent wiring this up.
    }
}

import SwiftUI
import EmailClientKit

#if os(iOS)
/// iOS wrapper for the shared EmailDetailView.
/// Pushed via NavigationStack when tapping an email row.
/// Loads the email detail on appear and handles toolbar actions.
struct IOSEmailDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore
    @Environment(\.dismiss) private var dismiss

    @State private var actionHandler = EmailActionHandler()

    /// The email ID to display. Passed via NavigationLink(value:).
    let emailID: String

    var body: some View {
        Group {
            if let detail = emailStore.selectedDetail, detail.id == emailID {
                detailContent(detail)
            } else {
                ProgressView("Loading email...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task {
            appState.selectedEmailID = emailID
            await emailStore.loadDetail(for: emailID, using: appState.apiClient)
        }
        .onDisappear {
            // Clear selection when navigating back
            if appState.selectedEmailID == emailID {
                appState.selectedEmailID = nil
                emailStore.clearDetail()
            }
        }
        .overlay(alignment: .bottom) {
            if let toast = actionHandler.undoToast {
                UndoToast(message: toast.message) {
                    toast.undoAction()
                    actionHandler.dismissUndoToast()
                } onDismiss: {
                    actionHandler.dismissUndoToast()
                }
            }
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ detail: EmailDetail) -> some View {
        VStack(spacing: 0) {
            EmailHeaderView(detail: detail)

            Divider()

            EmailWebView(
                htmlBody: detail.htmlBody,
                textBody: detail.textBody
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                replyMenu(detail)
                archiveButton(detail)
                snoozeButton(detail)
                moreMenu(detail)
            }
        }
    }

    // MARK: - Toolbar Items

    @ViewBuilder
    private func replyMenu(_ detail: EmailDetail) -> some View {
        Menu {
            Button {
                // Reply -- will be wired in compose task
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }

            Button {
                // Reply All -- will be wired in compose task
            } label: {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }

            Button {
                // Forward -- will be wired in compose task
            } label: {
                Label("Forward", systemImage: "arrowshape.turn.up.right")
            }
        } label: {
            Label("Reply", systemImage: "arrowshape.turn.up.left")
        }
    }

    @ViewBuilder
    private func archiveButton(_ detail: EmailDetail) -> some View {
        Button {
            actionHandler.archive(
                emailID: detail.id,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
            // Pop back to list after archive
            dismiss()
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
    }

    @ViewBuilder
    private func snoozeButton(_ detail: EmailDetail) -> some View {
        Button {
            // Will present snooze picker sheet (I-2.4)
        } label: {
            Label("Snooze", systemImage: "clock")
        }
    }

    @ViewBuilder
    private func moreMenu(_ detail: EmailDetail) -> some View {
        Menu {
            Button {
                // Move -- will be wired with reclassify
            } label: {
                Label("Move to...", systemImage: "folder")
            }

            Button(role: .destructive) {
                actionHandler.trash(
                    emailID: detail.id,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
                dismiss()
            } label: {
                Label("Trash", systemImage: "trash")
            }

            Divider()

            Button {
                actionHandler.toggleRead(
                    emailID: detail.id,
                    isCurrentlyRead: detail.email.isRead,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
            } label: {
                Label(
                    detail.email.isRead ? "Mark Unread" : "Mark Read",
                    systemImage: detail.email.isRead ? "envelope.badge" : "envelope.open"
                )
            }
        } label: {
            Label("More", systemImage: "ellipsis.circle")
        }
    }
}
#endif

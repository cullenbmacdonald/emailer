import SwiftUI
import EmailClientKit

#if os(iOS)
/// iOS detail view for filtered emails.
/// Pushed via NavigationStack when tapping a filtered email row.
/// Shows email content, classification info, and rescue/confirm actions.
struct IOSFilteredDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore
    @Environment(\.dismiss) private var dismiss

    @State private var actionHandler = FilteredActionHandler()
    @State private var showRescueSheet = false

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
        .confirmationDialog(
            "This email is not spam.\nWhere should it go?",
            isPresented: $showRescueSheet,
            titleVisibility: .visible
        ) {
            ForEach(RescueDestination.allCases, id: \.self) { destination in
                Button("Move to \(destination.label)") {
                    actionHandler.rescue(
                        emailID: emailID,
                        to: destination,
                        emailStore: emailStore,
                        apiClient: appState.apiClient
                    )
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(_ detail: EmailDetail) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    EmailHeaderView(detail: detail)

                    // Classification info section
                    classificationSection(detail)

                    Divider()

                    EmailWebView(
                        htmlBody: detail.htmlBody,
                        textBody: detail.textBody
                    )
                    .frame(minHeight: 300)
                }
            }

            Divider()

            // Bottom action bar
            bottomActionBar(detail)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showRescueSheet = true
                } label: {
                    Label("Not Spam", systemImage: "arrow.uturn.left")
                }

                Button {
                    actionHandler.confirmSpam(
                        emailID: detail.id,
                        emailStore: emailStore,
                        apiClient: appState.apiClient
                    )
                    dismiss()
                } label: {
                    Label("Confirm Spam", systemImage: "xmark.shield.fill")
                }
            }
        }
        .task(id: detail.id) {
            await markAsRead(detail)
        }
    }

    // MARK: - Classification Info

    private func classificationSection(_ detail: EmailDetail) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Text("Classification:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("Filtered (Spam/Marketing)")
                    .font(.callout)
                    .foregroundStyle(Color.filteredColor)
            }

            HStack(spacing: Spacing.sm) {
                Text("Confidence:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text("\(Int(detail.email.classification.confidence * 100))%")
                    .font(.callout)
                    .foregroundStyle(confidenceColor(detail.email.classification.confidence))
                if detail.email.classification.confidence < 0.80 {
                    Text("(borderline)")
                        .font(.callout)
                        .foregroundStyle(Color.snooze)
                }
            }

            if let reason = detail.email.classification.reason {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Text("Reason:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("\"\(reason)\"")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.filteredColor.opacity(0.05))
    }

    // MARK: - Bottom Action Bar

    private func bottomActionBar(_ detail: EmailDetail) -> some View {
        HStack(spacing: Spacing.lg) {
            Button {
                showRescueSheet = true
            } label: {
                Label("Not Spam", systemImage: "arrow.uturn.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                actionHandler.confirmSpam(
                    emailID: detail.id,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
                dismiss()
            } label: {
                Label("Confirm Spam", systemImage: "xmark.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.filteredColor)
        }
        .padding(Spacing.lg)
    }

    // MARK: - Helpers

    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence < 0.70 {
            return .destructive
        } else if confidence < 0.80 {
            return .snooze
        } else if confidence < 0.90 {
            return .filteredColor
        } else {
            return .success
        }
    }

    private func markAsRead(_ detail: EmailDetail) async {
        guard !detail.email.isRead else { return }
        _ = try? await appState.apiClient?.updateEmail(id: detail.id, isRead: true)
        emailStore.updateReadState(id: detail.id, isRead: true)
    }
}
#endif

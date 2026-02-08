import SwiftUI

/// Detail view for filtered emails showing classification info and rescue actions.
public struct FilteredDetailView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    @State private var showRescuePicker = false
    @State private var actionHandler = FilteredActionHandler()

    public init() {}

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
            // Header
            EmailHeaderView(detail: detail)

            // Classification info section
            classificationSection(detail)

            Divider()

            // Email body
            EmailWebView(
                htmlBody: detail.htmlBody,
                textBody: detail.textBody
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Rescue actions
            rescueActionsSection(detail)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                filteredToolbar(detail)
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

    // MARK: - Rescue Actions

    private func rescueActionsSection(_ detail: EmailDetail) -> some View {
        VStack(spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Button {
                    rescue(detail: detail, to: .actionQueue)
                } label: {
                    Label("Not Spam -- Move to Action Queue", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("1", modifiers: [])

                Button {
                    rescue(detail: detail, to: .readingQueue)
                } label: {
                    Label("Not Spam -- Move to Reading Queue", systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("2", modifiers: [])

                Button {
                    rescue(detail: detail, to: .allInboxes)
                } label: {
                    Label("Not Spam -- Move to All Inboxes", systemImage: "tray")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("3", modifiers: [])
            }

            HStack(spacing: Spacing.sm) {
                Button {
                    confirmSpam(detail: detail)
                } label: {
                    Label("This IS Spam", systemImage: "xmark.shield")
                        .frame(maxWidth: .infinity)
                }
                .keyboardShortcut("c", modifiers: [])

                Button(role: .destructive) {
                    deleteNow(detail: detail)
                } label: {
                    Label("Delete Now", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(Spacing.lg)
    }

    // MARK: - Toolbar

    @ViewBuilder
    private func filteredToolbar(_ detail: EmailDetail) -> some View {
        Button {
            showRescuePicker = true
        } label: {
            Label("Not Spam", systemImage: "arrow.uturn.left")
        }
        .help("Not Spam (N)")
        .popover(isPresented: $showRescuePicker) {
            RescuePicker { destination in
                showRescuePicker = false
                rescue(detail: detail, to: destination)
            }
        }

        Button {
            confirmSpam(detail: detail)
        } label: {
            Label("Confirm Spam", systemImage: "xmark.shield.fill")
        }
        .help("Confirm Spam (C)")
    }

    // MARK: - Actions

    private func rescue(detail: EmailDetail, to destination: RescueDestination) {
        actionHandler.rescue(
            emailID: detail.id,
            to: destination,
            emailStore: emailStore,
            apiClient: appState.apiClient
        )
        appState.selectedEmailID = nil
    }

    private func confirmSpam(detail: EmailDetail) {
        actionHandler.confirmSpam(
            emailID: detail.id,
            emailStore: emailStore,
            apiClient: appState.apiClient
        )
        appState.selectedEmailID = nil
    }

    private func deleteNow(detail: EmailDetail) {
        actionHandler.deleteNow(
            emailID: detail.id,
            emailStore: emailStore,
            apiClient: appState.apiClient
        )
        appState.selectedEmailID = nil
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

// MARK: - Filtered Action Handler

/// Handles filtered-specific actions (rescue, confirm spam, delete) with optimistic updates.
@Observable
@MainActor
public final class FilteredActionHandler {
    public private(set) var undoToast: UndoToastInfo?

    public init() {}

    /// Rescue an email from filtered to a destination queue.
    public func rescue(
        emailID: String,
        to destination: RescueDestination,
        emailStore: EmailStore,
        apiClient: APIClient?
    ) {
        let removedEmail = emailStore.removeFromFiltered(id: emailID)

        undoToast = UndoToastInfo(
            message: "Moved to \(destination.label)",
            undoAction: { [weak emailStore] in
                if let email = removedEmail {
                    emailStore?.restoreToFiltered(email)
                }
            }
        )

        Task {
            do {
                _ = try await apiClient?.reclassifyEmail(
                    id: emailID,
                    classification: destination.targetClassification
                )
            } catch {
                if let email = removedEmail {
                    emailStore.restoreToFiltered(email)
                }
            }
        }
    }

    /// Confirm an email as spam (training signal).
    public func confirmSpam(
        emailID: String,
        emailStore: EmailStore,
        apiClient: APIClient?
    ) {
        let removedEmail = emailStore.removeFromFiltered(id: emailID)

        undoToast = UndoToastInfo(
            message: "Confirmed as spam",
            undoAction: { [weak emailStore] in
                if let email = removedEmail {
                    emailStore?.restoreToFiltered(email)
                }
            }
        )

        Task {
            do {
                _ = try await apiClient?.reclassifyEmail(
                    id: emailID,
                    classification: .filtered,
                    confirm: true
                )
            } catch {
                if let email = removedEmail {
                    emailStore.restoreToFiltered(email)
                }
            }
        }
    }

    /// Permanently delete a filtered email.
    public func deleteNow(
        emailID: String,
        emailStore: EmailStore,
        apiClient: APIClient?
    ) {
        let removedEmail = emailStore.removeFromFiltered(id: emailID)

        undoToast = UndoToastInfo(
            message: "Email deleted",
            undoAction: { [weak emailStore] in
                if let email = removedEmail {
                    emailStore?.restoreToFiltered(email)
                }
            }
        )

        Task {
            do {
                try await apiClient?.deleteEmail(id: emailID)
            } catch {
                if let email = removedEmail {
                    emailStore.restoreToFiltered(email)
                }
            }
        }
    }

    public func dismissUndoToast() {
        undoToast = nil
    }
}

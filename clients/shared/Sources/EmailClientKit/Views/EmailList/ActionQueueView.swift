import SwiftUI

/// The Action Queue content column: emails needing a response.
///
/// Shows two sections when snoozed returns exist (RETURNING + NEW),
/// or a flat list when there are none. Account filter at top.
/// On iOS, adds swipe actions, context menu, pull-to-refresh, and NavigationLink.
public struct ActionQueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    #if os(iOS)
    @State private var actionHandler = EmailActionHandler()
    #endif

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        Group {
            if emailStore.isLoading && emailStore.actionQueue.isEmpty {
                loadingState
            } else if filteredEmails.isEmpty {
                emptyState
            } else {
                emailList
            }
        }
        .navigationTitle("Action Queue")
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                AccountFilterControl(selection: $state.accountFilter)
                    .frame(width: 200)
            }
        }
        #else
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AccountFilterMenu(accountFilter: $state.accountFilter)
            }
        }
        .refreshable {
            await refreshActionQueue()
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
        #endif
    }

    // MARK: - Email List

    @ViewBuilder
    private var emailList: some View {
        let returning = returningEmails
        let newEmails = newItems

        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { appState.selectedEmailID },
                set: { newValue in
                    appState.selectedEmailID = newValue
                }
            )) {
                if !returning.isEmpty {
                    sectionedList(returning: returning, new: newEmails)
                } else {
                    flatList(newEmails)
                }
            }
            .listStyle(.plain)
            .animation(.default, value: emailStore.actionQueue.map(\.id))
            .onChange(of: appState.selectedEmailID) { _, newValue in
                if let id = newValue {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Sectioned List (RETURNING + NEW)

    @ViewBuilder
    private func sectionedList(returning: [Email], new: [Email]) -> some View {
        Section {
            ForEach(returning) { email in
                emailRow(email: email, isSnoozeReturn: true)
            }
        } header: {
            returningSectionHeader
        }

        Section {
            ForEach(new) { email in
                emailRow(email: email)
            }
        } header: {
            newSectionHeader
        }

        loadMoreRow
    }

    // MARK: - Flat List

    @ViewBuilder
    private func flatList(_ emails: [Email]) -> some View {
        ForEach(emails) { email in
            emailRow(email: email)
        }

        loadMoreRow
    }

    // MARK: - Email Row (with platform-specific wrapping)

    @ViewBuilder
    private func emailRow(email: Email, isSnoozeReturn: Bool = false) -> some View {
        let row = EmailRowView(
            email: email,
            isSelected: email.id == appState.selectedEmailID,
            isSnoozeReturn: isSnoozeReturn
        )
        .tag(email.id)
        .id(email.id)

        #if os(iOS)
        NavigationLink(value: email.id) {
            row
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                actionHandler.archive(
                    emailID: email.id,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
            } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .tint(Color.success)

            Button {
                actionHandler.toggleRead(
                    emailID: email.id,
                    isCurrentlyRead: email.isRead,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
            } label: {
                Label(
                    email.isRead ? "Mark Unread" : "Mark Read",
                    systemImage: email.isRead ? "envelope.badge" : "envelope.open"
                )
            }
            .tint(Color.accentColor)
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button(role: .destructive) {
                actionHandler.trash(
                    emailID: email.id,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
            } label: {
                Label("Trash", systemImage: "trash")
            }
            .tint(Color.destructive)

            Button {
                actionHandler.beginSnooze(emailID: email.id)
            } label: {
                Label("Snooze", systemImage: "clock")
            }
            .tint(Color.snooze)
        }
        .contextMenu {
            emailContextMenu(email: email)
        }
        #else
        row
        #endif
    }

    // MARK: - Context Menu (iOS)

    #if os(iOS)
    @ViewBuilder
    private func emailContextMenu(email: Email) -> some View {
        Button {
            // Reply action -- will be wired in compose task
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

        Divider()

        Button {
            actionHandler.archive(
                emailID: email.id,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label("Archive", systemImage: "archivebox")
        }

        Button {
            actionHandler.beginSnooze(emailID: email.id)
        } label: {
            Label("Snooze", systemImage: "clock")
        }

        Menu {
            Button {
                // Move to Reading Queue -- will be wired with reclassify
            } label: {
                Label("Reading Queue", systemImage: "book")
            }
            Button {
                // Move to Filtered -- will be wired with reclassify
            } label: {
                Label("Filtered", systemImage: "xmark.shield")
            }
        } label: {
            Label("Move to...", systemImage: "folder")
        }

        Button {
            actionHandler.toggleRead(
                emailID: email.id,
                isCurrentlyRead: email.isRead,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label(
                email.isRead ? "Mark Unread" : "Mark Read",
                systemImage: email.isRead ? "envelope.badge" : "envelope.open"
            )
        }

        Divider()

        Button(role: .destructive) {
            actionHandler.trash(
                emailID: email.id,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label("Trash", systemImage: "trash")
        }
    }
    #endif

    // MARK: - Section Headers

    private var returningSectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.snooze)
                .frame(width: 2, height: 12)

            Text("RETURNING")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
    }

    private var newSectionHeader: some View {
        Text("NEW")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }

    // MARK: - Infinite Scroll

    @ViewBuilder
    private var loadMoreRow: some View {
        if emailStore.actionQueueHasMore {
            Color.clear
                .frame(height: 1)
                .onAppear {
                    Task {
                        await loadNextPage()
                    }
                }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading action queue...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            iconName: "checkmark.circle",
            title: "All caught up",
            subtitle: "No emails need your response"
        )
    }

    // MARK: - Filtering & Sorting

    /// All action queue emails filtered by account.
    private var filteredEmails: [Email] {
        emailStore.actionQueue.filter { matchesAccountFilter($0) }
    }

    /// Returning emails: snoozed items that have returned, sorted by returnAt DESC.
    private var returningEmails: [Email] {
        filteredEmails
            .filter { isSnoozeReturn($0) }
            .sorted { lhs, rhs in
                let lhsReturn = lhs.snooze?.returnAt ?? .distantPast
                let rhsReturn = rhs.snooze?.returnAt ?? .distantPast
                return lhsReturn > rhsReturn
            }
    }

    /// New items: non-returning emails sorted by receivedAt DESC.
    private var newItems: [Email] {
        filteredEmails
            .filter { !isSnoozeReturn($0) }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    /// Whether an email is a snooze return (has a non-active snooze with a past returnAt).
    private func isSnoozeReturn(_ email: Email) -> Bool {
        guard let snooze = email.snooze else { return false }
        return !snooze.isActive && snooze.returnAt <= Date()
    }

    /// Whether an email matches the current account filter.
    private func matchesAccountFilter(_ email: Email) -> Bool {
        switch appState.accountFilter {
        case .all:
            return true
        case .work:
            return email.accountName?.lowercased() == "work"
        case .personal:
            return email.accountName?.lowercased() != "work"
        case .account(let id, _):
            return email.accountId == id
        }
    }

    // MARK: - Data Loading

    private func loadNextPage() async {
        // Pagination requires the coordinator's API client.
        // This will be wired up when the coordinator is injected into the environment.
    }

    #if os(iOS)
    private func refreshActionQueue() async {
        guard let client = appState.apiClient else { return }
        emailStore.setLoading(true)
        do {
            let response = try await client.fetchEmails(view: .actionQueue)
            emailStore.setEmails(response.data, for: .actionQueue)
        } catch {
            // Refresh failed -- keep existing data
        }
        emailStore.setLoading(false)
    }
    #endif
}

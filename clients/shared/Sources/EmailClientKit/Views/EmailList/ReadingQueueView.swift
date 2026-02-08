import SwiftUI

/// The Reading Queue content column: newsletter emails for leisurely reading.
///
/// No section headers, no badge counts, no snooze. Unread newsletters appear
/// first (full opacity), partially read sink to bottom (dimmer).
/// On iOS, adds swipe actions, context menu, pull-to-refresh, and NavigationLink.
public struct ReadingQueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    #if os(iOS)
    @State private var actionHandler = EmailActionHandler()
    #endif

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        Group {
            if emailStore.isLoading && emailStore.readingQueue.isEmpty {
                loadingState
            } else if filteredEmails.isEmpty {
                emptyState
            } else {
                emailList
            }
        }
        .navigationTitle("Reading Queue")
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                AccountFilterControl(selection: $state.accountFilter)
                    .frame(width: 200)
            }
        }
        #else
        .safeAreaInset(edge: .top) {
            AccountFilterPillBar(selection: $state.accountFilter)
        }
        .refreshable {
            await refreshReadingQueue()
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
        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { appState.selectedEmailID },
                set: { newValue in
                    appState.selectedEmailID = newValue
                }
            )) {
                ForEach(sortedEmails) { email in
                    emailRow(email: email)
                }
            }
            .listStyle(.plain)
            .animation(.default, value: emailStore.readingQueue.map(\.id))
            .onChange(of: appState.selectedEmailID) { _, newValue in
                if let id = newValue {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Email Row

    @ViewBuilder
    private func emailRow(email: Email) -> some View {
        let row = ReadingQueueRowView(
            email: email,
            isSelected: email.id == appState.selectedEmailID
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
            .tint(Color.newsletter)
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
        }
        .contextMenu {
            readingContextMenu(email: email)
        }
        #else
        row
        #endif
    }

    // MARK: - Context Menu (iOS)

    #if os(iOS)
    @ViewBuilder
    private func readingContextMenu(email: Email) -> some View {
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
            // Open original -- navigate to All Inboxes with this email
            appState.selectedView = .allInboxes
            appState.selectedEmailID = email.id
        } label: {
            Label("Open Original", systemImage: "envelope")
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

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading newsletters...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView.readingQueue
    }

    // MARK: - Filtering & Sorting

    /// All reading queue emails filtered by account.
    private var filteredEmails: [Email] {
        emailStore.readingQueue.filter { matchesAccountFilter($0) }
    }

    /// Sorted: unread first (newest first), then read (most recently received first).
    private var sortedEmails: [Email] {
        let unread = filteredEmails
            .filter { !$0.isRead }
            .sorted { $0.receivedAt > $1.receivedAt }
        let read = filteredEmails
            .filter { $0.isRead }
            .sorted { $0.receivedAt > $1.receivedAt }
        return unread + read
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

    #if os(iOS)
    private func refreshReadingQueue() async {
        guard let client = appState.apiClient else { return }
        emailStore.setLoading(true)
        do {
            let response = try await client.fetchEmails(view: .readingQueue)
            emailStore.setEmails(response.data, for: .readingQueue)
        } catch {
            // Refresh failed -- keep existing data
        }
        emailStore.setLoading(false)
    }
    #endif
}

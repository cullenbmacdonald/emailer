import SwiftUI

/// The All Inboxes content column: a flat chronological list of all emails
/// with classification badges, search, and full action set.
///
/// This is the "escape hatch" view -- traditional unified inbox showing everything
/// across all accounts including transactional emails.
public struct AllInboxesView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String?
    @State private var searchTask: Task<Void, Never>?

    #if os(iOS)
    @State private var actionHandler = EmailActionHandler()
    #endif

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        Group {
            if emailStore.isLoading && emailStore.allInboxes.isEmpty && !isSearchActive {
                loadingState
            } else if isSearchActive {
                searchContent
            } else if displayedEmails.isEmpty {
                emptyState
            } else {
                emailList
            }
        }
        .navigationTitle("All Inboxes")
        .searchable(text: $searchText, prompt: "Search all email...")
        .onChange(of: searchText) { _, newValue in
            handleSearchChange(newValue)
        }
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
            await refreshAllInboxes()
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
                ForEach(displayedEmails) { email in
                    allInboxesRow(email: email)
                }
            }
            .listStyle(.plain)
            .animation(.default, value: emailStore.allInboxes.map(\.id))
            .onChange(of: appState.selectedEmailID) { _, newValue in
                if let id = newValue {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Search Content

    @ViewBuilder
    private var searchContent: some View {
        if isSearching {
            ProgressView("Searching...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = searchError {
            EmptyStateView(
                iconName: "exclamationmark.triangle",
                title: "Search failed",
                subtitle: error
            )
        } else if searchResults.isEmpty && searchText.count >= 2 {
            EmptyStateView(
                iconName: "magnifyingglass",
                title: "No results",
                subtitle: "No emails match '\(searchText)'"
            )
        } else {
            searchResultsList
        }
    }

    @ViewBuilder
    private var searchResultsList: some View {
        List(selection: Binding(
            get: { appState.selectedEmailID },
            set: { newValue in
                appState.selectedEmailID = newValue
            }
        )) {
            ForEach(searchResults, id: \.email.id) { result in
                allInboxesRow(email: result.email)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Email Row

    @ViewBuilder
    private func allInboxesRow(email: Email) -> some View {
        let row = AllInboxesRowView(
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
            allInboxesContextMenu(email: email)
        }
        #else
        row
        #endif
    }

    // MARK: - Context Menu (iOS)

    #if os(iOS)
    @ViewBuilder
    private func allInboxesContextMenu(email: Email) -> some View {
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
                // Move to Action Queue
            } label: {
                Label("Action Queue", systemImage: "tray.and.arrow.down")
            }
            Button {
                // Move to Reading Queue
            } label: {
                Label("Reading Queue", systemImage: "book")
            }
            Button {
                // Move to Filtered
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

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading emails...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            iconName: "tray",
            title: "No emails",
            subtitle: "Your inbox is empty"
        )
    }

    // MARK: - Filtering & Sorting

    /// Whether search mode is active (user has typed something).
    var isSearchActive: Bool {
        !searchText.isEmpty
    }

    /// All emails sorted by receivedAt DESC, filtered by account.
    var displayedEmails: [Email] {
        emailStore.allInboxes
            .filter { matchesAccountFilter($0) }
            .sorted { $0.receivedAt > $1.receivedAt }
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

    // MARK: - Search

    /// Handle search text changes with 300ms debounce.
    private func handleSearchChange(_ query: String) {
        searchTask?.cancel()
        searchError = nil

        if query.count < 2 {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            // 300ms debounce
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            do {
                guard let client = appState.apiClient else {
                    isSearching = false
                    return
                }
                let accountID: String? = switch appState.accountFilter {
                case .all: nil
                case .work: nil // Server-side filtering by name not supported; filter client-side
                case .personal: nil
                case .account(let id, _): id
                }
                let response = try await client.search(query: query, accountID: accountID)
                guard !Task.isCancelled else { return }
                searchResults = response.data
                isSearching = false
            } catch {
                guard !Task.isCancelled else { return }
                searchError = error.localizedDescription
                isSearching = false
            }
        }
    }

    // MARK: - Data Loading

    #if os(iOS)
    private func refreshAllInboxes() async {
        guard let client = appState.apiClient else { return }
        emailStore.setLoading(true)
        do {
            let response = try await client.fetchEmails(view: .allInboxes)
            emailStore.setEmails(response.data, for: .allInboxes)
        } catch {
            // Refresh failed -- keep existing data
        }
        emailStore.setLoading(false)
    }
    #endif
}

// MARK: - All Inboxes Row View

/// An email row for All Inboxes with a classification badge on the snippet line.
public struct AllInboxesRowView: View {
    public let email: Email
    public let isSelected: Bool

    #if os(macOS)
    @State private var isHovering = false
    #endif

    public init(email: Email, isSelected: Bool) {
        self.email = email
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            AccountDot(
                color: accountColor,
                accountName: email.accountName ?? "Unknown"
            )
            .padding(.top, Spacing.xs)

            VStack(alignment: .leading, spacing: 2) {
                // Line 1: sender + timestamp
                HStack {
                    Text(senderDisplayName)
                        .font(email.isRead ? .subheadline : .headline)
                        .foregroundStyle(email.isRead ? .secondary : .primary)
                        .lineLimit(1)

                    Spacer()

                    if email.hasAttachments {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel("Has attachments")
                    }

                    Text(relativeTimestamp)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Line 2: subject
                Text(email.subject)
                    .font(email.isRead ? .subheadline : .headline)
                    .fontWeight(email.isRead ? .regular : .semibold)
                    .foregroundStyle(email.isRead ? .secondary : .primary)
                    .lineLimit(1)

                // Line 3: snippet + classification badge
                HStack {
                    Text(email.snippet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Spacer()

                    ClassificationBadge(
                        classificationType: email.classification.classification
                    )
                }
            }
        }
        .padding(.horizontal, ListRowMetrics.horizontalPadding)
        .padding(.vertical, ListRowMetrics.verticalPadding)
        .frame(minHeight: ListRowMetrics.rowHeight)
        .background(rowBackground)
        .contentShape(Rectangle())
        .opacity(email.isArchived ? 0.6 : 1.0)
        #if os(macOS)
        .onHover { hovering in
            isHovering = hovering
        }
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Background

    @ViewBuilder
    private var rowBackground: some View {
        #if os(macOS)
        if isSelected {
            Color.accentColor.opacity(0.15)
        } else if isHovering {
            Color(nsColor: .quaternarySystemFill)
        } else {
            Color.clear
        }
        #else
        Color.clear
        #endif
    }

    // MARK: - Helpers

    private var senderDisplayName: String {
        email.from.name ?? email.from.email
    }

    private var accountColor: Color {
        guard let hex = email.accountColor else { return .gray }
        return Color(hexString: hex)
    }

    private var relativeTimestamp: String {
        let now = Date.now
        let interval = now.timeIntervalSince(email.receivedAt)

        if interval < 60 {
            return "now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m"
        } else if interval < 86400, Calendar.current.isDateInToday(email.receivedAt) {
            let hours = Int(interval / 3600)
            return "\(hours)h"
        } else if Calendar.current.isDateInYesterday(email.receivedAt) {
            return "Yesterday"
        } else {
            return email.receivedAt.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if !email.isRead { parts.append("Unread") }
        parts.append("Email from \(senderDisplayName)")
        parts.append("about \(email.subject)")
        parts.append("received \(relativeTimestamp)")
        if let accountName = email.accountName {
            parts.append("\(accountName) account")
        }
        parts.append("Classification: \(ClassificationBadge(classificationType: email.classification.classification).fullLabel)")
        if email.isArchived { parts.append("archived") }
        if email.hasAttachments { parts.append("has attachments") }
        return parts.joined(separator: ", ")
    }
}

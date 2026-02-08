import SwiftUI

/// The Filtered content column: spam and marketing emails for review.
///
/// Shows two sections when borderline items exist (NEEDS REVIEW + OTHER),
/// or a flat list when there are none. Info banner at top, confidence scores,
/// days remaining on every row.
/// On iOS, adds swipe actions, context menu, pull-to-refresh, and NavigationLink.
public struct FilteredView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    #if os(iOS)
    @State private var actionHandler = FilteredActionHandler()
    @State private var showRescueSheet = false
    @State private var rescueTargetID: String?
    #endif

    public init() {}

    public var body: some View {
        @Bindable var state = appState

        Group {
            if emailStore.isLoading && emailStore.filtered.isEmpty {
                loadingState
            } else if filteredEmails.isEmpty {
                emptyState
            } else {
                emailList
            }
        }
        .navigationTitle("Filtered")
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
            await refreshFiltered()
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
                    if let emailID = rescueTargetID {
                        actionHandler.rescue(
                            emailID: emailID,
                            to: destination,
                            emailStore: emailStore,
                            apiClient: appState.apiClient
                        )
                    }
                    rescueTargetID = nil
                }
            }
            Button("Cancel", role: .cancel) {
                rescueTargetID = nil
            }
        }
        #endif
    }

    // MARK: - Email List

    @ViewBuilder
    private var emailList: some View {
        let borderline = borderlineEmails
        let other = otherEmails

        ScrollViewReader { proxy in
            List(selection: Binding(
                get: { appState.selectedEmailID },
                set: { newValue in
                    appState.selectedEmailID = newValue
                }
            )) {
                // Info banner
                infoBanner
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())

                if !borderline.isEmpty {
                    sectionedList(borderline: borderline, other: other)
                } else {
                    flatList(other)
                }
            }
            .listStyle(.plain)
            .animation(.default, value: emailStore.filtered.map(\.id))
            .onChange(of: appState.selectedEmailID) { _, newValue in
                if let id = newValue {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Text("Items auto-delete after 14 days")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(height: 28)
        .background(Color.filteredColor.opacity(0.08))
        .accessibilityLabel("Items in this view auto-delete after 14 days")
    }

    // MARK: - Sectioned List (NEEDS REVIEW + OTHER)

    @ViewBuilder
    private func sectionedList(borderline: [Email], other: [Email]) -> some View {
        Section {
            ForEach(borderline) { email in
                filteredRow(email: email, isBorderline: true)
            }
        } header: {
            needsReviewHeader(count: borderline.count)
        }

        Section {
            ForEach(other) { email in
                filteredRow(email: email)
            }
        } header: {
            otherSectionHeader
        }
    }

    // MARK: - Flat List

    @ViewBuilder
    private func flatList(_ emails: [Email]) -> some View {
        ForEach(emails) { email in
            filteredRow(email: email)
        }
    }

    // MARK: - Email Row (with platform-specific wrapping)

    @ViewBuilder
    private func filteredRow(email: Email, isBorderline: Bool = false) -> some View {
        let row = FilteredRowView(
            email: email,
            isSelected: email.id == appState.selectedEmailID,
            isBorderline: isBorderline
        )
        .tag(email.id)
        .id(email.id)

        #if os(iOS)
        NavigationLink(value: email.id) {
            row
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                rescueTargetID = email.id
                showRescueSheet = true
            } label: {
                Label("Not Spam", systemImage: "arrow.uturn.left")
            }
            .tint(Color.accentColor)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                actionHandler.deleteNow(
                    emailID: email.id,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(Color.destructive)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                actionHandler.confirmSpam(
                    emailID: email.id,
                    emailStore: emailStore,
                    apiClient: appState.apiClient
                )
            } label: {
                Label("Confirm Spam", systemImage: "xmark.shield")
            }
            .tint(Color.filteredColor)
        }
        .contextMenu {
            filteredContextMenu(email: email)
        }
        #else
        row
        #endif
    }

    // MARK: - Context Menu (iOS)

    #if os(iOS)
    @ViewBuilder
    private func filteredContextMenu(email: Email) -> some View {
        Button {
            rescueTargetID = email.id
            showRescueSheet = true
        } label: {
            Label("Move to Action Queue", systemImage: "tray.and.arrow.down")
        }

        Button {
            actionHandler.rescue(
                emailID: email.id,
                to: .readingQueue,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label("Move to Reading Queue", systemImage: "book")
        }

        Button {
            actionHandler.rescue(
                emailID: email.id,
                to: .allInboxes,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label("Move to All Inboxes", systemImage: "tray")
        }

        Divider()

        Button {
            actionHandler.confirmSpam(
                emailID: email.id,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label("Confirm as Spam", systemImage: "xmark.shield")
        }

        Divider()

        Button(role: .destructive) {
            actionHandler.deleteNow(
                emailID: email.id,
                emailStore: emailStore,
                apiClient: appState.apiClient
            )
        } label: {
            Label("Delete Now", systemImage: "trash")
        }
    }
    #endif

    // MARK: - Section Headers

    private func needsReviewHeader(count: Int) -> some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.snooze)
                .frame(width: 2, height: 12)

            Text("NEEDS REVIEW (\(count))")
                .font(.caption)
                .foregroundStyle(Color.snooze)
                .textCase(.uppercase)
        }
        .accessibilityLabel("Needs review, \(count) items that may not be spam")
    }

    private var otherSectionHeader: some View {
        Text("OTHER")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading filtered items...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            iconName: "xmark.shield",
            title: "Nothing filtered",
            subtitle: "Spam and marketing emails will appear here for review.\nItems auto-delete after 14 days."
        )
    }

    // MARK: - Filtering & Sorting

    /// All filtered emails matching the account filter.
    private var filteredEmails: [Email] {
        emailStore.filtered.filter { matchesAccountFilter($0) }
    }

    /// Borderline items: confidence < 0.80, sorted by receivedAt DESC.
    private var borderlineEmails: [Email] {
        filteredEmails
            .filter { $0.classification.confidence < 0.80 }
            .sorted { $0.receivedAt > $1.receivedAt }
    }

    /// Standard filtered items: confidence >= 0.80, sorted by receivedAt DESC.
    private var otherEmails: [Email] {
        filteredEmails
            .filter { $0.classification.confidence >= 0.80 }
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

    // MARK: - Data Loading

    #if os(iOS)
    private func refreshFiltered() async {
        guard let client = appState.apiClient else { return }
        emailStore.setLoading(true)
        do {
            let response = try await client.fetchEmails(view: .filtered)
            emailStore.setEmails(response.data, for: .filtered)
        } catch {
            // Refresh failed -- keep existing data
        }
        emailStore.setLoading(false)
    }
    #endif
}

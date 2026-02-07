import SwiftUI

/// The Action Queue content column: emails needing a response.
///
/// Shows two sections when snoozed returns exist (RETURNING + NEW),
/// or a flat list when there are none. Account filter at top.
public struct ActionQueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

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
                EmailRowView(
                    email: email,
                    isSelected: email.id == appState.selectedEmailID,
                    isSnoozeReturn: true
                )
                .tag(email.id)
                .id(email.id)
            }
        } header: {
            returningSectionHeader
        }

        Section {
            ForEach(new) { email in
                EmailRowView(
                    email: email,
                    isSelected: email.id == appState.selectedEmailID
                )
                .tag(email.id)
                .id(email.id)
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
            EmailRowView(
                email: email,
                isSelected: email.id == appState.selectedEmailID
            )
            .tag(email.id)
            .id(email.id)
        }

        loadMoreRow
    }

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

    // MARK: - Pagination

    private func loadNextPage() async {
        // Pagination requires the coordinator's API client.
        // This will be wired up when the coordinator is injected into the environment.
    }
}

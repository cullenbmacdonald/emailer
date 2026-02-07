import SwiftUI
import EmailClientKit

/// The Action Queue content column: emails needing a response.
///
/// Shows two sections when snoozed returns exist (RETURNING + NEW),
/// or a flat list when there are none. Account filter at top.
struct ActionQueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(EmailStore.self) private var emailStore

    var body: some View {
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                AccountFilterControl(selection: $state.accountFilter)
                    .frame(width: 200)
            }
        }
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
        }
    }

    // MARK: - Pagination

    private func loadNextPage() async {
        guard let coordinator = findCoordinator() else { return }
        guard let client = coordinator.apiClient else { return }
        guard let cursor = emailStore.actionQueueCursor else { return }

        do {
            let response = try await client.fetchEmails(
                view: .actionQueue,
                cursor: cursor
            )
            emailStore.appendActionQueueEmails(response.data)
            emailStore.setActionQueuePagination(
                cursor: response.nextCursor,
                hasMore: response.hasMore
            )
        } catch {
            // Pagination error — silently fail, user can scroll again
        }
    }

    /// Find the AppCoordinator from environment. Returns nil if not accessible.
    private func findCoordinator() -> AppCoordinator? {
        nil // Will be wired up when coordinator is injected into environment
    }
}

#Preview("ActionQueueView - Populated") {
    let state = AppState()
    let store = EmailStore()
    store.setEmails([
        Email(
            id: "1", accountId: "acc-1",
            from: Contact(name: "Jane Smith", email: "jane@co.com"),
            to: [Contact(email: "you@work.com")],
            subject: "Re: Q3 budget review",
            snippet: "Can you sign off on the Q3 budget?",
            receivedAt: Date().addingTimeInterval(-120),
            classification: Classification(
                classification: .actionRequired, confidence: 0.95, classifiedBy: .llm
            ),
            isRead: false, isArchived: false, hasAttachments: false,
            snooze: SnoozeState(
                id: "snz-1", emailId: "1",
                snoozedAt: Date().addingTimeInterval(-86400),
                returnAt: Date().addingTimeInterval(-60),
                snoozeCount: 2, isActive: false
            ),
            accountColor: "#3B82F6", accountName: "Work"
        ),
        Email(
            id: "2", accountId: "acc-1",
            from: Contact(name: "Bob Lee", email: "bob@co.com"),
            to: [Contact(email: "you@work.com")],
            subject: "Project Falcon update",
            snippet: "What do you think about the new timeline?",
            receivedAt: Date().addingTimeInterval(-3600),
            classification: Classification(
                classification: .actionRequired, confidence: 0.90, classifiedBy: .llm
            ),
            isRead: false, isArchived: false, hasAttachments: true,
            accountColor: "#3B82F6", accountName: "Work"
        ),
        Email(
            id: "3", accountId: "acc-2",
            from: Contact(name: "Sarah M.", email: "sarah@gmail.com"),
            to: [Contact(email: "you@gmail.com")],
            subject: "Dinner Saturday?",
            snippet: "Are you free tomorrow evening?",
            receivedAt: Date().addingTimeInterval(-7200),
            classification: Classification(
                classification: .actionRequired, confidence: 0.88, classifiedBy: .llm
            ),
            isRead: true, isArchived: false, hasAttachments: false,
            accountColor: "#22C55E", accountName: "Personal"
        ),
    ], for: .actionQueue)

    return NavigationSplitView {
        Text("Sidebar")
    } content: {
        ActionQueueView()
            .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 420)
    } detail: {
        Text("Detail")
    }
    .environment(state)
    .environment(store)
    .environment(DigestStore())
    .environment(RecommendationStore())
}

#Preview("ActionQueueView - Empty") {
    let state = AppState()
    let store = EmailStore()

    return ActionQueueView()
        .environment(state)
        .environment(store)
}

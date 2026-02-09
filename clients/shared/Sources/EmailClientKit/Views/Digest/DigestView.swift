import SwiftUI

/// The Daily Digest view -- a vertically scrollable, section-based summary.
/// Shows morning sections (6 AM) or evening sections (7 PM) based on digest type.
public struct DigestView: View {
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore

    public init() {}

    public var body: some View {
        Group {
            if digestStore.isLoading && digestStore.displayedDigest == nil {
                loadingState
            } else if let digest = digestStore.displayedDigest {
                digestContent(digest)
            } else {
                emptyState
            }
        }
        .navigationTitle("Daily Digest")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        Task {
                            guard let client = appState.apiClient else { return }
                            await digestStore.generateDigest(type: .morning, using: client)
                        }
                    } label: {
                        Label("Morning Digest", systemImage: "sun.horizon")
                    }
                    Button {
                        Task {
                            guard let client = appState.apiClient else { return }
                            await digestStore.generateDigest(type: .evening, using: client)
                        }
                    } label: {
                        Label("Evening Digest", systemImage: "moon.stars")
                    }
                } label: {
                    Label("Generate Digest", systemImage: "arrow.clockwise")
                }
                .help("Generate digest now")
            }
        }
        .onAppear {
            digestStore.markAsRead()
        }
        #if os(iOS)
        .refreshable {
            guard let client = appState.apiClient else { return }
            await digestStore.loadLatestDigest(using: client)
        }
        #endif
    }

    // MARK: - Digest Content

    @ViewBuilder
    private func digestContent(_ digest: DailyDigest) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                digestHeader(digest)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.xl)

                if let error = digestStore.errorMessage {
                    errorBanner(error)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.bottom, Spacing.lg)
                }

                ForEach(digest.sections.indices, id: \.self) { index in
                    let section = digest.sections[index]
                    if shouldShowSection(section) {
                        digestSection(section)
                            .padding(.horizontal, Spacing.lg)

                        if index < digest.sections.count - 1 {
                            Divider()
                                .padding(.horizontal, Spacing.lg)
                                .padding(.vertical, Spacing.xl)
                        }
                    }
                }

                DigestDatePicker(
                    currentDate: digest.generatedAt,
                    onPrevious: {
                        // Navigate to previous digest -- placeholder
                    },
                    onDateSelected: { _ in
                        // Navigate to digest for date -- placeholder
                    }
                )
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.xl)
                .padding(.bottom, Spacing.xxxl)
            }
            .padding(.top, Spacing.lg)
        }
    }

    // MARK: - Header

    private func digestHeader(_ digest: DailyDigest) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(digest.digestType == .morning ? "Morning Digest" : "Evening Digest")
                .font(.title2)
                .fontWeight(.semibold)

            Text(digest.generatedAt, format: .dateTime.month(.wide).day().year().hour().minute())
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Section Router

    @ViewBuilder
    private func digestSection(_ section: DigestSection) -> some View {
        switch section.type {
        case .actionQueueSummary:
            ActionQueueSummarySection(section: section)
        case .returningToday:
            ReturningTodaySection(section: section)
        case .readingQueueSummary:
            ReadingQueueSummarySection(section: section)
        case .borderlineItems:
            BorderlineItemsSection(section: section)
        case .notableTransactional:
            NotableTransactionalSection(section: section)
        case .todayStats:
            TodayStatsSection(section: section)
        case .stillPending:
            StillPendingSection(section: section)
        case .newslettersToday:
            NewslettersTodaySection(section: section)
        case .snoozeNudges:
            SnoozeNudgesSection(section: section)
        }
    }

    /// Whether a section should be displayed (hides empty optional sections).
    private func shouldShowSection(_ section: DigestSection) -> Bool {
        switch section.type {
        case .actionQueueSummary, .readingQueueSummary, .todayStats:
            // Always shown when present
            return true
        case .returningToday, .borderlineItems, .notableTransactional,
             .stillPending, .newslettersToday, .snoozeNudges:
            // Hidden if no items
            let items = section.items ?? []
            let activeItems = items.filter { !digestStore.dismissedItemIDs.contains($0.emailId) }
            if section.type == .stillPending {
                return (section.count ?? 0) > 0
            }
            return !activeItems.isEmpty
        }
    }

    // MARK: - States

    private var loadingState: some View {
        ProgressView("Loading digest...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            iconName: "sun.horizon",
            title: "No digest yet",
            subtitle: "Your first digest will be generated at 6:00 AM"
        )
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
            Spacer()
            Button("Retry") {
                Task {
                    guard let client = appState.apiClient else { return }
                    await digestStore.loadLatestDigest(using: client)
                }
            }
            .font(.caption)
        }
        .padding(Spacing.sm)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Section Header Component

struct DigestSectionHeader: View {
    let title: String
    var accentColor: Color = .secondary

    var body: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: 1)
                .fill(accentColor)
                .frame(width: 2, height: 12)

            Text(title)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
        }
        .padding(.bottom, Spacing.sm)
    }
}

// MARK: - Action Queue Summary Section

struct ActionQueueSummarySection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "ACTION QUEUE", accentColor: .accentColor)

            HStack(spacing: Spacing.sm) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                Text("\(section.count ?? 0) emails need your response")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            if let accounts = section.accountBreakdown, accounts.count > 1 {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(accounts, id: \.accountId) { account in
                        HStack(spacing: Spacing.xs) {
                            Circle()
                                .fill(Color(hexString: account.accountColor))
                                .frame(width: ListRowMetrics.accountDotSize,
                                       height: ListRowMetrics.accountDotSize)
                            Text("\(account.accountName): \(account.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Button {
                appState.selectedView = .actionQueue
            } label: {
                Text("View Action Queue")
                    .font(.callout)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Action Queue section, \(section.count ?? 0) emails need your response")
    }
}

// MARK: - Returning Today Section

struct ReturningTodaySection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "RETURNING TODAY", accentColor: .snooze)

            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            if let items = section.items {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    if !digestStore.dismissedItemIDs.contains(item.emailId) {
                        returningItemRow(item)
                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func returningItemRow(_ item: DigestItem) -> some View {
        Button {
            appState.selectedView = .actionQueue
            appState.selectedEmailID = item.emailId
        } label: {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Circle()
                    .fill(Color.snooze)
                    .frame(width: ListRowMetrics.accountDotSize,
                           height: ListRowMetrics.accountDotSize)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("\(item.subject ?? "No subject") (\(item.from ?? "Unknown"))")
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }

                    HStack(spacing: Spacing.sm) {
                        if let returnAt = item.returnAt {
                            Text("Returns at \(returnAt, format: .dateTime.hour().minute())")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        if let count = item.snoozeCount, count >= 2 {
                            SnoozeCountBadge(snoozeCount: count)
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(returningItemAccessibilityLabel(item))
    }

    private func returningItemAccessibilityLabel(_ item: DigestItem) -> String {
        var label = "\(item.subject ?? "No subject") from \(item.from ?? "Unknown")"
        if let returnAt = item.returnAt {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            label += ", returns at \(formatter.string(from: returnAt))"
        }
        if let count = item.snoozeCount, count >= 2 {
            label += ", snoozed \(count) times"
        }
        return label
    }
}

// MARK: - Reading Queue Summary Section

struct ReadingQueueSummarySection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "READING QUEUE", accentColor: .newsletter)

            Text("\(section.count ?? 0) newsletters waiting")
                .font(.callout)

            Button {
                appState.selectedView = .readingQueue
            } label: {
                Text("View Reading Queue")
                    .font(.callout)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reading Queue section, \(section.count ?? 0) newsletters waiting")
    }
}

// MARK: - Borderline Items Section

struct BorderlineItemsSection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "MIGHT NOT BE SPAM", accentColor: .filteredColor)

            let activeItems = (section.items ?? []).filter {
                !digestStore.dismissedItemIDs.contains($0.emailId)
            }

            if !activeItems.isEmpty {
                Text("These \(activeItems.count) might be worth checking:")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            ForEach(activeItems.indices, id: \.self) { index in
                let item = activeItems[index]
                borderlineItemRow(item)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                if index < activeItems.count - 1 {
                    Divider()
                }
            }
        }
        .animation(.default, value: digestStore.dismissedItemIDs)
    }

    @ViewBuilder
    private func borderlineItemRow(_ item: DigestItem) -> some View {
        @Bindable var store = digestStore

        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.from ?? "Unknown sender")
                        .font(.subheadline)

                    if let subject = item.subject {
                        Text("\"\(subject)\"")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    if let confidence = item.confidence {
                        Text("Confidence: \(Int(confidence * 100))%")
                            .font(.caption)
                            .foregroundStyle(Color.filteredColor)
                    }
                }

                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                Button("Not Spam") {
                    store.rescueEmailID = item.emailId
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Spam") {
                    Task {
                        guard let client = appState.apiClient else { return }
                        await digestStore.confirmSpam(emailID: item.emailId, using: client)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(borderlineAccessibilityLabel(item))
        .sheet(item: Binding(
            get: {
                store.rescueEmailID == item.emailId ? RescueTarget(emailId: item.emailId) : nil
            },
            set: { newValue in
                if newValue == nil { store.rescueEmailID = nil }
            }
        )) { target in
            BorderlineRescuePicker(emailId: target.emailId)
        }
    }

    private func borderlineAccessibilityLabel(_ item: DigestItem) -> String {
        var label = "Borderline item from \(item.from ?? "Unknown")"
        if let subject = item.subject { label += ", \(subject)" }
        if let confidence = item.confidence { label += ", \(Int(confidence * 100)) percent confidence" }
        return label
    }
}

/// Identifiable wrapper for rescue picker binding.
struct RescueTarget: Identifiable {
    let emailId: String
    var id: String { emailId }
}

/// Inline rescue picker for borderline items.
struct BorderlineRescuePicker: View {
    let emailId: String
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Button {
                    rescueTo(.actionRequired)
                } label: {
                    Label("Action Queue", systemImage: "tray.and.arrow.down.fill")
                }

                Button {
                    rescueTo(.newsletter)
                } label: {
                    Label("Reading Queue", systemImage: "book.fill")
                }

                Button {
                    rescueTo(.transactional)
                } label: {
                    Label("All Inboxes", systemImage: "tray.full.fill")
                }
            }
            .navigationTitle("Move to...")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents([.medium])
        #endif
        .frame(minWidth: 280, minHeight: 200)
    }

    private func rescueTo(_ classification: ClassificationType) {
        Task {
            guard let client = appState.apiClient else { return }
            await digestStore.rescueItem(emailID: emailId, to: classification, using: client)
            dismiss()
        }
    }
}

// MARK: - Notable Transactional Section

struct NotableTransactionalSection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "NOTABLE", accentColor: .secondary)

            if let items = section.items {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    Button {
                        appState.selectedView = .allInboxes
                        appState.selectedEmailID = item.emailId
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: iconForHighlight(item.highlightType))
                                .foregroundStyle(.secondary)

                            Text(item.displayText ?? item.subject ?? "Notable item")
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private func iconForHighlight(_ type: HighlightType?) -> String {
        switch type {
        case .packageArriving: "shippingbox.fill"
        case .largeCharge: "creditcard.fill"
        case .calendarEvent: "calendar"
        case nil: "info.circle"
        }
    }
}

// MARK: - Today's Stats Section (Evening)

struct TodayStatsSection: View {
    let section: DigestSection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "TODAY", accentColor: .success)

            let total = (section.sentCount ?? 0) + (section.archivedCount ?? 0)

            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.success)

                Text("You handled \(total) emails today")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            HStack(spacing: Spacing.lg) {
                Text("Sent: \(section.sentCount ?? 0)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Text("Archived: \(section.archivedCount ?? 0)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Today's stats, you handled \((section.sentCount ?? 0) + (section.archivedCount ?? 0)) emails. " +
            "Sent \(section.sentCount ?? 0), archived \(section.archivedCount ?? 0)."
        )
    }
}

// MARK: - Still Pending Section (Evening)

struct StillPendingSection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "STILL PENDING", accentColor: .accentColor)

            Text("\(section.count ?? 0) emails still need your response")
                .font(.callout)

            Button {
                appState.selectedView = .actionQueue
            } label: {
                Text("View Action Queue")
                    .font(.callout)
            }
        }
    }
}

// MARK: - Newsletters Today Section (Evening)

struct NewslettersTodaySection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "NEWSLETTERS TODAY", accentColor: .newsletter)

            Text("\(section.items?.count ?? 0) newsletters arrived today:")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let items = section.items {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    Button {
                        appState.selectedView = .readingQueue
                        appState.selectedEmailID = item.emailId
                    } label: {
                        HStack {
                            Text("- \(item.newsletterName ?? "Newsletter"): \"\(item.subject ?? "")\"")
                                .font(.callout)
                                .lineLimit(1)
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Button {
                appState.selectedView = .readingQueue
            } label: {
                Text("View Reading Queue")
                    .font(.callout)
            }
        }
    }
}

// MARK: - Snooze Nudges Section (Evening)

struct SnoozeNudgesSection: View {
    let section: DigestSection
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            DigestSectionHeader(title: "GENTLE NUDGE", accentColor: .snooze)

            Text("These have been snoozed multiple times:")
                .font(.callout)
                .foregroundStyle(.secondary)

            if let items = section.items {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    if !digestStore.dismissedItemIDs.contains(item.emailId) {
                        snoozeNudgeRow(item)
                        if index < items.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func snoozeNudgeRow(_ item: DigestItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.circle")
                    .foregroundStyle(Color.snooze)
                    .font(.caption)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    if let subject = item.subject {
                        Text("\"\(subject)\"")
                            .font(.subheadline)
                    }

                    if let from = item.from {
                        Text(from)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: Spacing.xs) {
                        if let count = item.snoozeCount, let days = item.daysSinceFirstSnooze {
                            Text("Snoozed \(count) times over \(days) days")
                                .font(.caption)
                                .foregroundStyle(Color.snooze)
                        }
                    }
                }

                Spacer()
            }

            HStack(spacing: Spacing.sm) {
                Button("Reply Now") {
                    appState.selectedView = .actionQueue
                    appState.selectedEmailID = item.emailId
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Snooze Again") {
                    // Opens snooze picker -- placeholder for now
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Date Picker

struct DigestDatePicker: View {
    let currentDate: Date
    let onPrevious: () -> Void
    let onDateSelected: (Date) -> Void

    @State private var selectedDate: Date

    init(currentDate: Date, onPrevious: @escaping () -> Void, onDateSelected: @escaping (Date) -> Void) {
        self.currentDate = currentDate
        self.onPrevious = onPrevious
        self.onDateSelected = onDateSelected
        self._selectedDate = State(initialValue: currentDate)
    }

    var body: some View {
        HStack {
            Button {
                onPrevious()
            } label: {
                Label("Previous Digest", systemImage: "chevron.left")
                    .font(.caption)
            }

            Spacer()

            DatePicker(
                "",
                selection: $selectedDate,
                in: ...Date(),
                displayedComponents: .date
            )
            .labelsHidden()
            .onChange(of: selectedDate) { _, newDate in
                onDateSelected(newDate)
            }
        }
    }
}

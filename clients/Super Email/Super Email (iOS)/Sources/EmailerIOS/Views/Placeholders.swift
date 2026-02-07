import SwiftUI

/// Placeholder views for tabs that will be implemented in later tasks.
/// Each placeholder displays the view name so the TabView is navigable.

struct ActionQueuePlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Action Queue",
            systemImage: "exclamationmark.circle",
            description: Text("Coming in Phase 2")
        )
        .navigationTitle("Action Queue")
    }
}

struct ReadingQueuePlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Reading Queue",
            systemImage: "book",
            description: Text("Coming in Phase 2")
        )
        .navigationTitle("Reading Queue")
    }
}

struct RecommendationsPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Recommendations",
            systemImage: "star",
            description: Text("Coming in Phase 3")
        )
        .navigationTitle("Recommendations")
    }
}

struct FilteredPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Filtered",
            systemImage: "shield",
            description: Text("Coming in Phase 3")
        )
        .navigationTitle("Filtered")
    }
}

struct AllInboxesPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "All Inboxes",
            systemImage: "tray.2",
            description: Text("Coming in Phase 3")
        )
        .navigationTitle("All Inboxes")
    }
}

struct DailyDigestPlaceholder: View {
    var body: some View {
        ContentUnavailableView(
            "Daily Digest",
            systemImage: "newspaper",
            description: Text("Coming in Phase 3")
        )
        .navigationTitle("Daily Digest")
    }
}

#Preview("Action Queue") {
    NavigationStack {
        ActionQueuePlaceholder()
    }
}

#Preview("Reading Queue") {
    NavigationStack {
        ReadingQueuePlaceholder()
    }
}

#Preview("More View") {
    NavigationStack {
        MoreView()
    }
}

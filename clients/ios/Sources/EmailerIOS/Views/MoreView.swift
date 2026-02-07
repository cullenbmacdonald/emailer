import SwiftUI

/// The "More" tab containing Filtered, All Inboxes, and Daily Digest entries.
public struct MoreView: View {
    public init() {}

    public var body: some View {
        List {
            NavigationLink {
                FilteredPlaceholder()
            } label: {
                Label("Filtered", systemImage: "shield")
            }

            NavigationLink {
                AllInboxesPlaceholder()
            } label: {
                Label("All Inboxes", systemImage: "tray.2")
            }

            NavigationLink {
                DailyDigestPlaceholder()
            } label: {
                Label("Daily Digest", systemImage: "newspaper")
            }
        }
        .navigationTitle("More")
    }
}

#Preview {
    NavigationStack {
        MoreView()
    }
}

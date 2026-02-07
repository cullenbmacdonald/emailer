import SwiftUI

/// The "More" tab containing Filtered, All Inboxes, and Daily Digest entries.
/// Shows uncertain count badge on Filtered and "NEW" indicator on Daily Digest.
public struct MoreView: View {
    @Environment(IOSAppState.self) private var appState

    public init() {}

    public var body: some View {
        List {
            NavigationLink {
                FilteredPlaceholder()
            } label: {
                Label("Filtered", systemImage: "xmark.shield")
                    .badge(appState.filteredUncertainCount)
            }

            NavigationLink {
                AllInboxesPlaceholder()
            } label: {
                Label("All Inboxes", systemImage: "tray.full.fill")
            }

            NavigationLink {
                DailyDigestPlaceholder()
            } label: {
                HStack {
                    Label("Daily Digest", systemImage: "newspaper.fill")
                    Spacer()
                    if appState.hasNewDigest {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .frame(minHeight: 22)
                            .background(.blue, in: .capsule)
                    }
                }
            }
        }
        .navigationTitle("More")
    }
}

#Preview {
    NavigationStack {
        MoreView()
            .environment(IOSAppState())
    }
}

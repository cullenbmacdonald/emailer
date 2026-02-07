import SwiftUI
import EmailClientKit

/// The "More" tab containing Filtered, All Inboxes, and Daily Digest entries.
/// Shows uncertain count badge on Filtered and "NEW" indicator on Daily Digest.
public struct MoreView: View {
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        List {
            NavigationLink {
                IOSPlaceholderView(title: "Filtered", icon: "shield", phase: "Phase 3")
            } label: {
                Label("Filtered", systemImage: "xmark.shield")
                    .badge(appState.filteredUncertainCount)
            }

            NavigationLink {
                IOSPlaceholderView(title: "All Inboxes", icon: "tray.2", phase: "Phase 3")
            } label: {
                Label("All Inboxes", systemImage: "tray.full.fill")
            }

            NavigationLink {
                IOSPlaceholderView(title: "Daily Digest", icon: "newspaper", phase: "Phase 3")
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
                            .frame(minHeight: ListRowMetrics.badgeHeight)
                            .background(.blue, in: .capsule)
                    }
                }
            }
        }
        .navigationTitle("More")
    }
}

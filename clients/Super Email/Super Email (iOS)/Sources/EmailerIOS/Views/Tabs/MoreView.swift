import SwiftUI
import EmailClientKit

/// The "More" tab containing Filtered, All Inboxes, and Daily Digest entries.
/// Shows uncertain count badge on Filtered and "NEW" indicator on Daily Digest.
public struct MoreView: View {
    @Environment(AppState.self) private var appState
    @Environment(DigestStore.self) private var digestStore

    public init() {}

    public var body: some View {
        List {
            NavigationLink {
                FilteredView()
                    .navigationDestination(for: String.self) { emailID in
                        IOSFilteredDetailView(emailID: emailID)
                    }
            } label: {
                Label("Filtered", systemImage: "xmark.shield")
                    .badge(appState.filteredUncertainCount)
            }

            NavigationLink {
                AllInboxesView()
                    .navigationDestination(for: String.self) { emailID in
                        IOSEmailDetailView(emailID: emailID)
                    }
            } label: {
                Label("All Inboxes", systemImage: "tray.full.fill")
            }

            NavigationLink {
                DigestView()
                    .onAppear {
                        digestStore.markAsRead()
                        appState.hasNewDigest = false
                    }
            } label: {
                HStack {
                    Label("Daily Digest", systemImage: "newspaper.fill")
                    Spacer()
                    if digestStore.hasNewDigest {
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

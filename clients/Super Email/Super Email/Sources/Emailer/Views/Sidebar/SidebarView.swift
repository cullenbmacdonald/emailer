import SwiftUI

/// The sidebar column showing the five main views plus Daily Digest.
///
/// Displays badge counts for Action Queue and Filtered, a "NEW" indicator
/// for Daily Digest, and no badge for Reading Queue (ADHD-friendly design).
struct SidebarView: View {
    @Binding var selection: SidebarDestination?
    var actionQueueCount: Int
    var filteredCount: Int
    var hasNewDigest: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(SidebarDestination.mainViews) { destination in
                    SidebarRow(
                        destination: destination,
                        badgeCount: badgeCount(for: destination),
                        showNewIndicator: false
                    )
                    .tag(destination)
                }
            }
            Section {
                SidebarRow(
                    destination: .dailyDigest,
                    badgeCount: 0,
                    showNewIndicator: hasNewDigest
                )
                .tag(SidebarDestination.dailyDigest)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Emailer")
    }

    private func badgeCount(for destination: SidebarDestination) -> Int {
        switch destination {
        case .actionQueue:
            actionQueueCount
        case .filtered:
            filteredCount
        default:
            0
        }
    }
}

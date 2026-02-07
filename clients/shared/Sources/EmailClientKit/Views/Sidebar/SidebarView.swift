import SwiftUI

/// The sidebar column showing the five main views plus Daily Digest.
///
/// Displays badge counts for Action Queue and Filtered, a "NEW" indicator
/// for Daily Digest, and no badge for Reading Queue (ADHD-friendly design).
/// Used by both macOS (NavigationSplitView) and iPad (NavigationSplitView).
public struct SidebarView: View {
    @Binding public var selection: SidebarDestination?
    public var actionQueueCount: Int
    public var filteredCount: Int
    public var hasNewDigest: Bool

    public init(
        selection: Binding<SidebarDestination?>,
        actionQueueCount: Int,
        filteredCount: Int,
        hasNewDigest: Bool
    ) {
        self._selection = selection
        self.actionQueueCount = actionQueueCount
        self.filteredCount = filteredCount
        self.hasNewDigest = hasNewDigest
    }

    public var body: some View {
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

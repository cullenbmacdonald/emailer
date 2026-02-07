import SwiftUI

/// The sidebar for iPad, showing all 5 views + Daily Digest.
/// Matches macOS sidebar layout for cross-platform consistency.
struct IOSSidebarView: View {
    @Binding var selection: IOSSidebarDestination?
    var actionQueueCount: Int
    var filteredCount: Int
    var hasNewDigest: Bool

    var body: some View {
        List(selection: $selection) {
            Section {
                ForEach(IOSSidebarDestination.mainViews) { destination in
                    IOSSidebarRow(
                        destination: destination,
                        badgeCount: badgeCount(for: destination),
                        showNewIndicator: false
                    )
                    .tag(destination)
                }
            }
            Section {
                IOSSidebarRow(
                    destination: .dailyDigest,
                    badgeCount: 0,
                    showNewIndicator: hasNewDigest
                )
                .tag(IOSSidebarDestination.dailyDigest)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Emailer")
    }

    private func badgeCount(for destination: IOSSidebarDestination) -> Int {
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

/// A single row in the iPad sidebar.
struct IOSSidebarRow: View {
    let destination: IOSSidebarDestination
    var badgeCount: Int = 0
    var showNewIndicator: Bool = false

    var body: some View {
        Label {
            HStack {
                Text(destination.title)
                Spacer()
                if showNewIndicator {
                    newBadge
                } else if badgeCount > 0 {
                    countBadge
                }
            }
        } icon: {
            Image(systemName: destination.iconName)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var countBadge: some View {
        Text("\(badgeCount)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minWidth: 22, minHeight: 22)
            .background(badgeColor, in: .capsule)
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minHeight: 22)
            .background(.blue, in: .capsule)
    }

    private var badgeColor: Color {
        switch destination {
        case .actionQueue:
            .accentColor
        case .filtered:
            .gray
        default:
            .secondary
        }
    }

    private var accessibilityText: String {
        var text = destination.title
        if showNewIndicator {
            text += ", new digest available"
        } else if badgeCount > 0 {
            text += ", \(badgeCount) items"
        }
        return text
    }
}

#Preview("iPad Sidebar") {
    NavigationSplitView {
        IOSSidebarView(
            selection: .constant(.actionQueue),
            actionQueueCount: 12,
            filteredCount: 3,
            hasNewDigest: true
        )
    } detail: {
        Text("Detail")
    }
}

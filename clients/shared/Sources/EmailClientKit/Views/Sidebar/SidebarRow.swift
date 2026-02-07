import SwiftUI

/// A single row in the sidebar, showing icon, title, and optional badge or "NEW" indicator.
public struct SidebarRow: View {
    public let destination: SidebarDestination
    public var badgeCount: Int = 0
    public var showNewIndicator: Bool = false

    public init(
        destination: SidebarDestination,
        badgeCount: Int = 0,
        showNewIndicator: Bool = false
    ) {
        self.destination = destination
        self.badgeCount = badgeCount
        self.showNewIndicator = showNewIndicator
    }

    public var body: some View {
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
            .frame(minWidth: ListRowMetrics.badgeHeight, minHeight: ListRowMetrics.badgeHeight)
            .background(badgeColor, in: .capsule)
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minHeight: ListRowMetrics.badgeHeight)
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

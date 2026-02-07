import SwiftUI

/// A single row in the sidebar, showing icon, title, and optional badge or "NEW" indicator.
struct SidebarRow: View {
    let destination: SidebarDestination
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
            .frame(minWidth: 20, minHeight: 20)
            .background(badgeColor, in: .capsule)
    }

    private var newBadge: some View {
        Text("NEW")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(minHeight: 20)
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

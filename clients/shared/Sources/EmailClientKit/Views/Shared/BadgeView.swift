import SwiftUI

/// A pill-shaped badge showing a count.
/// Hidden when count is 0.
public struct BadgeView: View {
    public let count: Int
    public var color: Color

    private var isVisible: Bool { count >= 1 }

    public init(count: Int, color: Color = .accentColor) {
        self.count = count
        self.color = color
    }

    public var body: some View {
        if isVisible {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: ListRowMetrics.badgeHeight, minHeight: ListRowMetrics.badgeHeight)
                .background(color, in: .capsule)
                .accessibilityLabel("\(count) items")
        }
    }
}

#Preview("BadgeView") {
    VStack(spacing: Spacing.md) {
        BadgeView(count: 3, color: .accentColor)
        BadgeView(count: 12, color: .snooze)
        BadgeView(count: 99, color: .filteredColor)
        BadgeView(count: 0, color: .accentColor)
    }
    .padding()
}

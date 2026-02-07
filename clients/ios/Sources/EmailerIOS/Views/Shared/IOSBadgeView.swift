import SwiftUI

/// A pill-shaped badge showing a count.
/// iOS variant: 22pt height (vs 20pt macOS).
/// Hidden when count is 0.
public struct IOSBadgeView: View {
    let count: Int
    let color: Color

    public init(count: Int, color: Color = .accentColor) {
        self.count = count
        self.color = color
    }

    public var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(
                    minWidth: IOSDesignTokens.badgeHeight,
                    minHeight: IOSDesignTokens.badgeHeight
                )
                .background(color, in: .capsule)
                .accessibilityLabel("\(count) items")
        }
    }
}

#Preview("Badges") {
    VStack(spacing: 12) {
        IOSBadgeView(count: 5, color: .accentColor)
        IOSBadgeView(count: 42, color: .snoozeFallback)
        IOSBadgeView(count: 3, color: .filteredFallback)
        IOSBadgeView(count: 0, color: .accentColor) // hidden
    }
    .padding()
}

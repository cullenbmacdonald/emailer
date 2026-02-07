import SwiftUI

/// A pill-shaped badge showing a count.
/// Hidden when count is 0.
struct BadgeView: View {
    let count: Int
    var color: Color = .accentColor

    private var isVisible: Bool { count >= 1 }

    var body: some View {
        if isVisible {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .frame(minWidth: 20, minHeight: 20)
                .background(color, in: .capsule)
                .accessibilityLabel("\(count) items")
        }
    }
}

#Preview("BadgeView") {
    VStack(spacing: Spacing.md) {
        BadgeView(count: 3, color: .accentColor)
        BadgeView(count: 12, color: .snooze)
        BadgeView(count: 99, color: .filtered)
        BadgeView(count: 0, color: .accentColor)
    }
    .padding()
}

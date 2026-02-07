import SwiftUI

/// Shows how many times an email has been snoozed ("snoozed 3x").
/// iOS variant: 22pt height (vs 20pt macOS).
/// Only visible when snoozeCount >= 2.
public struct IOSSnoozeCountBadge: View {
    let snoozeCount: Int

    public init(snoozeCount: Int) {
        self.snoozeCount = snoozeCount
    }

    public var body: some View {
        if snoozeCount >= 2 {
            Text("snoozed \(snoozeCount)x")
                .font(.caption2)
                .foregroundStyle(Color.snoozeFallback)
                .padding(.horizontal, 6)
                .frame(minHeight: IOSDesignTokens.snoozeBadgeHeight)
                .background(Color.snoozeFallback.opacity(0.15), in: .capsule)
                .accessibilityLabel("Snoozed \(snoozeCount) times")
        }
    }
}

#Preview("Snooze Badges") {
    VStack(spacing: 12) {
        IOSSnoozeCountBadge(snoozeCount: 1) // hidden
        IOSSnoozeCountBadge(snoozeCount: 2)
        IOSSnoozeCountBadge(snoozeCount: 5)
    }
    .padding()
}

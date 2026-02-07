import SwiftUI

/// Shows how many times an email has been snoozed ("snoozed 3x").
/// Only visible when snoozeCount >= 2.
public struct SnoozeCountBadge: View {
    public let snoozeCount: Int

    public init(snoozeCount: Int) {
        self.snoozeCount = snoozeCount
    }

    public var body: some View {
        if snoozeCount >= 2 {
            Text("snoozed \(snoozeCount)x")
                .font(.caption2)
                .foregroundStyle(Color.snooze)
                .padding(.horizontal, 6)
                .frame(minHeight: ListRowMetrics.snoozeBadgeHeight)
                .background(Color.snooze.opacity(0.15), in: .capsule)
                .accessibilityLabel("Snoozed \(snoozeCount) times")
        }
    }
}

#Preview("SnoozeCountBadge") {
    VStack(spacing: Spacing.md) {
        SnoozeCountBadge(snoozeCount: 1)
        SnoozeCountBadge(snoozeCount: 2)
        SnoozeCountBadge(snoozeCount: 5)
    }
    .padding()
}

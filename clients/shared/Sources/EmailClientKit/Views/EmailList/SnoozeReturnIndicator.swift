import SwiftUI

/// A 2pt purple left border with a "Returning" label, shown on emails
/// that have returned from snooze in the Action Queue.
public struct SnoozeReturnIndicator: View {
    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.snooze)
                .frame(width: 2)

            Text("Returning")
                .font(.caption2)
                .foregroundStyle(Color.snooze)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Returning from snooze")
    }
}

#Preview("SnoozeReturnIndicator") {
    SnoozeReturnIndicator()
        .padding()
}

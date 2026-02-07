import SwiftUI

/// A 2pt purple vertical accent line shown on the leading edge of
/// email rows that are returning from snooze.
public struct IOSSnoozeReturnIndicator: View {
    public init() {}

    public var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color.snoozeFallback)
            .frame(width: 2)
            .accessibilityHidden(true)
    }
}

#Preview("Snooze Return Indicator") {
    HStack(spacing: 8) {
        IOSSnoozeReturnIndicator()
            .frame(height: 72)

        Text("Email row content here")
            .foregroundStyle(.secondary)
    }
    .padding()
}

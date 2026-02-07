import SwiftUI

/// Banner shown when the app cannot reach the server.
/// Slides down from the top and auto-dismisses when connection is restored.
public struct OfflineBanner: View {
    public let pendingActionCount: Int

    public init(pendingActionCount: Int = 0) {
        self.pendingActionCount = pendingActionCount
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Server unreachable \u{2014} showing cached data")
                .font(.caption)
            if pendingActionCount > 0 {
                Text("(\(pendingActionCount) pending)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(Color.destructive)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Color.destructive.opacity(0.10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "Server unreachable, showing cached data"
        if pendingActionCount > 0 {
            text += ", \(pendingActionCount) actions pending"
        }
        return text
    }
}

#Preview("OfflineBanner") {
    VStack {
        OfflineBanner()
        OfflineBanner(pendingActionCount: 3)
        Spacer()
    }
}

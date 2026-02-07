import SwiftUI

/// Shown when the app cannot reach the Go server.
/// Adapted for iOS safe area — positioned at top of content below navigation bar.
public struct IOSOfflineBanner: View {
    let pendingActionCount: Int

    public init(pendingActionCount: Int = 0) {
        self.pendingActionCount = pendingActionCount
    }

    public var body: some View {
        HStack(spacing: IOSDesignTokens.spaceXS) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Server unreachable — showing cached data")
                .font(.caption)
            if pendingActionCount > 0 {
                Text("(\(pendingActionCount) pending)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .foregroundStyle(.red)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(.red.opacity(0.1))
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

#Preview("Offline Banner") {
    VStack {
        IOSOfflineBanner()
        IOSOfflineBanner(pendingActionCount: 3)
        Spacer()
    }
}

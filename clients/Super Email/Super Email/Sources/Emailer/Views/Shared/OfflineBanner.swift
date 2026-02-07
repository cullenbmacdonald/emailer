import SwiftUI

/// Banner shown when the app cannot reach the server.
/// Slides down from the top and auto-dismisses when connection is restored.
struct OfflineBanner: View {
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.caption)
            Text("Server unreachable \u{2014} showing cached data")
                .font(.caption)
        }
        .foregroundStyle(Color.destructive)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(Color.destructive.opacity(0.10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Offline. Showing cached data.")
    }
}

#Preview("OfflineBanner") {
    VStack {
        OfflineBanner()
        Spacer()
    }
}

import SwiftUI

/// A small colored circle indicating which email account a message belongs to.
/// iOS variant: 10pt diameter (vs 8pt macOS).
public struct IOSAccountDot: View {
    let color: Color
    let accountName: String

    public init(color: Color, accountName: String) {
        self.color = color
        self.accountName = accountName
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(
                width: IOSDesignTokens.accountDotDiameter,
                height: IOSDesignTokens.accountDotDiameter
            )
            .accessibilityLabel("\(accountName) account")
    }
}

#Preview("Account Dots") {
    HStack(spacing: 12) {
        IOSAccountDot(color: .accountWorkFallback, accountName: "Work")
        IOSAccountDot(color: .accountPersonal1Fallback, accountName: "Personal")
        IOSAccountDot(color: .accountPersonal2Fallback, accountName: "Personal 2")
    }
    .padding()
}

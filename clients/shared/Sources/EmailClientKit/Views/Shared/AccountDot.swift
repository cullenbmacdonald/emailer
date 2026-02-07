import SwiftUI

/// A small colored circle indicating which email account a message belongs to.
public struct AccountDot: View {
    let color: Color
    let accountName: String
    var size: CGFloat = ListRowMetrics.accountDotSize

    public init(color: Color, accountName: String, size: CGFloat = ListRowMetrics.accountDotSize) {
        self.color = color
        self.accountName = accountName
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .accessibilityLabel("\(accountName) account")
    }
}

#Preview("AccountDot") {
    HStack(spacing: Spacing.md) {
        AccountDot(color: .accountWork, accountName: "Work")
        AccountDot(color: .accountPersonal1, accountName: "Personal")
        AccountDot(color: .accountPersonal2, accountName: "Personal 2")
    }
    .padding()
}

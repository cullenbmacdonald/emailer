import SwiftUI

/// Toast shown after reversible actions (archive, snooze, reclassify).
/// Bottom-positioned with swipe to dismiss.
public struct IOSUndoToast: View {
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    public init(
        message: String,
        onUndo: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.message = message
        self.onUndo = onUndo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: IOSDesignTokens.spaceSM) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer()
            Button("Undo") {
                onUndo()
            }
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, IOSDesignTokens.spaceLG)
        .padding(.vertical, IOSDesignTokens.spaceSM)
        .background(.regularMaterial, in: .capsule)
        .padding(.horizontal, IOSDesignTokens.spaceLG)
        .padding(.bottom, IOSDesignTokens.spaceLG)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    if value.translation.height > 0 {
                        onDismiss()
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Double tap to undo.")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Undo Toast") {
    VStack {
        Spacer()
        IOSUndoToast(
            message: "Email archived",
            onUndo: {},
            onDismiss: {}
        )
    }
}

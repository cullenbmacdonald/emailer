import SwiftUI

/// Toast shown after reversible actions (archive, snooze, reclassify).
/// Appears at the bottom center of the content area.
/// On macOS, auto-dismisses after 5 seconds.
/// On iOS, supports swipe-to-dismiss.
public struct UndoToast: View {
    public let message: String
    public var onUndo: () -> Void
    public var onDismiss: (() -> Void)?

    @State private var isVisible: Bool = true

    public init(
        message: String,
        onUndo: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.message = message
        self.onUndo = onUndo
        self.onDismiss = onDismiss
    }

    public var body: some View {
        if isVisible {
            toastContent
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(message). Double tap to undo.")
                .accessibilityAddTraits(.isButton)
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(5))
                        dismiss()
                    }
                }
                #if os(iOS)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.height > 0 {
                                dismiss()
                            }
                        }
                )
                #endif
        }
    }

    private var toastContent: some View {
        HStack(spacing: Spacing.sm) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.primary)

            #if os(iOS)
            Spacer()
            #endif

            Button("Undo") {
                onUndo()
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.callout)
            .fontWeight(.semibold)
            .foregroundStyle(Color.accentColor)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.regularMaterial, in: .capsule)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        #if os(iOS)
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.lg)
        #endif
    }

    private func dismiss() {
        withAnimation(.easeIn(duration: 0.3)) {
            isVisible = false
        }
        onDismiss?()
    }
}

#Preview("UndoToast") {
    ZStack(alignment: .bottom) {
        Color.clear
        UndoToast(message: "Email archived") {
            // undo action
        }
        .padding(.bottom, Spacing.lg)
    }
    .frame(width: 400, height: 300)
}

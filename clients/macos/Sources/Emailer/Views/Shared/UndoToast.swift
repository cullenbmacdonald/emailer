import SwiftUI

/// Toast shown after reversible actions (archive, snooze, reclassify).
/// Appears at the bottom center of the content area and auto-dismisses after 5 seconds.
struct UndoToast: View {
    let message: String
    var onUndo: () -> Void

    @State private var isVisible: Bool = true

    var body: some View {
        if isVisible {
            HStack(spacing: Spacing.sm) {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.primary)

                Button("Undo") {
                    onUndo()
                    withAnimation(.easeIn(duration: 0.3)) {
                        isVisible = false
                    }
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
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(message). Double tap to undo.")
            .accessibilityAddTraits(.isButton)
            .onAppear {
                Task {
                    try? await Task.sleep(for: .seconds(5))
                    withAnimation(.easeIn(duration: 0.3)) {
                        isVisible = false
                    }
                }
            }
        }
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

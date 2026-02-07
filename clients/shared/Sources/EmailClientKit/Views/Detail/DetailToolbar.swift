import SwiftUI

/// Actions available from the email detail toolbar.
public enum DetailAction: String, CaseIterable, Sendable {
    case reply
    case replyAll
    case forward
    case archive
    case snooze
    case move
    case trash
}

/// Toolbar content for the email detail view.
/// Uses glass-style buttons with SF Symbols per the design system.
public struct DetailToolbar: View {
    public let onAction: (DetailAction) -> Void

    public init(onAction: @escaping (DetailAction) -> Void) {
        self.onAction = onAction
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            // Reply group
            Group {
                toolbarButton("Reply", icon: "arrowshape.turn.up.left", action: .reply)
                toolbarButton("Reply All", icon: "arrowshape.turn.up.left.2", action: .replyAll)
                toolbarButton("Forward", icon: "arrowshape.turn.up.right", action: .forward)
            }

            Divider()
                .frame(height: 20)

            // Action group
            Group {
                toolbarButton("Archive", icon: "archivebox", action: .archive)
                toolbarButton("Snooze", icon: "clock", action: .snooze)
                toolbarButton("Move", icon: "folder", action: .move)
            }

            Divider()
                .frame(height: 20)

            toolbarButton("Trash", icon: "trash", action: .trash, tint: .destructive)
        }
    }

    @ViewBuilder
    private func toolbarButton(
        _ label: String,
        icon: String,
        action: DetailAction,
        tint: Color? = nil
    ) -> some View {
        Button {
            onAction(action)
        } label: {
            Label(label, systemImage: icon)
                .labelStyle(.iconOnly)
                .foregroundStyle(tint ?? .primary)
        }
        .buttonStyle(.borderless)
        .help(label)
    }
}

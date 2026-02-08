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
            // Reply group -- morphs as connected glass group
            GlassToolbarGroup {
                toolbarButton("Reply", icon: "arrowshape.turn.up.left", action: .reply)
                toolbarButton("Reply All", icon: "arrowshape.turn.up.left.2", action: .replyAll)
                toolbarButton("Forward", icon: "arrowshape.turn.up.right", action: .forward)
            }

            // Action group -- morphs as connected glass group
            GlassToolbarGroup {
                toolbarButton("Archive", icon: "archivebox", action: .archive)
                toolbarButton("Snooze", icon: "clock", action: .snooze)
                toolbarButton("Move", icon: "folder", action: .move)
            }

            // Trash -- standalone glass button
            toolbarButton("Trash", icon: "trash", action: .trash, tint: .destructive)
                .buttonStyle(.glass(tint: .destructive))
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
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
        }
        .buttonStyle(.borderless)
        .help(label)
    }
}

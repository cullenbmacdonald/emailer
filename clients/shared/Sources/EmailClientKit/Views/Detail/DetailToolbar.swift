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
/// Provides individual toolbar items so each button gets a proper hover tooltip.
public struct DetailToolbar: ToolbarContent {
    public let onAction: (DetailAction) -> Void

    public init(onAction: @escaping (DetailAction) -> Void) {
        self.onAction = onAction
    }

    public var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button { onAction(.reply) } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
            .help("Reply")
        }
        ToolbarItem(placement: .automatic) {
            Button { onAction(.replyAll) } label: {
                Label("Reply All", systemImage: "arrowshape.turn.up.left.2")
            }
            .help("Reply All")
        }
        ToolbarItem(placement: .automatic) {
            Button { onAction(.forward) } label: {
                Label("Forward", systemImage: "arrowshape.turn.up.right")
            }
            .help("Forward")
        }
        ToolbarItem(placement: .automatic) {
            Button { onAction(.archive) } label: {
                Label("Archive", systemImage: "archivebox")
            }
            .help("Archive")
        }
        ToolbarItem(placement: .automatic) {
            Button { onAction(.snooze) } label: {
                Label("Snooze", systemImage: "clock")
            }
            .help("Snooze")
        }
        ToolbarItem(placement: .automatic) {
            Button { onAction(.move) } label: {
                Label("Move", systemImage: "folder")
            }
            .help("Move")
        }
        ToolbarItem(placement: .automatic) {
            Button { onAction(.trash) } label: {
                Label("Trash", systemImage: "trash")
            }
            .help("Trash")
        }
    }
}

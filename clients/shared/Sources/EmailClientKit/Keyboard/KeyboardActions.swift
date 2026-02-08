import SwiftUI

/// Builds the standard set of palette commands for the app.
@MainActor
public struct PaletteCommandBuilder {
    public static func buildCommands(
        appState: AppState,
        focusCoordinator: FocusCoordinator,
        onCompose: @escaping @Sendable @MainActor () -> Void,
        onReply: @escaping @Sendable @MainActor () -> Void,
        onReplyAll: @escaping @Sendable @MainActor () -> Void,
        onForward: @escaping @Sendable @MainActor () -> Void,
        onArchive: @escaping @Sendable @MainActor () -> Void,
        onSnooze: @escaping @Sendable @MainActor () -> Void,
        onTrash: @escaping @Sendable @MainActor () -> Void,
        onToggleRead: @escaping @Sendable @MainActor () -> Void
    ) -> [PaletteCommand] {
        var commands: [PaletteCommand] = []

        // Navigation commands
        let navItems: [(String, SidebarDestination, String, String)] = [
            ("nav-action", .actionQueue, "tray.and.arrow.down.fill", "Cmd+1"),
            ("nav-reading", .readingQueue, "book.fill", "Cmd+2"),
            ("nav-recommendations", .recommendations, "star.fill", "Cmd+3"),
            ("nav-filtered", .filtered, "xmark.shield", "Cmd+4"),
            ("nav-all", .allInboxes, "tray.full.fill", "Cmd+5"),
            ("nav-digest", .dailyDigest, "newspaper.fill", "Cmd+D"),
        ]
        for (id, dest, icon, hint) in navItems {
            commands.append(PaletteCommand(
                id: id,
                title: "Go to \(dest.title)",
                icon: icon,
                shortcutHint: hint,
                category: .navigation
            ) {
                appState.selectedView = dest
                focusCoordinator.dismissCommandPalette()
            })
        }

        // Account filter commands
        let filters: [(String, AccountFilter, String)] = [
            ("filter-work", .work, "Cmd+Shift+1"),
            ("filter-personal", .personal, "Cmd+Shift+2"),
            ("filter-all", .all, "Cmd+Shift+3"),
        ]
        for (id, filter, hint) in filters {
            commands.append(PaletteCommand(
                id: id,
                title: "\(filter.label) accounts",
                icon: "line.3.horizontal.decrease.circle",
                shortcutHint: hint,
                category: .accountFilter
            ) {
                appState.accountFilter = filter
                focusCoordinator.dismissCommandPalette()
            })
        }

        // Compose
        commands.append(PaletteCommand(
            id: "compose-new",
            title: "New Email",
            icon: "square.and.pencil",
            shortcutHint: "Cmd+N",
            category: .compose
        ) {
            onCompose()
            focusCoordinator.dismissCommandPalette()
        })

        // Email actions
        let emailActions: [(String, String, String, String?, @Sendable @MainActor () -> Void)] = [
            ("action-reply", "Reply", "arrowshape.turn.up.left", "R", onReply),
            ("action-reply-all", "Reply All", "arrowshape.turn.up.left.2", "A", onReplyAll),
            ("action-forward", "Forward", "arrowshape.turn.up.right", "F", onForward),
            ("action-archive", "Archive", "archivebox", "E", onArchive),
            ("action-snooze", "Snooze", "clock", "S", onSnooze),
            ("action-trash", "Trash", "trash", "#", onTrash),
            ("action-toggle-read", "Toggle Read/Unread", "envelope.badge", "U", onToggleRead),
        ]
        for (id, title, icon, hint, action) in emailActions {
            commands.append(PaletteCommand(
                id: id,
                title: title,
                icon: icon,
                shortcutHint: hint,
                category: .emailAction
            ) {
                action()
                focusCoordinator.dismissCommandPalette()
            })
        }

        return commands
    }
}

/// Handles single-key (Layer 2) keyboard events when the email list has focus.
@MainActor
public struct EmailListKeyHandler {
    public let appState: AppState
    public let emailStore: EmailStore
    public let focusCoordinator: FocusCoordinator
    public let onReply: () -> Void
    public let onReplyAll: () -> Void
    public let onForward: () -> Void
    public let onArchive: () -> Void
    public let onSnooze: () -> Void
    public let onMove: () -> Void
    public let onTrash: () -> Void
    public let onToggleRead: () -> Void
    public let onSearch: () -> Void
    public let onCompose: () -> Void

    public init(
        appState: AppState,
        emailStore: EmailStore,
        focusCoordinator: FocusCoordinator,
        onReply: @escaping () -> Void = {},
        onReplyAll: @escaping () -> Void = {},
        onForward: @escaping () -> Void = {},
        onArchive: @escaping () -> Void = {},
        onSnooze: @escaping () -> Void = {},
        onMove: @escaping () -> Void = {},
        onTrash: @escaping () -> Void = {},
        onToggleRead: @escaping () -> Void = {},
        onSearch: @escaping () -> Void = {},
        onCompose: @escaping () -> Void = {}
    ) {
        self.appState = appState
        self.emailStore = emailStore
        self.focusCoordinator = focusCoordinator
        self.onReply = onReply
        self.onReplyAll = onReplyAll
        self.onForward = onForward
        self.onArchive = onArchive
        self.onSnooze = onSnooze
        self.onMove = onMove
        self.onTrash = onTrash
        self.onToggleRead = onToggleRead
        self.onSearch = onSearch
        self.onCompose = onCompose
    }

    /// Get the current email list for the selected view.
    public var currentEmailList: [Email] {
        guard let view = appState.selectedView else { return [] }
        switch view {
        case .actionQueue: return emailStore.actionQueue
        case .readingQueue: return emailStore.readingQueue
        case .filtered: return emailStore.filtered
        case .allInboxes: return emailStore.allInboxes
        default: return []
        }
    }

    /// Navigate down in the email list (J key).
    public func navigateDown() {
        let list = currentEmailList
        guard !list.isEmpty else { return }

        if let currentID = appState.selectedEmailID,
           let index = list.firstIndex(where: { $0.id == currentID }) {
            let nextIndex = min(index + 1, list.count - 1)
            appState.selectedEmailID = list[nextIndex].id
        } else {
            appState.selectedEmailID = list.first?.id
        }
    }

    /// Navigate up in the email list (K key).
    public func navigateUp() {
        let list = currentEmailList
        guard !list.isEmpty else { return }

        if let currentID = appState.selectedEmailID,
           let index = list.firstIndex(where: { $0.id == currentID }) {
            let prevIndex = max(index - 1, 0)
            appState.selectedEmailID = list[prevIndex].id
        } else {
            appState.selectedEmailID = list.last?.id
        }
    }

    /// Handle a key press. Returns true if handled.
    #if os(macOS)
    public func handleKeyPress(_ key: KeyEquivalent) -> KeyPress.Result {
        guard focusCoordinator.singleKeyShortcutsEnabled else { return .ignored }

        switch key {
        case "j":
            navigateDown()
            return .handled
        case "k":
            navigateUp()
            return .handled
        case KeyEquivalent("\r"): // Enter
            if appState.selectedEmailID != nil {
                focusCoordinator.activeFocus = .emailDetail
            }
            return .handled
        case KeyEquivalent("\u{1B}"): // Escape
            handleEscape()
            return .handled
        case "r":
            if appState.selectedEmailID != nil { onReply() }
            return .handled
        case "a":
            if appState.selectedEmailID != nil { onReplyAll() }
            return .handled
        case "f":
            if appState.selectedEmailID != nil { onForward() }
            return .handled
        case "e":
            if appState.selectedEmailID != nil { onArchive() }
            return .handled
        case "s":
            if appState.selectedEmailID != nil { onSnooze() }
            return .handled
        case "m":
            if appState.selectedEmailID != nil { onMove() }
            return .handled
        case "#":
            if appState.selectedEmailID != nil { onTrash() }
            return .handled
        case "u":
            if appState.selectedEmailID != nil { onToggleRead() }
            return .handled
        case "/":
            onSearch()
            focusCoordinator.activeFocus = .searchField
            return .handled
        case "?":
            focusCoordinator.showShortcutHelp()
            return .handled
        case KeyEquivalent("\t"): // Tab
            focusCoordinator.cycleFocusForward()
            return .handled
        default:
            return .ignored
        }
    }
    #endif

    /// Handle escape key behavior.
    public func handleEscape() {
        if focusCoordinator.isCommandPaletteVisible {
            focusCoordinator.dismissCommandPalette()
        } else if focusCoordinator.isShortcutHelpVisible {
            focusCoordinator.dismissShortcutHelp()
        } else {
            focusCoordinator.returnFocusToList()
        }
    }
}

import SwiftUI
import Observation

/// Tracks which area of the app currently has keyboard focus.
/// Single-key shortcuts (J, K, R, etc.) only fire when a non-text area has focus.
@Observable
@MainActor
public final class FocusCoordinator {
    /// The areas of the app that can hold focus.
    public enum FocusArea: String, Sendable, Equatable {
        case sidebar
        case emailList
        case emailDetail
        case composeBody
        case searchField
        case commandPalette
        case snoozePicker
    }

    /// The currently active focus area.
    public var activeFocus: FocusArea = .emailList

    /// Whether the command palette is showing.
    public var isCommandPaletteVisible: Bool = false

    /// Whether the shortcut help overlay is showing.
    public var isShortcutHelpVisible: Bool = false

    public init() {}

    /// Whether single-key shortcuts should be active (not in a text input).
    public var singleKeyShortcutsEnabled: Bool {
        switch activeFocus {
        case .composeBody, .searchField, .commandPalette:
            return false
        case .sidebar, .emailList, .emailDetail, .snoozePicker:
            return true
        }
    }

    /// Cycle focus forward: sidebar -> list -> detail.
    public func cycleFocusForward() {
        switch activeFocus {
        case .sidebar:
            activeFocus = .emailList
        case .emailList:
            activeFocus = .emailDetail
        case .emailDetail:
            activeFocus = .sidebar
        default:
            activeFocus = .emailList
        }
    }

    /// Return focus to the email list (used by Escape).
    public func returnFocusToList() {
        activeFocus = .emailList
        isCommandPaletteVisible = false
        isShortcutHelpVisible = false
    }

    /// Show the command palette.
    public func showCommandPalette() {
        isCommandPaletteVisible = true
        activeFocus = .commandPalette
    }

    /// Dismiss the command palette.
    public func dismissCommandPalette() {
        isCommandPaletteVisible = false
        activeFocus = .emailList
    }

    /// Show shortcut help overlay.
    public func showShortcutHelp() {
        isShortcutHelpVisible = true
    }

    /// Dismiss shortcut help overlay.
    public func dismissShortcutHelp() {
        isShortcutHelpVisible = false
    }
}

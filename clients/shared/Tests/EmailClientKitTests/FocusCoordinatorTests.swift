import Testing
@testable import EmailClientKit

@Suite("FocusCoordinator")
@MainActor
struct FocusCoordinatorTests {
    @Test("Initial state is emailList")
    func initialState() {
        let coord = FocusCoordinator()
        #expect(coord.activeFocus == .emailList)
        #expect(!coord.isCommandPaletteVisible)
        #expect(!coord.isShortcutHelpVisible)
    }

    @Test("Single key shortcuts enabled for non-text areas")
    func singleKeyShortcutsEnabled() {
        let coord = FocusCoordinator()

        // Enabled by default (emailList)
        #expect(coord.singleKeyShortcutsEnabled)

        // Enabled for sidebar
        coord.activeFocus = .sidebar
        #expect(coord.singleKeyShortcutsEnabled)

        // Enabled for detail
        coord.activeFocus = .emailDetail
        #expect(coord.singleKeyShortcutsEnabled)

        // Disabled for text inputs
        coord.activeFocus = .composeBody
        #expect(!coord.singleKeyShortcutsEnabled)

        coord.activeFocus = .searchField
        #expect(!coord.singleKeyShortcutsEnabled)

        coord.activeFocus = .commandPalette
        #expect(!coord.singleKeyShortcutsEnabled)
    }

    @Test("Cycle focus forward: sidebar -> list -> detail -> sidebar")
    func cycleFocusForward() {
        let coord = FocusCoordinator()
        coord.activeFocus = .sidebar
        coord.cycleFocusForward()
        #expect(coord.activeFocus == .emailList)

        coord.cycleFocusForward()
        #expect(coord.activeFocus == .emailDetail)

        coord.cycleFocusForward()
        #expect(coord.activeFocus == .sidebar)
    }

    @Test("Cycle focus from non-standard area defaults to list")
    func cycleFocusFromNonStandard() {
        let coord = FocusCoordinator()
        coord.activeFocus = .composeBody
        coord.cycleFocusForward()
        #expect(coord.activeFocus == .emailList)
    }

    @Test("Return focus to list dismisses overlays")
    func returnFocusToList() {
        let coord = FocusCoordinator()
        coord.activeFocus = .emailDetail
        coord.isCommandPaletteVisible = true
        coord.isShortcutHelpVisible = true

        coord.returnFocusToList()

        #expect(coord.activeFocus == .emailList)
        #expect(!coord.isCommandPaletteVisible)
        #expect(!coord.isShortcutHelpVisible)
    }

    @Test("Show command palette sets focus")
    func showCommandPalette() {
        let coord = FocusCoordinator()
        coord.showCommandPalette()

        #expect(coord.isCommandPaletteVisible)
        #expect(coord.activeFocus == .commandPalette)
    }

    @Test("Dismiss command palette returns to list")
    func dismissCommandPalette() {
        let coord = FocusCoordinator()
        coord.showCommandPalette()
        coord.dismissCommandPalette()

        #expect(!coord.isCommandPaletteVisible)
        #expect(coord.activeFocus == .emailList)
    }

    @Test("Show and dismiss shortcut help")
    func shortcutHelp() {
        let coord = FocusCoordinator()
        coord.showShortcutHelp()
        #expect(coord.isShortcutHelpVisible)

        coord.dismissShortcutHelp()
        #expect(!coord.isShortcutHelpVisible)
    }
}

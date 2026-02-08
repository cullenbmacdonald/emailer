import Testing
@testable import EmailClientKit

@Suite("PaletteCommandBuilder")
@MainActor
struct PaletteCommandBuilderTests {
    @Test("Builds all expected commands")
    func buildsAllCommands() {
        let appState = AppState()
        let focusCoordinator = FocusCoordinator()

        let commands = PaletteCommandBuilder.buildCommands(
            appState: appState,
            focusCoordinator: focusCoordinator,
            onCompose: {},
            onReply: {},
            onReplyAll: {},
            onForward: {},
            onArchive: {},
            onSnooze: {},
            onTrash: {},
            onToggleRead: {}
        )

        // 6 navigation + 3 account filter + 1 compose + 7 email actions = 17
        #expect(commands.count == 17)
    }

    @Test("Navigation commands switch views")
    func navigationCommandsSwitchViews() {
        let appState = AppState()
        let focusCoordinator = FocusCoordinator()
        focusCoordinator.showCommandPalette()

        let commands = PaletteCommandBuilder.buildCommands(
            appState: appState,
            focusCoordinator: focusCoordinator,
            onCompose: {},
            onReply: {},
            onReplyAll: {},
            onForward: {},
            onArchive: {},
            onSnooze: {},
            onTrash: {},
            onToggleRead: {}
        )

        // Find "Go to Reading Queue" command and execute it
        let readingCmd = commands.first { $0.id == "nav-reading" }
        #expect(readingCmd != nil)
        readingCmd?.action()

        #expect(appState.selectedView == .readingQueue)
        #expect(!focusCoordinator.isCommandPaletteVisible)
    }

    @Test("Account filter commands change filter")
    func accountFilterCommands() {
        let appState = AppState()
        let focusCoordinator = FocusCoordinator()

        let commands = PaletteCommandBuilder.buildCommands(
            appState: appState,
            focusCoordinator: focusCoordinator,
            onCompose: {},
            onReply: {},
            onReplyAll: {},
            onForward: {},
            onArchive: {},
            onSnooze: {},
            onTrash: {},
            onToggleRead: {}
        )

        let workCmd = commands.first { $0.id == "filter-work" }
        #expect(workCmd != nil)
        workCmd?.action()

        #expect(appState.accountFilter == .work)
    }

    @Test("Commands have categories")
    func commandsHaveCategories() {
        let appState = AppState()
        let focusCoordinator = FocusCoordinator()

        let commands = PaletteCommandBuilder.buildCommands(
            appState: appState,
            focusCoordinator: focusCoordinator,
            onCompose: {},
            onReply: {},
            onReplyAll: {},
            onForward: {},
            onArchive: {},
            onSnooze: {},
            onTrash: {},
            onToggleRead: {}
        )

        let navCommands = commands.filter { $0.category == .navigation }
        let actionCommands = commands.filter { $0.category == .emailAction }
        let filterCommands = commands.filter { $0.category == .accountFilter }
        let composeCommands = commands.filter { $0.category == .compose }

        #expect(navCommands.count == 6)
        #expect(actionCommands.count == 7)
        #expect(filterCommands.count == 3)
        #expect(composeCommands.count == 1)
    }
}

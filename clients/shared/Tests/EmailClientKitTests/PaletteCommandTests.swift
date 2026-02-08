import Testing
@testable import EmailClientKit

@Suite("PaletteCommand")
struct PaletteCommandTests {
    @Test("Matches empty query returns true")
    func matchesEmptyQuery() {
        let cmd = PaletteCommand(
            id: "test",
            title: "Go to Action Queue",
            icon: "tray",
            category: .navigation
        ) {}
        #expect(cmd.matches(""))
    }

    @Test("Matches title substring case-insensitive")
    func matchesTitleSubstring() {
        let cmd = PaletteCommand(
            id: "test",
            title: "Go to Action Queue",
            icon: "tray",
            category: .navigation
        ) {}
        #expect(cmd.matches("action"))
        #expect(cmd.matches("ACTION"))
        #expect(cmd.matches("queue"))
    }

    @Test("Matches category")
    func matchesCategory() {
        let cmd = PaletteCommand(
            id: "test",
            title: "Archive",
            icon: "archivebox",
            category: .emailAction
        ) {}
        #expect(cmd.matches("email"))
    }

    @Test("Does not match unrelated query")
    func doesNotMatch() {
        let cmd = PaletteCommand(
            id: "test",
            title: "Archive",
            icon: "archivebox",
            category: .emailAction
        ) {}
        #expect(!cmd.matches("snooze"))
    }

    @Test("Shortcut hint is optional")
    func shortcutHintOptional() {
        let withHint = PaletteCommand(
            id: "1", title: "Test", icon: "star",
            shortcutHint: "Cmd+1", category: .navigation
        ) {}
        let withoutHint = PaletteCommand(
            id: "2", title: "Test", icon: "star",
            category: .navigation
        ) {}
        #expect(withHint.shortcutHint == "Cmd+1")
        #expect(withoutHint.shortcutHint == nil)
    }
}

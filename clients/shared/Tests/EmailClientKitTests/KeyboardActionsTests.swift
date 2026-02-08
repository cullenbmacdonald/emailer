import Testing
@testable import EmailClientKit

@Suite("EmailListKeyHandler")
@MainActor
struct EmailListKeyHandlerTests {
    // MARK: - Helpers

    private func makeTestEmails(count: Int) -> [Email] {
        (0..<count).map { i in
            TestHelpers.makeEmail(id: "email-\(i)", subject: "Email \(i)")
        }
    }

    // MARK: - Navigate Down (J)

    @Test("Navigate down selects first email when none selected")
    func navigateDownFromNone() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let emails = (0..<3).map { TestHelpers.makeEmail(id: "email-\($0)") }
        emailStore.setEmails(emails, for: .actionQueue)
        appState.selectedView = .actionQueue

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateDown()
        #expect(appState.selectedEmailID == "email-0")
    }

    @Test("Navigate down moves to next email")
    func navigateDownToNext() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let emails = (0..<3).map { TestHelpers.makeEmail(id: "email-\($0)") }
        emailStore.setEmails(emails, for: .actionQueue)
        appState.selectedView = .actionQueue
        appState.selectedEmailID = "email-0"

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateDown()
        #expect(appState.selectedEmailID == "email-1")
    }

    @Test("Navigate down stops at last email")
    func navigateDownStopsAtEnd() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let emails = (0..<3).map { TestHelpers.makeEmail(id: "email-\($0)") }
        emailStore.setEmails(emails, for: .actionQueue)
        appState.selectedView = .actionQueue
        appState.selectedEmailID = "email-2"

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateDown()
        #expect(appState.selectedEmailID == "email-2")
    }

    // MARK: - Navigate Up (K)

    @Test("Navigate up selects last email when none selected")
    func navigateUpFromNone() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let emails = (0..<3).map { TestHelpers.makeEmail(id: "email-\($0)") }
        emailStore.setEmails(emails, for: .actionQueue)
        appState.selectedView = .actionQueue

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateUp()
        #expect(appState.selectedEmailID == "email-2")
    }

    @Test("Navigate up moves to previous email")
    func navigateUpToPrevious() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let emails = (0..<3).map { TestHelpers.makeEmail(id: "email-\($0)") }
        emailStore.setEmails(emails, for: .actionQueue)
        appState.selectedView = .actionQueue
        appState.selectedEmailID = "email-2"

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateUp()
        #expect(appState.selectedEmailID == "email-1")
    }

    @Test("Navigate up stops at first email")
    func navigateUpStopsAtStart() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let emails = (0..<3).map { TestHelpers.makeEmail(id: "email-\($0)") }
        emailStore.setEmails(emails, for: .actionQueue)
        appState.selectedView = .actionQueue
        appState.selectedEmailID = "email-0"

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateUp()
        #expect(appState.selectedEmailID == "email-0")
    }

    // MARK: - Current Email List

    @Test("Current email list returns correct list for each view")
    func currentEmailListPerView() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()

        let actionEmails = [TestHelpers.makeEmail(id: "a1")]
        let readingEmails = [TestHelpers.makeEmail(id: "r1"), TestHelpers.makeEmail(id: "r2")]

        emailStore.setEmails(actionEmails, for: .actionQueue)
        emailStore.setEmails(readingEmails, for: .readingQueue)

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        appState.selectedView = .actionQueue
        #expect(handler.currentEmailList.count == 1)

        appState.selectedView = .readingQueue
        #expect(handler.currentEmailList.count == 2)

        appState.selectedView = .dailyDigest
        #expect(handler.currentEmailList.isEmpty)
    }

    // MARK: - Escape

    @Test("Escape dismisses command palette first")
    func escapeDissmissesCommandPalette() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()
        focusCoordinator.showCommandPalette()

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.handleEscape()
        #expect(!focusCoordinator.isCommandPaletteVisible)
    }

    @Test("Escape dismisses shortcut help")
    func escapeDismissesShortcutHelp() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()
        focusCoordinator.showShortcutHelp()

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.handleEscape()
        #expect(!focusCoordinator.isShortcutHelpVisible)
    }

    @Test("Escape returns focus to list when no overlays")
    func escapeReturnsFocusToList() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()
        focusCoordinator.activeFocus = .emailDetail

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.handleEscape()
        #expect(focusCoordinator.activeFocus == .emailList)
    }

    // MARK: - Empty List

    @Test("Navigate on empty list does nothing")
    func navigateOnEmptyList() {
        let appState = AppState()
        let emailStore = EmailStore()
        let focusCoordinator = FocusCoordinator()
        appState.selectedView = .actionQueue

        let handler = EmailListKeyHandler(
            appState: appState,
            emailStore: emailStore,
            focusCoordinator: focusCoordinator
        )

        handler.navigateDown()
        #expect(appState.selectedEmailID == nil)

        handler.navigateUp()
        #expect(appState.selectedEmailID == nil)
    }
}

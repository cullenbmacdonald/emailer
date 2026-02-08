#if os(macOS)
import SwiftUI

/// Menu bar commands (Layer 1) -- global keyboard shortcuts via Cmd+key.
public struct AppCommands: Commands {
    @Bindable var appState: AppState
    @Bindable var focusCoordinator: FocusCoordinator

    public init(appState: AppState, focusCoordinator: FocusCoordinator) {
        self.appState = appState
        self.focusCoordinator = focusCoordinator
    }

    public var body: some Commands {
        // View navigation
        CommandMenu("Navigate") {
            Button("Action Queue") {
                appState.selectedView = .actionQueue
            }
            .keyboardShortcut("1", modifiers: .command)

            Button("Reading Queue") {
                appState.selectedView = .readingQueue
            }
            .keyboardShortcut("2", modifiers: .command)

            Button("Recommendations") {
                appState.selectedView = .recommendations
            }
            .keyboardShortcut("3", modifiers: .command)

            Button("Filtered") {
                appState.selectedView = .filtered
            }
            .keyboardShortcut("4", modifiers: .command)

            Button("All Inboxes") {
                appState.selectedView = .allInboxes
            }
            .keyboardShortcut("5", modifiers: .command)

            Divider()

            Button("Daily Digest") {
                appState.selectedView = .dailyDigest
            }
            .keyboardShortcut("d", modifiers: .command)

            Divider()

            Button("Command Palette") {
                focusCoordinator.showCommandPalette()
            }
            .keyboardShortcut("k", modifiers: .command)
        }

        // Account filters
        CommandMenu("Accounts") {
            Button("Work Accounts Only") {
                appState.accountFilter = .work
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])

            Button("Personal Accounts Only") {
                appState.accountFilter = .personal
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])

            Button("All Accounts") {
                appState.accountFilter = .all
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])
        }

        // Compose
        CommandGroup(replacing: .newItem) {
            Button("New Email") {
                // Will be handled by compose window (M-2.6)
                NotificationCenter.default.post(
                    name: .composeNewEmail,
                    object: nil
                )
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}

extension Notification.Name {
    /// Posted when the user triggers Cmd+N to compose a new email.
    public static let composeNewEmail = Notification.Name("composeNewEmail")

    /// Posted when the user triggers Cmd+Enter to send an email.
    public static let sendEmail = Notification.Name("sendEmail")
}
#endif

#if os(macOS)
import SwiftUI

/// Menu bar extra content showing action queue count and connection status.
/// Intended to be used with `.menuBarExtraStyle(.menu)` in the App scene.
///
/// Usage in app entry point:
/// ```swift
/// MenuBarExtra {
///     MenuBarView(actionQueueCount: appState.actionQueueUnreadCount,
///                 isConnected: appState.isConnected)
/// } label: {
///     Image(systemName: "envelope")
/// }
/// .menuBarExtraStyle(.menu)
/// ```
public struct MenuBarView: View {
    public let actionQueueCount: Int
    public let isConnected: Bool
    public let onNewEmail: () -> Void
    public let onOpenApp: () -> Void

    public init(
        actionQueueCount: Int,
        isConnected: Bool,
        onNewEmail: @escaping () -> Void = {},
        onOpenApp: @escaping () -> Void = {}
    ) {
        self.actionQueueCount = actionQueueCount
        self.isConnected = isConnected
        self.onNewEmail = onNewEmail
        self.onOpenApp = onOpenApp
    }

    public var body: some View {
        Group {
            Button("Action Queue: \(actionQueueCount)") {
                onOpenApp()
            }

            Divider()

            Button("New Email") {
                onNewEmail()
            }
            .keyboardShortcut("n", modifiers: .command)

            Divider()

            HStack {
                Image(systemName: isConnected ? "wifi" : "wifi.slash")
                Text(isConnected ? "Connected" : "Disconnected")
            }
            .disabled(true)
        }
    }
}

/// Provides the menu bar extra icon label.
/// Shows an envelope icon, optionally with a badge.
public struct MenuBarLabel: View {
    public let actionQueueCount: Int

    public init(actionQueueCount: Int) {
        self.actionQueueCount = actionQueueCount
    }

    public var body: some View {
        Image(systemName: actionQueueCount > 0 ? "envelope.badge" : "envelope")
    }
}
#endif

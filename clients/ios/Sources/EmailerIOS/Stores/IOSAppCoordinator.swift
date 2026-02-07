import Foundation
import Observation
import EmailClientKit

/// Coordinates app lifecycle, server discovery, and store initialization.
///
/// On launch, the coordinator discovers the server, connects the API client
/// and WebSocket, and populates stores with initial data.
/// Server connection logic is stubbed until M-1.3 (API client) lands.
@MainActor
@Observable
public final class IOSAppCoordinator {
    public let appState: IOSAppState

    public init(appState: IOSAppState) {
        self.appState = appState
    }

    /// Start the coordinator: discover server, connect, and fetch initial data.
    /// Currently stubbed — real implementation depends on M-1.3 (API client).
    public func start() async {
        // TODO: M-1.3 — Discover server via Bonjour/mDNS or saved URL
        // TODO: M-1.3 — Initialize APIClient with server URL
        // TODO: M-1.4 — Connect WebSocket for real-time updates
        // TODO: M-1.3 — Fetch initial data for all views

        // Mark connected once server is reachable (stubbed as true for now)
        appState.isConnected = true
    }

    /// Handle app moving to background: disconnect WebSocket, save state.
    public func didEnterBackground() {
        // TODO: M-1.4 — Disconnect WebSocket
        // TODO: M-1.5 — Save current state to local cache
    }

    /// Handle app returning to foreground: reconnect and sync.
    public func willEnterForeground() async {
        // TODO: M-1.3 — Fetch changes since last sync
        // TODO: M-1.4 — Reconnect WebSocket
    }
}

import SwiftUI
import Observation

/// Observable state for the app's navigation and connection status.
@Observable
@MainActor
public final class AppState {
    /// The currently selected sidebar destination.
    public var selectedView: SidebarDestination? = .actionQueue

    /// Whether the app is connected to the server.
    public var isConnected: Bool = false

    /// A user-facing error message, if any.
    public var errorMessage: String?

    public init() {}
}

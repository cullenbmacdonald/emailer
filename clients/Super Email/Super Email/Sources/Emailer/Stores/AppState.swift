import SwiftUI
import Observation

/// Observable state for the app's navigation and connection status.
@Observable
@MainActor
public final class AppState {
    /// The currently selected sidebar destination.
    public var selectedView: SidebarDestination? = .actionQueue

    /// The ID of the currently selected email in the list.
    public var selectedEmailID: String?

    /// The active account filter (All, Work, Personal).
    public var accountFilter: AccountFilter = .all

    /// Whether the app is connected to the server.
    public var isConnected: Bool = false

    /// A user-facing error message, if any.
    public var errorMessage: String?

    public init() {}
}

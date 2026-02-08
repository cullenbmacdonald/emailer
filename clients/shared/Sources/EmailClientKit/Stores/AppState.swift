import SwiftUI
import Observation

/// Observable state for the app's navigation and connection status.
/// Shared between macOS and iOS with platform-specific navigation properties.
@Observable
@MainActor
public final class AppState {
    // MARK: - Sidebar selection (macOS + iPad)

    /// The currently selected sidebar destination.
    public var selectedView: SidebarDestination? = .actionQueue

    /// The ID of the currently selected email in the list.
    public var selectedEmailID: String?

    /// The active account filter.
    public var accountFilter: AccountFilter = .all

    // MARK: - Connectivity

    /// Whether the app is connected to the server.
    public var isConnected: Bool = false

    /// The API client, available after server discovery.
    public var apiClient: APIClient?

    /// A user-facing error message, if any.
    public var errorMessage: String?

    /// Number of offline actions pending sync.
    public var pendingActionCount: Int = 0

    /// Whether the app is currently offline (not connected to server).
    public var isOffline: Bool { !isConnected }

    // MARK: - Badge counts

    /// Unread count for the Action Queue badge.
    public var actionQueueUnreadCount: Int = 0

    /// Uncertain item count for the Filtered badge.
    public var filteredUncertainCount: Int = 0

    /// Whether a new digest is available (shows "NEW" indicator).
    public var hasNewDigest: Bool = false

    /// Whether the digest sheet is presented (iOS).
    public var showDigestSheet: Bool = false

    /// Whether the compose sheet is presented.
    public var showComposeSheet: Bool = false

    /// The compose mode for the currently presented compose sheet.
    public var composeMode: ComposeMode?

    /// All email accounts fetched from the server.
    public var accounts: [Account] = []

    #if os(iOS)
    // MARK: - Tab selection (iPhone)

    /// The currently selected tab on iPhone.
    public var selectedTab: TabDestination = .actionQueue
    #endif

    public init() {}
}

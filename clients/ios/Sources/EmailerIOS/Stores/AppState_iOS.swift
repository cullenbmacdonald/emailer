import Foundation
import Observation

/// App-wide observable state for the iOS app.
///
/// Provides reactive counts for badges, account filter state,
/// and connectivity status. Stores are injected into the SwiftUI
/// environment at the root level.
@Observable
public final class AppState_iOS: Sendable {
    // MARK: - Badge counts

    /// Unread count for the Action Queue tab badge.
    public var actionQueueUnreadCount: Int = 0

    /// Uncertain item count for the Filtered badge in More tab.
    public var filteredUncertainCount: Int = 0

    /// Whether a new digest is available (shows "NEW" indicator).
    public var hasNewDigest: Bool = false

    // MARK: - Account filter

    /// The currently selected account filter. `nil` means "All Accounts".
    public var accountFilter: AccountFilter = .all

    // MARK: - Connectivity

    /// Whether the app is connected to the server.
    public var isConnected: Bool = false

    // MARK: - Tab selection (iPhone)

    /// The currently selected tab on iPhone.
    public var selectedTab: TabDestination = .actionQueue

    // MARK: - Sidebar selection (iPad)

    /// The currently selected sidebar destination on iPad.
    public var selectedSidebarDestination: SidebarDestination_iOS? = .actionQueue

    public init() {}
}

/// Account filter options.
public enum AccountFilter: Hashable, Sendable {
    case all
    case account(id: String, name: String)
}

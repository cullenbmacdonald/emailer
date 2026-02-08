import Foundation
import Observation
import os

/// Cache keys used by AppCoordinator for local persistence.
enum CacheKey {
    static let actionQueue = "emails/action_queue"
    static let readingQueue = "emails/reading_queue"
    static let filtered = "emails/filtered"
    static let allInboxes = "emails/all_inboxes"
    static let recommendations = "recommendations/list"
    static let latestDigest = "digest/latest"
    static let accounts = "accounts/list"
}

/// Orchestrates server discovery, API client connection, WebSocket connection,
/// initial data fetching, event routing to stores, and offline caching.
@Observable
@MainActor
public final class AppCoordinator {
    public let appState: AppState
    public let emailStore: EmailStore
    public let recommendationStore: RecommendationStore
    public let digestStore: DigestStore
    public let localCache: LocalCache
    public let offlineQueue: OfflineActionQueue

    public internal(set) var apiClient: APIClient?
    public private(set) var webSocketManager: WebSocketManager?

    private var eventRoutingTask: Task<Void, Never>?
    private var reconnectionTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.cullenbmacdonald.emailer", category: "AppCoordinator")

    /// Interval between reconnection attempts when offline (seconds).
    public static let reconnectionInterval: TimeInterval = 15

    public init(
        appState: AppState,
        emailStore: EmailStore,
        recommendationStore: RecommendationStore,
        digestStore: DigestStore,
        localCache: LocalCache = LocalCache(),
        offlineQueue: OfflineActionQueue = OfflineActionQueue()
    ) {
        self.appState = appState
        self.emailStore = emailStore
        self.recommendationStore = recommendationStore
        self.digestStore = digestStore
        self.localCache = localCache
        self.offlineQueue = offlineQueue
    }

    /// Start the app: load cached data, discover server, connect API + WebSocket, fetch initial data.
    public func start() {
        Task {
            await loadCachedData()
            await updatePendingCount()
            await connectToServer()
        }
    }

    /// Stop event routing and disconnect WebSocket.
    public func stop() {
        eventRoutingTask?.cancel()
        eventRoutingTask = nil
        reconnectionTask?.cancel()
        reconnectionTask = nil
        Task {
            await webSocketManager?.disconnect()
        }
    }

    #if os(iOS)
    /// Handle app moving to background: disconnect WebSocket, save state.
    public func didEnterBackground() {
        // TODO: Disconnect WebSocket, save state to local cache
    }

    /// Handle app returning to foreground: reconnect and sync.
    public func willEnterForeground() async {
        // TODO: Fetch changes since last sync, reconnect WebSocket
    }
    #endif

    // MARK: - Cache Loading

    /// Load cached data from disk into stores for instant display.
    public func loadCachedData() async {
        if let emails: [Email] = await localCache.load([Email].self, key: CacheKey.actionQueue) {
            emailStore.setEmails(emails, for: .actionQueue)
        }
        if let emails: [Email] = await localCache.load([Email].self, key: CacheKey.readingQueue) {
            emailStore.setEmails(emails, for: .readingQueue)
        }
        if let emails: [Email] = await localCache.load([Email].self, key: CacheKey.filtered) {
            emailStore.setEmails(emails, for: .filtered)
        }
        if let emails: [Email] = await localCache.load([Email].self, key: CacheKey.allInboxes) {
            emailStore.setEmails(emails, for: .allInboxes)
        }
        if let recs: [Recommendation] = await localCache.load([Recommendation].self, key: CacheKey.recommendations) {
            recommendationStore.setRecommendations(recs)
        }
        if let digest: DailyDigest = await localCache.load(DailyDigest.self, key: CacheKey.latestDigest) {
            digestStore.setLatestDigest(digest)
        }
    }

    /// Update cache after a successful server fetch.
    public func cacheCurrentData() async {
        try? await localCache.save(emailStore.actionQueue, key: CacheKey.actionQueue)
        try? await localCache.save(emailStore.readingQueue, key: CacheKey.readingQueue)
        try? await localCache.save(emailStore.filtered, key: CacheKey.filtered)
        try? await localCache.save(emailStore.allInboxes, key: CacheKey.allInboxes)
        try? await localCache.save(recommendationStore.recommendations, key: CacheKey.recommendations)
        if let digest = digestStore.latestDigest {
            try? await localCache.save(digest, key: CacheKey.latestDigest)
        }
    }

    // MARK: - Offline Action Queue

    /// Enqueue an offline action and update pending count.
    public func enqueueOfflineAction(_ action: OfflineAction) async {
        await offlineQueue.enqueue(action)
        await updatePendingCount()
    }

    /// Update the pending action count in app state.
    public func updatePendingCount() async {
        appState.pendingActionCount = await offlineQueue.pendingCount
    }

    /// Flush the offline action queue. Returns the failed action, if any.
    @discardableResult
    public func flushOfflineQueue() async -> OfflineAction? {
        guard let client = apiClient else { return nil }
        let failedAction = await offlineQueue.flush(apiClient: client)
        await updatePendingCount()
        if let failedAction {
            logger.warning("Flush stopped at: \(String(describing: failedAction))")
            appState.errorMessage = "Some offline actions failed to sync"
        }
        return failedAction
    }

    // MARK: - Server Connection

    private func connectToServer() async {
        let discovery = ServerDiscovery()
        do {
            let serverURL = try await discovery.discover()
            logger.info("Discovered server at \(serverURL.absoluteString)")

            let client = APIClient(baseURL: serverURL, token: "change-me-to-a-secret")
            self.apiClient = client
            appState.apiClient = client
            appState.isConnected = true
            appState.errorMessage = nil

            // Stop any reconnection timer
            reconnectionTask?.cancel()
            reconnectionTask = nil

            // Flush queued offline actions
            await flushOfflineQueue()

            await startWebSocket(baseURL: serverURL)
            await fetchInitialData(client: client)

            // Cache data after successful fetch
            await cacheCurrentData()
        } catch {
            logger.error("Server discovery failed: \(error.localizedDescription)")
            appState.isConnected = false
            appState.errorMessage = "Unable to connect to server"

            // Start reconnection timer
            startReconnectionTimer()
        }
    }

    // MARK: - Reconnection

    /// Start a timer that attempts reconnection every 15 seconds.
    private func startReconnectionTimer() {
        reconnectionTask?.cancel()
        reconnectionTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.reconnectionInterval))
                guard !Task.isCancelled else { return }
                self?.logger.info("Attempting reconnection...")
                await self?.attemptReconnection()
                // If connected, stop the timer
                if self?.appState.isConnected == true {
                    return
                }
            }
        }
    }

    /// Attempt to reconnect to the server.
    func attemptReconnection() async {
        let discovery = ServerDiscovery()
        do {
            let serverURL = try await discovery.discover()
            let client = APIClient(baseURL: serverURL, token: "change-me-to-a-secret")
            self.apiClient = client
            appState.apiClient = client
            appState.isConnected = true
            appState.errorMessage = nil

            // Flush queued offline actions
            await flushOfflineQueue()

            await startWebSocket(baseURL: serverURL)
            await fetchInitialData(client: client)
            await cacheCurrentData()

            logger.info("Reconnection successful")
        } catch {
            logger.info("Reconnection attempt failed: \(error.localizedDescription)")
        }
    }

    // MARK: - WebSocket

    private func startWebSocket(baseURL: URL) async {
        let manager = WebSocketManager()
        self.webSocketManager = manager
        await manager.connect(baseURL: baseURL, token: "change-me-to-a-secret")
        startEventRouting(manager: manager)
    }

    /// Route WebSocket events to the appropriate stores.
    func startEventRouting(manager: WebSocketManager) {
        eventRoutingTask?.cancel()
        eventRoutingTask = Task { [weak self] in
            let events = await manager.events
            for await event in events {
                guard !Task.isCancelled else { return }
                self?.routeEvent(event)
            }
        }
    }

    private func routeEvent(_ event: WebSocketEvent) {
        switch event.type {
        case .emailNew, .emailUpdated, .emailDeleted,
             .classificationChanged,
             .snoozeCreated, .snoozeReturned, .snoozeCancelled:
            emailStore.handleEvent(event)
        case .recommendationNew, .recommendationUpdated:
            recommendationStore.handleEvent(event)
        case .digestAvailable:
            digestStore.handleEvent(event)
        case .accountStatus:
            handleAccountStatus(event)
        case .connectionLost:
            appState.isConnected = false
            startReconnectionTimer()
        case .pong:
            break
        }
    }

    private func handleAccountStatus(_ event: WebSocketEvent) {
        if case let .accountStatus(payload) = event.payload {
            if payload.status == .error {
                logger.warning("Account \(payload.accountId) error: \(payload.statusMessage ?? "unknown")")
            }
        }
    }

    // MARK: - Initial Data Fetch

    private func fetchInitialData(client: APIClient) async {
        async let accountsResult: () = fetchAccounts(client: client)
        async let actionResult: () = fetchEmailView(.actionQueue, client: client)
        async let readingResult: () = fetchEmailView(.readingQueue, client: client)
        async let filteredResult: () = fetchEmailView(.filtered, client: client)
        async let digestResult: () = fetchLatestDigest(client: client)
        async let recsResult: () = fetchRecommendations(client: client)

        _ = await (accountsResult, actionResult, readingResult, filteredResult, digestResult, recsResult)
    }

    private func fetchAccounts(client: APIClient) async {
        do {
            _ = try await client.fetchAccounts()
            logger.info("Fetched accounts")
        } catch {
            logger.warning("Failed to fetch accounts: \(error.localizedDescription)")
        }
    }

    private func fetchEmailView(_ view: EmailView, client: APIClient) async {
        do {
            let response = try await client.fetchEmails(view: view)
            emailStore.setEmails(response.data, for: view)
            logger.info("Fetched \(response.data.count) emails for \(view.rawValue)")
        } catch {
            logger.warning("Failed to fetch \(view.rawValue): \(error.localizedDescription)")
        }
    }

    private func fetchRecommendations(client: APIClient) async {
        do {
            let response = try await client.fetchRecommendations(status: .new)
            recommendationStore.setRecommendations(response.data)
            logger.info("Fetched \(response.data.count) recommendations")
        } catch {
            logger.warning("Failed to fetch recommendations: \(error.localizedDescription)")
        }
    }

    private func fetchLatestDigest(client: APIClient) async {
        do {
            let digest = try await client.fetchLatestDigest()
            digestStore.setLatestDigest(digest)
            logger.info("Fetched latest digest")
        } catch {
            logger.info("No latest digest available")
        }
    }
}

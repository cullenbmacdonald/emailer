import Foundation
import Observation
import EmailClientKit
import os

/// Orchestrates server discovery, API client connection, WebSocket connection,
/// initial data fetching, and event routing to stores.
@Observable
@MainActor
public final class AppCoordinator {
    let appState: AppState
    let emailStore: EmailStore
    let recommendationStore: RecommendationStore
    let digestStore: DigestStore

    private(set) var apiClient: APIClient?
    private(set) var webSocketManager: WebSocketManager?

    private var eventRoutingTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.cullenbmacdonald.emailer", category: "AppCoordinator")

    public init(
        appState: AppState,
        emailStore: EmailStore,
        recommendationStore: RecommendationStore,
        digestStore: DigestStore
    ) {
        self.appState = appState
        self.emailStore = emailStore
        self.recommendationStore = recommendationStore
        self.digestStore = digestStore
    }

    /// Start the app: discover server, connect API + WebSocket, fetch initial data.
    public func start() {
        Task {
            await connectToServer()
        }
    }

    /// Stop event routing and disconnect WebSocket.
    public func stop() {
        eventRoutingTask?.cancel()
        eventRoutingTask = nil
        Task {
            await webSocketManager?.disconnect()
        }
    }

    // MARK: - Server Connection

    private func connectToServer() async {
        let discovery = ServerDiscovery()
        do {
            let serverURL = try await discovery.discover()
            logger.info("Discovered server at \(serverURL.absoluteString)")

            let client = APIClient(baseURL: serverURL, token: "")
            self.apiClient = client
            appState.isConnected = true
            appState.errorMessage = nil

            await startWebSocket(baseURL: serverURL)
            await fetchInitialData(client: client)
        } catch {
            logger.error("Server discovery failed: \(error.localizedDescription)")
            appState.isConnected = false
            appState.errorMessage = "Unable to connect to server"
        }
    }

    // MARK: - WebSocket

    private func startWebSocket(baseURL: URL) async {
        let manager = WebSocketManager()
        self.webSocketManager = manager
        await manager.connect(baseURL: baseURL, token: "")
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

        _ = await (accountsResult, actionResult, readingResult, filteredResult, digestResult)
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

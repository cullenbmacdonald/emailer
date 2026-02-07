import Foundation
import os

/// Manages a persistent WebSocket connection with auto-reconnect and keep-alive pings.
public actor WebSocketManager {
    /// Connection state.
    public enum ConnectionState: Sendable, Equatable {
        case disconnected
        case connecting
        case connected
    }

    // MARK: - Configuration

    private let pingInterval: TimeInterval
    private let pongTimeout: TimeInterval
    private let reconnectPolicy: ReconnectPolicy

    // MARK: - State

    private var state: ConnectionState = .disconnected
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var baseURL: URL?
    private var token: String?
    private var eventContinuation: AsyncStream<WebSocketEvent>.Continuation?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var currentReconnectAttempt: Int = 0

    private let logger = Logger(subsystem: "com.cullenbmacdonald.emailer", category: "WebSocket")

    /// Whether the connection is currently established.
    public var isConnected: Bool {
        state == .connected
    }

    /// The current connection state.
    public var connectionState: ConnectionState {
        state
    }

    // MARK: - Event Stream

    /// Lazily-created async stream of WebSocket events.
    /// Calling this property multiple times returns the same stream.
    public private(set) lazy var events: AsyncStream<WebSocketEvent> = {
        AsyncStream { continuation in
            self.eventContinuation = continuation
        }
    }()

    // MARK: - Init

    public init(
        session: URLSession = .shared,
        pingInterval: TimeInterval = 30.0,
        pongTimeout: TimeInterval = 10.0,
        reconnectPolicy: ReconnectPolicy = ReconnectPolicy()
    ) {
        self.session = session
        self.pingInterval = pingInterval
        self.pongTimeout = pongTimeout
        self.reconnectPolicy = reconnectPolicy
    }

    // MARK: - Connect / Disconnect

    /// Connect to the server's WebSocket endpoint.
    ///
    /// - Parameters:
    ///   - baseURL: The server base URL (http:// or https://).
    ///   - token: Authentication token.
    public func connect(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
        currentReconnectAttempt = 0
        startConnection()
    }

    /// Cleanly close the WebSocket connection. Does not auto-reconnect.
    public func disconnect() {
        cancelAllTasks()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        state = .disconnected
    }

    // MARK: - Private Connection Logic

    private func startConnection() {
        guard let baseURL, let token else { return }

        cancelAllTasks()
        state = .connecting

        guard let wsURL = buildWebSocketURL(baseURL: baseURL, token: token) else {
            logger.error("Failed to build WebSocket URL from \(baseURL.absoluteString)")
            state = .disconnected
            return
        }

        logger.info("Connecting to WebSocket at \(wsURL.absoluteString)")

        let task = session.webSocketTask(with: wsURL)
        self.webSocketTask = task
        task.resume()

        state = .connected
        currentReconnectAttempt = 0
        logger.info("WebSocket connected")

        startReceiveLoop()
        startPingLoop()
    }

    private func buildWebSocketURL(baseURL: URL, token: String) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent("/api/v1/ws"), resolvingAgainstBaseURL: true)

        // Convert http(s) to ws(s)
        switch components?.scheme {
        case "http":
            components?.scheme = "ws"
        case "https":
            components?.scheme = "wss"
        default:
            break
        }

        components?.queryItems = [URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    // MARK: - Receive Loop

    private func startReceiveLoop() {
        receiveTask = Task { [weak webSocketTask] in
            guard let task = webSocketTask else { return }
            await receiveMessages(from: task)
        }
    }

    private func receiveMessages(from task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                handleMessage(message)
            } catch {
                guard !Task.isCancelled else { return }
                logger.warning("WebSocket receive error: \(error.localizedDescription)")
                handleDisconnect(reason: error.localizedDescription)
                return
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case let .string(text):
            guard let textData = text.data(using: .utf8) else {
                logger.warning("Failed to convert WebSocket text message to data")
                return
            }
            data = textData
        case let .data(binaryData):
            data = binaryData
        @unknown default:
            logger.warning("Unknown WebSocket message type")
            return
        }

        do {
            let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: data)
            eventContinuation?.yield(event)
        } catch {
            // Unknown event types are logged and skipped (forward compatibility)
            logger.info("Skipping undecodable WebSocket event: \(error.localizedDescription)")
        }
    }

    private func handleDisconnect(reason: String?) {
        state = .disconnected
        webSocketTask = nil

        // Emit synthetic connectionLost event
        let event = WebSocketEvent(
            type: .connectionLost,
            payload: .connectionLost(ConnectionLostPayload(reason: reason)),
            timestamp: Date()
        )
        eventContinuation?.yield(event)

        // Schedule reconnect
        scheduleReconnect()
    }

    // MARK: - Ping / Pong

    private func startPingLoop() {
        pingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(pingInterval))
                guard !Task.isCancelled else { return }
                await sendPing()
            }
        }
    }

    /// Send a WebSocket ping and handle pong timeout.
    public func sendPing() async {
        guard let task = webSocketTask, state == .connected else { return }

        let pongReceived = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            task.sendPing { error in
                if let error {
                    continuation.resume(returning: false)
                    _ = error // Suppress unused warning
                } else {
                    continuation.resume(returning: true)
                }
            }
        }

        if !pongReceived {
            logger.warning("Pong not received, triggering reconnect")
            handleDisconnect(reason: "Pong timeout")
        }
    }

    // MARK: - Reconnection

    private func scheduleReconnect() {
        guard baseURL != nil, token != nil else { return }
        guard currentReconnectAttempt < reconnectPolicy.maxAttempts || reconnectPolicy.maxAttempts == 0 else {
            logger.error("Max reconnection attempts reached")
            return
        }

        let delay = reconnectPolicy.delay(forAttempt: currentReconnectAttempt)
        currentReconnectAttempt += 1
        logger.info("Scheduling reconnect in \(delay)s (attempt \(self.currentReconnectAttempt))")

        reconnectTask = Task {
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            performReconnect()
        }
    }

    private func performReconnect() {
        guard state == .disconnected else { return }
        startConnection()
    }

    // MARK: - Cleanup

    private func cancelAllTasks() {
        pingTask?.cancel()
        pingTask = nil
        receiveTask?.cancel()
        receiveTask = nil
        reconnectTask?.cancel()
        reconnectTask = nil
    }
}

/// Reconnection policy with exponential backoff.
public struct ReconnectPolicy: Sendable {
    /// Maximum number of reconnection attempts. 0 means unlimited.
    public let maxAttempts: Int

    /// Base delay in seconds before the first reconnect.
    public let baseDelay: TimeInterval

    /// Maximum delay in seconds between reconnects.
    public let maxDelay: TimeInterval

    public init(maxAttempts: Int = 0, baseDelay: TimeInterval = 1.0, maxDelay: TimeInterval = 60.0) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
    }

    /// Calculates the delay before reconnection attempt `attempt` (0-indexed).
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(attempt))
        return min(delay, maxDelay)
    }
}

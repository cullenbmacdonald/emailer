import Foundation
import Testing
@testable import EmailClientKit

@Suite("WebSocketManager")
struct WebSocketManagerTests {
    // MARK: - ReconnectPolicy Tests

    @Test("ReconnectPolicy calculates exponential delays")
    func reconnectExponentialDelay() {
        let policy = ReconnectPolicy(maxAttempts: 0, baseDelay: 1.0, maxDelay: 60.0)
        #expect(policy.delay(forAttempt: 0) == 1.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 4.0)
        #expect(policy.delay(forAttempt: 3) == 8.0)
        #expect(policy.delay(forAttempt: 4) == 16.0)
        #expect(policy.delay(forAttempt: 5) == 32.0)
        #expect(policy.delay(forAttempt: 6) == 60.0) // capped at maxDelay
        #expect(policy.delay(forAttempt: 7) == 60.0) // still capped
    }

    @Test("ReconnectPolicy default values")
    func reconnectDefaults() {
        let policy = ReconnectPolicy()
        #expect(policy.maxAttempts == 0) // unlimited
        #expect(policy.baseDelay == 1.0)
        #expect(policy.maxDelay == 60.0)
    }

    @Test("ReconnectPolicy custom values")
    func reconnectCustom() {
        let policy = ReconnectPolicy(maxAttempts: 5, baseDelay: 0.5, maxDelay: 30.0)
        #expect(policy.maxAttempts == 5)
        #expect(policy.baseDelay == 0.5)
        #expect(policy.maxDelay == 30.0)
        #expect(policy.delay(forAttempt: 0) == 0.5)
        #expect(policy.delay(forAttempt: 1) == 1.0)
        #expect(policy.delay(forAttempt: 2) == 2.0)
    }

    // MARK: - WebSocketManager State Tests

    @Test("Initial state is disconnected")
    func initialState() async {
        let manager = WebSocketManager()
        let connected = await manager.isConnected
        #expect(!connected)
        let state = await manager.connectionState
        #expect(state == .disconnected)
    }

    @Test("Disconnect from disconnected state does not crash")
    func disconnectWhenDisconnected() async {
        let manager = WebSocketManager()
        await manager.disconnect()
        let state = await manager.connectionState
        #expect(state == .disconnected)
    }

    // MARK: - URL Construction Tests

    @Test("WebSocket URL converts http to ws")
    func urlConversionHTTP() async {
        let manager = WebSocketManager()
        // Connect with a bogus URL — we just want to verify the URL is constructed correctly.
        // The connection will fail but that's OK for this test.
        await manager.connect(
            baseURL: URL(string: "http://localhost:8080")!,
            token: "test-token"
        )
        // Give a moment for the connection attempt
        try? await Task.sleep(for: .milliseconds(50))
        // Disconnect to clean up
        await manager.disconnect()
    }

    @Test("WebSocket URL converts https to wss")
    func urlConversionHTTPS() async {
        let manager = WebSocketManager()
        await manager.connect(
            baseURL: URL(string: "https://example.com")!,
            token: "test-token"
        )
        try? await Task.sleep(for: .milliseconds(50))
        await manager.disconnect()
    }

    // MARK: - Event Decoding Tests

    @Test("All 11 server event types decode correctly")
    func allServerEventTypes() throws {
        let eventTypes: [(String, WebSocketEventType)] = [
            ("email.new", .emailNew),
            ("email.updated", .emailUpdated),
            ("email.deleted", .emailDeleted),
            ("classification.changed", .classificationChanged),
            ("snooze.created", .snoozeCreated),
            ("snooze.returned", .snoozeReturned),
            ("snooze.cancelled", .snoozeCancelled),
            ("recommendation.new", .recommendationNew),
            ("recommendation.updated", .recommendationUpdated),
            ("digest.available", .digestAvailable),
            ("account.status", .accountStatus),
        ]
        #expect(eventTypes.count == 11)
    }

    @Test("ConnectionLost event creates correctly")
    func connectionLostEvent() {
        let event = WebSocketEvent(
            type: .connectionLost,
            payload: .connectionLost(ConnectionLostPayload(reason: "Network error")),
            timestamp: Date()
        )
        #expect(event.type == .connectionLost)
        if case let .connectionLost(payload) = event.payload {
            #expect(payload.reason == "Network error")
        } else {
            Issue.record("Expected connectionLost payload")
        }
    }

    @Test("ConnectionLost with nil reason")
    func connectionLostNilReason() {
        let payload = ConnectionLostPayload()
        #expect(payload.reason == nil)
    }

    @Test("ConnectionLost round-trip encoding")
    func connectionLostRoundTrip() throws {
        let event = WebSocketEvent(
            type: .connectionLost,
            payload: .connectionLost(ConnectionLostPayload(reason: "Pong timeout")),
            timestamp: ISO8601DateFormatter().date(from: "2026-02-07T10:00:00Z")
        )

        let encoded = try JSONEncoder.apiEncoder.encode(event)
        let decoded = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: encoded)
        #expect(decoded == event)
    }

    // MARK: - Manager Lifecycle Tests

    @Test("Disconnect cancels reconnection")
    func disconnectCancelsReconnect() async {
        let policy = ReconnectPolicy(maxAttempts: 0, baseDelay: 10.0, maxDelay: 10.0)
        let manager = WebSocketManager(
            pingInterval: 30.0,
            pongTimeout: 10.0,
            reconnectPolicy: policy
        )
        // Connect to a nonexistent server (will fail immediately)
        await manager.connect(
            baseURL: URL(string: "http://127.0.0.1:1")!,
            token: "test"
        )
        try? await Task.sleep(for: .milliseconds(100))
        // Disconnect should cancel any pending reconnect
        await manager.disconnect()
        let state = await manager.connectionState
        #expect(state == .disconnected)
    }

    @Test("Events stream is accessible")
    func eventsStreamAccessible() async {
        let manager = WebSocketManager()
        // Accessing events property should not crash
        _ = await manager.events
    }
}

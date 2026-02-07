import Foundation
import Testing
@testable import EmailClientKit

@Suite("HealthResponse Model")
struct HealthResponseTests {
    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "status": "healthy",
            "version": "1.0.0",
            "commit": "abc1234",
            "uptime_seconds": 3600,
            "checks": {
                "database": "ok",
                "ollama": "unavailable",
                "imap": {
                    "work": "connected",
                    "personal_gmail": "connected",
                    "icloud": "disconnected"
                }
            }
        }
        """.data(using: .utf8)!

        let health = try JSONDecoder.apiDecoder.decode(HealthResponse.self, from: json)
        #expect(health.status == .healthy)
        #expect(health.version == "1.0.0")
        #expect(health.commit == "abc1234")
        #expect(health.uptimeSeconds == 3600)
        #expect(health.checks?.database == .ok)
        #expect(health.checks?.ollama == .unavailable)
        #expect(health.checks?.imap?["work"] == .connected)
        #expect(health.checks?.imap?["icloud"] == .disconnected)
    }

    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let health = HealthResponse(
            status: .degraded,
            version: "1.0.0",
            uptimeSeconds: 7200,
            checks: HealthChecks(
                database: .ok,
                ollama: .error
            )
        )
        let encoded = try JSONEncoder.apiEncoder.encode(health)
        let decoded = try JSONDecoder.apiDecoder.decode(HealthResponse.self, from: encoded)
        #expect(decoded == health)
    }

    @Test("HealthStatus raw values")
    func healthStatusRawValues() {
        #expect(HealthStatus.healthy.rawValue == "healthy")
        #expect(HealthStatus.degraded.rawValue == "degraded")
        #expect(HealthStatus.unhealthy.rawValue == "unhealthy")
    }

    @Test("Minimal health response")
    func minimalResponse() throws {
        let json = """
        {"status": "unhealthy"}
        """.data(using: .utf8)!

        let health = try JSONDecoder.apiDecoder.decode(HealthResponse.self, from: json)
        #expect(health.status == .unhealthy)
        #expect(health.version == nil)
        #expect(health.checks == nil)
    }
}

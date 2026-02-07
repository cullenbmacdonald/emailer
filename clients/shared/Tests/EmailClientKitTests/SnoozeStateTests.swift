import Foundation
import Testing
@testable import EmailClientKit

@Suite("SnoozeState Model")
struct SnoozeStateTests {
    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let snooze = SnoozeState(
            id: "550e8400-e29b-41d4-a716-446655440000",
            emailId: "660e8400-e29b-41d4-a716-446655440001",
            snoozedAt: ISO8601DateFormatter().date(from: "2026-02-07T10:00:00Z")!,
            returnAt: ISO8601DateFormatter().date(from: "2026-02-08T09:00:00Z")!,
            snoozeCount: 2,
            isActive: true
        )
        let data = try JSONEncoder.apiEncoder.encode(snooze)
        let decoded = try JSONDecoder.apiDecoder.decode(SnoozeState.self, from: data)
        #expect(decoded == snooze)
    }

    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "email_id": "660e8400-e29b-41d4-a716-446655440001",
            "snoozed_at": "2026-02-07T10:00:00Z",
            "return_at": "2026-02-08T09:00:00Z",
            "snooze_count": 2,
            "is_active": true
        }
        """.data(using: .utf8)!

        let snooze = try JSONDecoder.apiDecoder.decode(SnoozeState.self, from: json)
        #expect(snooze.id == "550e8400-e29b-41d4-a716-446655440000")
        #expect(snooze.emailId == "660e8400-e29b-41d4-a716-446655440001")
        #expect(snooze.snoozeCount == 2)
        #expect(snooze.isActive == true)
    }

    @Test("Conforms to Identifiable")
    func identifiable() {
        let snooze = SnoozeState(
            id: "abc-123",
            emailId: "def-456",
            snoozedAt: Date(),
            returnAt: Date(),
            snoozeCount: 1,
            isActive: true
        )
        #expect(snooze.id == "abc-123")
    }
}

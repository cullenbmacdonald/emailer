import Foundation
import Testing
@testable import EmailClientKit

@Suite("VIPSender Model")
struct VIPSenderTests {
    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "id": "vip-1",
            "email": "boss@company.com",
            "name": "My Boss",
            "added_at": "2026-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let vip = try JSONDecoder.apiDecoder.decode(VIPSender.self, from: json)
        #expect(vip.id == "vip-1")
        #expect(vip.email == "boss@company.com")
        #expect(vip.name == "My Boss")
    }

    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let vip = VIPSender(
            id: "vip-1",
            email: "@important-client.com",
            name: nil,
            addedAt: ISO8601DateFormatter().date(from: "2026-01-15T10:00:00Z")!
        )
        let encoded = try JSONEncoder.apiEncoder.encode(vip)
        let decoded = try JSONDecoder.apiDecoder.decode(VIPSender.self, from: encoded)
        #expect(decoded == vip)
    }

    @Test("Decodes without optional name")
    func withoutName() throws {
        let json = """
        {
            "id": "vip-2",
            "email": "@domain.com",
            "added_at": "2026-01-20T10:00:00Z"
        }
        """.data(using: .utf8)!

        let vip = try JSONDecoder.apiDecoder.decode(VIPSender.self, from: json)
        #expect(vip.name == nil)
        #expect(vip.email == "@domain.com")
    }
}

import Foundation
import Testing
@testable import EmailClientKit

@Suite("PaginatedResponse Model")
struct PaginatedResponseTests {
    @Test("Decodes email list response")
    func decodeEmailList() throws {
        let json = """
        {
            "data": [
                {
                    "id": "abc",
                    "account_id": "def",
                    "from": {"email": "a@b.com"},
                    "to": [],
                    "subject": "Test",
                    "snippet": "",
                    "received_at": "2026-01-01T00:00:00Z",
                    "classification": {
                        "classification": "newsletter",
                        "confidence": 0.9,
                        "classified_by": "rules"
                    },
                    "is_read": false,
                    "is_archived": false,
                    "has_attachments": false
                }
            ],
            "next_cursor": "eyJpZCI6ImFiYyJ9",
            "has_more": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.apiDecoder.decode(
            PaginatedResponse<Email>.self, from: json
        )
        #expect(response.data.count == 1)
        #expect(response.data[0].id == "abc")
        #expect(response.nextCursor == "eyJpZCI6ImFiYyJ9")
        #expect(response.hasMore == true)
    }

    @Test("Decodes recommendation list response")
    func decodeRecommendationList() throws {
        let json = """
        {
            "data": [
                {
                    "id": "rec-1",
                    "type": "book",
                    "title": "Test",
                    "source_newsletter_name": "Newsletter",
                    "source_date": "2026-01-01T00:00:00Z",
                    "context_snippet": "Context",
                    "status": "new",
                    "duplicate_count": 1
                }
            ],
            "has_more": false
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder.apiDecoder.decode(
            PaginatedResponse<Recommendation>.self, from: json
        )
        #expect(response.data.count == 1)
        #expect(response.nextCursor == nil)
        #expect(response.hasMore == false)
    }

    @Test("PaginatedResponse round-trip")
    func roundTrip() throws {
        let response = PaginatedResponse<VIPSender>(
            data: [
                VIPSender(
                    id: "vip-1",
                    email: "boss@work.com",
                    addedAt: ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!
                )
            ],
            nextCursor: "cursor123",
            hasMore: true
        )
        let encoded = try JSONEncoder.apiEncoder.encode(response)
        let decoded = try JSONDecoder.apiDecoder.decode(
            PaginatedResponse<VIPSender>.self, from: encoded
        )
        #expect(decoded == response)
    }

    @Test("Empty data array")
    func emptyData() throws {
        let json = """
        {"data": [], "has_more": false}
        """.data(using: .utf8)!

        let response = try JSONDecoder.apiDecoder.decode(
            PaginatedResponse<Email>.self, from: json
        )
        #expect(response.data.isEmpty)
        #expect(response.hasMore == false)
    }
}

import Foundation
import Testing
@testable import EmailClientKit

@Suite("SearchResult Model")
struct SearchResultTests {
    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "email": {
                "id": "abc",
                "account_id": "def",
                "from": {"email": "a@b.com"},
                "to": [],
                "subject": "Q3 budget",
                "snippet": "Budget details",
                "received_at": "2026-01-01T00:00:00Z",
                "classification": {
                    "classification": "action_required",
                    "confidence": 0.9,
                    "classified_by": "llm"
                },
                "is_read": true,
                "is_archived": false,
                "has_attachments": false
            },
            "highlight_snippet": "...updated the <mark>Q3 budget</mark> with the changes..."
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder.apiDecoder.decode(SearchResult.self, from: json)
        #expect(result.email.subject == "Q3 budget")
        #expect(result.highlightSnippet.contains("<mark>"))
    }

    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let result = SearchResult(
            email: Email(
                id: "abc",
                accountId: "def",
                from: Contact(email: "a@b.com"),
                to: [],
                subject: "Test",
                snippet: "",
                receivedAt: ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!,
                classification: Classification(
                    classification: .filtered,
                    confidence: 0.7,
                    classifiedBy: .features
                ),
                isRead: false,
                isArchived: false,
                hasAttachments: false
            ),
            highlightSnippet: "highlighted text"
        )
        let encoded = try JSONEncoder.apiEncoder.encode(result)
        let decoded = try JSONDecoder.apiDecoder.decode(SearchResult.self, from: encoded)
        #expect(decoded == result)
    }
}

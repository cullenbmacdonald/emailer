import Foundation
import Testing
@testable import EmailClientKit

@Suite("EmailDetail Model")
struct EmailDetailTests {
    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "id": "550e8400-e29b-41d4-a716-446655440000",
            "email": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "account_id": "def",
                "from": {"email": "a@b.com"},
                "to": [{"email": "b@c.com"}],
                "subject": "Test",
                "snippet": "Test snippet",
                "received_at": "2026-01-01T00:00:00Z",
                "classification": {
                    "classification": "newsletter",
                    "confidence": 0.9,
                    "classified_by": "rules"
                },
                "is_read": true,
                "is_archived": false,
                "has_attachments": true
            },
            "html_body": "<h1>Hello</h1>",
            "text_body": "Hello",
            "attachments": [
                {
                    "id": "att-1",
                    "filename": "report.pdf",
                    "mime_type": "application/pdf",
                    "size": 245760,
                    "download_url": "/api/v1/emails/550e8400/attachments/att-1"
                }
            ]
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder.apiDecoder.decode(EmailDetail.self, from: json)
        #expect(detail.id == "550e8400-e29b-41d4-a716-446655440000")
        #expect(detail.email.subject == "Test")
        #expect(detail.htmlBody == "<h1>Hello</h1>")
        #expect(detail.textBody == "Hello")
        #expect(detail.attachments.count == 1)
        #expect(detail.attachments[0].filename == "report.pdf")
        #expect(detail.attachments[0].mimeType == "application/pdf")
        #expect(detail.attachments[0].size == 245760)
    }

    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let detail = EmailDetail(
            id: "abc",
            email: Email(
                id: "abc",
                accountId: "def",
                from: Contact(email: "a@b.com"),
                to: [],
                subject: "Test",
                snippet: "",
                receivedAt: ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!,
                classification: Classification(
                    classification: .newsletter,
                    confidence: 0.9,
                    classifiedBy: .rules
                ),
                isRead: false,
                isArchived: false,
                hasAttachments: false
            ),
            htmlBody: "<p>Body</p>",
            textBody: "Body",
            attachments: []
        )
        let encoded = try JSONEncoder.apiEncoder.encode(detail)
        let decoded = try JSONDecoder.apiDecoder.decode(EmailDetail.self, from: encoded)
        #expect(decoded == detail)
    }
}

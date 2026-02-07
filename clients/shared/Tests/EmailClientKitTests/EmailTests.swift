import Foundation
import Testing
@testable import EmailClientKit

@Suite("Email Model")
struct EmailTests {
    static let sampleJSON = """
    {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "account_id": "660e8400-e29b-41d4-a716-446655440001",
        "message_id": "<abc123@mail.example.com>",
        "thread_id": "thread-001",
        "from": {"name": "Jane Smith", "email": "jane@example.com"},
        "to": [{"name": "John Doe", "email": "john@example.com"}],
        "cc": [{"email": "cc@example.com"}],
        "subject": "Re: Q3 budget review",
        "snippet": "Can you sign off on the Q3 budget before Friday?",
        "received_at": "2026-02-07T14:30:00Z",
        "classification": {
            "classification": "action_required",
            "confidence": 0.95,
            "classified_by": "llm"
        },
        "is_read": false,
        "is_archived": false,
        "has_attachments": true,
        "labels": ["Important"],
        "account_color": "#3B82F6",
        "account_name": "Work",
        "recommendation_count": 0,
        "days_until_expiry": null
    }
    """.data(using: .utf8)!

    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let email = try JSONDecoder.apiDecoder.decode(Email.self, from: EmailTests.sampleJSON)
        #expect(email.id == "550e8400-e29b-41d4-a716-446655440000")
        #expect(email.accountId == "660e8400-e29b-41d4-a716-446655440001")
        #expect(email.messageId == "<abc123@mail.example.com>")
        #expect(email.threadId == "thread-001")
        #expect(email.from.name == "Jane Smith")
        #expect(email.from.email == "jane@example.com")
        #expect(email.to.count == 1)
        #expect(email.cc?.count == 1)
        #expect(email.subject == "Re: Q3 budget review")
        #expect(email.snippet == "Can you sign off on the Q3 budget before Friday?")
        #expect(email.classification.classification == .actionRequired)
        #expect(email.classification.confidence == 0.95)
        #expect(email.isRead == false)
        #expect(email.isArchived == false)
        #expect(email.hasAttachments == true)
        #expect(email.labels == ["Important"])
        #expect(email.accountColor == "#3B82F6")
        #expect(email.accountName == "Work")
        #expect(email.recommendationCount == 0)
        #expect(email.snooze == nil)
        #expect(email.daysUntilExpiry == nil)
    }

    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let email = try JSONDecoder.apiDecoder.decode(Email.self, from: EmailTests.sampleJSON)
        let encoded = try JSONEncoder.apiEncoder.encode(email)
        let decoded = try JSONDecoder.apiDecoder.decode(Email.self, from: encoded)
        #expect(decoded == email)
    }

    @Test("Decodes minimal email (only required fields)")
    func decodeMinimal() throws {
        let json = """
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
                "confidence": 0.5,
                "classified_by": "rules"
            },
            "is_read": true,
            "is_archived": false,
            "has_attachments": false
        }
        """.data(using: .utf8)!

        let email = try JSONDecoder.apiDecoder.decode(Email.self, from: json)
        #expect(email.id == "abc")
        #expect(email.messageId == nil)
        #expect(email.threadId == nil)
        #expect(email.cc == nil)
        #expect(email.labels == nil)
        #expect(email.accountColor == nil)
        #expect(email.accountName == nil)
        #expect(email.recommendationCount == nil)
        #expect(email.lastReadAt == nil)
        #expect(email.readProgress == nil)
        #expect(email.daysUntilExpiry == nil)
    }

    @Test("Email with snooze state")
    func withSnooze() throws {
        let json = """
        {
            "id": "abc",
            "account_id": "def",
            "from": {"email": "a@b.com"},
            "to": [],
            "subject": "Test",
            "snippet": "",
            "received_at": "2026-01-01T00:00:00Z",
            "classification": {
                "classification": "action_required",
                "confidence": 0.9,
                "classified_by": "llm"
            },
            "is_read": false,
            "is_archived": false,
            "has_attachments": false,
            "snooze": {
                "id": "snooze-1",
                "email_id": "abc",
                "snoozed_at": "2026-02-07T10:00:00Z",
                "return_at": "2026-02-08T09:00:00Z",
                "snooze_count": 1,
                "is_active": true
            }
        }
        """.data(using: .utf8)!

        let email = try JSONDecoder.apiDecoder.decode(Email.self, from: json)
        #expect(email.snooze != nil)
        #expect(email.snooze?.snoozeCount == 1)
        #expect(email.snooze?.isActive == true)
    }

    @Test("Conforms to Identifiable")
    func identifiable() throws {
        let email = try JSONDecoder.apiDecoder.decode(Email.self, from: EmailTests.sampleJSON)
        #expect(email.id == "550e8400-e29b-41d4-a716-446655440000")
    }

    @Test("Email with read progress and last_read_at")
    func withReadProgress() throws {
        let json = """
        {
            "id": "abc",
            "account_id": "def",
            "from": {"email": "a@b.com"},
            "to": [],
            "subject": "Newsletter",
            "snippet": "",
            "received_at": "2026-01-01T00:00:00Z",
            "classification": {
                "classification": "newsletter",
                "confidence": 0.9,
                "classified_by": "llm"
            },
            "is_read": false,
            "is_archived": false,
            "has_attachments": false,
            "last_read_at": "2026-02-07T12:00:00Z",
            "read_progress": 0.45
        }
        """.data(using: .utf8)!

        let email = try JSONDecoder.apiDecoder.decode(Email.self, from: json)
        #expect(email.lastReadAt != nil)
        #expect(email.readProgress == 0.45)
    }
}

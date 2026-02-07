import Foundation
import Testing
@testable import EmailClientKit

@Suite("WebSocketEvent Models")
struct WebSocketEventTests {
    @Test("WebSocketEventType raw values match API spec")
    func eventTypeRawValues() {
        #expect(WebSocketEventType.emailNew.rawValue == "email.new")
        #expect(WebSocketEventType.emailUpdated.rawValue == "email.updated")
        #expect(WebSocketEventType.emailDeleted.rawValue == "email.deleted")
        #expect(WebSocketEventType.classificationChanged.rawValue == "classification.changed")
        #expect(WebSocketEventType.snoozeCreated.rawValue == "snooze.created")
        #expect(WebSocketEventType.snoozeReturned.rawValue == "snooze.returned")
        #expect(WebSocketEventType.snoozeCancelled.rawValue == "snooze.cancelled")
        #expect(WebSocketEventType.recommendationNew.rawValue == "recommendation.new")
        #expect(WebSocketEventType.recommendationUpdated.rawValue == "recommendation.updated")
        #expect(WebSocketEventType.digestAvailable.rawValue == "digest.available")
        #expect(WebSocketEventType.accountStatus.rawValue == "account.status")
        #expect(WebSocketEventType.pong.rawValue == "pong")
    }

    private func makeEmailJSON() -> String {
        """
        {
            "id": "email-1",
            "account_id": "acc-1",
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
            "has_attachments": false
        }
        """
    }

    @Test("Decodes email.new event")
    func decodeEmailNew() throws {
        let json = """
        {
            "type": "email.new",
            "payload": {
                "email": \(makeEmailJSON())
            },
            "timestamp": "2026-02-07T14:30:00Z"
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .emailNew)
        #expect(event.timestamp != nil)
        if case let .emailNew(payload) = event.payload {
            #expect(payload.email.id == "email-1")
        } else {
            Issue.record("Expected emailNew payload")
        }
    }

    @Test("Decodes email.updated event")
    func decodeEmailUpdated() throws {
        let json = """
        {
            "type": "email.updated",
            "payload": {
                "email": \(makeEmailJSON())
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .emailUpdated)
        if case let .emailUpdated(payload) = event.payload {
            #expect(payload.email.id == "email-1")
        } else {
            Issue.record("Expected emailUpdated payload")
        }
    }

    @Test("Decodes email.deleted event")
    func decodeEmailDeleted() throws {
        let json = """
        {
            "type": "email.deleted",
            "payload": {
                "email_id": "email-1"
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .emailDeleted)
        if case let .emailDeleted(payload) = event.payload {
            #expect(payload.emailId == "email-1")
        } else {
            Issue.record("Expected emailDeleted payload")
        }
    }

    @Test("Decodes classification.changed event")
    func decodeClassificationChanged() throws {
        let json = """
        {
            "type": "classification.changed",
            "payload": {
                "email_id": "email-1",
                "previous_classification": "filtered",
                "new_classification": "action_required",
                "email": \(makeEmailJSON())
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .classificationChanged)
        if case let .classificationChanged(payload) = event.payload {
            #expect(payload.emailId == "email-1")
            #expect(payload.previousClassification == .filtered)
            #expect(payload.newClassification == .actionRequired)
            #expect(payload.email != nil)
        } else {
            Issue.record("Expected classificationChanged payload")
        }
    }

    @Test("Decodes snooze.created event")
    func decodeSnoozeCreated() throws {
        let json = """
        {
            "type": "snooze.created",
            "payload": {
                "email_id": "email-1",
                "snooze": {
                    "id": "snooze-1",
                    "email_id": "email-1",
                    "snoozed_at": "2026-02-07T10:00:00Z",
                    "return_at": "2026-02-08T09:00:00Z",
                    "snooze_count": 1,
                    "is_active": true
                }
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .snoozeCreated)
        if case let .snoozeCreated(payload) = event.payload {
            #expect(payload.emailId == "email-1")
            #expect(payload.snooze.isActive == true)
        } else {
            Issue.record("Expected snoozeCreated payload")
        }
    }

    @Test("Decodes snooze.returned event")
    func decodeSnoozeReturned() throws {
        let json = """
        {
            "type": "snooze.returned",
            "payload": {
                "email_id": "email-1",
                "email": \(makeEmailJSON())
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .snoozeReturned)
        if case let .snoozeReturned(payload) = event.payload {
            #expect(payload.emailId == "email-1")
        } else {
            Issue.record("Expected snoozeReturned payload")
        }
    }

    @Test("Decodes snooze.cancelled event")
    func decodeSnoozeCancelled() throws {
        let json = """
        {
            "type": "snooze.cancelled",
            "payload": {
                "email_id": "email-1",
                "email": \(makeEmailJSON())
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .snoozeCancelled)
        if case let .snoozeCancelled(payload) = event.payload {
            #expect(payload.emailId == "email-1")
        } else {
            Issue.record("Expected snoozeCancelled payload")
        }
    }

    @Test("Decodes recommendation.new event")
    func decodeRecommendationNew() throws {
        let json = """
        {
            "type": "recommendation.new",
            "payload": {
                "recommendation": {
                    "id": "rec-1",
                    "type": "book",
                    "title": "Test Book",
                    "source_newsletter_name": "Newsletter",
                    "source_date": "2026-01-01T00:00:00Z",
                    "context_snippet": "Context",
                    "status": "new",
                    "duplicate_count": 1
                }
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .recommendationNew)
        if case let .recommendationNew(payload) = event.payload {
            #expect(payload.recommendation.title == "Test Book")
        } else {
            Issue.record("Expected recommendationNew payload")
        }
    }

    @Test("Decodes recommendation.updated event")
    func decodeRecommendationUpdated() throws {
        let json = """
        {
            "type": "recommendation.updated",
            "payload": {
                "recommendation": {
                    "id": "rec-1",
                    "type": "book",
                    "title": "Test Book",
                    "source_newsletter_name": "Newsletter",
                    "source_date": "2026-01-01T00:00:00Z",
                    "context_snippet": "Context",
                    "status": "saved",
                    "duplicate_count": 1
                }
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .recommendationUpdated)
        if case let .recommendationUpdated(payload) = event.payload {
            #expect(payload.recommendation.status == .saved)
        } else {
            Issue.record("Expected recommendationUpdated payload")
        }
    }

    @Test("Decodes digest.available event")
    func decodeDigestAvailable() throws {
        let json = """
        {
            "type": "digest.available",
            "payload": {
                "digest_id": "digest-1",
                "digest_type": "morning",
                "generated_at": "2026-02-07T07:00:00Z"
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .digestAvailable)
        if case let .digestAvailable(payload) = event.payload {
            #expect(payload.digestId == "digest-1")
            #expect(payload.digestType == .morning)
        } else {
            Issue.record("Expected digestAvailable payload")
        }
    }

    @Test("Decodes account.status event")
    func decodeAccountStatus() throws {
        let json = """
        {
            "type": "account.status",
            "payload": {
                "account_id": "acc-1",
                "status": "error",
                "status_message": "IMAP connection refused"
            }
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .accountStatus)
        if case let .accountStatus(payload) = event.payload {
            #expect(payload.accountId == "acc-1")
            #expect(payload.status == .error)
            #expect(payload.statusMessage == "IMAP connection refused")
        } else {
            Issue.record("Expected accountStatus payload")
        }
    }

    @Test("Decodes pong event")
    func decodePong() throws {
        let json = """
        {
            "type": "pong",
            "payload": {}
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: json)
        #expect(event.type == .pong)
        #expect(event.payload == .pong)
    }

    @Test("email.new round-trip encoding/decoding")
    func emailNewRoundTrip() throws {
        let event = WebSocketEvent(
            type: .emailNew,
            payload: .emailNew(
                EmailNewPayload(
                    email: Email(
                        id: "email-1",
                        accountId: "acc-1",
                        from: Contact(email: "a@b.com"),
                        to: [],
                        subject: "Test",
                        snippet: "",
                        receivedAt: ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!,
                        classification: Classification(
                            classification: .actionRequired,
                            confidence: 0.9,
                            classifiedBy: .llm
                        ),
                        isRead: false,
                        isArchived: false,
                        hasAttachments: false
                    )
                )
            ),
            timestamp: ISO8601DateFormatter().date(from: "2026-02-07T14:30:00Z")
        )

        let encoded = try JSONEncoder.apiEncoder.encode(event)
        let decoded = try JSONDecoder.apiDecoder.decode(WebSocketEvent.self, from: encoded)
        #expect(decoded == event)
    }

    @Test("All 12 event types are covered")
    func allEventTypes() {
        #expect(WebSocketEventType.allCases.count == 12)
    }
}

import Foundation
import Testing
@testable import EmailClientKit

@Suite("Request Models")
struct RequestModelsTests {
    @Test("EmailUpdateRequest encodes to snake_case")
    func emailUpdateEncoding() throws {
        let request = EmailUpdateRequest(isRead: true, isArchived: false, readProgress: 0.5)
        let data = try JSONEncoder.apiEncoder.encode(request)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["is_read"] as? Bool == true)
        #expect(json["is_archived"] as? Bool == false)
        #expect(json["read_progress"] as? Double == 0.5)
    }

    @Test("ReclassifyRequest encodes to snake_case")
    func reclassifyEncoding() throws {
        let request = ReclassifyRequest(newClassification: .newsletter, confirm: true)
        let data = try JSONEncoder.apiEncoder.encode(request)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["new_classification"] as? String == "newsletter")
        #expect(json["confirm"] as? Bool == true)
    }

    @Test("SnoozeRequest encodes to snake_case")
    func snoozeEncoding() throws {
        let date = ISO8601DateFormatter().date(from: "2026-02-08T09:00:00Z")!
        let request = SnoozeRequest(returnAt: date)
        let data = try JSONEncoder.apiEncoder.encode(request)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["return_at"] is String)
    }

    @Test("RecommendationCreateRequest round-trip")
    func recCreateRoundTrip() throws {
        let request = RecommendationCreateRequest(
            type: .book,
            title: "Test Book",
            creator: "Author",
            contextSnippet: "Great read"
        )
        let encoded = try JSONEncoder.apiEncoder.encode(request)
        let decoded = try JSONDecoder.apiDecoder.decode(RecommendationCreateRequest.self, from: encoded)
        #expect(decoded == request)
    }

    @Test("RecommendationUpdateRequest round-trip")
    func recUpdateRoundTrip() throws {
        let request = RecommendationUpdateRequest(status: .done)
        let encoded = try JSONEncoder.apiEncoder.encode(request)
        let decoded = try JSONDecoder.apiDecoder.decode(RecommendationUpdateRequest.self, from: encoded)
        #expect(decoded == request)
    }

    @Test("DigestUpdateRequest round-trip")
    func digestUpdateRoundTrip() throws {
        let request = DigestUpdateRequest(isRead: true)
        let encoded = try JSONEncoder.apiEncoder.encode(request)
        let decoded = try JSONDecoder.apiDecoder.decode(DigestUpdateRequest.self, from: encoded)
        #expect(decoded == request)
    }

    @Test("VIPCreateRequest round-trip")
    func vipCreateRoundTrip() throws {
        let request = VIPCreateRequest(email: "boss@work.com", name: "Boss")
        let encoded = try JSONEncoder.apiEncoder.encode(request)
        let decoded = try JSONDecoder.apiDecoder.decode(VIPCreateRequest.self, from: encoded)
        #expect(decoded == request)
    }

    @Test("EmailView raw values match API spec")
    func emailViewRawValues() {
        #expect(EmailView.actionQueue.rawValue == "action_queue")
        #expect(EmailView.readingQueue.rawValue == "reading_queue")
        #expect(EmailView.filtered.rawValue == "filtered")
        #expect(EmailView.allInboxes.rawValue == "all_inboxes")
    }
}

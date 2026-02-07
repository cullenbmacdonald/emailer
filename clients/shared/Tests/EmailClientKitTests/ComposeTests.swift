import Foundation
import Testing
@testable import EmailClientKit

@Suite("Compose Models")
struct ComposeTests {
    @Test("ComposeRequest round-trip")
    func composeRequestRoundTrip() throws {
        let request = ComposeRequest(
            accountId: "acc-1",
            to: ["recipient@example.com"],
            cc: ["cc@example.com"],
            subject: "Test subject",
            body: "Hello, world!",
            inReplyTo: "email-1"
        )
        let encoded = try JSONEncoder.apiEncoder.encode(request)
        let decoded = try JSONDecoder.apiDecoder.decode(ComposeRequest.self, from: encoded)
        #expect(decoded == request)
    }

    @Test("ComposeRequest encodes to snake_case JSON")
    func composeRequestSnakeCase() throws {
        let request = ComposeRequest(
            accountId: "acc-1",
            to: ["a@b.com"],
            subject: "Test",
            body: "Body",
            inReplyTo: "email-1"
        )
        let data = try JSONEncoder.apiEncoder.encode(request)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["account_id"] as? String == "acc-1")
        #expect(json["in_reply_to"] as? String == "email-1")
    }

    @Test("ComposeSendResponse decodes")
    func composeSendResponse() throws {
        let json = """
        {"message_id": "<abc123@mail.example.com>"}
        """.data(using: .utf8)!

        let response = try JSONDecoder.apiDecoder.decode(ComposeSendResponse.self, from: json)
        #expect(response.messageId == "<abc123@mail.example.com>")
    }

    @Test("Draft decodes from API JSON")
    func draftDecode() throws {
        let json = """
        {
            "id": "draft-1",
            "account_id": "acc-1",
            "to": ["a@b.com"],
            "cc": [],
            "subject": "Draft subject",
            "body": "Draft body",
            "created_at": "2026-02-07T10:00:00Z",
            "updated_at": "2026-02-07T10:30:00Z"
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder.apiDecoder.decode(Draft.self, from: json)
        #expect(draft.id == "draft-1")
        #expect(draft.accountId == "acc-1")
        #expect(draft.subject == "Draft subject")
    }

    @Test("Draft round-trip")
    func draftRoundTrip() throws {
        let draft = Draft(
            id: "draft-1",
            accountId: "acc-1",
            to: ["a@b.com"],
            subject: "Test",
            body: "Body",
            createdAt: ISO8601DateFormatter().date(from: "2026-02-07T10:00:00Z")!,
            updatedAt: ISO8601DateFormatter().date(from: "2026-02-07T10:30:00Z")!
        )
        let encoded = try JSONEncoder.apiEncoder.encode(draft)
        let decoded = try JSONDecoder.apiDecoder.decode(Draft.self, from: encoded)
        #expect(decoded == draft)
    }
}

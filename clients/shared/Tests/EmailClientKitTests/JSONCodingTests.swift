import Foundation
import Testing
@testable import EmailClientKit

@Suite("JSON Coding Utilities")
struct JSONCodingTests {
    @Test("apiDecoder uses snake_case key decoding")
    func decoderSnakeCase() throws {
        let json = """
        {"account_id": "abc", "is_read": true}
        """.data(using: .utf8)!

        struct Sample: Codable {
            let accountId: String
            let isRead: Bool
        }

        let decoded = try JSONDecoder.apiDecoder.decode(Sample.self, from: json)
        #expect(decoded.accountId == "abc")
        #expect(decoded.isRead == true)
    }

    @Test("apiDecoder handles ISO 8601 dates")
    func decoderDates() throws {
        let json = """
        {"timestamp": "2026-02-07T14:30:00Z"}
        """.data(using: .utf8)!

        struct Sample: Codable {
            let timestamp: Date
        }

        let decoded = try JSONDecoder.apiDecoder.decode(Sample.self, from: json)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: decoded.timestamp)
        #expect(components.year == 2026)
        #expect(components.month == 2)
        #expect(components.day == 7)
    }

    @Test("apiEncoder uses snake_case key encoding")
    func encoderSnakeCase() throws {
        struct Sample: Codable {
            let accountId: String
            let isRead: Bool
        }

        let sample = Sample(accountId: "abc", isRead: true)
        let data = try JSONEncoder.apiEncoder.encode(sample)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        #expect(json["account_id"] as? String == "abc")
        #expect(json["is_read"] as? Bool == true)
    }

    @Test("apiEncoder encodes ISO 8601 dates")
    func encoderDates() throws {
        struct Sample: Codable {
            let timestamp: Date
        }

        let date = ISO8601DateFormatter().date(from: "2026-02-07T14:30:00Z")!
        let sample = Sample(timestamp: date)
        let data = try JSONEncoder.apiEncoder.encode(sample)
        let jsonString = String(data: data, encoding: .utf8)!
        #expect(jsonString.contains("2026-02-07T14:30:00Z"))
    }
}

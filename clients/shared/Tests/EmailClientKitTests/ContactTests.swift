import Foundation
import Testing
@testable import EmailClientKit

@Suite("Contact Model")
struct ContactTests {
    @Test("Round-trip encoding/decoding")
    func roundTrip() throws {
        let contact = Contact(name: "Jane Smith", email: "jane@example.com")
        let data = try JSONEncoder.apiEncoder.encode(contact)
        let decoded = try JSONDecoder.apiDecoder.decode(Contact.self, from: data)
        #expect(decoded == contact)
    }

    @Test("Decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {"name": "Jane Smith", "email": "jane@example.com"}
        """.data(using: .utf8)!

        let contact = try JSONDecoder.apiDecoder.decode(Contact.self, from: json)
        #expect(contact.name == "Jane Smith")
        #expect(contact.email == "jane@example.com")
    }

    @Test("Decodes with missing name")
    func decodeMissingName() throws {
        let json = """
        {"email": "jane@example.com"}
        """.data(using: .utf8)!

        let contact = try JSONDecoder.apiDecoder.decode(Contact.self, from: json)
        #expect(contact.name == nil)
        #expect(contact.email == "jane@example.com")
    }
}

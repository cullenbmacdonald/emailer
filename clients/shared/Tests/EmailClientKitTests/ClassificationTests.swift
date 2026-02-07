import Foundation
import Testing
@testable import EmailClientKit

@Suite("Classification Model")
struct ClassificationTests {
    @Test("ClassificationType raw values match API spec")
    func classificationTypeRawValues() {
        #expect(ClassificationType.actionRequired.rawValue == "action_required")
        #expect(ClassificationType.newsletter.rawValue == "newsletter")
        #expect(ClassificationType.filtered.rawValue == "filtered")
        #expect(ClassificationType.transactional.rawValue == "transactional")
    }

    @Test("ClassifiedBy raw values match API spec")
    func classifiedByRawValues() {
        #expect(ClassifiedBy.rules.rawValue == "rules")
        #expect(ClassifiedBy.features.rawValue == "features")
        #expect(ClassifiedBy.llm.rawValue == "llm")
        #expect(ClassifiedBy.user.rawValue == "user")
    }

    @Test("Classification round-trip")
    func roundTrip() throws {
        let classification = Classification(
            classification: .actionRequired,
            confidence: 0.95,
            classifiedBy: .llm,
            reason: "Urgent language detected",
            isOverridden: false
        )
        let data = try JSONEncoder.apiEncoder.encode(classification)
        let decoded = try JSONDecoder.apiDecoder.decode(Classification.self, from: data)
        #expect(decoded == classification)
    }

    @Test("Decodes from API JSON with snake_case")
    func decodeFromAPI() throws {
        let json = """
        {
            "classification": "action_required",
            "confidence": 0.95,
            "classified_by": "llm",
            "reason": "Urgent language detected",
            "is_overridden": false
        }
        """.data(using: .utf8)!

        let classification = try JSONDecoder.apiDecoder.decode(Classification.self, from: json)
        #expect(classification.classification == .actionRequired)
        #expect(classification.confidence == 0.95)
        #expect(classification.classifiedBy == .llm)
        #expect(classification.reason == "Urgent language detected")
        #expect(classification.isOverridden == false)
    }

    @Test("Decodes with optional fields missing")
    func decodeMinimal() throws {
        let json = """
        {
            "classification": "newsletter",
            "confidence": 0.80,
            "classified_by": "rules"
        }
        """.data(using: .utf8)!

        let classification = try JSONDecoder.apiDecoder.decode(Classification.self, from: json)
        #expect(classification.classification == .newsletter)
        #expect(classification.reason == nil)
        #expect(classification.isOverridden == nil)
    }
}

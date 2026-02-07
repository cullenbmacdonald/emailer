import Foundation

/// The classification category assigned to an email.
public enum ClassificationType: String, Codable, Sendable, Equatable, CaseIterable {
    case actionRequired = "action_required"
    case newsletter
    case filtered
    case transactional
}

/// Which layer of the classification pipeline assigned the classification.
public enum ClassifiedBy: String, Codable, Sendable, Equatable, CaseIterable {
    case rules
    case features
    case llm
    case user
}

/// Classification metadata for an email.
public struct Classification: Codable, Sendable, Equatable {
    public let classification: ClassificationType
    public let confidence: Double
    public let classifiedBy: ClassifiedBy
    public let reason: String?
    public let isOverridden: Bool?

    public init(
        classification: ClassificationType,
        confidence: Double,
        classifiedBy: ClassifiedBy,
        reason: String? = nil,
        isOverridden: Bool? = nil
    ) {
        self.classification = classification
        self.confidence = confidence
        self.classifiedBy = classifiedBy
        self.reason = reason
        self.isOverridden = isOverridden
    }
}

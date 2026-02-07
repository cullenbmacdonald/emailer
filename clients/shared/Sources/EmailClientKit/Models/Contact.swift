import Foundation

/// A contact with an email address and optional display name.
public struct Contact: Codable, Sendable, Equatable, Hashable {
    public let name: String?
    public let email: String

    public init(name: String? = nil, email: String) {
        self.name = name
        self.email = email
    }
}

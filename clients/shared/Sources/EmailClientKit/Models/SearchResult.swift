import Foundation

/// A search result containing an email and a highlighted snippet.
public struct SearchResult: Codable, Sendable, Equatable {
    public let email: Email
    public let highlightSnippet: String

    public init(email: Email, highlightSnippet: String) {
        self.email = email
        self.highlightSnippet = highlightSnippet
    }
}

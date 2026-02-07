import Foundation

extension APIClient {
    /// Search emails with a query string (minimum 2 characters).
    public func search(
        query: String,
        accountID: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> SearchResponse {
        guard query.count >= 2 else {
            throw APIError.validationError("Search query must be at least 2 characters")
        }

        var queryItems = [URLQueryItem(name: "q", value: query)]
        if let accountID { queryItems.append(URLQueryItem(name: "account_id", value: accountID)) }
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return try await request(method: .get, path: "/api/v1/search", queryItems: queryItems)
    }
}

/// Response from the search endpoint.
public struct SearchResponse: Codable, Sendable, Equatable {
    public let data: [SearchResult]
    public let nextCursor: String?
    public let hasMore: Bool
    public let query: String

    public init(data: [SearchResult], nextCursor: String? = nil, hasMore: Bool, query: String) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.query = query
    }
}

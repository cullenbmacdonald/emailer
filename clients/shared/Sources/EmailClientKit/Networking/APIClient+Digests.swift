import Foundation

extension APIClient {
    /// Fetch a paginated list of digest summaries.
    public func fetchDigests(
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> PaginatedResponse<DigestSummary> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return try await request(
            method: .get,
            path: "/api/v1/digests",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Fetch the latest digest, optionally filtered by type.
    public func fetchLatestDigest(type: DigestType? = nil) async throws -> DailyDigest {
        var queryItems: [URLQueryItem]?
        if let type {
            queryItems = [URLQueryItem(name: "type", value: type.rawValue)]
        }
        return try await request(method: .get, path: "/api/v1/digests/latest", queryItems: queryItems)
    }

    /// Fetch a specific digest by ID.
    public func fetchDigest(id: String) async throws -> DailyDigest {
        try await request(method: .get, path: "/api/v1/digests/\(id)")
    }

    /// Update digest metadata (mark as read).
    public func updateDigest(id: String, isRead: Bool) async throws -> DailyDigest {
        let body = DigestUpdateRequest(isRead: isRead)
        return try await request(method: .patch, path: "/api/v1/digests/\(id)", body: body)
    }
}

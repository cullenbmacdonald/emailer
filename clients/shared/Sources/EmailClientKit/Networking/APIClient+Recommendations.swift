import Foundation

extension APIClient {
    /// Fetch a paginated list of recommendations.
    public func fetchRecommendations(
        type: RecommendationType? = nil,
        status: RecommendationStatus? = nil,
        accountID: String? = nil,
        sourceEmailID: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> PaginatedResponse<Recommendation> {
        var queryItems: [URLQueryItem] = []
        if let type { queryItems.append(URLQueryItem(name: "type", value: type.rawValue)) }
        if let status { queryItems.append(URLQueryItem(name: "status", value: status.rawValue)) }
        if let accountID { queryItems.append(URLQueryItem(name: "account_id", value: accountID)) }
        if let sourceEmailID { queryItems.append(URLQueryItem(name: "source_email_id", value: sourceEmailID)) }
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return try await request(
            method: .get,
            path: "/api/v1/recommendations",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Fetch full recommendation detail including duplicate sources.
    public func fetchRecommendationDetail(id: String) async throws -> RecommendationDetail {
        try await request(method: .get, path: "/api/v1/recommendations/\(id)")
    }

    /// Create a user-added recommendation.
    public func createRecommendation(
        _ request: RecommendationCreateRequest
    ) async throws -> Recommendation {
        try await self.request(method: .post, path: "/api/v1/recommendations", body: request)
    }

    /// Update recommendation status.
    public func updateRecommendationStatus(
        id: String,
        status: RecommendationStatus
    ) async throws -> Recommendation {
        let body = RecommendationUpdateRequest(status: status)
        return try await request(method: .patch, path: "/api/v1/recommendations/\(id)", body: body)
    }
}

import Foundation

extension APIClient {
    /// Send an email via SMTP.
    public func sendEmail(_ request: ComposeRequest) async throws -> ComposeSendResponse {
        try await self.request(method: .post, path: "/api/v1/compose/send", body: request)
    }

    /// List drafts.
    public func fetchDrafts(
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> PaginatedResponse<Draft> {
        var queryItems: [URLQueryItem] = []
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }

        return try await request(
            method: .get,
            path: "/api/v1/compose/drafts",
            queryItems: queryItems.isEmpty ? nil : queryItems
        )
    }

    /// Create a new draft.
    public func createDraft(_ request: ComposeRequest) async throws -> Draft {
        try await self.request(method: .post, path: "/api/v1/compose/drafts", body: request)
    }

    /// Update an existing draft.
    public func updateDraft(id: String, _ request: ComposeRequest) async throws -> Draft {
        try await self.request(method: .put, path: "/api/v1/compose/drafts/\(id)", body: request)
    }

    /// Delete a draft.
    public func deleteDraft(id: String) async throws {
        try await requestNoContent(method: .delete, path: "/api/v1/compose/drafts/\(id)")
    }
}

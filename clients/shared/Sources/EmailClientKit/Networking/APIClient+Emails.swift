import Foundation

extension APIClient {
    /// Fetch a paginated list of emails for a given view.
    public func fetchEmails(
        view: EmailView,
        accountID: String? = nil,
        cursor: String? = nil,
        limit: Int? = nil,
        isRead: Bool? = nil,
        isArchived: Bool? = nil
    ) async throws -> PaginatedResponse<Email> {
        var queryItems = [URLQueryItem(name: "view", value: view.rawValue)]
        if let accountID { queryItems.append(URLQueryItem(name: "account_id", value: accountID)) }
        if let cursor { queryItems.append(URLQueryItem(name: "cursor", value: cursor)) }
        if let limit { queryItems.append(URLQueryItem(name: "limit", value: String(limit))) }
        if let isRead { queryItems.append(URLQueryItem(name: "is_read", value: String(isRead))) }
        if let isArchived { queryItems.append(URLQueryItem(name: "is_archived", value: String(isArchived))) }

        return try await request(method: .get, path: "/api/v1/emails", queryItems: queryItems)
    }

    /// Fetch full email detail including body content.
    public func fetchEmailDetail(id: String, readerMode: Bool = false) async throws -> EmailDetail {
        var queryItems: [URLQueryItem]?
        if readerMode {
            queryItems = [URLQueryItem(name: "reader_mode", value: "true")]
        }
        return try await request(method: .get, path: "/api/v1/emails/\(id)", queryItems: queryItems)
    }

    /// Update email metadata (read state, archived state, read progress).
    public func updateEmail(
        id: String,
        isRead: Bool? = nil,
        isArchived: Bool? = nil,
        readProgress: Double? = nil
    ) async throws -> Email {
        let body = EmailUpdateRequest(isRead: isRead, isArchived: isArchived, readProgress: readProgress)
        return try await request(method: .patch, path: "/api/v1/emails/\(id)", body: body)
    }

    /// Permanently delete an email.
    public func deleteEmail(id: String) async throws {
        try await requestNoContent(method: .delete, path: "/api/v1/emails/\(id)")
    }

    /// Reclassify an email with a new classification.
    public func reclassifyEmail(
        id: String,
        classification: ClassificationType,
        confirm: Bool = false
    ) async throws -> Email {
        let body = ReclassifyRequest(newClassification: classification, confirm: confirm)
        return try await request(method: .post, path: "/api/v1/emails/\(id)/reclassify", body: body)
    }

    /// Snooze an email until a specified time.
    public func snoozeEmail(id: String, returnAt: Date) async throws -> SnoozeState {
        let body = SnoozeRequest(returnAt: returnAt)
        return try await request(method: .post, path: "/api/v1/emails/\(id)/snooze", body: body)
    }

    /// Cancel an active snooze on an email.
    public func unsnoozeEmail(id: String) async throws -> Email {
        try await request(method: .delete, path: "/api/v1/emails/\(id)/snooze")
    }
}

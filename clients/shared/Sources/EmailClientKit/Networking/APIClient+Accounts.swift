import Foundation

extension APIClient {
    /// Fetch all email accounts.
    public func fetchAccounts() async throws -> [Account] {
        let response: AccountListResponse = try await request(method: .get, path: "/api/v1/accounts")
        return response.data
    }

    /// Fetch a single account by ID.
    public func fetchAccount(id: String) async throws -> Account {
        try await request(method: .get, path: "/api/v1/accounts/\(id)")
    }
}

/// Response wrapper for account list (not paginated).
struct AccountListResponse: Codable, Sendable {
    let data: [Account]
}

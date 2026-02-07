import Foundation

extension APIClient {
    /// Fetch all VIP senders.
    public func fetchVIPSenders() async throws -> [VIPSender] {
        let response: VIPListResponse = try await request(method: .get, path: "/api/v1/vip")
        return response.data
    }

    /// Add a VIP sender.
    public func addVIPSender(email: String, name: String? = nil) async throws -> VIPSender {
        let body = VIPCreateRequest(email: email, name: name)
        return try await request(method: .post, path: "/api/v1/vip", body: body)
    }

    /// Remove a VIP sender.
    public func removeVIPSender(id: String) async throws {
        try await requestNoContent(method: .delete, path: "/api/v1/vip/\(id)")
    }
}

/// Response wrapper for VIP list (not paginated).
struct VIPListResponse: Codable, Sendable {
    let data: [VIPSender]
}

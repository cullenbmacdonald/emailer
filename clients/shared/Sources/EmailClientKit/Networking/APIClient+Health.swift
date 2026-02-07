import Foundation

extension APIClient {
    /// Fetch server health status. Does NOT require auth.
    public func fetchHealth() async throws -> HealthResponse {
        try await request(method: .get, path: "/health", requiresAuth: false)
    }
}

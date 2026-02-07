import Foundation

/// Discovers the server URL by trying multiple endpoints in order.
public actor ServerDiscovery {
    /// The URLs to try, in order of priority.
    private let candidates: [URL]
    private let session: URLSession
    private let timeout: TimeInterval

    /// Creates a server discovery actor.
    ///
    /// - Parameters:
    ///   - configuredURL: The user-configured URL (highest priority).
    ///   - localURL: The local development URL (e.g., http://localhost:8080).
    ///   - tailscaleURL: The Tailscale/Caddy URL (e.g., https://emailer.tailnet.ts.net).
    ///   - session: The URL session to use for health checks.
    ///   - timeout: Timeout for each health check request.
    public init(
        configuredURL: URL? = nil,
        localURL: URL? = URL(string: "http://localhost:8080"),
        tailscaleURL: URL? = nil,
        session: URLSession = .shared,
        timeout: TimeInterval = 5.0
    ) {
        var urls: [URL] = []
        if let configuredURL { urls.append(configuredURL) }
        if let localURL { urls.append(localURL) }
        if let tailscaleURL { urls.append(tailscaleURL) }
        self.candidates = urls
        self.session = session
        self.timeout = timeout
    }

    /// Discover the first reachable server by checking /health on each candidate.
    ///
    /// - Returns: The URL of the first reachable server.
    /// - Throws: `APIError.serverUnreachable` if no server responds.
    public func discover() async throws -> URL {
        for candidate in candidates where await isReachable(candidate) {
            return candidate
        }
        throw APIError.serverUnreachable
    }

    private func isReachable(_ baseURL: URL) async -> Bool {
        let healthURL = baseURL.appendingPathComponent("/health")
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = timeout
        request.httpMethod = "GET"

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<500).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}

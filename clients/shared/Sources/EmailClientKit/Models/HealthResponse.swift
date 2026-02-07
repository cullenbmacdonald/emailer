import Foundation

/// Health status of the server.
public enum HealthStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case healthy
    case degraded
    case unhealthy
}

/// Service check status.
public enum CheckStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case ok
    case error
    case unavailable
}

/// IMAP connection status per account.
public enum IMAPStatus: String, Codable, Sendable, Equatable, CaseIterable {
    case connected
    case disconnected
    case error
}

/// Health check response from the server.
public struct HealthChecks: Codable, Sendable, Equatable {
    public let database: CheckStatus?
    public let ollama: CheckStatus?
    public let imap: [String: IMAPStatus]?

    public init(
        database: CheckStatus? = nil,
        ollama: CheckStatus? = nil,
        imap: [String: IMAPStatus]? = nil
    ) {
        self.database = database
        self.ollama = ollama
        self.imap = imap
    }
}

/// Response from the health endpoint.
public struct HealthResponse: Codable, Sendable, Equatable {
    public let status: HealthStatus
    public let version: String?
    public let commit: String?
    public let uptimeSeconds: Int?
    public let checks: HealthChecks?

    public init(
        status: HealthStatus,
        version: String? = nil,
        commit: String? = nil,
        uptimeSeconds: Int? = nil,
        checks: HealthChecks? = nil
    ) {
        self.status = status
        self.version = version
        self.commit = commit
        self.uptimeSeconds = uptimeSeconds
        self.checks = checks
    }
}

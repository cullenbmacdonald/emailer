import Foundation

/// Errors that can occur when communicating with the Emailer API.
public enum APIError: Error, Sendable, Equatable, LocalizedError {
    /// An HTTP error with status code and optional server error body.
    case httpError(statusCode: Int, serverError: ServerError?)

    /// The request was unauthorized (HTTP 401).
    case unauthorized

    /// The requested resource was not found (HTTP 404).
    case notFound(String?)

    /// A conflict occurred (HTTP 409), e.g. duplicate VIP sender.
    case conflict(String?)

    /// Failed to decode a response from the server.
    case decodingError(String)

    /// The server is unreachable.
    case serverUnreachable

    /// The server returned an invalid response.
    case invalidResponse

    /// A client-side validation error.
    case validationError(String)

    public var errorDescription: String? {
        switch self {
        case let .httpError(statusCode, serverError):
            if let message = serverError?.message {
                return "HTTP \(statusCode): \(message)"
            }
            return "HTTP error \(statusCode)"
        case .unauthorized:
            return "Unauthorized: invalid or missing authentication token"
        case let .notFound(message):
            return message ?? "Resource not found"
        case let .conflict(message):
            return message ?? "Conflict"
        case let .decodingError(message):
            return "Decoding error: \(message)"
        case .serverUnreachable:
            return "Server is unreachable"
        case .invalidResponse:
            return "Invalid response from server"
        case let .validationError(message):
            return message
        }
    }
}

/// Error response body from the server.
public struct ServerError: Codable, Sendable, Equatable {
    public let code: String
    public let message: String
    public let details: [String: String]?

    public init(code: String, message: String, details: [String: String]? = nil) {
        self.code = code
        self.message = message
        self.details = details
    }
}

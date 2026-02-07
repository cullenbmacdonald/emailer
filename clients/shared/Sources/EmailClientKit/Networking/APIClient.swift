import Foundation

/// HTTP methods used by the API client.
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Thread-safe API client for the Emailer REST API.
public actor APIClient {
    private var baseURL: URL
    private var token: String
    private let session: URLSession
    private let retryPolicy: RetryPolicy
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(
        baseURL: URL,
        token: String,
        session: URLSession = .shared,
        retryPolicy: RetryPolicy = RetryPolicy()
    ) {
        self.baseURL = baseURL
        self.token = token
        self.session = session
        self.retryPolicy = retryPolicy
        self.decoder = .apiDecoder
        self.encoder = .apiEncoder
    }

    /// Update the base URL at runtime (e.g., after server discovery).
    public func updateBaseURL(_ url: URL) {
        self.baseURL = url
    }

    /// Update the auth token at runtime.
    public func updateToken(_ token: String) {
        self.token = token
    }

    // MARK: - Core Request Methods

    /// Perform a request that returns a decoded response body.
    func request<T: Decodable & Sendable>(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (some Encodable & Sendable)? = nil as Empty?,
        requiresAuth: Bool = true
    ) async throws -> T {
        let urlRequest = try buildRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            requiresAuth: requiresAuth
        )

        let (data, _) = try await performRequest(urlRequest, method: method)
        return try decodeResponse(data)
    }

    /// Perform a request that returns no response body (e.g., DELETE → 204).
    func requestNoContent(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]? = nil,
        body: (some Encodable & Sendable)? = nil as Empty?,
        requiresAuth: Bool = true
    ) async throws {
        let urlRequest = try buildRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            requiresAuth: requiresAuth
        )

        _ = try await performRequest(urlRequest, method: method)
    }

    // MARK: - Private Helpers

    private func buildRequest(
        method: HTTPMethod,
        path: String,
        queryItems: [URLQueryItem]?,
        body: (some Encodable)?,
        requiresAuth: Bool
    ) throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        if let queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        if requiresAuth {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body, !(body is Empty) {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        return request
    }

    private func performRequest(
        _ request: URLRequest,
        method: HTTPMethod
    ) async throws -> (Data, URLResponse) {
        // Only retry GET requests
        guard method == .get else {
            let (data, response) = try await executeRequest(request)
            try validateResponse(response, data: data)
            return (data, response)
        }

        var lastError: Error?
        for attempt in 0..<retryPolicy.maxAttempts {
            do {
                let (data, response) = try await executeRequest(request)
                try validateResponse(response, data: data)
                return (data, response)
            } catch {
                lastError = error

                // Don't retry client errors (4xx) — only retry on network/server errors
                if let apiError = error as? APIError {
                    switch apiError {
                    case .unauthorized, .notFound, .conflict, .invalidResponse, .decodingError, .validationError:
                        throw error
                    case .httpError(let statusCode, _) where statusCode < 500:
                        throw error
                    default:
                        break
                    }
                }

                let isLastAttempt = attempt == retryPolicy.maxAttempts - 1
                if isLastAttempt { break }

                let delay = retryPolicy.delay(forAttempt: attempt)
                try await Task.sleep(for: .seconds(delay))
            }
        }

        throw lastError ?? APIError.serverUnreachable
    }

    private func executeRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch is URLError {
            throw APIError.serverUnreachable
        } catch {
            throw APIError.serverUnreachable
        }
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        guard (200..<300).contains(statusCode) else {
            // Try to decode server error body
            let serverError = try? decoder.decode(ServerError.self, from: data)

            switch statusCode {
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound(serverError?.message)
            case 409:
                throw APIError.conflict(serverError?.message)
            default:
                throw APIError.httpError(statusCode: statusCode, serverError: serverError)
            }
        }
    }

    private func decodeResponse<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}

/// Empty type used as a default for requests with no body.
struct Empty: Encodable, Sendable {}

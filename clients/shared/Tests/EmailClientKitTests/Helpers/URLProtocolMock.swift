import Foundation

/// Thread-safe handler registry for URLProtocolMock.
/// Each test registers a handler with a unique token, embedded in the session's
/// additional headers, so concurrent tests don't interfere with each other.
final class MockHandlerRegistry: @unchecked Sendable {
    static let shared = MockHandlerRegistry()

    private let lock = NSLock()
    private var _handlers: [String: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    private var _capturedRequests: [String: [URLRequest]] = [:]

    func register(
        token: String,
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        lock.lock()
        _handlers[token] = handler
        _capturedRequests[token] = []
        lock.unlock()
    }

    func handler(for token: String) -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        lock.lock()
        defer { lock.unlock() }
        return _handlers[token]
    }

    func captureRequest(_ request: URLRequest, token: String) {
        lock.lock()
        _capturedRequests[token, default: []].append(request)
        lock.unlock()
    }

    func capturedRequests(for token: String) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return _capturedRequests[token] ?? []
    }

    func unregister(token: String) {
        lock.lock()
        _handlers.removeValue(forKey: token)
        _capturedRequests.removeValue(forKey: token)
        lock.unlock()
    }
}

/// Mock URL protocol for testing API client without a real server.
/// Uses a per-session token (via custom HTTP header) so tests can run concurrently.
final class URLProtocolMock: URLProtocol, @unchecked Sendable {
    /// Header name used to route requests to the correct mock handler.
    static let tokenHeader = "X-Mock-Token"

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let token = request.value(forHTTPHeaderField: Self.tokenHeader) ?? "default"

        MockHandlerRegistry.shared.captureRequest(request, token: token)

        guard let handler = MockHandlerRegistry.shared.handler(for: token) else {
            let error = URLError(.badServerResponse)
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

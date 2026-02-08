import Foundation
@testable import EmailClientKit

/// Container for a mock API client with its own isolated handler registry.
/// Each test gets its own token so concurrent tests don't interfere.
struct MockAPIContext: Sendable {
    let client: APIClient
    let token: String

    /// Register a request handler for this context's mock session.
    func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        MockHandlerRegistry.shared.register(token: token, handler: handler)
    }

    /// Get captured requests for this context.
    var capturedRequests: [URLRequest] {
        MockHandlerRegistry.shared.capturedRequests(for: token)
    }

    /// Clean up the handler registry.
    func tearDown() {
        MockHandlerRegistry.shared.unregister(token: token)
    }
}

/// Creates a mock API context with an isolated URLSession and handler registry.
func makeMockContext(retryPolicy: RetryPolicy = RetryPolicy(maxAttempts: 1)) -> MockAPIContext {
    let mockToken = UUID().uuidString
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [URLProtocolMock.self]
    config.httpAdditionalHeaders = [URLProtocolMock.tokenHeader: mockToken]
    let session = URLSession(configuration: config)

    let client = APIClient(
        baseURL: URL(string: "http://test.local")!,
        token: "test-token",
        session: session,
        retryPolicy: retryPolicy
    )

    return MockAPIContext(client: client, token: mockToken)
}

/// Creates a mock HTTP response.
func mockResponse(
    url: String = "http://test.local",
    statusCode: Int = 200,
    headers: [String: String]? = ["Content-Type": "application/json"]
) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: url)!,
        statusCode: statusCode,
        httpVersion: "HTTP/1.1",
        headerFields: headers
    )!
}

/// Convenience factory for creating test Email instances.
enum TestHelpers {
    static func makeEmail(
        id: String = "email-1",
        subject: String = "Test Email",
        classification: ClassificationType = .actionRequired,
        isRead: Bool = false
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: "Jane", email: "jane@example.com"),
            to: [Contact(email: "john@example.com")],
            subject: subject,
            snippet: "This is a test",
            receivedAt: Date(),
            classification: Classification(
                classification: classification,
                confidence: 0.95,
                classifiedBy: .llm
            ),
            isRead: isRead,
            isArchived: false,
            hasAttachments: false
        )
    }
}

/// Sample email JSON for tests.
let sampleEmailJSON = """
{
    "id": "email-1",
    "account_id": "acc-1",
    "from": {"name": "Jane", "email": "jane@example.com"},
    "to": [{"email": "john@example.com"}],
    "subject": "Test Email",
    "snippet": "This is a test",
    "received_at": "2026-02-07T14:30:00Z",
    "classification": {
        "classification": "action_required",
        "confidence": 0.95,
        "classified_by": "llm"
    },
    "is_read": false,
    "is_archived": false,
    "has_attachments": false
}
"""

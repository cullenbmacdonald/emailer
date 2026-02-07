import Foundation
import Testing
@testable import EmailClientKit

/// Thread-safe counter for tracking mock handler invocations.
final class AtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: Int = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    @discardableResult
    func increment() -> Int {
        lock.lock()
        _value += 1
        let result = _value
        lock.unlock()
        return result
    }
}

@Suite("APIClient Retry Logic")
struct APIClientRetryTests {
    @Test("GET requests retry on server error")
    func retryOnServerError() async throws {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        let ctx = makeMockContext(retryPolicy: policy)
        defer { ctx.tearDown() }

        let counter = AtomicCounter()
        ctx.setHandler { _ in
            let count = counter.increment()
            if count < 3 {
                return (mockResponse(statusCode: 503), Data("{\"code\":\"unavailable\",\"message\":\"Retry\"}".utf8))
            }
            let json = "{\"data\":[],\"has_more\":false}"
            return (mockResponse(), Data(json.utf8))
        }

        let response: PaginatedResponse<Email> = try await ctx.client.fetchEmails(view: .actionQueue)

        #expect(response.data.isEmpty)
        #expect(counter.value == 3)
    }

    @Test("GET requests do not retry on 4xx errors")
    func noRetryOn4xx() async throws {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        let ctx = makeMockContext(retryPolicy: policy)
        defer { ctx.tearDown() }

        let counter = AtomicCounter()
        ctx.setHandler { _ in
            counter.increment()
            return (mockResponse(statusCode: 404), Data("{\"code\":\"not_found\",\"message\":\"Not found\"}".utf8))
        }

        do {
            _ = try await ctx.client.fetchEmailDetail(id: "nonexistent")
            Issue.record("Expected error")
        } catch {
            #expect(counter.value == 1)
        }
    }

    @Test("POST requests do not retry")
    func noRetryOnPost() async throws {
        let policy = RetryPolicy(maxAttempts: 3, baseDelay: 0.01, maxDelay: 0.1)
        let ctx = makeMockContext(retryPolicy: policy)
        defer { ctx.tearDown() }

        let counter = AtomicCounter()
        ctx.setHandler { _ in
            counter.increment()
            return (mockResponse(statusCode: 503), Data("{\"code\":\"unavailable\",\"message\":\"Retry\"}".utf8))
        }

        do {
            _ = try await ctx.client.sendEmail(ComposeRequest(
                accountId: "acc-1",
                to: ["a@b.com"],
                subject: "Test",
                body: "Body"
            ))
            Issue.record("Expected error")
        } catch {
            #expect(counter.value == 1)
        }
    }

    @Test("RetryPolicy calculates exponential delays")
    func exponentialDelay() {
        let policy = RetryPolicy(maxAttempts: 5, baseDelay: 1.0, maxDelay: 8.0)
        #expect(policy.delay(forAttempt: 0) == 1.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 4.0)
        #expect(policy.delay(forAttempt: 3) == 8.0)
        #expect(policy.delay(forAttempt: 4) == 8.0) // capped at maxDelay
    }
}

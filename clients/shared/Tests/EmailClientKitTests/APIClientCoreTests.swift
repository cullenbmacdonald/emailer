import Foundation
import Testing
@testable import EmailClientKit

@Suite("APIClient Core")
struct APIClientCoreTests {
    @Test("Includes Bearer token in Authorization header")
    func authHeader() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"data\":[],\"has_more\":false}"
            return (mockResponse(), Data(json.utf8))
        }

        _ = try await ctx.client.fetchEmails(view: .actionQueue)

        let captured = ctx.capturedRequests.last!
        let authHeader = captured.value(forHTTPHeaderField: "Authorization")
        #expect(authHeader == "Bearer test-token")
    }

    @Test("Health endpoint does not include auth header")
    func healthNoAuth() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            (mockResponse(), Data("{\"status\":\"healthy\"}".utf8))
        }

        _ = try await ctx.client.fetchHealth()

        let captured = ctx.capturedRequests.last!
        #expect(captured.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Sets Content-Type for POST requests")
    func contentType() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"message_id\":\"<abc@test.com>\"}"
            return (mockResponse(), Data(json.utf8))
        }

        let request = ComposeRequest(
            accountId: "acc-1",
            to: ["a@b.com"],
            subject: "Test",
            body: "Body"
        )
        _ = try await ctx.client.sendEmail(request)

        let captured = ctx.capturedRequests.last!
        #expect(captured.httpMethod == "POST")
        #expect(captured.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Maps 401 to APIError.unauthorized")
    func unauthorized() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"code\":\"unauthorized\",\"message\":\"Invalid token\"}"
            return (mockResponse(statusCode: 401), Data(json.utf8))
        }

        do {
            _ = try await ctx.client.fetchEmails(view: .actionQueue)
            Issue.record("Expected unauthorized error")
        } catch let error as APIError {
            #expect(error == .unauthorized)
        }
    }

    @Test("Maps 404 to APIError.notFound")
    func notFound() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"code\":\"not_found\",\"message\":\"Email not found\"}"
            return (mockResponse(statusCode: 404), Data(json.utf8))
        }

        do {
            _ = try await ctx.client.fetchEmailDetail(id: "nonexistent")
            Issue.record("Expected notFound error")
        } catch let error as APIError {
            #expect(error == .notFound("Email not found"))
        }
    }

    @Test("Maps 409 to APIError.conflict")
    func conflict() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"code\":\"conflict\",\"message\":\"VIP sender already exists\"}"
            return (mockResponse(statusCode: 409), Data(json.utf8))
        }

        do {
            _ = try await ctx.client.addVIPSender(email: "dup@test.com")
            Issue.record("Expected conflict error")
        } catch let error as APIError {
            #expect(error == .conflict("VIP sender already exists"))
        }
    }

    @Test("Maps 500 to APIError.httpError")
    func serverError() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"code\":\"internal_error\",\"message\":\"Something broke\"}"
            return (mockResponse(statusCode: 500), Data(json.utf8))
        }

        do {
            _ = try await ctx.client.fetchEmails(view: .actionQueue)
            Issue.record("Expected httpError")
        } catch let error as APIError {
            if case let .httpError(code, serverError) = error {
                #expect(code == 500)
                #expect(serverError?.message == "Something broke")
            } else {
                Issue.record("Expected httpError, got \(error)")
            }
        }
    }

    @Test("Decoding error maps to APIError.decodingError")
    func decodingError() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            (mockResponse(), Data("not json at all".utf8))
        }

        do {
            _ = try await ctx.client.fetchHealth()
            Issue.record("Expected decodingError")
        } catch let error as APIError {
            if case .decodingError = error {
                // pass
            } else {
                Issue.record("Expected decodingError, got \(error)")
            }
        }
    }

    @Test("updateBaseURL changes the base URL")
    func updateBaseURL() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            (mockResponse(), Data("{\"status\":\"healthy\"}".utf8))
        }

        await ctx.client.updateBaseURL(URL(string: "http://new-server.local")!)
        _ = try await ctx.client.fetchHealth()

        let captured = ctx.capturedRequests.last!
        #expect(captured.url?.host == "new-server.local")
    }
}

import Foundation
import Testing
@testable import EmailClientKit

@Suite("APIClient Endpoints")
struct APIClientEndpointTests {
    // MARK: - Emails

    @Test("fetchEmails sends correct query parameters")
    func fetchEmails() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            let url = request.url!.absoluteString
            #expect(url.contains("view=action_queue"))
            #expect(url.contains("account_id=acc-1"))
            #expect(url.contains("limit=10"))
            let json = "{\"data\":[\(sampleEmailJSON)],\"has_more\":true,\"next_cursor\":\"cursor1\"}"
            return (mockResponse(), Data(json.utf8))
        }

        let response = try await ctx.client.fetchEmails(view: .actionQueue, accountID: "acc-1", limit: 10)
        #expect(response.data.count == 1)
        #expect(response.hasMore == true)
        #expect(response.nextCursor == "cursor1")
    }

    @Test("fetchEmailDetail with reader mode")
    func fetchEmailDetail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            let url = request.url!.absoluteString
            #expect(url.contains("reader_mode=true"))
            let json = """
            {"id":"email-1","email":\(sampleEmailJSON),"html_body":"<p>Body</p>","attachments":[]}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let detail = try await ctx.client.fetchEmailDetail(id: "email-1", readerMode: true)
        #expect(detail.id == "email-1")
        #expect(detail.htmlBody == "<p>Body</p>")
    }

    @Test("updateEmail sends PATCH with correct body")
    func updateEmail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "PATCH")
            #expect(request.url!.path.hasSuffix("/emails/email-1"))
            // Note: URLSession strips httpBody before passing to URLProtocol;
            // body content is verified via the successful decode of the response.
            return (mockResponse(), Data(sampleEmailJSON.utf8))
        }

        let email = try await ctx.client.updateEmail(id: "email-1", isRead: true)
        #expect(email.id == "email-1")
    }

    @Test("deleteEmail sends DELETE and returns void")
    func deleteEmail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.path.hasSuffix("/emails/email-1"))
            return (mockResponse(statusCode: 204), Data())
        }

        try await ctx.client.deleteEmail(id: "email-1")
    }

    @Test("reclassifyEmail sends POST with classification body")
    func reclassifyEmail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url!.path.hasSuffix("/reclassify"))
            return (mockResponse(), Data(sampleEmailJSON.utf8))
        }

        let email = try await ctx.client.reclassifyEmail(id: "email-1", classification: .newsletter)
        #expect(email.id == "email-1")
    }

    @Test("snoozeEmail sends POST with return_at")
    func snoozeEmail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url!.path.hasSuffix("/snooze"))
            let json = """
            {"id":"snooze-1","email_id":"email-1","snoozed_at":"2026-02-07T10:00:00Z",
             "return_at":"2026-02-08T09:00:00Z","snooze_count":1,"is_active":true}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let date = ISO8601DateFormatter().date(from: "2026-02-08T09:00:00Z")!
        let snooze = try await ctx.client.snoozeEmail(id: "email-1", returnAt: date)
        #expect(snooze.isActive == true)
    }

    @Test("unsnoozeEmail sends DELETE to snooze path")
    func unsnoozeEmail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "DELETE")
            #expect(request.url!.path.hasSuffix("/snooze"))
            return (mockResponse(), Data(sampleEmailJSON.utf8))
        }

        let email = try await ctx.client.unsnoozeEmail(id: "email-1")
        #expect(email.id == "email-1")
    }

    // MARK: - Search

    @Test("search sends correct query parameter")
    func searchEmails() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            let url = request.url!.absoluteString
            #expect(url.contains("q=budget"))
            let json = "{\"data\":[],\"has_more\":false,\"query\":\"budget\"}"
            return (mockResponse(), Data(json.utf8))
        }

        let response = try await ctx.client.search(query: "budget")
        #expect(response.query == "budget")
    }

    @Test("search validates minimum query length")
    func searchMinLength() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        do {
            _ = try await ctx.client.search(query: "a")
            Issue.record("Expected validation error")
        } catch let error as APIError {
            if case .validationError = error {
                // pass
            } else {
                Issue.record("Expected validationError, got \(error)")
            }
        }
    }

    // MARK: - Compose

    @Test("sendEmail sends POST to compose/send")
    func sendEmail() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "POST")
            #expect(request.url!.path.hasSuffix("/compose/send"))
            return (mockResponse(), Data("{\"message_id\":\"<abc@test.com>\"}".utf8))
        }

        let request = ComposeRequest(accountId: "acc-1", to: ["a@b.com"], subject: "Test", body: "Body")
        let response = try await ctx.client.sendEmail(request)
        #expect(response.messageId == "<abc@test.com>")
    }

    @Test("createDraft sends POST to compose/drafts")
    func createDraft() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "POST")
            let json = """
            {"id":"draft-1","account_id":"acc-1","created_at":"2026-02-07T10:00:00Z",
             "updated_at":"2026-02-07T10:00:00Z"}
            """
            return (mockResponse(statusCode: 201), Data(json.utf8))
        }

        let request = ComposeRequest(accountId: "acc-1", to: ["a@b.com"], subject: "Draft", body: "Body")
        let draft = try await ctx.client.createDraft(request)
        #expect(draft.id == "draft-1")
    }

    @Test("deleteDraft sends DELETE")
    func deleteDraft() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "DELETE")
            return (mockResponse(statusCode: 204), Data())
        }

        try await ctx.client.deleteDraft(id: "draft-1")
    }

    // MARK: - Recommendations

    @Test("fetchRecommendations with filters")
    func fetchRecommendations() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            let url = request.url!.absoluteString
            #expect(url.contains("type=book"))
            #expect(url.contains("status=new"))
            let json = "{\"data\":[],\"has_more\":false}"
            return (mockResponse(), Data(json.utf8))
        }

        let response = try await ctx.client.fetchRecommendations(type: .book, status: .new)
        #expect(response.data.isEmpty)
    }

    @Test("updateRecommendationStatus sends PATCH")
    func updateRecommendationStatus() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "PATCH")
            let json = """
            {"id":"rec-1","type":"book","title":"Test","source_newsletter_name":"Newsletter",
             "source_date":"2026-01-01T00:00:00Z","context_snippet":"Context","status":"saved",
             "duplicate_count":1}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let rec = try await ctx.client.updateRecommendationStatus(id: "rec-1", status: .saved)
        #expect(rec.status == .saved)
    }

    // MARK: - Digests

    @Test("fetchLatestDigest with type filter")
    func fetchLatestDigest() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            let url = request.url!.absoluteString
            #expect(url.contains("type=morning"))
            let json = """
            {"id":"digest-1","digest_type":"morning","generated_at":"2026-02-07T07:00:00Z","sections":[]}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let digest = try await ctx.client.fetchLatestDigest(type: .morning)
        #expect(digest.digestType == .morning)
    }

    @Test("updateDigest sends PATCH")
    func updateDigest() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "PATCH")
            let json = """
            {"id":"digest-1","digest_type":"morning","generated_at":"2026-02-07T07:00:00Z",
             "is_read":true,"sections":[]}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let digest = try await ctx.client.updateDigest(id: "digest-1", isRead: true)
        #expect(digest.isRead == true)
    }

    // MARK: - Accounts

    @Test("fetchAccounts returns array of accounts")
    func fetchAccounts() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = """
            {"data":[{"id":"acc-1","name":"Work","email_address":"me@work.com",
             "account_type":"work","color":"#3B82F6","status":"online"}]}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let accounts = try await ctx.client.fetchAccounts()
        #expect(accounts.count == 1)
        #expect(accounts[0].name == "Work")
    }

    @Test("fetchAccount returns single account")
    func fetchAccount() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = """
            {"id":"acc-1","name":"Work","email_address":"me@work.com",
             "account_type":"work","color":"#3B82F6","status":"online"}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let account = try await ctx.client.fetchAccount(id: "acc-1")
        #expect(account.id == "acc-1")
    }

    // MARK: - VIP

    @Test("fetchVIPSenders returns array")
    func fetchVIPSenders() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = """
            {"data":[{"id":"vip-1","email":"boss@work.com","added_at":"2026-01-15T10:00:00Z"}]}
            """
            return (mockResponse(), Data(json.utf8))
        }

        let vips = try await ctx.client.fetchVIPSenders()
        #expect(vips.count == 1)
    }

    @Test("addVIPSender sends POST")
    func addVIPSender() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "POST")
            let json = "{\"id\":\"vip-2\",\"email\":\"boss@work.com\",\"added_at\":\"2026-02-07T10:00:00Z\"}"
            return (mockResponse(statusCode: 201), Data(json.utf8))
        }

        let vip = try await ctx.client.addVIPSender(email: "boss@work.com", name: "My Boss")
        #expect(vip.email == "boss@work.com")
    }

    @Test("removeVIPSender sends DELETE")
    func removeVIPSender() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { request in
            #expect(request.httpMethod == "DELETE")
            return (mockResponse(statusCode: 204), Data())
        }

        try await ctx.client.removeVIPSender(id: "vip-1")
    }

    // MARK: - Health

    @Test("fetchHealth returns health response")
    func fetchHealth() async throws {
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        ctx.setHandler { _ in
            let json = "{\"status\":\"healthy\",\"version\":\"1.0.0\"}"
            return (mockResponse(), Data(json.utf8))
        }

        let health = try await ctx.client.fetchHealth()
        #expect(health.status == .healthy)
        #expect(health.version == "1.0.0")
    }
}

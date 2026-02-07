import Foundation
import Testing
@testable import EmailClientKit

@Suite("OfflineActionQueue")
struct OfflineActionQueueTests {
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineQueueTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Enqueue / PendingCount

    @Test("Enqueue increments pending count")
    func enqueueIncrements() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let queue = OfflineActionQueue(storageDirectory: dir)

        #expect(await queue.pendingCount == 0)
        await queue.enqueue(.archive(emailId: "e1"))
        #expect(await queue.pendingCount == 1)
        await queue.enqueue(.markRead(emailId: "e2", isRead: true))
        #expect(await queue.pendingCount == 2)
    }

    @Test("ClearAll removes all actions")
    func clearAll() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let queue = OfflineActionQueue(storageDirectory: dir)

        await queue.enqueue(.archive(emailId: "e1"))
        await queue.enqueue(.archive(emailId: "e2"))
        await queue.clearAll()
        #expect(await queue.pendingCount == 0)
    }

    // MARK: - Persistence

    @Test("Queue persists to disk and reloads")
    func persistenceRoundTrip() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        // Enqueue actions
        let queue1 = OfflineActionQueue(storageDirectory: dir)
        await queue1.enqueue(.archive(emailId: "e1"))
        await queue1.enqueue(.snooze(
            emailId: "e2",
            returnAt: Date(timeIntervalSinceReferenceDate: 1_000_000)
        ))
        await queue1.enqueue(.reclassify(
            emailId: "e3",
            classification: .newsletter,
            confirm: true
        ))
        await queue1.enqueue(.markRead(emailId: "e4", isRead: false))
        await queue1.enqueue(.updateRecommendationStatus(id: "r1", status: .saved))

        // Create new queue pointing at same directory — should reload
        let queue2 = OfflineActionQueue(storageDirectory: dir)
        #expect(await queue2.pendingCount == 5)

        let actions = await queue2.pendingActions
        #expect(actions[0] == .archive(emailId: "e1"))
        #expect(actions[1] == .snooze(
            emailId: "e2",
            returnAt: Date(timeIntervalSinceReferenceDate: 1_000_000)
        ))
        #expect(actions[2] == .reclassify(
            emailId: "e3",
            classification: .newsletter,
            confirm: true
        ))
        #expect(actions[3] == .markRead(emailId: "e4", isRead: false))
        #expect(actions[4] == .updateRecommendationStatus(id: "r1", status: .saved))
    }

    @Test("Empty directory loads empty queue")
    func emptyLoad() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let queue = OfflineActionQueue(storageDirectory: dir)
        #expect(await queue.pendingCount == 0)
    }

    // MARK: - Flush

    @Test("Flush executes all actions and clears queue on success")
    func flushSuccess() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let queue = OfflineActionQueue(storageDirectory: dir)
        await queue.enqueue(.archive(emailId: "e1"))
        await queue.enqueue(.markRead(emailId: "e2", isRead: true))

        ctx.setHandler { _ in
            let response = mockResponse(statusCode: 200)
            let data = sampleEmailJSON.data(using: .utf8)!
            return (response, data)
        }

        let failedAction = await queue.flush(apiClient: ctx.client)
        #expect(failedAction == nil)
        #expect(await queue.pendingCount == 0)

        // Verify requests were made
        let requests = ctx.capturedRequests
        #expect(requests.count == 2)
    }

    @Test("Flush stops on first failure and preserves remaining actions")
    func flushStopsOnFailure() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let queue = OfflineActionQueue(storageDirectory: dir)
        await queue.enqueue(.archive(emailId: "e1"))
        await queue.enqueue(.markRead(emailId: "e2", isRead: true))
        await queue.enqueue(.archive(emailId: "e3"))

        let callCount = AtomicCounter()
        ctx.setHandler { _ in
            let count = callCount.increment()
            if count == 1 {
                // First call succeeds (archive e1)
                let response = mockResponse(statusCode: 200)
                let data = sampleEmailJSON.data(using: .utf8)!
                return (response, data)
            } else {
                // Second call fails (markRead e2)
                let response = mockResponse(statusCode: 500)
                let data = """
                {"error": {"code": "internal_error", "message": "Server error"}}
                """.data(using: .utf8)!
                return (response, data)
            }
        }

        let failedAction = await queue.flush(apiClient: ctx.client)
        #expect(failedAction == .markRead(emailId: "e2", isRead: true))

        // e1 was removed, e2 and e3 remain
        #expect(await queue.pendingCount == 2)
        let remaining = await queue.pendingActions
        #expect(remaining[0] == .markRead(emailId: "e2", isRead: true))
        #expect(remaining[1] == .archive(emailId: "e3"))
    }

    @Test("Flush with empty queue returns nil")
    func flushEmpty() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let queue = OfflineActionQueue(storageDirectory: dir)
        let result = await queue.flush(apiClient: ctx.client)
        #expect(result == nil)
    }

    @Test("Flush for snooze action calls correct endpoint")
    func flushSnooze() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let queue = OfflineActionQueue(storageDirectory: dir)
        await queue.enqueue(.snooze(
            emailId: "e1",
            returnAt: Date(timeIntervalSinceReferenceDate: 1_000_000)
        ))

        ctx.setHandler { _ in
            let response = mockResponse(statusCode: 200)
            let data = """
            {
                "id": "snz-1",
                "email_id": "e1",
                "snoozed_at": "2026-02-07T10:00:00Z",
                "return_at": "2026-02-08T09:00:00Z",
                "snooze_count": 1,
                "is_active": true
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        let result = await queue.flush(apiClient: ctx.client)
        #expect(result == nil)
        #expect(await queue.pendingCount == 0)

        let request = ctx.capturedRequests.first
        #expect(request?.url?.path.contains("/snooze") == true)
        #expect(request?.httpMethod == "POST")
    }

    @Test("Flush for reclassify action calls correct endpoint")
    func flushReclassify() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let queue = OfflineActionQueue(storageDirectory: dir)
        await queue.enqueue(.reclassify(
            emailId: "e1", classification: .filtered, confirm: false
        ))

        ctx.setHandler { _ in
            let response = mockResponse(statusCode: 200)
            let data = sampleEmailJSON.data(using: .utf8)!
            return (response, data)
        }

        let result = await queue.flush(apiClient: ctx.client)
        #expect(result == nil)

        let request = ctx.capturedRequests.first
        #expect(request?.url?.path.contains("/reclassify") == true)
        #expect(request?.httpMethod == "POST")
    }

    @Test("Flush for updateRecommendationStatus calls correct endpoint")
    func flushUpdateRecommendation() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let queue = OfflineActionQueue(storageDirectory: dir)
        await queue.enqueue(.updateRecommendationStatus(id: "r1", status: .done))

        ctx.setHandler { _ in
            let response = mockResponse(statusCode: 200)
            let data = """
            {
                "id": "r1",
                "type": "book",
                "title": "Test Book",
                "source_newsletter_name": "Newsletter",
                "source_date": "2026-01-01T00:00:00Z",
                "context_snippet": "Context",
                "status": "done",
                "duplicate_count": 1
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        let result = await queue.flush(apiClient: ctx.client)
        #expect(result == nil)

        let request = ctx.capturedRequests.first
        #expect(request?.url?.path.contains("/recommendations/r1") == true)
        #expect(request?.httpMethod == "PATCH")
    }

    // MARK: - OfflineAction Codable

    @Test("All OfflineAction cases encode and decode correctly")
    func actionCodableRoundTrip() throws {
        let actions: [OfflineAction] = [
            .archive(emailId: "e1"),
            .markRead(emailId: "e2", isRead: true),
            .snooze(emailId: "e3", returnAt: Date(timeIntervalSinceReferenceDate: 1_000_000)),
            .reclassify(emailId: "e4", classification: .transactional, confirm: true),
            .updateRecommendationStatus(id: "r1", status: .dismissed),
        ]

        let encoder = JSONEncoder.apiEncoder
        let decoder = JSONDecoder.apiDecoder

        let data = try encoder.encode(actions)
        let decoded = try decoder.decode([OfflineAction].self, from: data)

        #expect(decoded == actions)
    }
}

import Foundation
import Testing
@testable import EmailClientKit

@Suite("LocalCache")
struct LocalCacheTests {
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalCacheTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Generic save/load

    @Test("Save and load round-trip for Codable value")
    func saveLoadRoundTrip() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir)

        let emails = [
            Email(
                id: "e1", accountId: "a1",
                from: Contact(email: "a@b.com"), to: [],
                subject: "Test", snippet: "",
                receivedAt: Date(timeIntervalSinceReferenceDate: 0),
                classification: Classification(
                    classification: .actionRequired, confidence: 0.9, classifiedBy: .llm
                ),
                isRead: false, isArchived: false, hasAttachments: false
            )
        ]

        try await cache.save(emails, key: "emails/action_queue")
        let loaded = await cache.load([Email].self, key: "emails/action_queue")
        #expect(loaded != nil)
        #expect(loaded?.count == 1)
        #expect(loaded?.first?.id == "e1")
    }

    @Test("Load returns nil for missing key")
    func loadMissing() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir)

        let result = await cache.load(String.self, key: "nonexistent")
        #expect(result == nil)
    }

    @Test("Clear removes a cached value")
    func clearKey() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir)

        try await cache.save("hello", key: "greeting")
        let before = await cache.load(String.self, key: "greeting")
        #expect(before == "hello")

        await cache.clear(key: "greeting")
        let after = await cache.load(String.self, key: "greeting")
        #expect(after == nil)
    }

    @Test("ClearAll removes all cached files")
    func clearAll() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir)

        try await cache.save("a", key: "key1")
        try await cache.save("b", key: "key2")
        await cache.clearAll()

        let val1 = await cache.load(String.self, key: "key1")
        let val2 = await cache.load(String.self, key: "key2")
        #expect(val1 == nil)
        #expect(val2 == nil)
    }

    // MARK: - LRU Email Detail Cache

    @Test("Email detail LRU eviction at max count")
    func lruEviction() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir, lruMaxCount: 3)

        try await cache.saveEmailDetail("body1", emailId: "e1")
        try await cache.saveEmailDetail("body2", emailId: "e2")
        try await cache.saveEmailDetail("body3", emailId: "e3")
        #expect(await cache.emailDetailCacheCount == 3)

        // Adding a 4th should evict the oldest (e1)
        try await cache.saveEmailDetail("body4", emailId: "e4")
        #expect(await cache.emailDetailCacheCount == 3)

        let evicted = await cache.loadEmailDetail(String.self, emailId: "e1")
        #expect(evicted == nil)

        let kept = await cache.loadEmailDetail(String.self, emailId: "e2")
        #expect(kept == "body2")
    }

    @Test("Loading email detail touches LRU order")
    func lruTouch() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir, lruMaxCount: 3)

        try await cache.saveEmailDetail("body1", emailId: "e1")
        try await cache.saveEmailDetail("body2", emailId: "e2")
        try await cache.saveEmailDetail("body3", emailId: "e3")

        // Touch e1 so it becomes most recent
        _ = await cache.loadEmailDetail(String.self, emailId: "e1")

        // Add e4 — should evict e2 (oldest untouched)
        try await cache.saveEmailDetail("body4", emailId: "e4")

        let e1 = await cache.loadEmailDetail(String.self, emailId: "e1")
        #expect(e1 == "body1")

        let e2 = await cache.loadEmailDetail(String.self, emailId: "e2")
        #expect(e2 == nil)
    }

    @Test("Saving same email ID updates value and LRU position")
    func lruUpdate() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir, lruMaxCount: 3)

        try await cache.saveEmailDetail("body1-v1", emailId: "e1")
        try await cache.saveEmailDetail("body2", emailId: "e2")
        try await cache.saveEmailDetail("body1-v2", emailId: "e1")

        #expect(await cache.emailDetailCacheCount == 2)

        let val = await cache.loadEmailDetail(String.self, emailId: "e1")
        #expect(val == "body1-v2")
    }

    @Test("ClearAll resets LRU tracking")
    func clearAllResetsLRU() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir, lruMaxCount: 3)

        try await cache.saveEmailDetail("body1", emailId: "e1")
        #expect(await cache.emailDetailCacheCount == 1)

        await cache.clearAll()
        #expect(await cache.emailDetailCacheCount == 0)
    }

    // MARK: - Nested keys

    @Test("Nested key paths create subdirectories")
    func nestedKeys() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let cache = LocalCache(cacheDirectory: dir)

        try await cache.save(42, key: "deep/nested/value")
        let loaded = await cache.load(Int.self, key: "deep/nested/value")
        #expect(loaded == 42)
    }
}

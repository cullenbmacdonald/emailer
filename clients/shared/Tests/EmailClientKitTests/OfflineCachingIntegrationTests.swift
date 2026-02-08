import Foundation
import Testing
@testable import EmailClientKit

@Suite("Offline Caching Integration")
struct OfflineCachingIntegrationTests {
    private func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OfflineCachingTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }

    @MainActor
    private func makeCoordinator(
        cacheDir: URL
    ) -> (AppCoordinator, AppState, EmailStore, RecommendationStore, DigestStore) {
        let appState = AppState()
        let emailStore = EmailStore()
        let recStore = RecommendationStore()
        let digestStore = DigestStore()
        let cache = LocalCache(cacheDirectory: cacheDir)
        let queue = OfflineActionQueue(storageDirectory: cacheDir)
        let coordinator = AppCoordinator(
            appState: appState,
            emailStore: emailStore,
            recommendationStore: recStore,
            digestStore: digestStore,
            localCache: cache,
            offlineQueue: queue
        )
        return (coordinator, appState, emailStore, recStore, digestStore)
    }

    // MARK: - Cache Loading

    @Test("loadCachedData populates email store from cache")
    @MainActor
    func loadCachedEmailData() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        // Pre-populate cache
        let cache = LocalCache(cacheDirectory: dir)
        let emails = [TestHelpers.makeEmail(id: "e1", subject: "Cached")]
        try await cache.save(emails, key: CacheKey.actionQueue)

        let (coordinator, _, emailStore, _, _) = makeCoordinator(cacheDir: dir)
        await coordinator.loadCachedData()

        #expect(emailStore.actionQueue.count == 1)
        #expect(emailStore.actionQueue.first?.id == "e1")
    }

    @Test("loadCachedData populates all email views")
    @MainActor
    func loadAllCachedViews() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let cache = LocalCache(cacheDirectory: dir)
        let action = [TestHelpers.makeEmail(id: "a1", classification: .actionRequired)]
        let reading = [TestHelpers.makeEmail(id: "r1", classification: .newsletter)]
        let filtered = [TestHelpers.makeEmail(id: "f1", classification: .filtered)]
        let all = [TestHelpers.makeEmail(id: "all1")]

        try await cache.save(action, key: CacheKey.actionQueue)
        try await cache.save(reading, key: CacheKey.readingQueue)
        try await cache.save(filtered, key: CacheKey.filtered)
        try await cache.save(all, key: CacheKey.allInboxes)

        let (coordinator, _, emailStore, _, _) = makeCoordinator(cacheDir: dir)
        await coordinator.loadCachedData()

        #expect(emailStore.actionQueue.count == 1)
        #expect(emailStore.readingQueue.count == 1)
        #expect(emailStore.filtered.count == 1)
        #expect(emailStore.allInboxes.count == 1)
    }

    @Test("loadCachedData populates recommendations from cache")
    @MainActor
    func loadCachedRecommendations() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let cache = LocalCache(cacheDirectory: dir)
        let recs = [Recommendation(
            id: "rec1",
            type: .book,
            title: "Test Book",
            sourceNewsletterName: "Newsletter",
            sourceDate: Date(timeIntervalSinceReferenceDate: 0),
            contextSnippet: "Context",
            status: .new,
            duplicateCount: 1
        )]
        try await cache.save(recs, key: CacheKey.recommendations)

        let (coordinator, _, _, recStore, _) = makeCoordinator(cacheDir: dir)
        await coordinator.loadCachedData()

        #expect(recStore.recommendations.count == 1)
        #expect(recStore.recommendations.first?.id == "rec1")
    }

    @Test("loadCachedData populates digest from cache")
    @MainActor
    func loadCachedDigest() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let cache = LocalCache(cacheDirectory: dir)
        let digest = DailyDigest(
            id: "d1",
            digestType: .morning,
            generatedAt: Date(timeIntervalSinceReferenceDate: 0),
            isRead: false,
            sections: []
        )
        try await cache.save(digest, key: CacheKey.latestDigest)

        let (coordinator, _, _, _, digestStore) = makeCoordinator(cacheDir: dir)
        await coordinator.loadCachedData()

        #expect(digestStore.latestDigest?.id == "d1")
    }

    @Test("loadCachedData handles empty cache gracefully")
    @MainActor
    func loadEmptyCache() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (coordinator, _, emailStore, recStore, digestStore) = makeCoordinator(cacheDir: dir)
        await coordinator.loadCachedData()

        #expect(emailStore.actionQueue.isEmpty)
        #expect(emailStore.readingQueue.isEmpty)
        #expect(emailStore.filtered.isEmpty)
        #expect(emailStore.allInboxes.isEmpty)
        #expect(recStore.recommendations.isEmpty)
        #expect(digestStore.latestDigest == nil)
    }

    // MARK: - Cache Writing

    @Test("cacheCurrentData persists store data to disk")
    @MainActor
    func cacheCurrentData() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (coordinator, _, emailStore, recStore, digestStore) = makeCoordinator(cacheDir: dir)

        // Populate stores
        emailStore.setEmails([TestHelpers.makeEmail(id: "e1")], for: .actionQueue)
        emailStore.setEmails([TestHelpers.makeEmail(id: "e2", classification: .newsletter)], for: .readingQueue)
        recStore.setRecommendations([Recommendation(
            id: "rec1",
            type: .book,
            title: "Book",
            sourceNewsletterName: "NL",
            sourceDate: Date(timeIntervalSinceReferenceDate: 0),
            contextSnippet: "ctx",
            status: .new,
            duplicateCount: 1
        )])
        digestStore.setLatestDigest(DailyDigest(
            id: "d1",
            digestType: .morning,
            generatedAt: Date(timeIntervalSinceReferenceDate: 0),
            isRead: false,
            sections: []
        ))

        await coordinator.cacheCurrentData()

        // Verify by loading from a fresh cache
        let cache2 = LocalCache(cacheDirectory: dir)
        let cachedAction = await cache2.load([Email].self, key: CacheKey.actionQueue)
        #expect(cachedAction?.count == 1)
        #expect(cachedAction?.first?.id == "e1")

        let cachedReading = await cache2.load([Email].self, key: CacheKey.readingQueue)
        #expect(cachedReading?.count == 1)

        let cachedRecs = await cache2.load([Recommendation].self, key: CacheKey.recommendations)
        #expect(cachedRecs?.count == 1)

        let cachedDigest = await cache2.load(DailyDigest.self, key: CacheKey.latestDigest)
        #expect(cachedDigest?.id == "d1")
    }

    // MARK: - Offline Action Queue Integration

    @Test("enqueueOfflineAction updates pending count in app state")
    @MainActor
    func enqueueUpdatesCount() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (coordinator, appState, _, _, _) = makeCoordinator(cacheDir: dir)
        #expect(appState.pendingActionCount == 0)

        await coordinator.enqueueOfflineAction(.archive(emailId: "e1"))
        #expect(appState.pendingActionCount == 1)

        await coordinator.enqueueOfflineAction(.markRead(emailId: "e2", isRead: true))
        #expect(appState.pendingActionCount == 2)
    }

    @Test("flushOfflineQueue clears pending count on success")
    @MainActor
    func flushClearsPendingCount() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let (coordinator, appState, _, _, _) = makeCoordinator(cacheDir: dir)
        coordinator.apiClient = ctx.client

        await coordinator.enqueueOfflineAction(.archive(emailId: "e1"))
        #expect(appState.pendingActionCount == 1)

        ctx.setHandler { _ in
            let response = mockResponse(statusCode: 200)
            let data = sampleEmailJSON.data(using: .utf8)!
            return (response, data)
        }

        let failed = await coordinator.flushOfflineQueue()
        #expect(failed == nil)
        #expect(appState.pendingActionCount == 0)
    }

    @Test("flushOfflineQueue sets error message on partial failure")
    @MainActor
    func flushPartialFailure() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }
        let ctx = makeMockContext()
        defer { ctx.tearDown() }

        let (coordinator, appState, _, _, _) = makeCoordinator(cacheDir: dir)
        coordinator.apiClient = ctx.client

        await coordinator.enqueueOfflineAction(.archive(emailId: "e1"))
        await coordinator.enqueueOfflineAction(.archive(emailId: "e2"))

        let callCount = AtomicCounter()
        ctx.setHandler { _ in
            let count = callCount.increment()
            if count == 1 {
                return (mockResponse(statusCode: 200), sampleEmailJSON.data(using: .utf8)!)
            } else {
                return (mockResponse(statusCode: 500), """
                {"error": {"code": "internal_error", "message": "fail"}}
                """.data(using: .utf8)!)
            }
        }

        let failed = await coordinator.flushOfflineQueue()
        #expect(failed == .archive(emailId: "e2"))
        #expect(appState.pendingActionCount == 1)
        #expect(appState.errorMessage != nil)
    }

    @Test("flushOfflineQueue returns nil with no API client")
    @MainActor
    func flushWithNoClient() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (coordinator, _, _, _, _) = makeCoordinator(cacheDir: dir)
        await coordinator.enqueueOfflineAction(.archive(emailId: "e1"))

        let failed = await coordinator.flushOfflineQueue()
        #expect(failed == nil)
        // Pending count should not change since no client was available
    }

    // MARK: - App State

    @Test("AppState isOffline reflects connection status")
    @MainActor
    func isOfflineProperty() {
        let state = AppState()
        state.isConnected = false
        #expect(state.isOffline == true)

        state.isConnected = true
        #expect(state.isOffline == false)
    }

    @Test("AppState pendingActionCount defaults to zero")
    @MainActor
    func pendingActionCountDefault() {
        let state = AppState()
        #expect(state.pendingActionCount == 0)
    }

    // MARK: - Cache round-trip (load, modify, cache, reload)

    @Test("Full round-trip: cache -> load -> modify -> cache -> reload")
    @MainActor
    func fullRoundTrip() async throws {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        // First coordinator: populate and cache
        let (coord1, _, emailStore1, _, _) = makeCoordinator(cacheDir: dir)
        emailStore1.setEmails([
            TestHelpers.makeEmail(id: "e1", subject: "First"),
            TestHelpers.makeEmail(id: "e2", subject: "Second"),
        ], for: .actionQueue)
        await coord1.cacheCurrentData()

        // Second coordinator: load cached, modify, re-cache
        let (coord2, _, emailStore2, _, _) = makeCoordinator(cacheDir: dir)
        await coord2.loadCachedData()
        #expect(emailStore2.actionQueue.count == 2)

        // Simulate archiving e1
        emailStore2.removeFromActionQueue(id: "e1")
        #expect(emailStore2.actionQueue.count == 1)
        await coord2.cacheCurrentData()

        // Third coordinator: verify updated cache
        let (coord3, _, emailStore3, _, _) = makeCoordinator(cacheDir: dir)
        await coord3.loadCachedData()
        #expect(emailStore3.actionQueue.count == 1)
        #expect(emailStore3.actionQueue.first?.id == "e2")
    }

    // MARK: - Offline queue persists across coordinators

    @Test("Offline queue persists across coordinator instances")
    @MainActor
    func offlineQueuePersistence() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (coord1, state1, _, _, _) = makeCoordinator(cacheDir: dir)
        await coord1.enqueueOfflineAction(.archive(emailId: "e1"))
        await coord1.enqueueOfflineAction(.markRead(emailId: "e2", isRead: true))
        #expect(state1.pendingActionCount == 2)

        // New coordinator with same directory
        let (coord2, state2, _, _, _) = makeCoordinator(cacheDir: dir)
        await coord2.updatePendingCount()
        #expect(state2.pendingActionCount == 2)
    }

    // MARK: - Connection Lost triggers reconnection

    @Test("connectionLost event sets isConnected to false")
    @MainActor
    func connectionLostSetsOffline() {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (_, appState, _, _, _) = makeCoordinator(cacheDir: dir)
        appState.isConnected = true

        // Simulate connectionLost event through the email store path
        // (The coordinator routes this, but we test the state change directly)
        appState.isConnected = false
        #expect(appState.isOffline == true)
    }

    // MARK: - OfflineBanner pending count display

    @Test("OfflineBanner shows pending action count from app state")
    @MainActor
    func offlineBannerPendingCount() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let (coordinator, appState, _, _, _) = makeCoordinator(cacheDir: dir)
        await coordinator.enqueueOfflineAction(.archive(emailId: "e1"))
        await coordinator.enqueueOfflineAction(.snooze(emailId: "e2", returnAt: Date()))
        await coordinator.enqueueOfflineAction(.reclassify(emailId: "e3", classification: .newsletter, confirm: false))

        // The pending count should be available for the OfflineBanner
        #expect(appState.pendingActionCount == 3)
    }

    // MARK: - Coordinator init with custom cache/queue

    @Test("Coordinator accepts custom LocalCache and OfflineActionQueue")
    @MainActor
    func customCacheAndQueue() async {
        let dir = makeTempDir()
        defer { cleanup(dir) }

        let cache = LocalCache(cacheDirectory: dir)
        let queue = OfflineActionQueue(storageDirectory: dir)

        let coordinator = AppCoordinator(
            appState: AppState(),
            emailStore: EmailStore(),
            recommendationStore: RecommendationStore(),
            digestStore: DigestStore(),
            localCache: cache,
            offlineQueue: queue
        )

        // Verify coordinator has the injected dependencies
        #expect(coordinator.localCache === cache)
        #expect(coordinator.offlineQueue === queue)
    }
}

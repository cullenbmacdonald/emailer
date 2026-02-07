import Foundation
import os

/// Thread-safe local cache for offline data persistence.
/// Uses JSON files in the app's caches directory.
public actor LocalCache {
    /// The base directory for all cached files.
    private let cacheDirectory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.cullenbmacdonald.emailer", category: "Cache")

    /// LRU tracking for email detail cache.
    private var lruOrder: [String] = []
    private let lruMaxCount: Int

    public init(
        cacheDirectory: URL? = nil,
        lruMaxCount: Int = 100
    ) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = caches.appendingPathComponent("EmailClientCache", isDirectory: true)
        }
        self.encoder = .apiEncoder
        self.decoder = .apiDecoder
        self.lruMaxCount = lruMaxCount

        // Ensure cache directory exists
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Generic Cache Operations

    /// Save a value to the cache.
    public func save<T: Encodable>(_ value: T, key: String) throws {
        let data = try encoder.encode(value)
        let fileURL = fileURL(for: key)

        // Ensure parent directory exists
        let parentDir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)

        try data.write(to: fileURL, options: .atomic)
    }

    /// Load a value from the cache. Returns nil if not found.
    public func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        let fileURL = fileURL(for: key)
        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logger.warning("Failed to decode cached data for key '\(key)': \(error.localizedDescription)")
            return nil
        }
    }

    /// Remove a cached value.
    public func clear(key: String) {
        let fileURL = fileURL(for: key)
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Remove all cached files.
    public func clearAll() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        lruOrder.removeAll()
    }

    // MARK: - Email Detail LRU Cache

    /// Save an email detail with LRU eviction.
    public func saveEmailDetail<T: Encodable>(_ value: T, emailId: String) throws {
        let key = "email_detail/\(emailId)"
        try save(value, key: key)

        // Update LRU order
        lruOrder.removeAll { $0 == emailId }
        lruOrder.append(emailId)

        // Evict oldest if over limit
        while lruOrder.count > lruMaxCount {
            let evictedId = lruOrder.removeFirst()
            clear(key: "email_detail/\(evictedId)")
            logger.info("Evicted email detail cache for \(evictedId)")
        }
    }

    /// Load an email detail, updating LRU order.
    public func loadEmailDetail<T: Decodable>(_ type: T.Type, emailId: String) -> T? {
        let key = "email_detail/\(emailId)"
        guard let value: T = load(type, key: key) else {
            return nil
        }

        // Touch in LRU order
        lruOrder.removeAll { $0 == emailId }
        lruOrder.append(emailId)

        return value
    }

    /// The number of email details currently cached.
    public var emailDetailCacheCount: Int {
        lruOrder.count
    }

    // MARK: - Helpers

    private func fileURL(for key: String) -> URL {
        cacheDirectory.appendingPathComponent("\(key).json")
    }
}

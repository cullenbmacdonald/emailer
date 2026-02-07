import Foundation
import os

/// An offline action that can be replayed against the API when connectivity is restored.
public enum OfflineAction: Codable, Sendable, Equatable {
    case archive(emailId: String)
    case markRead(emailId: String, isRead: Bool)
    case snooze(emailId: String, returnAt: Date)
    case reclassify(emailId: String, classification: ClassificationType, confirm: Bool)
    case updateRecommendationStatus(id: String, status: RecommendationStatus)
}

/// Queues user actions for offline replay. Persists the queue to disk so actions
/// survive app restarts. Flushes in FIFO order, stopping on first failure to
/// preserve action ordering.
public actor OfflineActionQueue {
    private var actions: [OfflineAction] = []
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.cullenbmacdonald.emailer", category: "OfflineQueue")

    /// The number of actions waiting to be flushed.
    public var pendingCount: Int {
        actions.count
    }

    public init(storageDirectory: URL? = nil) {
        let directory: URL
        if let storageDirectory {
            directory = storageDirectory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            directory = caches.appendingPathComponent("EmailClientCache", isDirectory: true)
        }
        self.fileURL = directory.appendingPathComponent("offline_actions.json")
        self.encoder = .apiEncoder
        self.decoder = .apiDecoder

        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Load persisted actions
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? decoder.decode([OfflineAction].self, from: data) {
            self.actions = loaded
        }
    }

    /// Add an action to the queue and persist to disk.
    public func enqueue(_ action: OfflineAction) {
        actions.append(action)
        persistToDisk()
    }

    /// Replay all queued actions in order via the given API client.
    /// Stops on first failure and returns the error. Successfully executed
    /// actions are removed from the queue.
    @discardableResult
    public func flush(apiClient: APIClient) async -> OfflineAction? {
        while !actions.isEmpty {
            let action = actions[0]
            do {
                try await execute(action, with: apiClient)
                actions.removeFirst()
                persistToDisk()
            } catch {
                logger.warning("Flush stopped at action \(String(describing: action)): \(error.localizedDescription)")
                return action
            }
        }
        return nil
    }

    /// Remove all pending actions.
    public func clearAll() {
        actions.removeAll()
        persistToDisk()
    }

    /// The current list of pending actions (read-only).
    public var pendingActions: [OfflineAction] {
        actions
    }

    // MARK: - Private

    private func execute(_ action: OfflineAction, with client: APIClient) async throws {
        switch action {
        case let .archive(emailId):
            _ = try await client.updateEmail(id: emailId, isArchived: true)
        case let .markRead(emailId, isRead):
            _ = try await client.updateEmail(id: emailId, isRead: isRead)
        case let .snooze(emailId, returnAt):
            _ = try await client.snoozeEmail(id: emailId, returnAt: returnAt)
        case let .reclassify(emailId, classification, confirm):
            _ = try await client.reclassifyEmail(id: emailId, classification: classification, confirm: confirm)
        case let .updateRecommendationStatus(id, status):
            _ = try await client.updateRecommendationStatus(id: id, status: status)
        }
    }

    private func persistToDisk() {
        do {
            let data = try encoder.encode(actions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Failed to persist offline action queue: \(error.localizedDescription)")
        }
    }
}

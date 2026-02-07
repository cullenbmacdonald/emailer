import Foundation
import Observation

/// Manages daily digest state and handles WebSocket events.
@Observable
@MainActor
public final class DigestStore {
    /// The latest digest, if available.
    public private(set) var latestDigest: DailyDigest?

    /// Whether a new unread digest is available (for sidebar "NEW" indicator).
    public var hasNewDigest: Bool {
        guard let digest = latestDigest else { return false }
        return digest.isRead != true
    }

    public init() {}

    /// Handle a WebSocket event that affects digests.
    public func handleEvent(_ event: WebSocketEvent) {
        switch event.payload {
        case let .digestAvailable(payload):
            handleDigestAvailable(payload)
        default:
            break
        }
    }

    /// Set the latest digest (used for initial fetch).
    public func setLatestDigest(_ digest: DailyDigest?) {
        latestDigest = digest
    }

    /// Mark the current digest as read.
    public func markAsRead() {
        guard let digest = latestDigest else { return }
        latestDigest = DailyDigest(
            id: digest.id,
            digestType: digest.digestType,
            generatedAt: digest.generatedAt,
            isRead: true,
            sections: digest.sections
        )
    }

    // MARK: - Private

    private func handleDigestAvailable(_ payload: DigestAvailablePayload) {
        // A new digest is available -- create a placeholder until full fetch.
        // The coordinator will fetch the full digest.
        latestDigest = DailyDigest(
            id: payload.digestId,
            digestType: payload.digestType,
            generatedAt: payload.generatedAt,
            isRead: false,
            sections: []
        )
    }
}

import Foundation
import Observation

/// Manages daily digest state and handles WebSocket events.
@Observable
@MainActor
public final class DigestStore {
    /// The latest digest, if available.
    public private(set) var latestDigest: DailyDigest?

    /// The currently displayed digest (may differ from latest when viewing historical).
    public private(set) var currentDigest: DailyDigest?

    /// Whether a digest is currently being loaded.
    public private(set) var isLoading: Bool = false

    /// An error message from the last failed operation.
    public private(set) var errorMessage: String?

    /// Items that have been acted on (for fade-out animation).
    public private(set) var dismissedItemIDs: Set<String> = []

    /// Whether the rescue picker is shown, and for which email ID.
    public var rescueEmailID: String?

    /// Whether a new unread digest is available (for sidebar "NEW" indicator).
    public var hasNewDigest: Bool {
        guard let digest = latestDigest else { return false }
        return digest.isRead != true
    }

    /// The digest currently being displayed (currentDigest if set, otherwise latestDigest).
    public var displayedDigest: DailyDigest? {
        currentDigest ?? latestDigest
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
        if currentDigest == nil {
            currentDigest = digest
        }
    }

    /// Set the current digest (used when navigating to a specific digest).
    public func setCurrentDigest(_ digest: DailyDigest?) {
        currentDigest = digest
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
        if currentDigest?.id == digest.id {
            currentDigest = latestDigest
        }
    }

    /// Set loading state.
    public func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    /// Set error message.
    public func setError(_ message: String?) {
        errorMessage = message
    }

    /// Dismiss a borderline item (mark it as acted upon).
    public func dismissItem(_ emailID: String) {
        dismissedItemIDs.insert(emailID)
    }

    /// Reset to showing the latest digest.
    public func showLatestDigest() {
        currentDigest = latestDigest
        dismissedItemIDs.removeAll()
    }

    /// Load a specific digest by ID using the provided API client.
    public func loadDigest(id: String, using client: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            let digest = try await client.fetchDigest(id: id)
            currentDigest = digest
            dismissedItemIDs.removeAll()
        } catch {
            errorMessage = "Failed to load digest"
        }
        isLoading = false
    }

    /// Load the latest digest using the provided API client.
    public func loadLatestDigest(using client: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            let digest = try await client.fetchLatestDigest()
            latestDigest = digest
            currentDigest = digest
            dismissedItemIDs.removeAll()
        } catch {
            errorMessage = "Failed to load digest"
        }
        isLoading = false
    }

    /// Generate a digest on demand.
    public func generateDigest(type: DigestType, using client: APIClient) async {
        isLoading = true
        errorMessage = nil
        do {
            let digest = try await client.generateDigest(type: type)
            latestDigest = digest
            currentDigest = digest
            dismissedItemIDs.removeAll()
        } catch {
            errorMessage = "Failed to generate digest"
        }
        isLoading = false
    }

    /// Confirm a borderline item as spam.
    public func confirmSpam(emailID: String, using client: APIClient) async {
        dismissItem(emailID)
        do {
            _ = try await client.reclassifyEmail(id: emailID, classification: .filtered, confirm: true)
        } catch {
            // Optimistic update already applied
        }
    }

    /// Rescue a borderline item to a new classification.
    public func rescueItem(emailID: String, to classification: ClassificationType, using client: APIClient) async {
        dismissItem(emailID)
        do {
            _ = try await client.reclassifyEmail(id: emailID, classification: classification)
        } catch {
            // Optimistic update already applied
        }
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

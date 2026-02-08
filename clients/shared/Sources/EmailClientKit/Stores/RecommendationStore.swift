import Foundation
import Observation
import os

/// Manages recommendation list, filtering, detail loading, and status updates.
@Observable
@MainActor
public final class RecommendationStore {
    /// All recommendations from the server.
    public private(set) var recommendations: [Recommendation] = []

    /// The currently selected recommendation detail.
    public private(set) var selectedDetail: RecommendationDetail?

    /// Whether the initial load is in progress.
    public private(set) var isLoading: Bool = false

    /// The currently selected recommendation ID.
    public var selectedRecommendationID: String?

    /// Active type filter (nil = All).
    public var typeFilter: RecommendationType?

    /// Active status filter.
    public var statusFilter: RecommendationStatus? = .new

    /// Pagination cursor.
    public private(set) var cursor: String?

    /// Whether more pages are available.
    public private(set) var hasMore: Bool = false

    /// Undo state for the last status change.
    public private(set) var undoState: UndoState?

    private let logger = Logger(subsystem: "com.cullenbmacdonald.emailer", category: "RecommendationStore")

    public init() {}

    // MARK: - Filtered list

    /// Recommendations matching current type and status filters.
    public var filteredRecommendations: [Recommendation] {
        recommendations.filter { rec in
            if let typeFilter, rec.type != typeFilter { return false }
            if let statusFilter, rec.status != statusFilter { return false }
            return true
        }
    }

    /// Count of new recommendations (for status filter badge).
    public var newCount: Int {
        recommendations.filter { $0.status == .new }.count
    }

    // MARK: - WebSocket Events

    /// Handle a WebSocket event that affects recommendations.
    public func handleEvent(_ event: WebSocketEvent) {
        switch event.payload {
        case let .recommendationNew(payload):
            upsert(payload.recommendation)
        case let .recommendationUpdated(payload):
            upsert(payload.recommendation)
        default:
            break
        }
    }

    // MARK: - Data Loading

    /// Replace all recommendations (used for initial fetch).
    public func setRecommendations(_ items: [Recommendation]) {
        recommendations = items
    }

    /// Set loading state.
    public func setLoading(_ loading: Bool) {
        isLoading = loading
    }

    /// Update pagination state.
    public func setPagination(cursor: String?, hasMore: Bool) {
        self.cursor = cursor
        self.hasMore = hasMore
    }

    /// Append a page of recommendations.
    public func appendRecommendations(_ items: [Recommendation]) {
        let existingIDs = Set(recommendations.map(\.id))
        for item in items where !existingIDs.contains(item.id) {
            recommendations.append(item)
        }
    }

    /// Load recommendations from the API.
    public func loadRecommendations(using client: APIClient?) async {
        guard let client else { return }
        isLoading = true
        do {
            let response = try await client.fetchRecommendations(
                type: typeFilter,
                status: statusFilter
            )
            recommendations = response.data
            cursor = response.nextCursor
            hasMore = response.hasMore
            logger.info("Fetched \(response.data.count) recommendations")
        } catch {
            logger.warning("Failed to fetch recommendations: \(error.localizedDescription)")
        }
        isLoading = false
    }

    /// Load more recommendations (pagination).
    public func loadMore(using client: APIClient?) async {
        guard let client, hasMore, let cursor else { return }
        do {
            let response = try await client.fetchRecommendations(
                type: typeFilter,
                status: statusFilter,
                cursor: cursor
            )
            appendRecommendations(response.data)
            self.cursor = response.nextCursor
            self.hasMore = response.hasMore
        } catch {
            logger.warning("Failed to load more recommendations: \(error.localizedDescription)")
        }
    }

    /// Load detail for a specific recommendation.
    public func loadDetail(for id: String, using client: APIClient?) async {
        selectedDetail = nil
        guard let client else { return }
        do {
            let detail = try await client.fetchRecommendationDetail(id: id)
            selectedDetail = detail
        } catch {
            logger.warning("Failed to load recommendation detail: \(error.localizedDescription)")
        }
    }

    /// Clear the selected detail.
    public func clearDetail() {
        selectedDetail = nil
    }

    // MARK: - Status Updates (Optimistic)

    /// Update the status of a recommendation optimistically.
    /// Returns the previous status for undo support.
    @discardableResult
    public func updateStatus(
        id: String,
        to newStatus: RecommendationStatus,
        using client: APIClient?
    ) async -> RecommendationStatus? {
        guard let index = recommendations.firstIndex(where: { $0.id == id }) else { return nil }
        let oldRec = recommendations[index]
        let oldStatus = oldRec.status

        // Optimistic update
        let updated = oldRec.withStatus(newStatus)
        recommendations[index] = updated

        // Update detail if showing this recommendation
        if selectedDetail?.recommendation.id == id {
            selectedDetail = selectedDetail.map {
                RecommendationDetail(
                    recommendation: updated,
                    fullContext: $0.fullContext,
                    duplicateSources: $0.duplicateSources
                )
            }
        }

        // Store undo state
        undoState = UndoState(
            recommendationID: id,
            previousStatus: oldStatus,
            message: statusChangeMessage(newStatus)
        )

        // Fire API call
        if let client {
            do {
                _ = try await client.updateRecommendationStatus(id: id, status: newStatus)
            } catch {
                // Revert on failure
                if let idx = recommendations.firstIndex(where: { $0.id == id }) {
                    recommendations[idx] = oldRec
                }
                logger.warning("Failed to update recommendation status: \(error.localizedDescription)")
            }
        }

        return oldStatus
    }

    /// Undo the last status change.
    public func undoLastStatusChange(using client: APIClient?) async {
        guard let undo = undoState else { return }
        undoState = nil
        await updateStatus(id: undo.recommendationID, to: undo.previousStatus, using: client)
        // Clear the undo state that was just set by the recursive call
        undoState = nil
    }

    /// Clear the undo state.
    public func clearUndo() {
        undoState = nil
    }

    // MARK: - Undo State

    public struct UndoState: Sendable, Equatable {
        public let recommendationID: String
        public let previousStatus: RecommendationStatus
        public let message: String
    }

    // MARK: - Private

    private func upsert(_ recommendation: Recommendation) {
        if let index = recommendations.firstIndex(where: { $0.id == recommendation.id }) {
            recommendations[index] = recommendation
        } else {
            recommendations.insert(recommendation, at: 0)
        }
    }

    private func statusChangeMessage(_ status: RecommendationStatus) -> String {
        switch status {
        case .saved: "Recommendation saved"
        case .done: "Marked as done"
        case .dismissed: "Recommendation dismissed"
        case .new: "Recommendation restored"
        }
    }
}

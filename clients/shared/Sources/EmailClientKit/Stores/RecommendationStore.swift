import Foundation
import Observation

/// Manages recommendation list and handles WebSocket events.
@Observable
@MainActor
public final class RecommendationStore {
    /// All recommendations.
    public private(set) var recommendations: [Recommendation] = []

    public init() {}

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

    /// Replace all recommendations (used for initial fetch).
    public func setRecommendations(_ items: [Recommendation]) {
        recommendations = items
    }

    // MARK: - Private

    private func upsert(_ recommendation: Recommendation) {
        if let index = recommendations.firstIndex(where: { $0.id == recommendation.id }) {
            recommendations[index] = recommendation
        } else {
            recommendations.insert(recommendation, at: 0)
        }
    }
}

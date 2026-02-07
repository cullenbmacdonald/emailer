import Foundation
import Testing
import EmailClientKit
@testable import Emailer

@Suite("RecommendationStore")
@MainActor
struct RecommendationStoreTests {
    private func makeRecommendation(id: String = "r1", status: RecommendationStatus = .new) -> Recommendation {
        Recommendation(
            id: id,
            type: .book,
            title: "Test Book",
            sourceNewsletterName: "Newsletter",
            sourceDate: Date(),
            contextSnippet: "Context",
            status: status,
            duplicateCount: 1
        )
    }

    @Test("Initial state is empty")
    func initialState() {
        let store = RecommendationStore()
        #expect(store.recommendations.isEmpty)
    }

    @Test("setRecommendations replaces array")
    func setRecommendations() {
        let store = RecommendationStore()
        store.setRecommendations([makeRecommendation(id: "r1"), makeRecommendation(id: "r2")])
        #expect(store.recommendations.count == 2)
    }

    @Test("recommendationNew inserts new recommendation")
    func recommendationNew() {
        let store = RecommendationStore()
        let rec = makeRecommendation()
        let event = WebSocketEvent(
            type: .recommendationNew,
            payload: .recommendationNew(RecommendationNewPayload(recommendation: rec))
        )
        store.handleEvent(event)
        #expect(store.recommendations.count == 1)
        #expect(store.recommendations.first?.id == "r1")
    }

    @Test("recommendationUpdated updates existing recommendation")
    func recommendationUpdated() {
        let store = RecommendationStore()
        store.setRecommendations([makeRecommendation(id: "r1", status: .new)])

        let updated = makeRecommendation(id: "r1", status: .saved)
        let event = WebSocketEvent(
            type: .recommendationUpdated,
            payload: .recommendationUpdated(RecommendationUpdatedPayload(recommendation: updated))
        )
        store.handleEvent(event)
        #expect(store.recommendations.count == 1)
        #expect(store.recommendations.first?.status == .saved)
    }

    @Test("Non-recommendation events are ignored")
    func ignoresOtherEvents() {
        let store = RecommendationStore()
        let event = WebSocketEvent(type: .pong, payload: .pong)
        store.handleEvent(event)
        #expect(store.recommendations.isEmpty)
    }
}

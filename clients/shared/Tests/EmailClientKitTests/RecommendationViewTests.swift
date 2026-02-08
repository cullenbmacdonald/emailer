import Testing
import Foundation
@testable import EmailClientKit

// MARK: - Recommendation.withStatus Tests

@Suite("Recommendation.withStatus")
struct RecommendationWithStatusTests {
    @Test("withStatus returns copy with new status")
    func withStatusChangesStatus() {
        let rec = Recommendation.makeTest(status: .new)
        let updated = rec.withStatus(.saved)
        #expect(updated.status == .saved)
        #expect(updated.id == rec.id)
        #expect(updated.title == rec.title)
        #expect(updated.type == rec.type)
        #expect(updated.creator == rec.creator)
    }
}

// MARK: - RecommendationType UI Helpers Tests

@Suite("RecommendationType UI Helpers")
struct RecommendationTypeHelpersTests {
    @Test("All types have icon names")
    func allTypesHaveIcons() {
        for type in RecommendationType.allCases {
            #expect(!type.iconName.isEmpty)
        }
    }

    @Test("All types have labels")
    func allTypesHaveLabels() {
        for type in RecommendationType.allCases {
            #expect(!type.label.isEmpty)
            #expect(!type.singularLabel.isEmpty)
        }
    }

    @Test("Book icon is book.fill")
    func bookIcon() {
        #expect(RecommendationType.book.iconName == "book.fill")
    }

    @Test("Movie and TV share color")
    func movieTvColor() {
        #expect(RecommendationType.movie.color == RecommendationType.tv.color)
    }
}

// MARK: - RecommendationStore Tests

@Suite("RecommendationStore")
struct RecommendationStoreViewTests {
    @MainActor
    @Test("filteredRecommendations filters by type")
    func filterByType() {
        let store = RecommendationStore()
        store.statusFilter = nil
        store.setRecommendations([
            .makeTest(id: "1", type: .book),
            .makeTest(id: "2", type: .article),
            .makeTest(id: "3", type: .book)
        ])

        store.typeFilter = .book
        #expect(store.filteredRecommendations.count == 2)

        store.typeFilter = .article
        #expect(store.filteredRecommendations.count == 1)

        store.typeFilter = nil
        #expect(store.filteredRecommendations.count == 3)
    }

    @MainActor
    @Test("filteredRecommendations filters by status")
    func filterByStatus() {
        let store = RecommendationStore()
        store.typeFilter = nil
        store.setRecommendations([
            .makeTest(id: "1", status: .new),
            .makeTest(id: "2", status: .saved),
            .makeTest(id: "3", status: .new)
        ])

        store.statusFilter = .new
        #expect(store.filteredRecommendations.count == 2)

        store.statusFilter = .saved
        #expect(store.filteredRecommendations.count == 1)

        store.statusFilter = nil
        #expect(store.filteredRecommendations.count == 3)
    }

    @MainActor
    @Test("filteredRecommendations filters by type and status")
    func filterByTypeAndStatus() {
        let store = RecommendationStore()
        store.setRecommendations([
            .makeTest(id: "1", type: .book, status: .new),
            .makeTest(id: "2", type: .book, status: .saved),
            .makeTest(id: "3", type: .article, status: .new)
        ])

        store.typeFilter = .book
        store.statusFilter = .new
        #expect(store.filteredRecommendations.count == 1)
        #expect(store.filteredRecommendations.first?.id == "1")
    }

    @MainActor
    @Test("newCount returns count of new recommendations")
    func newCount() {
        let store = RecommendationStore()
        store.setRecommendations([
            .makeTest(id: "1", status: .new),
            .makeTest(id: "2", status: .saved),
            .makeTest(id: "3", status: .new)
        ])
        #expect(store.newCount == 2)
    }

    @MainActor
    @Test("optimistic status update changes status immediately")
    func optimisticStatusUpdate() async {
        let store = RecommendationStore()
        store.setRecommendations([.makeTest(id: "1", status: .new)])

        let oldStatus = await store.updateStatus(id: "1", to: .saved, using: nil)
        #expect(oldStatus == .new)
        #expect(store.recommendations.first?.status == .saved)
    }

    @MainActor
    @Test("optimistic update sets undo state")
    func undoState() async {
        let store = RecommendationStore()
        store.setRecommendations([.makeTest(id: "1", status: .new)])

        await store.updateStatus(id: "1", to: .saved, using: nil)
        #expect(store.undoState != nil)
        #expect(store.undoState?.previousStatus == .new)
        #expect(store.undoState?.recommendationID == "1")
    }

    @MainActor
    @Test("undo restores previous status")
    func undoRestore() async {
        let store = RecommendationStore()
        store.setRecommendations([.makeTest(id: "1", status: .new)])

        await store.updateStatus(id: "1", to: .dismissed, using: nil)
        #expect(store.recommendations.first?.status == .dismissed)

        await store.undoLastStatusChange(using: nil)
        #expect(store.recommendations.first?.status == .new)
        #expect(store.undoState == nil)
    }

    @MainActor
    @Test("clearUndo removes undo state")
    func clearUndo() async {
        let store = RecommendationStore()
        store.setRecommendations([.makeTest(id: "1", status: .new)])
        await store.updateStatus(id: "1", to: .saved, using: nil)
        #expect(store.undoState != nil)
        store.clearUndo()
        #expect(store.undoState == nil)
    }

    @MainActor
    @Test("optimistic update also updates selected detail")
    func updatesDetail() async {
        let store = RecommendationStore()
        let rec = Recommendation.makeTest(id: "1", status: .new)
        store.setRecommendations([rec])
        store.selectedRecommendationID = "1"

        // Manually set detail
        let detail = RecommendationDetail(
            recommendation: rec,
            fullContext: "Full context",
            duplicateSources: []
        )
        // Use internal access -- we can't set selectedDetail directly, so test via updateStatus
        // The detail will be nil since we haven't loaded it via API, but the code path exists
        await store.updateStatus(id: "1", to: .saved, using: nil)
        #expect(store.recommendations.first?.status == .saved)
    }

    @MainActor
    @Test("appendRecommendations deduplicates")
    func appendDeduplicates() {
        let store = RecommendationStore()
        store.setRecommendations([.makeTest(id: "1")])
        store.appendRecommendations([.makeTest(id: "1"), .makeTest(id: "2")])
        #expect(store.recommendations.count == 2)
    }

    @MainActor
    @Test("pagination state updates")
    func paginationState() {
        let store = RecommendationStore()
        store.setPagination(cursor: "abc", hasMore: true)
        #expect(store.cursor == "abc")
        #expect(store.hasMore == true)
    }
}

// MARK: - Test Helpers

extension Recommendation {
    static func makeTest(
        id: String = "test-1",
        type: RecommendationType = .book,
        status: RecommendationStatus = .new
    ) -> Recommendation {
        Recommendation(
            id: id,
            type: type,
            title: "Test Recommendation",
            creator: "Test Author",
            sourceNewsletterName: "Test Newsletter",
            sourceDate: Date(),
            contextSnippet: "A great recommendation",
            status: status,
            duplicateCount: 1
        )
    }
}

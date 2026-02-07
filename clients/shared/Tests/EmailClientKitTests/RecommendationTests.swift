import Foundation
import Testing
@testable import EmailClientKit

@Suite("Recommendation Models")
struct RecommendationTests {
    @Test("RecommendationType raw values match API spec")
    func typeRawValues() {
        #expect(RecommendationType.book.rawValue == "book")
        #expect(RecommendationType.movie.rawValue == "movie")
        #expect(RecommendationType.tv.rawValue == "tv")
        #expect(RecommendationType.music.rawValue == "music")
        #expect(RecommendationType.article.rawValue == "article")
        #expect(RecommendationType.podcast.rawValue == "podcast")
        #expect(RecommendationType.other.rawValue == "other")
    }

    @Test("RecommendationStatus raw values match API spec")
    func statusRawValues() {
        #expect(RecommendationStatus.new.rawValue == "new")
        #expect(RecommendationStatus.saved.rawValue == "saved")
        #expect(RecommendationStatus.done.rawValue == "done")
        #expect(RecommendationStatus.dismissed.rawValue == "dismissed")
    }

    @Test("Recommendation decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "id": "rec-1",
            "type": "book",
            "title": "The Innovator's Dilemma",
            "creator": "Clayton Christensen",
            "source_newsletter_name": "Stratechery",
            "source_email_id": "email-1",
            "source_date": "2026-02-01T00:00:00Z",
            "context_snippet": "Ben called it 'the best explanation of modularity theory'",
            "status": "new",
            "duplicate_count": 3,
            "is_user_added": false,
            "created_at": "2026-02-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let rec = try JSONDecoder.apiDecoder.decode(Recommendation.self, from: json)
        #expect(rec.id == "rec-1")
        #expect(rec.type == .book)
        #expect(rec.title == "The Innovator's Dilemma")
        #expect(rec.creator == "Clayton Christensen")
        #expect(rec.sourceNewsletterName == "Stratechery")
        #expect(rec.sourceEmailId == "email-1")
        #expect(rec.status == .new)
        #expect(rec.duplicateCount == 3)
        #expect(rec.isUserAdded == false)
    }

    @Test("Recommendation round-trip")
    func roundTrip() throws {
        let rec = Recommendation(
            id: "rec-1",
            type: .podcast,
            title: "Acquired",
            sourceNewsletterName: "Hacker News",
            sourceDate: ISO8601DateFormatter().date(from: "2026-02-01T00:00:00Z")!,
            contextSnippet: "Great podcast",
            status: .saved,
            duplicateCount: 1
        )
        let encoded = try JSONEncoder.apiEncoder.encode(rec)
        let decoded = try JSONDecoder.apiDecoder.decode(Recommendation.self, from: encoded)
        #expect(decoded == rec)
    }

    @Test("RecommendationDetail decodes from API JSON")
    func detailDecode() throws {
        let json = """
        {
            "recommendation": {
                "id": "rec-1",
                "type": "book",
                "title": "Test Book",
                "source_newsletter_name": "Test Newsletter",
                "source_date": "2026-02-01T00:00:00Z",
                "context_snippet": "Context",
                "status": "new",
                "duplicate_count": 2
            },
            "full_context": "Full context paragraph here",
            "duplicate_sources": [
                {
                    "newsletter_name": "Pragmatic Engineer",
                    "email_id": "email-2",
                    "date": "2026-01-30T00:00:00Z",
                    "context_snippet": "Also mentioned this book"
                }
            ]
        }
        """.data(using: .utf8)!

        let detail = try JSONDecoder.apiDecoder.decode(RecommendationDetail.self, from: json)
        #expect(detail.recommendation.title == "Test Book")
        #expect(detail.fullContext == "Full context paragraph here")
        #expect(detail.duplicateSources.count == 1)
        #expect(detail.duplicateSources[0].newsletterName == "Pragmatic Engineer")
    }
}

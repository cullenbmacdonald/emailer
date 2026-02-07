import Foundation
import Testing
@testable import EmailClientKit

@Suite("DailyDigest Models")
struct DailyDigestTests {
    @Test("DigestType raw values")
    func digestTypeRawValues() {
        #expect(DigestType.morning.rawValue == "morning")
        #expect(DigestType.evening.rawValue == "evening")
    }

    @Test("DigestSectionType raw values match API spec")
    func sectionTypeRawValues() {
        #expect(DigestSectionType.actionQueueSummary.rawValue == "action_queue_summary")
        #expect(DigestSectionType.returningToday.rawValue == "returning_today")
        #expect(DigestSectionType.readingQueueSummary.rawValue == "reading_queue_summary")
        #expect(DigestSectionType.borderlineItems.rawValue == "borderline_items")
        #expect(DigestSectionType.notableTransactional.rawValue == "notable_transactional")
        #expect(DigestSectionType.todayStats.rawValue == "today_stats")
        #expect(DigestSectionType.stillPending.rawValue == "still_pending")
        #expect(DigestSectionType.newslettersToday.rawValue == "newsletters_today")
        #expect(DigestSectionType.snoozeNudges.rawValue == "snooze_nudges")
    }

    @Test("DigestItemType raw values match API spec")
    func itemTypeRawValues() {
        #expect(DigestItemType.snoozedReturn.rawValue == "snoozed_return")
        #expect(DigestItemType.borderlineEmail.rawValue == "borderline_email")
        #expect(DigestItemType.notableTransactional.rawValue == "notable_transactional")
        #expect(DigestItemType.newsletterArrival.rawValue == "newsletter_arrival")
        #expect(DigestItemType.snoozeNudge.rawValue == "snooze_nudge")
    }

    @Test("HighlightType raw values match API spec")
    func highlightTypeRawValues() {
        #expect(HighlightType.packageArriving.rawValue == "package_arriving")
        #expect(HighlightType.largeCharge.rawValue == "large_charge")
        #expect(HighlightType.calendarEvent.rawValue == "calendar_event")
    }

    @Test("DailyDigest decodes from API JSON")
    // swiftlint:disable:next function_body_length
    func decodeFromAPI() throws {
        let json = """
        {
            "id": "digest-1",
            "digest_type": "morning",
            "generated_at": "2026-02-07T07:00:00Z",
            "is_read": false,
            "sections": [
                {
                    "type": "action_queue_summary",
                    "title": "ACTION QUEUE",
                    "subtitle": "3 emails need your response",
                    "count": 3,
                    "account_breakdown": [
                        {
                            "account_id": "acc-1",
                            "account_name": "Work",
                            "account_color": "#3B82F6",
                            "count": 2
                        }
                    ]
                },
                {
                    "type": "returning_today",
                    "title": "RETURNING TODAY",
                    "items": [
                        {
                            "type": "snoozed_return",
                            "email_id": "email-1",
                            "subject": "Budget review",
                            "from": "Jane Smith",
                            "return_at": "2026-02-07T09:00:00Z",
                            "snooze_count": 2
                        }
                    ]
                },
                {
                    "type": "today_stats",
                    "title": "TODAY'S STATS",
                    "sent_count": 5,
                    "archived_count": 12
                }
            ]
        }
        """.data(using: .utf8)!

        let digest = try JSONDecoder.apiDecoder.decode(DailyDigest.self, from: json)
        #expect(digest.id == "digest-1")
        #expect(digest.digestType == .morning)
        #expect(digest.isRead == false)
        #expect(digest.sections.count == 3)

        let actionSection = digest.sections[0]
        #expect(actionSection.type == .actionQueueSummary)
        #expect(actionSection.title == "ACTION QUEUE")
        #expect(actionSection.count == 3)
        #expect(actionSection.accountBreakdown?.count == 1)
        #expect(actionSection.accountBreakdown?[0].accountName == "Work")

        let returningSection = digest.sections[1]
        #expect(returningSection.type == .returningToday)
        #expect(returningSection.items?.count == 1)
        #expect(returningSection.items?[0].type == .snoozedReturn)
        #expect(returningSection.items?[0].snoozeCount == 2)

        let statsSection = digest.sections[2]
        #expect(statsSection.type == .todayStats)
        #expect(statsSection.sentCount == 5)
        #expect(statsSection.archivedCount == 12)
    }

    @Test("DailyDigest round-trip")
    func roundTrip() throws {
        let digest = DailyDigest(
            id: "digest-1",
            digestType: .evening,
            generatedAt: ISO8601DateFormatter().date(from: "2026-02-07T18:00:00Z")!,
            isRead: true,
            sections: [
                DigestSection(
                    type: .todayStats,
                    title: "TODAY",
                    sentCount: 3,
                    archivedCount: 10
                )
            ]
        )
        let encoded = try JSONEncoder.apiEncoder.encode(digest)
        let decoded = try JSONDecoder.apiDecoder.decode(DailyDigest.self, from: encoded)
        #expect(decoded == digest)
    }

    @Test("DigestSummary decodes from API JSON")
    func summaryDecode() throws {
        let json = """
        {
            "id": "digest-1",
            "digest_type": "morning",
            "generated_at": "2026-02-07T07:00:00Z",
            "is_read": true
        }
        """.data(using: .utf8)!

        let summary = try JSONDecoder.apiDecoder.decode(DigestSummary.self, from: json)
        #expect(summary.id == "digest-1")
        #expect(summary.digestType == .morning)
        #expect(summary.isRead == true)
    }

    @Test("DigestItem with borderline email fields")
    func borderlineItem() throws {
        let json = """
        {
            "type": "borderline_email",
            "email_id": "email-2",
            "subject": "Suspicious email",
            "from": "unknown@spam.com",
            "confidence": 0.72,
            "explanation": "Sender is in your contacts but content looks promotional"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder.apiDecoder.decode(DigestItem.self, from: json)
        #expect(item.type == .borderlineEmail)
        #expect(item.confidence == 0.72)
        #expect(item.explanation != nil)
    }

    @Test("DigestItem with notable transactional fields")
    func notableTransactionalItem() throws {
        let json = """
        {
            "type": "notable_transactional",
            "email_id": "email-3",
            "subject": "Your order shipped",
            "from": "Amazon",
            "highlight_type": "package_arriving",
            "display_text": "2 packages arriving today"
        }
        """.data(using: .utf8)!

        let item = try JSONDecoder.apiDecoder.decode(DigestItem.self, from: json)
        #expect(item.type == .notableTransactional)
        #expect(item.highlightType == .packageArriving)
        #expect(item.displayText == "2 packages arriving today")
    }
}

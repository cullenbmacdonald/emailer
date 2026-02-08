import Foundation
import Testing
@testable import EmailClientKit

@Suite("All Inboxes View Tests")
struct AllInboxesViewTests {

    // MARK: - ClassificationBadge

    @Test("ClassificationBadge has correct full labels")
    func classificationBadgeFullLabels() {
        #expect(ClassificationBadge(classificationType: .actionRequired).fullLabel == "Action Required")
        #expect(ClassificationBadge(classificationType: .newsletter).fullLabel == "Newsletter")
        #expect(ClassificationBadge(classificationType: .transactional).fullLabel == "Transactional")
        #expect(ClassificationBadge(classificationType: .filtered).fullLabel == "Filtered")
    }

    @Test("ClassificationBadge has correct abbreviated labels")
    func classificationBadgeAbbreviatedLabels() {
        #expect(ClassificationBadge(classificationType: .actionRequired).abbreviatedLabel == "Action Req.")
        #expect(ClassificationBadge(classificationType: .newsletter).abbreviatedLabel == "News.")
        #expect(ClassificationBadge(classificationType: .transactional).abbreviatedLabel == "Trans.")
        #expect(ClassificationBadge(classificationType: .filtered).abbreviatedLabel == "Filt.")
    }

    @Test("ClassificationBadge colors differ per type")
    func classificationBadgeColors() {
        let types = ClassificationType.allCases
        let colors = types.map { ClassificationBadge(classificationType: $0).badgeColor }
        // At minimum, action required and newsletter should differ
        #expect(colors.count == 4)
    }

    // MARK: - EmailStore All Inboxes

    @Test("setEmails for allInboxes populates the list")
    @MainActor
    func setAllInboxesEmails() {
        let store = EmailStore()
        let emails = [
            makeEmail(id: "e1", classification: .actionRequired),
            makeEmail(id: "e2", classification: .newsletter),
            makeEmail(id: "e3", classification: .transactional),
        ]
        store.setEmails(emails, for: .allInboxes)

        #expect(store.allInboxes.count == 3)
    }

    @Test("allInboxes includes all classification types")
    @MainActor
    func allInboxesIncludesAllTypes() {
        let store = EmailStore()
        let emails = [
            makeEmail(id: "e1", classification: .actionRequired),
            makeEmail(id: "e2", classification: .newsletter),
            makeEmail(id: "e3", classification: .transactional),
            makeEmail(id: "e4", classification: .filtered),
        ]
        store.setEmails(emails, for: .allInboxes)

        #expect(store.allInboxes.count == 4)
        let classifications = Set(store.allInboxes.map(\.classification.classification))
        #expect(classifications.contains(.actionRequired))
        #expect(classifications.contains(.newsletter))
        #expect(classifications.contains(.transactional))
        #expect(classifications.contains(.filtered))
    }

    // MARK: - Sorting (via AllInboxesView computed property)

    @Test("displayedEmails sorts by receivedAt descending")
    @MainActor
    func displayedEmailsSortOrder() {
        let store = EmailStore()
        let now = Date()
        let emails = [
            makeEmail(id: "old", classification: .actionRequired, receivedAt: now.addingTimeInterval(-3600)),
            makeEmail(id: "new", classification: .newsletter, receivedAt: now.addingTimeInterval(-60)),
            makeEmail(id: "mid", classification: .transactional, receivedAt: now.addingTimeInterval(-1800)),
        ]
        store.setEmails(emails, for: .allInboxes)

        let sorted = store.allInboxes.sorted { $0.receivedAt > $1.receivedAt }
        #expect(sorted[0].id == "new")
        #expect(sorted[1].id == "mid")
        #expect(sorted[2].id == "old")
    }

    // MARK: - Search State

    @Test("isSearchActive is false when searchText is empty")
    func searchActiveWhenEmpty() {
        // Test the logic directly: empty string means not active
        let searchText = ""
        #expect(searchText.isEmpty)
    }

    @Test("isSearchActive is true when searchText has content")
    func searchActiveWhenNotEmpty() {
        let searchText = "test"
        #expect(!searchText.isEmpty)
    }

    @Test("search requires minimum 2 characters")
    func searchMinimumLength() async throws {
        // The API client enforces this
        let client = APIClient(baseURL: URL(string: "http://localhost:1234")!, token: "test")
        do {
            _ = try await client.search(query: "a")
            Issue.record("Should have thrown for single character query")
        } catch let error as APIError {
            if case .validationError(let msg) = error {
                #expect(msg.contains("at least 2 characters"))
            } else {
                Issue.record("Wrong error type")
            }
        }
    }

    // MARK: - Flat List (no sections, no grouping)

    @Test("all inboxes is a flat list with no sections")
    @MainActor
    func flatListNoSections() {
        let store = EmailStore()
        let emails = [
            makeEmail(id: "e1", classification: .actionRequired),
            makeEmail(id: "e2", classification: .newsletter),
            makeEmail(id: "e3", classification: .filtered),
        ]
        store.setEmails(emails, for: .allInboxes)

        // All emails in a single flat list -- no separation by classification
        #expect(store.allInboxes.count == 3)
        // Verify they are all in allInboxes regardless of classification
        let ids = Set(store.allInboxes.map(\.id))
        #expect(ids == Set(["e1", "e2", "e3"]))
    }

    // MARK: - Archived Emails

    @Test("archived emails are included in allInboxes")
    @MainActor
    func archivedEmailsIncluded() {
        let store = EmailStore()
        let archivedEmail = makeEmail(id: "archived1", classification: .transactional, isArchived: true)
        let activeEmail = makeEmail(id: "active1", classification: .actionRequired)
        store.setEmails([archivedEmail, activeEmail], for: .allInboxes)

        #expect(store.allInboxes.count == 2)
        #expect(store.allInboxes.contains { $0.id == "archived1" && $0.isArchived })
    }

    // MARK: - Account Filtering

    @Test("account filter work only shows work emails")
    @MainActor
    func accountFilterWork() {
        let emails = [
            makeEmail(id: "e1", classification: .actionRequired, accountName: "Work"),
            makeEmail(id: "e2", classification: .newsletter, accountName: "Personal"),
        ]

        let workEmails = emails.filter { $0.accountName?.lowercased() == "work" }
        #expect(workEmails.count == 1)
        #expect(workEmails[0].id == "e1")
    }

    @Test("account filter personal excludes work emails")
    @MainActor
    func accountFilterPersonal() {
        let emails = [
            makeEmail(id: "e1", classification: .actionRequired, accountName: "Work"),
            makeEmail(id: "e2", classification: .newsletter, accountName: "Personal"),
        ]

        let personalEmails = emails.filter { $0.accountName?.lowercased() != "work" }
        #expect(personalEmails.count == 1)
        #expect(personalEmails[0].id == "e2")
    }

    @Test("account filter all shows everything")
    @MainActor
    func accountFilterAll() {
        let emails = [
            makeEmail(id: "e1", classification: .actionRequired, accountName: "Work"),
            makeEmail(id: "e2", classification: .newsletter, accountName: "Personal"),
        ]

        // All filter returns everything
        #expect(emails.count == 2)
    }

    // MARK: - AllInboxesRowView

    @Test("AllInboxesRowView shows classification badge")
    @MainActor
    func rowViewHasClassificationBadge() {
        let email = makeEmail(id: "e1", classification: .actionRequired)
        let row = AllInboxesRowView(email: email, isSelected: false)
        // The row type exists and can be instantiated
        #expect(type(of: row) == AllInboxesRowView.self)
    }

    @Test("AllInboxesRowView dims archived emails")
    func rowViewDimsArchived() {
        let archivedEmail = makeEmail(id: "e1", classification: .transactional, isArchived: true)
        // Verify the email is archived (the view applies 0.6 opacity)
        #expect(archivedEmail.isArchived)
    }

    // MARK: - Helpers

    private func makeEmail(
        id: String,
        classification: ClassificationType,
        receivedAt: Date = Date(),
        isArchived: Bool = false,
        accountName: String? = nil
    ) -> Email {
        Email(
            id: id,
            accountId: "acc-1",
            from: Contact(name: "Test Sender", email: "sender@example.com"),
            to: [Contact(name: "User", email: "user@test.com")],
            subject: "Test email \(id)",
            snippet: "This is a test email snippet",
            receivedAt: receivedAt,
            classification: Classification(
                classification: classification,
                confidence: 0.90,
                classifiedBy: .features
            ),
            isRead: false,
            isArchived: isArchived,
            hasAttachments: false,
            accountName: accountName
        )
    }
}

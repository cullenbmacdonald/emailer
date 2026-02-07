import Foundation
import Testing
@testable import EmailClientKit

@Suite("Account Models")
struct AccountTests {
    @Test("AccountType raw values match API spec")
    func accountTypeRawValues() {
        #expect(AccountType.work.rawValue == "work")
        #expect(AccountType.personal.rawValue == "personal")
    }

    @Test("AccountStatus raw values match API spec")
    func accountStatusRawValues() {
        #expect(AccountStatus.online.rawValue == "online")
        #expect(AccountStatus.offline.rawValue == "offline")
        #expect(AccountStatus.error.rawValue == "error")
        #expect(AccountStatus.syncing.rawValue == "syncing")
    }

    @Test("Account decodes from API JSON")
    func decodeFromAPI() throws {
        let json = """
        {
            "id": "acc-1",
            "name": "Work",
            "email_address": "me@work.com",
            "account_type": "work",
            "color": "#3B82F6",
            "status": "online",
            "status_message": null,
            "counts": {
                "action_queue": 5,
                "reading_queue": 12,
                "filtered": 30,
                "filtered_borderline": 3,
                "all_inboxes": 47
            }
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder.apiDecoder.decode(Account.self, from: json)
        #expect(account.id == "acc-1")
        #expect(account.name == "Work")
        #expect(account.emailAddress == "me@work.com")
        #expect(account.accountType == .work)
        #expect(account.color == "#3B82F6")
        #expect(account.status == .online)
        #expect(account.statusMessage == nil)
        #expect(account.counts?.actionQueue == 5)
        #expect(account.counts?.readingQueue == 12)
        #expect(account.counts?.filtered == 30)
        #expect(account.counts?.filteredBorderline == 3)
        #expect(account.counts?.allInboxes == 47)
    }

    @Test("Account round-trip")
    func roundTrip() throws {
        let account = Account(
            id: "acc-1",
            name: "Personal",
            emailAddress: "me@gmail.com",
            accountType: .personal,
            color: "#10B981",
            status: .syncing,
            statusMessage: "Syncing 42 emails"
        )
        let encoded = try JSONEncoder.apiEncoder.encode(account)
        let decoded = try JSONDecoder.apiDecoder.decode(Account.self, from: encoded)
        #expect(decoded == account)
    }

    @Test("Account without counts")
    func withoutCounts() throws {
        let json = """
        {
            "id": "acc-1",
            "name": "Work",
            "email_address": "me@work.com",
            "account_type": "work",
            "color": "#3B82F6",
            "status": "error",
            "status_message": "IMAP connection refused"
        }
        """.data(using: .utf8)!

        let account = try JSONDecoder.apiDecoder.decode(Account.self, from: json)
        #expect(account.status == .error)
        #expect(account.statusMessage == "IMAP connection refused")
        #expect(account.counts == nil)
    }
}

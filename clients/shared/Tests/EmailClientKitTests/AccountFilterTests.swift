import Testing
@testable import EmailClientKit

@Suite("AccountFilter")
@MainActor
struct AccountFilterTests {
    @Test("AccountFilter has 3 basic cases")
    func accountFilterCases() {
        #expect(AccountFilter.allCases.count == 3)
    }

    @Test("AccountFilter labels are correct")
    func accountFilterLabels() {
        #expect(AccountFilter.all.label == "All")
        #expect(AccountFilter.work.label == "Work")
        #expect(AccountFilter.personal.label == "Personal")
    }

    @Test("AccountFilter dotColor is nil for all, defined for others")
    func accountFilterDotColor() {
        #expect(AccountFilter.all.dotColor == nil)
        #expect(AccountFilter.work.dotColor != nil)
        #expect(AccountFilter.personal.dotColor != nil)
    }

    @Test("All filters are equal")
    func allEquality() {
        #expect(AccountFilter.all == AccountFilter.all)
    }

    @Test("Same accounts are equal")
    func accountEquality() {
        let filter1 = AccountFilter.account(id: "abc", name: "Work")
        let filter2 = AccountFilter.account(id: "abc", name: "Work")
        #expect(filter1 == filter2)
    }

    @Test("Different accounts are not equal")
    func differentAccountsAreNotEqual() {
        let filter1 = AccountFilter.account(id: "abc", name: "Work")
        let filter2 = AccountFilter.account(id: "def", name: "Personal")
        #expect(filter1 != filter2)
    }

    @Test("All vs account are not equal")
    func allVsAccountInequality() {
        let allFilter = AccountFilter.all
        let accountFilter = AccountFilter.account(id: "abc", name: "Work")
        #expect(allFilter != accountFilter)
    }

    @Test("Account filter id is unique per case")
    func accountFilterIds() {
        let ids = AccountFilter.allCases.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}

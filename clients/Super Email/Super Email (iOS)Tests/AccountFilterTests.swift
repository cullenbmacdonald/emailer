import Testing
@testable import EmailerIOS

@Suite("AccountFilter")
@MainActor
struct AccountFilterTests {
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
}

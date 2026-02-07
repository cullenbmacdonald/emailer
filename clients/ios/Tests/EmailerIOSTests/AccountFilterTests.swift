import Testing
@testable import EmailerIOSLib

@Suite("AccountFilter")
struct AccountFilterTests {
    @Test("All filter equals itself")
    func allEquality() {
        #expect(AccountFilter.all == AccountFilter.all)
    }

    @Test("Account filter equals same account")
    func accountEquality() {
        let filter1 = AccountFilter.account(id: "abc", name: "Work")
        let filter2 = AccountFilter.account(id: "abc", name: "Work")
        #expect(filter1 == filter2)
    }

    @Test("Different accounts are not equal")
    func accountInequality() {
        let filter1 = AccountFilter.account(id: "abc", name: "Work")
        let filter2 = AccountFilter.account(id: "def", name: "Personal")
        #expect(filter1 != filter2)
    }

    @Test("All is not equal to specific account")
    func allVsAccountInequality() {
        let allFilter = AccountFilter.all
        let accountFilter = AccountFilter.account(id: "abc", name: "Work")
        #expect(allFilter != accountFilter)
    }
}

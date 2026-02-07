import Testing
@testable import EmailClientKit

@Suite("EmailClientKit")
struct EmailClientKitTests {
    @Test("Package version is set")
    func packageVersion() {
        #expect(EmailClientKit.version == "0.1.0")
    }
}

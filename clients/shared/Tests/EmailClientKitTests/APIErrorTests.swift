import Foundation
import Testing
@testable import EmailClientKit

@Suite("APIError")
struct APIErrorTests {
    @Test("httpError provides localized description")
    func httpErrorDescription() {
        let error = APIError.httpError(
            statusCode: 404,
            serverError: ServerError(code: "not_found", message: "Email not found")
        )
        #expect(error.errorDescription == "HTTP 404: Email not found")
    }

    @Test("httpError without server message")
    func httpErrorNoMessage() {
        let error = APIError.httpError(statusCode: 500, serverError: nil)
        #expect(error.errorDescription == "HTTP error 500")
    }

    @Test("decodingError provides message")
    func decodingErrorDescription() {
        let error = APIError.decodingError("Unexpected type at key 'id'")
        #expect(error.errorDescription == "Decoding error: Unexpected type at key 'id'")
    }

    @Test("serverUnreachable provides description")
    func serverUnreachableDescription() {
        let error = APIError.serverUnreachable
        #expect(error.errorDescription == "Server is unreachable")
    }

    @Test("invalidResponse provides description")
    func invalidResponseDescription() {
        let error = APIError.invalidResponse
        #expect(error.errorDescription == "Invalid response from server")
    }

    @Test("ServerError decodes from API JSON")
    func serverErrorDecode() throws {
        let json = """
        {
            "code": "invalid_parameter",
            "message": "The 'view' query parameter is required"
        }
        """.data(using: .utf8)!

        let error = try JSONDecoder.apiDecoder.decode(ServerError.self, from: json)
        #expect(error.code == "invalid_parameter")
        #expect(error.message == "The 'view' query parameter is required")
    }

    @Test("APIError conforms to Equatable")
    func equatable() {
        let a = APIError.serverUnreachable
        let b = APIError.serverUnreachable
        #expect(a == b)

        let c = APIError.httpError(statusCode: 404, serverError: nil)
        let d = APIError.httpError(statusCode: 404, serverError: nil)
        #expect(c == d)
    }
}

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

    @Test("unauthorized provides description")
    func unauthorizedDescription() {
        let error = APIError.unauthorized
        #expect(error.errorDescription == "Unauthorized: invalid or missing authentication token")
    }

    @Test("notFound provides description")
    func notFoundDescription() {
        let error = APIError.notFound("Email not found")
        #expect(error.errorDescription == "Email not found")

        let errorNoMessage = APIError.notFound(nil)
        #expect(errorNoMessage.errorDescription == "Resource not found")
    }

    @Test("conflict provides description")
    func conflictDescription() {
        let error = APIError.conflict("VIP sender already exists")
        #expect(error.errorDescription == "VIP sender already exists")
    }

    @Test("validationError provides description")
    func validationErrorDescription() {
        let error = APIError.validationError("Query too short")
        #expect(error.errorDescription == "Query too short")
    }

    @Test("APIError conforms to Equatable")
    func equatable() {
        let error1 = APIError.serverUnreachable
        let error2 = APIError.serverUnreachable
        #expect(error1 == error2)

        let httpError1 = APIError.httpError(statusCode: 404, serverError: nil)
        let httpError2 = APIError.httpError(statusCode: 404, serverError: nil)
        #expect(httpError1 == httpError2)
    }
}

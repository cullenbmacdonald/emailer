import Foundation

extension JSONDecoder {
    /// Shared decoder configured for the Emailer API.
    ///
    /// - Uses `.convertFromSnakeCase` key decoding strategy.
    /// - Uses `.iso8601` date decoding strategy.
    public static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

extension JSONEncoder {
    /// Shared encoder configured for the Emailer API.
    ///
    /// - Uses `.convertToSnakeCase` key encoding strategy.
    /// - Uses `.iso8601` date encoding strategy.
    public static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}

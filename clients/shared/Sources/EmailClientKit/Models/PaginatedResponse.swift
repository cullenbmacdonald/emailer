import Foundation

/// A generic paginated response from the API.
public struct PaginatedResponse<T: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public let data: [T]
    public let nextCursor: String?
    public let hasMore: Bool

    public init(data: [T], nextCursor: String? = nil, hasMore: Bool) {
        self.data = data
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

import Foundation

/// An email attachment.
public struct Attachment: Codable, Identifiable, Sendable, Equatable {
    public let id: String
    public let filename: String
    public let mimeType: String
    public let size: Int
    public let downloadUrl: String?

    public init(
        id: String,
        filename: String,
        mimeType: String,
        size: Int,
        downloadUrl: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.mimeType = mimeType
        self.size = size
        self.downloadUrl = downloadUrl
    }
}

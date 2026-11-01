import Foundation

public struct UserPlaylist: Identifiable, Codable, Equatable {
    public let id: Int
    public let title: String
    public let publicId: String
    public var trackCount: Int?

    public init(id: Int, title: String, publicId: String, trackCount: Int? = nil) {
        self.id = id
        self.title = title
        self.publicId = publicId
        self.trackCount = trackCount
    }
}

public struct Supporter: Identifiable, Codable, Equatable {
    public var id: String { handle.isEmpty ? name : handle }
    public let name: String
    public let handle: String
    public let color: String

    public init(name: String, handle: String, color: String = "#8b5cf6") {
        self.name = name
        self.handle = handle
        self.color = color
    }
}

public struct RemotePlaybackState: Codable, Equatable {
    public let trackId: Int
    public let positionMs: Int64
    public let isPlaying: Bool
    public let updatedAt: Int64

    public init(trackId: Int, positionMs: Int64, isPlaying: Bool, updatedAt: Int64) {
        self.trackId = trackId
        self.positionMs = positionMs
        self.isPlaying = isPlaying
        self.updatedAt = updatedAt
    }
}

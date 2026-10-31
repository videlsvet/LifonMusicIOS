import Foundation

public struct Achievement: Identifiable, Codable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let description: String
    public let iconUrl: String?
    public let conditionType: String
    public let conditionValue: Int

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case iconUrl = "icon_url"
        case conditionType = "condition_type"
        case conditionValue = "condition_value"
    }
}

public struct UserAchievement: Identifiable, Codable, Equatable, Hashable {
    public let id: Int
    public let name: String
    public let description: String
    public let iconUrl: String?
    public let conditionType: String
    public let conditionValue: Int
    public let earnedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case iconUrl = "icon_url"
        case conditionType = "condition_type"
        case conditionValue = "condition_value"
        case earnedAt = "earned_at"
    }
}

public struct LyricsLine: Identifiable, Equatable, Hashable {
    public let id = UUID()
    public let timeMs: Int64
    public let text: String

    public init(timeMs: Int64, text: String) {
        self.timeMs = timeMs
        self.text = text
    }
}

public struct TopTrack: Identifiable, Codable, Equatable, Hashable {
    public var id: Int { trackId }
    public let trackId: Int
    public let playCount: Int

    enum CodingKeys: String, CodingKey {
        case trackId = "track_id"
        case playCount = "play_count"
    }
}

public struct StatsResult: Codable, Equatable {
    public let topTracks: [TopTrack]
    public let totalMs: Int64

    enum CodingKeys: String, CodingKey {
        case topTracks = "top_tracks"
        case totalMs = "total_ms"
    }
}

public struct BroadcastNotification: Identifiable, Codable, Equatable {
    public let id: Int
    public let title: String
    public let body: String
}

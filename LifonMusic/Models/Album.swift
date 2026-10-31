import Foundation

public struct Track: Identifiable, Codable, Equatable, Hashable {
    public let id: Int
    public let title: String
    public let duration: String
    public let audioUrl: String
    public let albumId: Int
    public let artist: String
    public let featArtist: String?
    public let coverUrl: String?

    public var displayArtist: String {
        if let feat = featArtist, !feat.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "\(artist) ft. \(feat)"
        }
        return artist
    }

    public init(
        id: Int,
        title: String,
        duration: String = "0:00",
        audioUrl: String,
        albumId: Int,
        artist: String = "CUPSIZE",
        featArtist: String? = nil,
        coverUrl: String? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.audioUrl = audioUrl
        self.albumId = albumId
        self.artist = artist
        self.featArtist = featArtist
        self.coverUrl = coverUrl
    }

    enum CodingKeys: String, CodingKey {
        case id, title, duration, artist
        case audioUrl = "audio_url"
        case albumId = "album_id"
        case featArtist = "feat_artist"
        case coverUrl = "cover_url"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.duration = try container.decodeIfPresent(String.self, forKey: .duration) ?? "0:00"
        self.audioUrl = try container.decodeIfPresent(String.self, forKey: .audioUrl) ?? ""
        self.albumId = try container.decodeIfPresent(Int.self, forKey: .albumId) ?? 0
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist) ?? "CUPSIZE"
        self.featArtist = try container.decodeIfPresent(String.self, forKey: .featArtist)
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
    }
}

public struct Album: Identifiable, Codable, Equatable, Hashable {
    public let id: Int
    public let title: String
    public let year: String
    public let coverUrl: String?
    public let glowColor: String?
    public let tracks: [Track]

    public init(
        id: Int,
        title: String,
        year: String,
        coverUrl: String? = nil,
        glowColor: String? = nil,
        tracks: [Track] = []
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.coverUrl = coverUrl
        self.glowColor = glowColor
        self.tracks = tracks
    }

    enum CodingKeys: String, CodingKey {
        case id, title, year, tracks
        case coverUrl = "cover_url"
        case glowColor = "glow_color"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.year = try container.decode(String.self, forKey: .year)
        self.coverUrl = try container.decodeIfPresent(String.self, forKey: .coverUrl)
        self.glowColor = try container.decodeIfPresent(String.self, forKey: .glowColor)
        self.tracks = try container.decodeIfPresent([Track].self, forKey: .tracks) ?? []
    }
}

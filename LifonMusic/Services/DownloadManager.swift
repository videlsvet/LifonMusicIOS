import Foundation
import Combine

public enum DownloadStatus: Equatable {
    case none
    case downloading
    case done
}

public struct DownloadedTrackMeta: Codable, Identifiable {
    public let id: Int
    public let title: String
    public let artist: String
    public let duration: String
    public let albumId: Int
    public let audioFileName: String
    public let coverFileName: String?
}

public final class DownloadManager: ObservableObject {
    public static let shared = DownloadManager()

    @Published public private(set) var statuses: [Int: DownloadStatus] = [:]
    @Published public private(set) var downloadedTracks: [DownloadedTrackMeta] = []

    private let fileManager = FileManager.default
    private let musicDirectory: URL
    private let metaKey = "downloaded_tracks_meta"

    private init() {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.musicDirectory = docs.appendingPathComponent("Music", isDirectory: true)

        if !fileManager.fileExists(atPath: musicDirectory.path) {
            try? fileManager.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        }

        loadMetadata()
    }

    public func status(for trackId: Int) -> DownloadStatus {
        if let s = statuses[trackId] { return s }
        let isDone = isTrackDownloaded(trackId)
        let s: DownloadStatus = isDone ? .done : .none
        statuses[trackId] = s
        return s
    }

    public func isTrackDownloaded(_ trackId: Int) -> Bool {
        let file = musicDirectory.appendingPathComponent("track_\(trackId).mp3")
        guard fileManager.fileExists(atPath: file.path) else { return false }
        if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
           let size = attrs[.size] as? Int64, size > 0 {
            return true
        }
        return false
    }

    public func localAudioUrl(for trackId: Int) -> URL? {
        let file = musicDirectory.appendingPathComponent("track_\(trackId).mp3")
        return isTrackDownloaded(trackId) ? file : nil
    }

    public func localCoverUrl(for trackId: Int) -> URL? {
        let file = musicDirectory.appendingPathComponent("cover_\(trackId).jpg")
        return fileManager.fileExists(atPath: file.path) ? file : nil
    }

    public func downloadTrack(_ track: Track) {
        guard status(for: track.id) != .downloading else { return }
        guard let url = URL(string: track.audioUrl), !track.audioUrl.isEmpty else { return }

        statuses[track.id] = .downloading

        Task {
            do {
                let (tempAudio, _) = try await URLSession.shared.download(from: url)
                let audioDest = self.musicDirectory.appendingPathComponent("track_\(track.id).mp3")
                if self.fileManager.fileExists(atPath: audioDest.path) {
                    try? self.fileManager.removeItem(at: audioDest)
                }
                try self.fileManager.moveItem(at: tempAudio, to: audioDest)

                // Optional cover download
                var coverFileName: String? = nil
                if let coverStr = track.coverUrl, let coverUrl = URL(string: coverStr) {
                    if let (tempCover, _) = try? await URLSession.shared.download(from: coverUrl) {
                        let coverDest = self.musicDirectory.appendingPathComponent("cover_\(track.id).jpg")
                        if self.fileManager.fileExists(atPath: coverDest.path) {
                            try? self.fileManager.removeItem(at: coverDest)
                        }
                        if (try? self.fileManager.moveItem(at: tempCover, to: coverDest)) != nil {
                            coverFileName = "cover_\(track.id).jpg"
                        }
                    }
                }

                let resolvedCover = coverFileName
                await MainActor.run {
                    let meta = DownloadedTrackMeta(
                        id: track.id,
                        title: track.title,
                        artist: track.artist,
                        duration: track.duration,
                        albumId: track.albumId,
                        audioFileName: "track_\(track.id).mp3",
                        coverFileName: resolvedCover
                    )
                    self.saveTrackMeta(meta)
                    self.statuses[track.id] = .done
                }
            } catch {
                await MainActor.run {
                    self.statuses[track.id] = DownloadStatus.none
                }
            }
        }
    }

    public func removeDownload(trackId: Int) {
        let audioDest = musicDirectory.appendingPathComponent("track_\(trackId).mp3")
        let coverDest = musicDirectory.appendingPathComponent("cover_\(trackId).jpg")
        try? fileManager.removeItem(at: audioDest)
        try? fileManager.removeItem(at: coverDest)

        downloadedTracks.removeAll { $0.id == trackId }
        statuses[trackId] = DownloadStatus.none
        persistMetadata()
    }

    private func saveTrackMeta(_ meta: DownloadedTrackMeta) {
        downloadedTracks.removeAll { $0.id == meta.id }
        downloadedTracks.append(meta)
        persistMetadata()
    }

    private func persistMetadata() {
        if let data = try? JSONEncoder().encode(downloadedTracks) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }
    }

    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: metaKey),
              let list = try? JSONDecoder().decode([DownloadedTrackMeta].self, from: data) else {
            return
        }
        self.downloadedTracks = list.filter { isTrackDownloaded($0.id) }
        for t in self.downloadedTracks {
            statuses[t.id] = .done
        }
    }
}

import Foundation
import UIKit
import AVFoundation
import MediaPlayer
import SwiftUI
import Combine

public enum PlayContext: Equatable {
    case album
    case favorites
    case downloaded
    case allTracks
    case wave
    case playlist
}

@MainActor
public final class AudioPlayerService: ObservableObject {
    public static let shared = AudioPlayerService()

    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var isPlaying: Bool = false
    @Published public var currentTimeMs: Int64 = 0
    @Published public var durationMs: Int64 = 0
    @Published public var isShuffled: Bool = false {
        didSet { recomputeQueue() }
    }
    @Published public var isRepeating: Bool = false
    @Published public var playerGlowColor: Color = DominantColorExtractor.fallbackColor

    public var playContext: PlayContext = .album
    public var currentPlaylist: [Track] = []

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var itemEndObserver: Any?

    private var activeQueue: [Track] = []
    private var currentQueueIndex: Int = 0

    // Listen tracker & sync metrics
    private var trackStartTime: Date?
    private var accumulatedPlayTimeMs: Int64 = 0
    private var lastSyncTimeMs: Int64 = 0

    public var onTrackChanged: ((Track?) -> Void)?
    public var onLikeToggled: ((Int) -> Void)?
    public var onNeedMoreWaveTracks: (() -> Void)?

    private init() {
        setupAudioSession()
        setupRemoteCommands()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("Failed to configure AVAudioSession: \(error)")
        }
    }

    // MARK: - Playback Control
    public func playTrack(_ track: Track, in playlist: [Track], context: PlayContext = .album, startPositionMs: Int64 = 0) {
        self.playContext = context
        self.currentPlaylist = playlist
        recomputeQueue()

        if let idx = activeQueue.firstIndex(where: { $0.id == track.id }) {
            currentQueueIndex = idx
        } else {
            activeQueue.insert(track, at: 0)
            currentQueueIndex = 0
        }

        startPlayback(for: track, startPositionMs: startPositionMs)
    }

    private func recomputeQueue() {
        if isShuffled {
            var shuffled = currentPlaylist
            shuffled.shuffle()
            if let cur = currentTrack, let idx = shuffled.firstIndex(where: { $0.id == cur.id }) {
                shuffled.remove(at: idx)
                shuffled.insert(cur, at: 0)
            }
            activeQueue = shuffled
        } else {
            activeQueue = currentPlaylist
        }
    }

    private func startPlayback(for track: Track, startPositionMs: Int64 = 0) {
        // Record previous listen if applicable
        finalizeListenTracking()

        self.currentTrack = track
        self.currentTimeMs = startPositionMs
        self.durationMs = 0
        self.trackStartTime = Date()
        self.accumulatedPlayTimeMs = 0
        self.lastSyncTimeMs = startPositionMs

        // Determine audio source: local download or remote URL
        let audioUrl: URL?
        if let local = DownloadManager.shared.localAudioUrl(for: track.id) {
            audioUrl = local
        } else if let remote = URL(string: track.audioUrl) {
            audioUrl = remote
        } else {
            audioUrl = nil
        }

        guard let targetUrl = audioUrl else { return }

        // Remove old observers
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
            itemEndObserver = nil
        }

        let playerItem = AVPlayerItem(url: targetUrl)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.automaticallyWaitsToMinimizeStalling = true
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        if startPositionMs > 0 {
            let targetTime = CMTime(seconds: Double(startPositionMs) / 1000.0, preferredTimescale: 1000)
            player?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        // Attach end notification
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleTrackEnded()
            }
        }

        // Time observer (4 updates per second is ideal for smooth slider & lyrics)
        let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let curSec = CMTimeGetSeconds(time)
                if !curSec.isNaN && !curSec.isInfinite {
                    self.currentTimeMs = Int64(curSec * 1000)
                }

                if let dur = self.player?.currentItem?.duration {
                    let durSec = CMTimeGetSeconds(dur)
                    if !durSec.isNaN && !durSec.isInfinite {
                        self.durationMs = Int64(durSec * 1000)
                    }
                }

                self.updateNowPlayingPlaybackInfo()

                if abs(self.currentTimeMs - self.lastSyncTimeMs) > 12_000 {
                    self.syncPlaybackState()
                }
            }
        }

        player?.play()
        self.isPlaying = true
        self.onTrackChanged?(track)
        self.syncPlaybackState()

        // Update glow background
        Task {
            let color = await DominantColorExtractor.extractDominantColor(from: track.coverUrl)
            await MainActor.run {
                self.playerGlowColor = color
            }
        }

        updateNowPlayingStaticInfo(for: track)
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard let p = player else {
            if let track = currentTrack ?? currentPlaylist.first {
                playTrack(track, in: currentPlaylist, context: playContext)
            }
            return
        }
        p.play()
        isPlaying = true
        trackStartTime = Date()
        updateNowPlayingPlaybackInfo()
        syncPlaybackState()
    }

    public func pause() {
        player?.pause()
        isPlaying = false
        if let start = trackStartTime {
            accumulatedPlayTimeMs += Int64(Date().timeIntervalSince(start) * 1000)
            trackStartTime = nil
        }
        updateNowPlayingPlaybackInfo()
        syncPlaybackState()
    }

    public func seek(to ms: Int64) {
        currentTimeMs = ms
        let seconds = Double(ms) / 1000.0
        let time = CMTime(seconds: seconds, preferredTimescale: 1000)
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in
                self?.updateNowPlayingPlaybackInfo()
                self?.syncPlaybackState()
            }
        }
    }

    public func playNext() {
        guard !activeQueue.isEmpty else { return }
        if currentQueueIndex + 1 < activeQueue.count {
            currentQueueIndex += 1
            startPlayback(for: activeQueue[currentQueueIndex])
        } else if playContext == .wave {
            onNeedMoreWaveTracks?()
            currentQueueIndex = 0
            startPlayback(for: activeQueue[0])
        } else if isRepeating {
            currentQueueIndex = 0
            startPlayback(for: activeQueue[0])
        } else {
            pause()
            seek(to: 0)
        }
    }

    public func playPrevious() {
        // If track played for > 3 seconds, restart current track
        if currentTimeMs > 3000 {
            seek(to: 0)
            return
        }

        guard !activeQueue.isEmpty else { return }
        if currentQueueIndex > 0 {
            currentQueueIndex -= 1
            startPlayback(for: activeQueue[currentQueueIndex])
        } else if let last = activeQueue.indices.last {
            currentQueueIndex = last
            startPlayback(for: activeQueue[currentQueueIndex])
        }
    }

    public func toggleShuffle() {
        isShuffled.toggle()
    }

    public func toggleRepeat() {
        isRepeating.toggle()
    }

    private func handleTrackEnded() {
        finalizeListenTracking()
        if isRepeating && activeQueue.count == 1 {
            seek(to: 0)
            play()
        } else {
            playNext()
        }
    }

    private func syncPlaybackState() {
        guard let track = currentTrack else { return }
        lastSyncTimeMs = currentTimeMs
        let pos = currentTimeMs
        let playing = isPlaying
        let trackId = track.id
        Task {
            if let token = UserDefaults.standard.string(forKey: "auth_token"),
               !token.isEmpty, token != "guest" {
                _ = await ApiClient.shared.savePlaybackSync(token: token, trackId: trackId, positionMs: pos, isPlaying: playing)
            }
        }
    }

    private func finalizeListenTracking() {
        guard let track = currentTrack else { return }
        if let start = trackStartTime {
            accumulatedPlayTimeMs += Int64(Date().timeIntervalSince(start) * 1000)
        }

        let totalMs = accumulatedPlayTimeMs
        trackStartTime = nil
        accumulatedPlayTimeMs = 0

        // Submit listen record if listened for at least 15 seconds
        if totalMs >= 15_000 {
            let trackId = track.id
            Task {
                if let token = UserDefaults.standard.string(forKey: "auth_token"),
                   !token.isEmpty, token != "guest" {
                    _ = await ApiClient.shared.recordListen(token: token, trackId: trackId, durationMs: totalMs)
                }
            }
        }
    }

    // MARK: - Now Playing & Remote Command Center
    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.togglePlayPause() }
            return .success
        }

        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playNext() }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.playPrevious() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let ms = Int64(posEvent.positionTime * 1000)
            Task { @MainActor in self?.seek(to: ms) }
            return .success
        }

        commandCenter.likeCommand.isEnabled = true
        commandCenter.likeCommand.localizedTitle = "Мне нравится"
        commandCenter.likeCommand.addTarget { [weak self] _ in
            guard let self = self, let track = self.currentTrack else { return .commandFailed }
            Task { @MainActor in self.onLikeToggled?(track.id) }
            return .success
        }
    }

    private func updateNowPlayingStaticInfo(for track: Track) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.displayArtist,
            MPMediaItemPropertyAlbumTitle: "LifonMUSIC",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]

        if durationMs > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentTimeMs) / 1000.0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        // Load Artwork asynchronously
        if let coverStr = track.coverUrl, let url = URL(string: coverStr) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let image = UIImage(data: data) {
                    let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                    await MainActor.run {
                        var cur = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                        cur[MPMediaItemPropertyArtwork] = artwork
                        MPNowPlayingInfoCenter.default().nowPlayingInfo = cur
                    }
                }
            }
        }
    }

    private func updateNowPlayingPlaybackInfo() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(currentTimeMs) / 1000.0
        if durationMs > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = Double(durationMs) / 1000.0
        }
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

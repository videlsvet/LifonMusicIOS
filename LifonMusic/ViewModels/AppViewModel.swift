import Foundation
import SwiftUI
import Combine

public enum AppScreen: Hashable {
    case library
    case favorites
    case profile
}

@MainActor
public final class AppViewModel: ObservableObject {
    public static let shared = AppViewModel()

    @Published public var albums: [Album] = []
    @Published public var currentScreen: AppScreen = .library
    @Published public var selectedAlbum: Album?
    @Published public var searchQuery: String = ""
    @Published public var likedTracks: Set<Int> = []

    @Published public var maintenanceMessage: String?
    @Published public var isOffline: Bool = false
    @Published public var isLoadingCatalog: Bool = false
    @Published public var broadcast: BroadcastNotification?

    @Published public var showDisclaimer: Bool = false
    @Published public var showRoadmap: Bool = false
    @Published public var showEqualizer: Bool = false
    @Published public var showCupsizeInfo: Bool = false
    @Published public var showFullPlayer: Bool = false
    @Published public var showAuth: Bool = false

    @Published public var authToken: String?
    @Published public var username: String?
    @Published public var stats: StatsResult?
    @Published public var achievements: [Achievement] = []
    @Published public var myAchievements: [UserAchievement] = []

    public let playerService = AudioPlayerService.shared
    public let downloadManager = DownloadManager.shared
    public let equalizerService = EqualizerService.shared

    private var pingTimer: AnyCancellable?
    private let tokenKey = "auth_token"
    private let usernameKey = "auth_username"
    private let likedKey = "liked_tracks_set"
    private let disclaimerKey = "disclaimer_shown"
    private let lastBroadcastIdKey = "last_broadcast_id"

    private init() {
        self.authToken = UserDefaults.standard.string(forKey: tokenKey)
        self.username = UserDefaults.standard.string(forKey: usernameKey)
        self.showDisclaimer = !UserDefaults.standard.bool(forKey: disclaimerKey)

        if let savedLikes = UserDefaults.standard.array(forKey: likedKey) as? [Int] {
            self.likedTracks = Set(savedLikes)
        }

        playerService.onTrackChanged = { [weak self] _ in
            // Handle any side effects on track change
        }

        playerService.onLikeToggled = { [weak self] trackId in
            self?.toggleLike(trackId: trackId)
        }

        startPingTimer()
    }

    public func initialize() async {
        await loadCatalog()
        await refreshLikes()
        await checkBroadcastNotification()
        if isAuthenticated {
            await loadProfileData()
        }
    }

    public var isAuthenticated: Bool {
        guard let t = authToken, !t.isEmpty, t != "guest" else { return false }
        return true
    }

    // MARK: - Catalog Loading
    public func loadCatalog() async {
        isLoadingCatalog = true
        maintenanceMessage = nil
        isOffline = false

        let result = await ApiClient.shared.fetchAlbums()
        isLoadingCatalog = false

        switch result {
        case .success(let fetchedAlbums):
            self.albums = fetchedAlbums
            self.isOffline = false
        case .maintenance(let msg):
            self.maintenanceMessage = msg
        case .offline:
            self.isOffline = true
        case .error(let err):
            if self.albums.isEmpty {
                self.isOffline = true
            }
            print("Catalog error: \(err)")
        }
    }

    // MARK: - Likes
    public func isLiked(_ trackId: Int) -> Bool {
        likedTracks.contains(trackId)
    }

    public func toggleLike(trackId: Int) {
        if likedTracks.contains(trackId) {
            likedTracks.remove(trackId)
            persistLikes()
            if let token = authToken, isAuthenticated {
                Task { _ = await ApiClient.shared.removeLike(token: token, trackId: trackId) }
            }
        } else {
            likedTracks.insert(trackId)
            persistLikes()
            if let token = authToken, isAuthenticated {
                Task { _ = await ApiClient.shared.addLike(token: token, trackId: trackId) }
            }
        }
    }

    public func refreshLikes() async {
        guard let token = authToken, isAuthenticated else { return }
        if let serverLikes = await ApiClient.shared.fetchLikes(token: token) {
            self.likedTracks = serverLikes
            persistLikes()
        }
    }

    private func persistLikes() {
        UserDefaults.standard.set(Array(likedTracks), forKey: likedKey)
    }

    // MARK: - Playback
    public func playTrack(_ track: Track, in context: PlayContext) {
        let playlist: [Track]
        switch context {
        case .album:
            if let alb = albumForTrack(track) {
                playlist = alb.tracks
            } else {
                playlist = [track]
            }
        case .favorites:
            playlist = favoriteTracks
        case .downloaded:
            playlist = downloadedTracksAsTracks
        case .allTracks:
            playlist = allTracks
        }
        playerService.playTrack(track, in: playlist, context: context)
    }

    public var allTracks: [Track] {
        albums.flatMap { $0.tracks }
    }

    public var favoriteTracks: [Track] {
        allTracks.filter { likedTracks.contains($0.id) }
    }

    public var downloadedTracksAsTracks: [Track] {
        downloadManager.downloadedTracks.map { meta in
            Track(
                id: meta.id,
                title: meta.title,
                duration: meta.duration,
                audioUrl: "",
                albumId: meta.albumId,
                artist: meta.artist,
                coverUrl: nil
            )
        }
    }

    public func albumForTrack(_ track: Track?) -> Album? {
        guard let track = track else { return nil }
        return albums.first(where: { $0.id == track.albumId })
    }

    public func albumForId(_ id: Int) -> Album? {
        albums.first(where: { $0.id == id })
    }

    // MARK: - Profile & Achievements
    public func loadProfileData() async {
        guard let token = authToken, isAuthenticated else { return }
        async let statsTask = ApiClient.shared.fetchStats(token: token)
        async let achievementsTask = ApiClient.shared.fetchAllAchievements()
        async let myAchievementsTask = ApiClient.shared.fetchMyAchievements(token: token)

        let (s, allAch, myAch) = await (statsTask, achievementsTask, myAchievementsTask)
        self.stats = s
        self.achievements = allAch
        self.myAchievements = myAch
    }

    public func setAuthToken(token: String, username: String) {
        self.authToken = token
        self.username = username
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        Task {
            await refreshLikes()
            await loadProfileData()
        }
    }

    public func logout() {
        self.authToken = nil
        self.username = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        self.stats = nil
        self.myAchievements = []
    }

    public func dismissDisclaimer() {
        showDisclaimer = false
        UserDefaults.standard.set(true, forKey: disclaimerKey)
    }

    // MARK: - Broadcast
    public func checkBroadcastNotification() async {
        if let notif = await ApiClient.shared.fetchBroadcastNotification() {
            let lastSeen = UserDefaults.standard.integer(forKey: lastBroadcastIdKey)
            if notif.id != lastSeen {
                self.broadcast = notif
            }
        }
    }

    public func dismissBroadcast() {
        if let b = broadcast {
            UserDefaults.standard.set(b.id, forKey: lastBroadcastIdKey)
            broadcast = nil
        }
    }

    // MARK: - Online Ping
    private func startPingTimer() {
        pingTimer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let token = self.authToken, self.isAuthenticated else { return }
                Task { await ApiClient.shared.pingProfile(token: token) }
            }
    }
}

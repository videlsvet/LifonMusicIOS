import Foundation
import SwiftUI
import Combine

public enum AppScreen: Hashable {
    case library
    case favorites
    case playlists
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

    // Auth & Profile
    @Published public var authToken: String?
    @Published public var username: String?
    @Published public var avatarUrl: String?
    @Published public var isUploadingAvatar: Bool = false
    @Published public var serverMinutes: Int64?
    @Published public var stats: StatsResult?
    @Published public var achievements: [Achievement] = []
    @Published public var myAchievements: [UserAchievement] = []
    @Published public var supporters: [Supporter] = []

    // Wave Mode
    @Published public var isWaveActive: Bool = false
    @Published public var isLoadingWave: Bool = false
    @Published public var waveTracks: [Track] = []

    // Playlists
    @Published public var playlists: [UserPlaylist] = []
    @Published public var selectedPlaylist: UserPlaylist?
    @Published public var selectedPlaylistTracks: [Track] = []
    @Published public var isLoadingPlaylists: Bool = false
    @Published public var playlistsError: String?
    @Published public var showCreatePlaylistDialog: Bool = false
    @Published public var showPlaylistPickerSheet: Bool = false
    @Published public var playlistPickerTrack: Track?

    public let playerService = AudioPlayerService.shared
    public let downloadManager = DownloadManager.shared
    public let equalizerService = EqualizerService.shared

    private var pingTimer: AnyCancellable?
    private let tokenKey = "auth_token"
    private let usernameKey = "auth_username"
    private let avatarKey = "auth_avatar_url"
    private let likedKey = "liked_tracks_set"
    private let disclaimerKey = "disclaimer_shown"
    private let lastBroadcastIdKey = "last_broadcast_id"

    private init() {
        self.authToken = UserDefaults.standard.string(forKey: tokenKey)
        self.username = UserDefaults.standard.string(forKey: usernameKey)
        self.avatarUrl = UserDefaults.standard.string(forKey: avatarKey)
        self.showDisclaimer = !UserDefaults.standard.bool(forKey: disclaimerKey)

        if let savedLikes = UserDefaults.standard.array(forKey: likedKey) as? [Int] {
            self.likedTracks = Set(savedLikes)
        }

        playerService.onTrackChanged = { [weak self] track in
            if let track = track, self?.playerService.playContext != .wave {
                self?.isWaveActive = false
            }
        }

        playerService.onLikeToggled = { [weak self] trackId in
            self?.toggleLike(trackId: trackId)
        }

        playerService.onNeedMoreWaveTracks = { [weak self] in
            Task { [weak self] in
                await self?.loadMoreWaveTracks()
            }
        }

        startPingTimer()
    }

    public func initialize() async {
        await loadCatalog()
        await refreshLikes()
        await checkBroadcastNotification()
        await loadSupporters()
        if isAuthenticated {
            await loadProfileData()
            await loadPlaylists()
            await syncRemotePlaybackOnLaunch()
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

    // MARK: - Wave ("Моя волна")
    public func toggleWave() async {
        if isWaveActive && playerService.isPlaying {
            playerService.pause()
        } else if isWaveActive && !playerService.isPlaying {
            playerService.play()
        } else {
            await startWave()
        }
    }

    public func startWave() async {
        isLoadingWave = true
        if let tracks = await ApiClient.shared.fetchWaveTracks(), !tracks.isEmpty {
            self.waveTracks = tracks
            self.isWaveActive = true
            if let first = tracks.first {
                playerService.playTrack(first, in: tracks, context: .wave)
            }
        } else {
            // Fallback: shuffle all catalog tracks
            let fallback = allTracks.shuffled()
            if let first = fallback.first {
                self.waveTracks = fallback
                self.isWaveActive = true
                playerService.playTrack(first, in: fallback, context: .wave)
            }
        }
        isLoadingWave = false
    }

    private func loadMoreWaveTracks() async {
        if let more = await ApiClient.shared.fetchWaveTracks() {
            self.waveTracks = more
        }
    }

    // MARK: - Playlists
    public func loadPlaylists() async {
        guard let token = authToken, isAuthenticated else {
            self.playlists = []
            return
        }
        isLoadingPlaylists = true
        playlistsError = nil
        let list = await ApiClient.shared.fetchPlaylists(token: token)
        self.playlists = list
        isLoadingPlaylists = false
    }

    public func createPlaylist(title: String) async -> UserPlaylist? {
        guard let token = authToken, isAuthenticated else { return nil }
        if let created = await ApiClient.shared.createPlaylist(token: token, title: title) {
            await loadPlaylists()
            return created
        }
        return nil
    }

    public func deletePlaylist(_ playlist: UserPlaylist) async {
        guard let token = authToken, isAuthenticated else { return }
        let ok = await ApiClient.shared.deletePlaylist(token: token, publicId: playlist.publicId)
        if ok {
            if selectedPlaylist?.publicId == playlist.publicId {
                selectedPlaylist = nil
                selectedPlaylistTracks = []
            }
            await loadPlaylists()
        }
    }

    public func selectPlaylist(_ playlist: UserPlaylist) async {
        self.selectedPlaylist = playlist
        let ids = await ApiClient.shared.fetchPlaylistTracks(publicId: playlist.publicId)
        let map = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
        self.selectedPlaylistTracks = ids.compactMap { map[$0] }
    }

    public func addTrackToPlaylist(playlist: UserPlaylist, trackId: Int) async {
        guard let token = authToken, isAuthenticated else { return }
        let ok = await ApiClient.shared.addTrackToPlaylist(token: token, publicId: playlist.publicId, trackId: trackId)
        if ok {
            if selectedPlaylist?.publicId == playlist.publicId {
                await selectPlaylist(playlist)
            }
            await loadPlaylists()
        }
    }

    public func openPlaylistPicker(for track: Track) {
        self.playlistPickerTrack = track
        self.showPlaylistPickerSheet = true
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
        case .playlist:
            playlist = selectedPlaylistTracks
        case .wave:
            playlist = waveTracks
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

    // MARK: - Playback Sync on Launch
    private func syncRemotePlaybackOnLaunch() async {
        guard let token = authToken, isAuthenticated else { return }
        if let remote = await ApiClient.shared.fetchPlaybackSync(token: token) {
            if let targetTrack = allTracks.first(where: { $0.id == remote.trackId }) {
                let alb = albumForTrack(targetTrack)
                let list = alb?.tracks ?? [targetTrack]
                // Prepare track position without auto-blasting sound if not actively playing
                playerService.playTrack(targetTrack, in: list, context: .album, startPositionMs: remote.positionMs)
                if !remote.isPlaying {
                    playerService.pause()
                }
            }
        }
    }

    // MARK: - Profile & Achievements
    public func loadProfileData() async {
        guard let token = authToken, isAuthenticated else { return }
        async let profileTask = ApiClient.shared.fetchProfileDetails(token: token)
        async let statsTask = ApiClient.shared.fetchStats(token: token)
        async let achievementsTask = ApiClient.shared.fetchAllAchievements()
        async let myAchievementsTask = ApiClient.shared.fetchMyAchievements(token: token)

        let (prof, s, allAch, myAch) = await (profileTask, statsTask, achievementsTask, myAchievementsTask)
        if let uname = prof.username, !uname.isEmpty {
            self.username = uname
            UserDefaults.standard.set(uname, forKey: usernameKey)
        }
        if let aUrl = prof.avatarUrl {
            self.avatarUrl = aUrl
            UserDefaults.standard.set(aUrl, forKey: avatarKey)
        }
        self.serverMinutes = prof.listenMs.map { $0 / 60_000 }
        self.stats = s
        self.achievements = allAch
        self.myAchievements = myAch
    }

    public func uploadAvatar(imageData: Data) async {
        guard let token = authToken, isAuthenticated else { return }
        isUploadingAvatar = true
        if let newUrl = await ApiClient.shared.uploadAvatar(token: token, imageData: imageData) {
            self.avatarUrl = newUrl
            UserDefaults.standard.set(newUrl, forKey: avatarKey)
        }
        isUploadingAvatar = false
    }

    public func loadSupporters() async {
        let supps = await ApiClient.shared.fetchSupporters()
        self.supporters = supps
    }

    public func setAuthToken(token: String, username: String) {
        self.authToken = token
        self.username = username
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(username, forKey: usernameKey)
        Task {
            await refreshLikes()
            await loadPlaylists()
            await loadProfileData()
        }
    }

    public func logout() {
        self.authToken = nil
        self.username = nil
        self.avatarUrl = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: usernameKey)
        UserDefaults.standard.removeObject(forKey: avatarKey)
        self.stats = nil
        self.myAchievements = []
        self.playlists = []
        self.selectedPlaylist = nil
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

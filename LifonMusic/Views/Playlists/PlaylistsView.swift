import SwiftUI

public struct PlaylistsView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared

    @State private var showCreateDialog = false
    @State private var newPlaylistTitle = ""
    @State private var playlistToDelete: UserPlaylist?
    @State private var showDeleteAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.035).ignoresSafeArea()

                if let current = appVm.selectedPlaylist {
                    playlistDetailView(for: current)
                } else {
                    playlistsListView
                }
            }
            .navigationBarHidden(true)
            .alert("Новый плейлист", isPresented: $showCreateDialog) {
                TextField("Название плейлиста", text: $newPlaylistTitle)
                Button("Создать") {
                    let title = newPlaylistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !title.isEmpty {
                        Task {
                            _ = await appVm.createPlaylist(title: title)
                            newPlaylistTitle = ""
                        }
                    }
                }
                Button("Отмена", role: .cancel) {
                    newPlaylistTitle = ""
                }
            }
            .alert("Удалить плейлист?", isPresented: $showDeleteAlert) {
                Button("Удалить", role: .destructive) {
                    if let pl = playlistToDelete {
                        Task {
                            await appVm.deletePlaylist(pl)
                            playlistToDelete = nil
                        }
                    }
                }
                Button("Отмена", role: .cancel) {
                    playlistToDelete = nil
                }
            } message: {
                Text("Плейлист «\(playlistToDelete?.title ?? "")» будет удален.")
            }
        }
        .onAppear {
            if appVm.isAuthenticated {
                Task {
                    await appVm.loadPlaylists()
                }
            }
        }
    }

    private var playlistsListView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Плейлисты")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Твои подборки треков")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    if appVm.isAuthenticated {
                        Button(action: { showCreateDialog = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if !appVm.isAuthenticated {
                    // Guest state
                    VStack(spacing: 12) {
                        Spacer(minLength: 40)
                        Image(systemName: "music.note.list")
                            .font(.system(size: 48))
                            .foregroundColor(Color(red: 0.83, green: 0.74, blue: 1.0).opacity(0.6))

                        Text("Плейлисты в облаке")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("Войди в аккаунт, чтобы создавать персональные подборки и синхронизировать их между устройствами.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        Button(action: { appVm.showAuth = true }) {
                            Text("Войти в аккаунт")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                        Spacer(minLength: 60)
                    }
                } else if appVm.isLoadingPlaylists && appVm.playlists.isEmpty {
                    VStack {
                        Spacer(minLength: 60)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Загрузка плейлистов...")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.top, 10)
                        Spacer(minLength: 60)
                    }
                    .frame(maxWidth: .infinity)
                } else if appVm.playlists.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 50)
                        Image(systemName: "square.stack.badge.plus")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.2))

                        Text("Нет плейлистов")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)

                        Text("Создай свой первый плейлист и добавляй любимые треки.")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)

                        Button(action: { showCreateDialog = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Создать плейлист")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .padding(.top, 6)
                        Spacer(minLength: 60)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(appVm.playlists) { playlist in
                            Button(action: {
                                Task {
                                    await appVm.selectPlaylist(playlist)
                                }
                            }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(red: 0.83, green: 0.74, blue: 1.0).opacity(0.16))
                                            .frame(width: 44, height: 44)

                                        Image(systemName: "music.note.list")
                                            .font(.system(size: 18))
                                            .foregroundColor(Color(red: 0.83, green: 0.74, blue: 1.0))
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)

                                        Text("Открыть подборку")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white.opacity(0.42))
                                    }

                                    Spacer()

                                    Button(action: {
                                        playlistToDelete = playlist
                                        showDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 15))
                                            .foregroundColor(Color(red: 1.0, green: 0.45, blue: 0.45).opacity(0.85))
                                            .frame(width: 36, height: 36)
                                    }

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white.opacity(0.3))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 130)
        }
        .refreshable {
            if appVm.isAuthenticated {
                await appVm.loadPlaylists()
            }
        }
    }

    private func playlistDetailView(for playlist: UserPlaylist) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Detail Header
                HStack(spacing: 12) {
                    Button(action: { appVm.selectedPlaylist = nil }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(playlist.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text("\(appVm.selectedPlaylistTracks.count) треков")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }

                    Spacer()

                    if let shareUrl = URL(string: "https://lifonmusic.lol/playlist/\(playlist.publicId)") {
                        ShareLink(item: shareUrl) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 38, height: 38)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                    }

                    Button(action: {
                        playlistToDelete = playlist
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(Color(red: 1.0, green: 0.5, blue: 0.5).opacity(0.85))
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if appVm.selectedPlaylistTracks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer(minLength: 60)
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.2))

                        Text("В этом плейлисте пока нет треков")
                            .font(.system(size: 15))
                            .foregroundColor(.white.opacity(0.45))
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 80)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(appVm.selectedPlaylistTracks) { track in
                            let alb = appVm.albumForTrack(track)
                            TrackRowView(
                                track: track,
                                coverUrl: track.coverUrl ?? alb?.coverUrl,
                                isCurrent: player.currentTrack?.id == track.id,
                                isPlaying: player.isPlaying,
                                isLiked: appVm.isLiked(track.id),
                                downloadStatus: appVm.downloadManager.status(for: track.id),
                                onPlay: {
                                    appVm.playTrack(track, in: .playlist)
                                },
                                onToggleLike: {
                                    appVm.toggleLike(trackId: track.id)
                                },
                                onDownload: {
                                    appVm.downloadManager.downloadTrack(track)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 130)
        }
    }
}

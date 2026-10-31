import SwiftUI

public struct FavoritesView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.035).ignoresSafeArea()

                let favs = appVm.favoriteTracks

                if favs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 54))
                            .foregroundColor(.white.opacity(0.2))

                        Text("Здесь пока пусто")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Ставь сердечки трекам в альбомах,\nчтобы они появились здесь")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            // Header
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Избранное")
                                        .font(.system(size: 26, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                    Text("\(favs.count) треков")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }

                                Spacer()

                                Button(action: {
                                    if let first = favs.first {
                                        appVm.playTrack(first, in: .favorites)
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 13))
                                        Text("Слушать")
                                            .font(.system(size: 14, weight: .bold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                            // List
                            LazyVStack(spacing: 4) {
                                ForEach(favs) { track in
                                    let alb = appVm.albumForTrack(track)
                                    TrackRowView(
                                        track: track,
                                        coverUrl: alb?.coverUrl,
                                        isCurrent: player.currentTrack?.id == track.id,
                                        isPlaying: player.isPlaying,
                                        isLiked: true,
                                        downloadStatus: appVm.downloadManager.status(for: track.id),
                                        onPlay: { appVm.playTrack(track, in: .favorites) },
                                        onToggleLike: { appVm.toggleLike(trackId: track.id) },
                                        onDownload: { appVm.downloadManager.downloadTrack(track) }
                                    )
                                }
                            }
                            .padding(.bottom, 130)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                Task {
                    await appVm.refreshLikes()
                }
            }
        }
    }
}

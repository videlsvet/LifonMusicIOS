import SwiftUI

public struct AlbumDetailView: View {
    public let album: Album
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared

    public init(album: Album) {
        self.album = album
    }

    public var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.03, blue: 0.035).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    // Header Cover Art
                    ZStack {
                        if let glow = album.glowColor, let glowCol = DominantColorExtractor.color(from: glow) {
                            Circle()
                                .fill(glowCol.opacity(0.35))
                                .blur(radius: 50)
                                .frame(width: 200, height: 200)
                        }

                        if let urlStr = album.coverUrl, let url = URL(string: urlStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(1, contentMode: .fit)
                                default:
                                    Rectangle().fill(Color.white.opacity(0.1))
                                }
                            }
                        } else {
                            Rectangle().fill(Color.white.opacity(0.1))
                        }
                    }
                    .frame(width: 210, height: 210)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 10)
                    .padding(.top, 16)

                    // Title & Meta
                    VStack(spacing: 6) {
                        Text(album.title)
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)

                        HStack(spacing: 8) {
                            Text("CUPSIZE")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))

                            Text("•")
                                .foregroundColor(.white.opacity(0.3))

                            Text(album.year)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Text("•")
                                .foregroundColor(.white.opacity(0.3))

                            Text("\(album.tracks.count) треков")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    // Play All Button
                    Button(action: {
                        if let first = album.tracks.first {
                            appVm.playTrack(first, in: .album)
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                            Text("Слушать альбом")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)

                    Divider()
                        .background(Color.white.opacity(0.1))
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    // Tracks List
                    LazyVStack(spacing: 4) {
                        ForEach(Array(album.tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRowView(
                                track: track,
                                coverUrl: album.coverUrl,
                                isCurrent: player.currentTrack?.id == track.id,
                                isPlaying: player.isPlaying,
                                isLiked: appVm.isLiked(track.id),
                                downloadStatus: appVm.downloadManager.status(for: track.id),
                                onPlay: {
                                    appVm.playTrack(track, in: .album)
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
                    .padding(.bottom, 120) // Extra padding for mini-player
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                        Text("Назад")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    appVm.showEqualizer = true
                }) {
                    Image(systemName: "slider.vertical.3")
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
    }
}

import SwiftUI

public struct OfflineView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared
    public let onRetry: () -> Void

    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                        .padding(.top, 30)

                    Text("Нет подключения")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.white)

                    Text("Ты в офлайн-режиме. Скачанные треки доступны для прослушивания.")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Button(action: onRetry) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Повторить попытку")
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)
                }

                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.top, 24)

                // Downloaded Tracks list
                let downloaded = appVm.downloadManager.downloadedTracks
                if downloaded.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "arrow.down.circle.dotted")
                            .font(.system(size: 44))
                            .foregroundColor(.white.opacity(0.2))
                        Text("Нет сохранённых треков")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Сохранённые треки (\(downloaded.count))")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.top, 14)

                            LazyVStack(spacing: 4) {
                                ForEach(downloaded) { meta in
                                    let track = Track(
                                        id: meta.id,
                                        title: meta.title,
                                        duration: meta.duration,
                                        audioUrl: "",
                                        albumId: meta.albumId,
                                        artist: meta.artist
                                    )
                                    TrackRowView(
                                        track: track,
                                        coverUrl: nil,
                                        isCurrent: player.currentTrack?.id == track.id,
                                        isPlaying: player.isPlaying,
                                        isLiked: appVm.isLiked(track.id),
                                        downloadStatus: .done,
                                        onPlay: {
                                            appVm.playTrack(track, in: .downloaded)
                                        },
                                        onToggleLike: {
                                            appVm.toggleLike(trackId: track.id)
                                        },
                                        onDownload: {
                                            appVm.downloadManager.removeDownload(trackId: track.id)
                                        }
                                    )
                                }
                            }
                            .padding(.bottom, 120)
                        }
                    }
                }
            }
        }
    }
}

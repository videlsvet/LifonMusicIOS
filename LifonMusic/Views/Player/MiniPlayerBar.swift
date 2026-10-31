import SwiftUI

public struct MiniPlayerBar: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var appVm = AppViewModel.shared

    public var body: some View {
        if let track = player.currentTrack {
            Button(action: {
                appVm.showFullPlayer = true
            }) {
                HStack(spacing: 12) {
                    // Album Cover
                    ZStack {
                        if let coverStr = track.coverUrl, let url = URL(string: coverStr) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let img):
                                    img.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(Color.white.opacity(0.1))
                                }
                            }
                        } else {
                            Rectangle().fill(Color.white.opacity(0.1))
                        }
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // Track Title & Artist
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(track.displayArtist)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Like Button
                    Button(action: {
                        appVm.toggleLike(trackId: track.id)
                    }) {
                        Image(systemName: appVm.isLiked(track.id) ? "heart.fill" : "heart")
                            .font(.system(size: 18))
                            .foregroundColor(appVm.isLiked(track.id) ? Color(red: 1.0, green: 0.42, blue: 0.54) : .white.opacity(0.5))
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    // Play / Pause Button
                    Button(action: {
                        player.togglePlayPause()
                    }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 38, height: 38)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(red: 0.11, green: 0.11, blue: 0.13).opacity(0.96))
                        .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(player.playerGlowColor.opacity(0.35), lineWidth: 1)
                )
                .padding(.horizontal, 14)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

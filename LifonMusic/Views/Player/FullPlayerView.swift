import SwiftUI

public struct FullPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var appVm = AppViewModel.shared
    @StateObject private var lyricsVm = LyricsViewModel()

    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0.0

    @State private var coverOffset: CGFloat = 0.0

    public var body: some View {
        ZStack {
            // Background Glow
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [player.playerGlowColor.opacity(0.45), Color.clear]),
                center: .top,
                startRadius: 50,
                endRadius: 450
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Handle & Bar
                VStack(spacing: 12) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 36, height: 4)
                        .padding(.top, 10)

                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 38, height: 38)
                        }

                        Spacer()

                        VStack(spacing: 2) {
                            Text(player.playContext == .wave ? "ИГРАЕТ ВОЛНА" : "ИГРАЕТ ИЗ ДИСКОГРАФИИ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.4))
                                .tracking(1)

                            if let track = player.currentTrack, let album = appVm.albumForTrack(track) {
                                Text(album.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        Button(action: { appVm.showEqualizer = true }) {
                            Image(systemName: "slider.vertical.3")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                                .frame(width: 38, height: 38)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 10)

                // Middle: Cover Art OR Lyrics
                if showLyrics {
                    LyricsOverlayView(lyricsVm: lyricsVm) { seekMs in
                        player.seek(to: seekMs)
                    }
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    // Album Cover with swipe gesture
                    GeometryReader { geo in
                        let size = min(geo.size.width - 64, geo.size.height - 20)

                        ZStack {
                            if let track = player.currentTrack, let coverStr = track.coverUrl, let url = URL(string: coverStr) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().aspectRatio(1, contentMode: .fill)
                                    default:
                                        coverPlaceholder
                                    }
                                }
                            } else {
                                coverPlaceholder
                            }
                        }
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: player.playerGlowColor.opacity(0.4), radius: 24, x: 0, y: 12)
                        .offset(x: coverOffset)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    coverOffset = value.translation.width * 0.4
                                }
                                .onEnded { value in
                                    if value.translation.width < -60 {
                                        player.playNext()
                                    } else if value.translation.width > 60 {
                                        player.playPrevious()
                                    }
                                    withAnimation(.spring()) {
                                        coverOffset = 0
                                    }
                                }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .frame(maxHeight: 380)
                    .transition(.opacity)
                }

                Spacer(minLength: 16)

                // Track Info & Actions (Like, Add to Playlist, Lyrics, Download)
                if let track = player.currentTrack {
                    VStack(spacing: 20) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(track.title)
                                    .font(.system(size: 22, weight: .black))
                                    .foregroundColor(.white)
                                    .lineLimit(1)

                                Text(track.displayArtist)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Lyrics toggle button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    showLyrics.toggle()
                                }
                            }) {
                                Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                                    .font(.system(size: 20))
                                    .foregroundColor(showLyrics ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.6))
                                    .padding(8)
                            }

                            // Add to playlist button
                            Button(action: {
                                appVm.openPlaylistPicker(for: track)
                            }) {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.6))
                                    .padding(8)
                            }

                            // Download button
                            Button(action: {
                                appVm.downloadManager.downloadTrack(track)
                            }) {
                                switch appVm.downloadManager.status(for: track.id) {
                                case .none:
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 20))
                                        .foregroundColor(.white.opacity(0.6))
                                case .downloading:
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                case .done:
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(red: 0.5, green: 0.8, blue: 0.77))
                                }
                            }
                            .padding(8)

                            // Like button
                            Button(action: {
                                appVm.toggleLike(trackId: track.id)
                            }) {
                                Image(systemName: appVm.isLiked(track.id) ? "heart.fill" : "heart")
                                    .font(.system(size: 22))
                                    .foregroundColor(appVm.isLiked(track.id) ? Color(red: 1.0, green: 0.42, blue: 0.54) : .white.opacity(0.6))
                                    .padding(8)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Scrubber Slider
                        VStack(spacing: 6) {
                            let duration = max(Double(player.durationMs), 1.0)
                            let current = isDraggingSlider ? dragSliderValue : Double(player.currentTimeMs)

                            Slider(
                                value: Binding(
                                    get: { min(max(current, 0.0), duration) },
                                    set: { newValue in
                                        isDraggingSlider = true
                                        dragSliderValue = newValue
                                    }
                                ),
                                in: 0.0...duration,
                                onEditingChanged: { editing in
                                    if !editing {
                                        player.seek(to: Int64(dragSliderValue))
                                        isDraggingSlider = false
                                    }
                                }
                            )
                            .accentColor(Color(red: 0.91, green: 0.835, blue: 1.0))

                            HStack {
                                Text(formatTime(current))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.45))

                                Spacer()

                                Text(formatTime(duration))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.45))
                            }
                        }
                        .padding(.horizontal, 24)

                        // Playback Controls (Shuffle, Prev, Play/Pause, Next, Repeat)
                        HStack(spacing: 24) {
                            // Shuffle
                            Button(action: { player.toggleShuffle() }) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(player.isShuffled ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.4))
                            }

                            Spacer()

                            // Previous
                            Button(action: { player.playPrevious() }) {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }

                            // Play / Pause (Large)
                            Button(action: { player.togglePlayPause() }) {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.black)
                                    .frame(width: 70, height: 70)
                                    .background(Color.white)
                                    .clipShape(Circle())
                                    .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 5)
                            }

                            // Next
                            Button(action: { player.playNext() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            // Repeat
                            Button(action: { player.toggleRepeat() }) {
                                Image(systemName: "repeat")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(player.isRepeating ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.4))
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .onAppear {
            if let track = player.currentTrack {
                lyricsVm.loadLyrics(for: track.id)
            }
        }
        .onChange(of: player.currentTrack) { newTrack in
            if let t = newTrack {
                lyricsVm.loadLyrics(for: t.id)
            }
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 48))
                    .foregroundColor(.white.opacity(0.2))
            )
    }

    private func formatTime(_ ms: Double) -> String {
        let totalSec = max(0, Int(ms / 1000.0))
        let m = totalSec / 60
        let s = totalSec % 60
        return String(format: "%d:%02d", m, s)
    }
}

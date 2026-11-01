import SwiftUI

public struct FullPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var appVm = AppViewModel.shared
    @StateObject private var lyricsVm = LyricsViewModel()

    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0.0

    // Gestures
    @State private var dismissOffsetY: CGFloat = 0.0
    @State private var carouselOffsetX: CGFloat = 0.0
    @State private var activeDragAxis: DragAxis = .none

    private enum DragAxis {
        case none
        case vertical
        case horizontal
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Background Glow
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [player.playerGlowColor.opacity(0.40), Color.clear]),
                center: .top,
                startRadius: 40,
                endRadius: 460
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Handle & Navigation Bar
                topHeaderBar

                Spacer(minLength: 8)

                // Middle: Cover Art Carousel OR Lyrics Overlay
                if showLyrics {
                    LyricsOverlayView(lyricsVm: lyricsVm) { seekMs in
                        player.seek(to: seekMs)
                    }
                    .frame(maxHeight: .infinity)
                    .transition(.opacity)
                } else {
                    coverCarouselArea
                        .frame(maxHeight: 380)
                        .transition(.opacity)
                }

                Spacer(minLength: 16)

                // Track Info & Decluttered Action Controls
                if let track = player.currentTrack {
                    VStack(spacing: 22) {
                        trackInfoAndMenuRow(track: track)

                        scrubberSliderArea

                        playbackControlsRow
                    }
                }
            }
        }
        .offset(y: dismissOffsetY)
        .opacity(1.0 - Double(dismissOffsetY / 450.0).clamped(to: 0.0...0.65))
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    if activeDragAxis == .none {
                        if abs(value.translation.height) > abs(value.translation.width) {
                            if value.translation.height > 0 {
                                activeDragAxis = .vertical
                            }
                        } else if abs(value.translation.width) > 6 && !showLyrics {
                            activeDragAxis = .horizontal
                        }
                    }

                    if activeDragAxis == .vertical {
                        dismissOffsetY = max(0, value.translation.height)
                    } else if activeDragAxis == .horizontal {
                        carouselOffsetX = value.translation.width * 0.85
                    }
                }
                .onEnded { value in
                    if activeDragAxis == .vertical {
                        if dismissOffsetY > 110 || value.predictedEndTranslation.height > 260 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                dismissOffsetY = 0
                            }
                        }
                    } else if activeDragAxis == .horizontal {
                        let threshold: CGFloat = 60
                        if carouselOffsetX < -threshold && player.nextTrack != nil {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                carouselOffsetX = -300
                            }
                            player.playNext()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                carouselOffsetX = 0
                            }
                        } else if carouselOffsetX > threshold && player.previousTrack != nil {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                carouselOffsetX = 300
                            }
                            player.playPrevious()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                carouselOffsetX = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                carouselOffsetX = 0
                            }
                        }
                    }
                    activeDragAxis = .none
                }
        )
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

    // MARK: - Top Header Bar
    private var topHeaderBar: some View {
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
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }

                Spacer()

                Button(action: {
                    if let track = player.currentTrack, let album = appVm.albumForTrack(track) {
                        dismiss()
                        appVm.currentScreen = .library
                        appVm.selectedAlbum = album
                    }
                }) {
                    VStack(spacing: 2) {
                        Text(player.playContext == .wave ? "ИГРАЕТ ВОЛНА" : "ИГРАЕТ ИЗ ДИСКОГРАФИИ")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.45))
                            .tracking(1.2)

                        if let track = player.currentTrack, let album = appVm.albumForTrack(track) {
                            Text(album.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: { appVm.showEqualizer = true }) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 28)
        }
    }

    // MARK: - Cover Carousel with "Ears"
    private var coverCarouselArea: some View {
        GeometryReader { geo in
            let cardSize = min(geo.size.width - 76, geo.size.height - 20)
            let stepWidth = cardSize + 20

            ZStack {
                // Previous Track Ear (Left)
                if let prev = player.previousTrack {
                    coverCard(track: prev, size: cardSize, slotX: -stepWidth, stepWidth: stepWidth)
                }

                // Next Track Ear (Right)
                if let next = player.nextTrack {
                    coverCard(track: next, size: cardSize, slotX: stepWidth, stepWidth: stepWidth)
                }

                // Current Center Track
                if let current = player.currentTrack {
                    coverCard(track: current, size: cardSize, slotX: 0, stepWidth: stepWidth)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func coverCard(track: Track, size: CGFloat, slotX: CGFloat, stepWidth: CGFloat) -> some View {
        let totalOffset = slotX + carouselOffsetX
        let normalizedDist = min(max(totalOffset / stepWidth, -1.0), 1.0)
        let absNorm = abs(normalizedDist)

        let isCenter = (slotX == 0)
        let scale: CGFloat = isCenter ? (1.0 - absNorm * 0.12) : (0.88 + (1.0 - absNorm) * 0.12)
        let alpha: Double = isCenter ? (1.0 - Double(absNorm) * 0.50) : (0.45 + (1.0 - Double(absNorm)) * 0.55)

        let alb = appVm.albumForTrack(track)
        let coverStr = track.coverUrl ?? alb?.coverUrl

        return ZStack {
            if let str = coverStr, let url = URL(string: str) {
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
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: isCenter ? player.playerGlowColor.opacity(0.35) : .black.opacity(0.3), radius: isCenter ? 24 : 10, x: 0, y: isCenter ? 12 : 5)
        .scaleEffect(scale)
        .opacity(alpha)
        .offset(x: totalOffset)
    }

    // MARK: - Track Info & Three-Dots Menu Row
    private func trackInfoAndMenuRow(track: Track) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                // Lyrics toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showLyrics.toggle()
                    }
                }) {
                    Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(showLyrics ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.65))
                        .frame(width: 40, height: 40)
                        .background(showLyrics ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                        .clipShape(Circle())
                }

                // Like button
                Button(action: {
                    appVm.toggleLike(trackId: track.id)
                }) {
                    Image(systemName: appVm.isLiked(track.id) ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(appVm.isLiked(track.id) ? Color(red: 1.0, green: 0.42, blue: 0.54) : .white.opacity(0.65))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }

                // "Три точки" (More Menu)
                Menu {
                    Button(action: {
                        appVm.openPlaylistPicker(for: track)
                    }) {
                        Label("Добавить в плейлист...", systemImage: "text.badge.plus")
                    }

                    Button(action: {
                        if appVm.downloadManager.status(for: track.id) == .done {
                            appVm.downloadManager.removeDownload(trackId: track.id)
                        } else {
                            appVm.downloadManager.downloadTrack(track)
                        }
                    }) {
                        if appVm.downloadManager.status(for: track.id) == .done {
                            Label("Удалить из загрузок", systemImage: "trash")
                        } else {
                            Label("Скачать трек", systemImage: "arrow.down.circle")
                        }
                    }

                    if let album = appVm.albumForTrack(track) {
                        Button(action: {
                            dismiss()
                            appVm.currentScreen = .library
                            appVm.selectedAlbum = album
                        }) {
                            Label("Перейти к альбому «\(album.title)»", systemImage: "opticaldisc")
                        }
                    }

                    if let shareUrl = URL(string: track.audioUrl) {
                        ShareLink(item: shareUrl) {
                            Label("Поделиться треком", systemImage: "square.and.arrow.up")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 28) // Generous margins from screen edges
    }

    // MARK: - Scrubber Slider Area
    private var scrubberSliderArea: some View {
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
                    .foregroundColor(.white.opacity(0.40))

                Spacer()

                Text(formatTime(duration))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Playback Controls Row
    private var playbackControlsRow: some View {
        HStack(spacing: 24) {
            // Shuffle
            Button(action: { player.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.isShuffled ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.4))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Previous
            Button(action: { player.playPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            // Play / Pause (Large)
            Button(action: { player.togglePlayPause() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.black)
                    .frame(width: 68, height: 68)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.2), radius: 10, x: 0, y: 5)
            }

            // Next
            Button(action: { player.playNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Repeat
            Button(action: { player.toggleRepeat() }) {
                Image(systemName: "repeat")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(player.isRepeating ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.4))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 36)
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

private extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        min(max(self, limits.lowerBound), limits.upperBound)
    }
}

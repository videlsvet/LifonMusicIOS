import SwiftUI

public struct FullPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var appVm = AppViewModel.shared
    @StateObject private var lyricsVm = LyricsViewModel()

    @State private var showLyrics: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0.0

    // Dismiss gesture
    @GestureState private var dismissDragY: CGFloat = 0
    @State private var dismissedY: CGFloat = 0

    // Carousel gesture
    @GestureState private var carouselDragX: CGFloat = 0
    @State private var carouselCommittedX: CGFloat = 0  // 0 normally, snaps to ±1 when track changes

    // Если true — идёт финальная анимация смены трека
    @State private var isChangingTrack: Bool = false

    public init() {}

    // Итоговое смещение вниз при свайпе закрытия
    private var totalDismissY: CGFloat {
        max(0, dismissDragY + dismissedY)
    }

    // Прозрачность плеера при свайпе вниз
    private var playerOpacity: Double {
        let raw = 1.0 - Double(totalDismissY / 500.0)
        return max(0.0, min(1.0, raw))
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                // Фон — немного прозрачный при свайпе, чтобы было видно что позади
                Color(red: 0.05, green: 0.05, blue: 0.06)
                    .opacity(playerOpacity)
                    .ignoresSafeArea()

                RadialGradient(
                    gradient: Gradient(colors: [player.playerGlowColor.opacity(0.38), Color.clear]),
                    center: .top,
                    startRadius: 40,
                    endRadius: 440
                )
                .opacity(playerOpacity)
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    topHeaderBar
                        .padding(.top, geo.safeAreaInsets.top > 0 ? geo.safeAreaInsets.top + 4 : 16)

                    Spacer(minLength: 12)

                    // Обложка или текст
                    if showLyrics {
                        LyricsOverlayView(lyricsVm: lyricsVm) { seekMs in
                            player.seek(to: seekMs)
                        }
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                    } else {
                        coverCarouselArea(geo: geo)
                            .transition(.opacity)
                    }

                    Spacer(minLength: 20)

                    if let track = player.currentTrack {
                        VStack(spacing: 20) {
                            trackInfoAndMenuRow(track: track, geo: geo)
                            scrubberSliderArea(geo: geo)
                            playbackControlsRow(geo: geo)
                        }
                        .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? geo.safeAreaInsets.bottom + 4 : 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .offset(y: totalDismissY)
            .opacity(playerOpacity)
            // Жест закрытия (свайп вниз) — работает только по вертикали
            .gesture(
                dismissGesture
            )
        }
        .ignoresSafeArea()
        .sheet(isPresented: $appVm.showEqualizer) {
            EqualizerSheet()
        }
        .sheet(isPresented: $appVm.showPlaylistPickerSheet) {
            PlaylistPickerSheet(track: appVm.playlistPickerTrack)
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
            // При смене трека сбрасываем смещение карусели
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                carouselCommittedX = 0
            }
            isChangingTrack = false
        }
    }

    // MARK: - Dismiss Gesture

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .updating($dismissDragY) { value, state, _ in
                // Только если движение преимущественно вертикальное вниз
                let isVertical = abs(value.translation.height) > abs(value.translation.width)
                if isVertical && value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onEnded { value in
                let isVertical = abs(value.translation.height) > abs(value.translation.width)
                let bigEnough = value.translation.height > 100 || value.predictedEndTranslation.height > 250
                if isVertical && bigEnough {
                    // Закрываем плеер
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        appVm.showFullPlayer = false
                    }
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dismissedY = 0
                    }
                }
            }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(Color.white.opacity(0.22))
                .frame(width: 34, height: 4)

            HStack(spacing: 0) {
                // Кнопка закрытия
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        appVm.showFullPlayer = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }

                Spacer()

                // Центр: название альбома
                if let track = player.currentTrack, let album = appVm.albumForTrack(track) {
                    Button(action: {
                        withAnimation {
                            appVm.showFullPlayer = false
                        }
                        appVm.currentScreen = .library
                        appVm.selectedAlbum = album
                    }) {
                        VStack(spacing: 2) {
                            Text(player.playContext == .wave ? "ИГРАЕТ ВОЛНА" : "ИГРАЕТ ИЗ ДИСКОГРАФИИ")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.40))
                                .tracking(1.0)

                            Text(album.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Эквалайзер
                Button(action: { appVm.showEqualizer = true }) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Cover Carousel with "Ears"

    @ViewBuilder
    private func coverCarouselArea(geo: GeometryProxy) -> some View {
        let hPad: CGFloat = 40
        let cardSize = min(geo.size.width - hPad * 2, geo.size.height * 0.40)
        let stepWidth = cardSize + 24

        ZStack {
            if let prev = player.previousTrack {
                coverCard(track: prev, size: cardSize, slotX: -stepWidth, stepWidth: stepWidth)
            }
            if let next = player.nextTrack {
                coverCard(track: next, size: cardSize, slotX: stepWidth, stepWidth: stepWidth)
            }
            if let current = player.currentTrack {
                coverCard(track: current, size: cardSize, slotX: 0, stepWidth: stepWidth)
            }
        }
        .frame(width: geo.size.width, height: cardSize + 20)
        .clipped()
        // Горизонтальный жест карусели — отдельный от вертикального dismiss
        .gesture(carouselGesture(stepWidth: stepWidth))
    }

    private func carouselGesture(stepWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .updating($carouselDragX) { value, state, _ in
                // Только горизонтальные свайпы
                if !isChangingTrack && abs(value.translation.width) > abs(value.translation.height) {
                    state = value.translation.width * 0.88
                }
            }
            .onEnded { value in
                guard !isChangingTrack else { return }
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                guard isHorizontal else { return }

                let threshold: CGFloat = 55
                let velocity = value.predictedEndTranslation.width

                if (value.translation.width < -threshold || velocity < -180) && player.nextTrack != nil {
                    isChangingTrack = true
                    player.playNext()
                } else if (value.translation.width > threshold || velocity > 180) && player.previousTrack != nil {
                    isChangingTrack = true
                    player.playPrevious()
                }
                // Если не сменили трек — карусель вернётся сама через GestureState
            }
    }

    private func coverCard(track: Track, size: CGFloat, slotX: CGFloat, stepWidth: CGFloat) -> some View {
        let dragOffset = carouselDragX
        let totalOffset = slotX + dragOffset
        let normalizedDist = (totalOffset / stepWidth).clamped(to: -1.5...1.5)
        let absNorm = abs(normalizedDist)

        let isCenter = (slotX == 0)
        let scale: CGFloat = isCenter
            ? (1.0 - absNorm * 0.10).clamped(to: 0.88...1.0)
            : (0.86 + (1.0 - absNorm.clamped(to: 0...1)) * 0.14)
        let alpha: Double = isCenter
            ? (1.0 - Double(absNorm) * 0.55).clamped(to: 0.3...1.0)
            : (0.38 + (1.0 - Double(absNorm.clamped(to: 0...1))) * 0.62)

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
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(
            color: isCenter ? player.playerGlowColor.opacity(0.32) : .black.opacity(0.28),
            radius: isCenter ? 22 : 8,
            x: 0,
            y: isCenter ? 10 : 4
        )
        .scaleEffect(scale)
        .opacity(alpha)
        .offset(x: totalOffset)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.78, blendDuration: 0.1), value: dragOffset)
    }

    // MARK: - Track Info & Three-Dots Menu

    private func trackInfoAndMenuRow(track: Track, geo: GeometryProxy) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Название трека + артист
            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(track.displayArtist)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.52))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Кнопки: лайк, текст, ещё
            HStack(spacing: 6) {
                // Тексты
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showLyrics.toggle()
                    }
                }) {
                    Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(showLyrics ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.6))
                        .frame(width: 38, height: 38)
                        .background(showLyrics ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                        .clipShape(Circle())
                }

                // Лайк
                Button(action: { appVm.toggleLike(trackId: track.id) }) {
                    Image(systemName: appVm.isLiked(track.id) ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(appVm.isLiked(track.id) ? Color(red: 1.0, green: 0.42, blue: 0.54) : .white.opacity(0.6))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }

                // Три точки — меню
                Menu {
                    Button(action: { appVm.openPlaylistPicker(for: track) }) {
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
                            withAnimation { appVm.showFullPlayer = false }
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
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Scrubber Slider

    private func scrubberSliderArea(geo: GeometryProxy) -> some View {
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
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.38))

                Spacer()

                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.38))
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Playback Controls Row

    private func playbackControlsRow(geo: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Shuffle
            Button(action: { player.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(player.isShuffled ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.38))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Назад
            Button(action: { player.playPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer(minLength: 12)

            // Пауза / Воспроизведение
            Button(action: { player.togglePlayPause() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.black)
                    .frame(width: 64, height: 64)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.18), radius: 10, x: 0, y: 4)
            }

            Spacer(minLength: 12)

            // Вперёд
            Button(action: { player.playNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Повтор
            Button(action: { player.toggleRepeat() }) {
                Image(systemName: "repeat")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(player.isRepeating ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.38))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Helpers

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.18))
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

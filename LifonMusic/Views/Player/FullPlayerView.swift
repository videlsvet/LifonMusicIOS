import SwiftUI

public struct FullPlayerView: View {
    @ObservedObject var player = AudioPlayerService.shared
    @ObservedObject var appVm = AppViewModel.shared
    @StateObject private var lyricsVm = LyricsViewModel()

    @State private var showLyrics: Bool = false
    @State private var isDraggingSlider: Bool = false
    @State private var dragSliderValue: Double = 0.0

    // Gestures state
    @State private var dismissOffset: CGFloat = 0
    @State private var carouselOffset: CGFloat = 0
    @State private var activeDragDirection: DragDirection = .none
    @State private var isTransitioningTrack: Bool = false

    private enum DragDirection {
        case none
        case vertical
        case horizontal
    }

    public init() {}

    // Итоговое вертикальное смещение при свайпе вниз
    private var totalDismissY: CGFloat {
        max(0, dismissOffset)
    }

    public var body: some View {
        GeometryReader { geo in
            let topSafeArea = geo.safeAreaInsets.top
            let bottomSafeArea = geo.safeAreaInsets.bottom

            // Точные отступы под iOS / Apple Music:
            // Верхние элементы чуть ниже (отступ от Dynamic Island / Notch)
            let topPadding: CGFloat = topSafeArea > 0 ? topSafeArea + 14 : 28
            // Нижние элементы чуть выше (отступ от Home Indicator)
            let bottomPadding: CGFloat = bottomSafeArea > 0 ? bottomSafeArea + 22 : 38

            // Размер обложки: аккуратный, с "ушками" по бокам
            let cardWidth = min(geo.size.width - 80, geo.size.height * 0.38, 330)
            let stepWidth = cardWidth + 22

            ZStack {
                // Подложка: плавное затемнение контента сзади при свайпе
                Color.black
                    .opacity(max(0.0, 0.40 * (1.0 - Double(totalDismissY / 400.0))))
                    .ignoresSafeArea()

                // Основное тело карточки плеера
                ZStack {
                    // Фоновый цвет плеера
                    Color(red: 0.05, green: 0.05, blue: 0.06)

                    // Мягкое цветное свечение в тон обложки трека
                    RadialGradient(
                        gradient: Gradient(colors: [player.playerGlowColor.opacity(0.38), Color.clear]),
                        center: .top,
                        startRadius: 40,
                        endRadius: 460
                    )

                    VStack(spacing: 0) {
                        // Верхняя панель: хэндл + шеврон + название альбома + эквалайзер
                        topHeaderBar
                            .padding(.top, topPadding)
                            .gesture(dismissGesture)

                        Spacer(minLength: 14)

                        // Центральная часть: Карусель обложек с ушками ИЛИ текст песни
                        if showLyrics {
                            LyricsOverlayView(lyricsVm: lyricsVm) { seekMs in
                                player.seek(to: seekMs)
                            }
                            .frame(maxHeight: .infinity)
                            .transition(.opacity)
                        } else {
                            coverCarouselArea(cardSize: cardWidth, stepWidth: stepWidth, viewWidth: geo.size.width)
                                .transition(.opacity)
                        }

                        Spacer(minLength: 18)

                        // Нижняя часть: информация о треке, скраббер, кнопки управления
                        if let track = player.currentTrack {
                            VStack(spacing: 22) {
                                trackInfoAndMenuRow(track: track)
                                scrubberSliderArea
                                playbackControlsRow
                            }
                            .padding(.bottom, bottomPadding)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .clipShape(
                    RoundedRectangle(cornerRadius: totalDismissY > 0 ? 36 : 0, style: .continuous)
                )
                .shadow(color: Color.black.opacity(totalDismissY > 0 ? 0.35 : 0), radius: 24, x: 0, y: -4)
                .offset(y: totalDismissY)
            }
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
        }
    }

    // MARK: - Gestures: Dismiss Gesture (Header Area)

    private var dismissGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                if value.translation.height > 0 {
                    dismissOffset = value.translation.height
                }
            }
            .onEnded { value in
                handleDismissEnd(value: value)
            }
    }

    private func handleDismissEnd(value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.height
        if dismissOffset > 110 || velocity > 260 {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                dismissOffset = 900
                appVm.showFullPlayer = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                dismissOffset = 0
                activeDragDirection = .none
            }
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                dismissOffset = 0
            }
            activeDragDirection = .none
        }
    }

    // MARK: - Top Header Bar

    private var topHeaderBar: some View {
        VStack(spacing: 8) {
            // Индикатор свайпа (Grabber Capsule)
            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 38, height: 4.5)
                .padding(.bottom, 6)

            HStack(spacing: 0) {
                // Кнопка закрытия (Шеврон вниз)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
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

                // Название альбома / контекста
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

                // Кнопка эквалайзера
                Button(action: { appVm.showEqualizer = true }) {
                    Image(systemName: "slider.vertical.3")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.07))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 22)
        }
    }

    // MARK: - Cover Carousel with "Ears" (Apple Music Style)

    @ViewBuilder
    private func coverCarouselArea(cardSize: CGFloat, stepWidth: CGFloat, viewWidth: CGFloat) -> some View {
        ZStack {
            // Предыдущий трек ("левое ушко")
            if let prev = player.previousTrack {
                coverCard(track: prev, size: cardSize, slotX: -stepWidth, stepWidth: stepWidth)
            }

            // Следующий трек ("правое ушко")
            if let next = player.nextTrack {
                coverCard(track: next, size: cardSize, slotX: stepWidth, stepWidth: stepWidth)
            }

            // Текущий трек по центру
            if let current = player.currentTrack {
                coverCard(track: current, size: cardSize, slotX: 0, stepWidth: stepWidth)
            }
        }
        .frame(width: viewWidth, height: cardSize + 22)
        .clipped()
        .contentShape(Rectangle())
        .gesture(carouselUnifiedGesture(stepWidth: stepWidth))
    }

    // Унифицированный жест для обложки: отличает вертикальный свайп вниз от горизонтального свайпа трека
    private func carouselUnifiedGesture(stepWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !isTransitioningTrack else { return }

                let dx = value.translation.width
                let dy = value.translation.height

                // Определение направления свайпа в начале движения
                if activeDragDirection == .none {
                    if abs(dy) > abs(dx) && dy > 6 {
                        activeDragDirection = .vertical
                    } else if abs(dx) > abs(dy) && abs(dx) > 6 && !showLyrics {
                        activeDragDirection = .horizontal
                    }
                }

                if activeDragDirection == .vertical {
                    dismissOffset = max(0, dy)
                } else if activeDragDirection == .horizontal {
                    // Упругое сопротивление, если следующего/предыдущего трека нет
                    if dx < 0 && player.nextTrack == nil {
                        carouselOffset = dx * 0.22
                    } else if dx > 0 && player.previousTrack == nil {
                        carouselOffset = dx * 0.22
                    } else {
                        carouselOffset = dx
                    }
                }
            }
            .onEnded { value in
                guard !isTransitioningTrack else { return }

                if activeDragDirection == .vertical {
                    handleDismissEnd(value: value)
                } else if activeDragDirection == .horizontal {
                    let threshold = stepWidth * 0.22
                    let velocity = value.predictedEndTranslation.width

                    // Свайп влево — переход к следующему треку
                    if (carouselOffset < -threshold || velocity < -200) && player.nextTrack != nil {
                        isTransitioningTrack = true
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            carouselOffset = -stepWidth
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            player.playNext()
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                carouselOffset = 0
                                activeDragDirection = .none
                                isTransitioningTrack = false
                            }
                        }
                    // Свайп вправо — переход к предыдущему треку
                    } else if (carouselOffset > threshold || velocity > 200) && player.previousTrack != nil {
                        isTransitioningTrack = true
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.86)) {
                            carouselOffset = stepWidth
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.24) {
                            player.playPrevious(force: true)
                            var transaction = Transaction()
                            transaction.disablesAnimations = true
                            withTransaction(transaction) {
                                carouselOffset = 0
                                activeDragDirection = .none
                                isTransitioningTrack = false
                            }
                        }
                    // Возврат на место (недостаточный свайп)
                    } else {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            carouselOffset = 0
                        }
                        activeDragDirection = .none
                    }
                } else {
                    activeDragDirection = .none
                }
            }
    }

    private func coverCard(track: Track, size: CGFloat, slotX: CGFloat, stepWidth: CGFloat) -> some View {
        let totalOffset = slotX + carouselOffset
        let normalizedDist = (totalOffset / stepWidth).clamped(to: -1.5...1.5)
        let absNorm = abs(normalizedDist)

        // Непрерывная плавная интерполяция масштаба, прозрачности и тени
        let currentScale = (1.0 - absNorm * 0.14).clamped(to: 0.86...1.0)
        let currentAlpha = (1.0 - Double(absNorm) * 0.58).clamped(to: 0.38...1.0)
        let glowAlpha = max(0.0, 0.34 * (1.0 - Double(absNorm)))
        let shadowRadius = max(4.0, 22.0 * (1.0 - absNorm))
        let shadowY = max(2.0, 10.0 * (1.0 - absNorm))

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
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(
            color: player.playerGlowColor.opacity(glowAlpha),
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .scaleEffect(currentScale)
        .opacity(currentAlpha)
        .offset(x: totalOffset)
        .id(track.id)
    }

    // MARK: - Track Info & Three-Dots Menu

    private func trackInfoAndMenuRow(track: Track) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Название трека и артист
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 21, weight: .black))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(track.displayArtist)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.2), value: track.id)

            // Кнопки справа: текст песни, лайк, три точки
            HStack(spacing: 8) {
                // Текст песни (Lyrics)
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        showLyrics.toggle()
                    }
                }) {
                    Image(systemName: showLyrics ? "quote.bubble.fill" : "quote.bubble")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(showLyrics ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.65))
                        .frame(width: 40, height: 40)
                        .background(showLyrics ? Color.white.opacity(0.12) : Color.white.opacity(0.05))
                        .clipShape(Circle())
                }

                // Лайк (Избранное)
                Button(action: { appVm.toggleLike(trackId: track.id) }) {
                    Image(systemName: appVm.isLiked(track.id) ? "heart.fill" : "heart")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(appVm.isLiked(track.id) ? Color(red: 1.0, green: 0.42, blue: 0.54) : .white.opacity(0.65))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }

                // Меню "Три точки"
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
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 24)
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
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.40))

                Spacer()

                Text(formatTime(duration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Playback Controls Row

    private var playbackControlsRow: some View {
        HStack(spacing: 0) {
            // Перемешивание (Shuffle)
            Button(action: { player.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(player.isShuffled ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.40))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Предыдущий трек (Назад)
            Button(action: { player.playPrevious() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer(minLength: 12)

            // Пауза / Воспроизведение (Большая кнопка)
            Button(action: { player.togglePlayPause() }) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.black)
                    .frame(width: 66, height: 66)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.20), radius: 10, x: 0, y: 4)
            }

            Spacer(minLength: 12)

            // Следующий трек (Вперед)
            Button(action: { player.playNext() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Повтор (Repeat)
            Button(action: { player.toggleRepeat() }) {
                Image(systemName: "repeat")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(player.isRepeating ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.40))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Helpers

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.07))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 46))
                    .foregroundColor(.white.opacity(0.20))
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

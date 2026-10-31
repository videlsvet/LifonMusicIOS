import SwiftUI

public struct LyricsOverlayView: View {
    @ObservedObject var lyricsVm: LyricsViewModel
    public let onSeek: (Int64) -> Void

    public init(lyricsVm: LyricsViewModel, onSeek: @escaping (Int64) -> Void) {
        self.lyricsVm = lyricsVm
        self.onSeek = onSeek
    }

    public var body: some View {
        if lyricsVm.isLoading {
            VStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                Text("Загрузка текста...")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 10)
                Spacer()
            }
        } else if lyricsVm.lines.isEmpty {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "quote.bubble")
                    .font(.system(size: 44))
                    .foregroundColor(.white.opacity(0.2))
                Text("Для этого трека пока нет текста")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
            }
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        Spacer(minLength: 40)

                        ForEach(Array(lyricsVm.lines.enumerated()), id: \.element.id) { index, line in
                            let isActive = (lyricsVm.activeLineIndex == index)

                            Button(action: {
                                onSeek(line.timeMs)
                            }) {
                                Text(line.text)
                                    .font(.system(size: isActive ? 22 : 17, weight: isActive ? .black : .semibold))
                                    .foregroundColor(isActive ? .white : .white.opacity(0.35))
                                    .scaleEffect(isActive ? 1.02 : 1.0, anchor: .leading)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isActive)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .multilineTextAlignment(.leading)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 24)
                }
                .onChange(of: lyricsVm.activeLineIndex) { newIndex in
                    if let idx = newIndex {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            proxy.scrollTo(idx, anchor: .center)
                        }
                    }
                }
            }
        }
    }
}

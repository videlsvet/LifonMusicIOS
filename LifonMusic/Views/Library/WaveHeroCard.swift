import SwiftUI

public struct WaveHeroCard: View {
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared

    public init() {}

    private var isWavePlaying: Bool {
        appVm.isWaveActive && player.isPlaying
    }

    public var body: some View {
        Button(action: {
            Task {
                await appVm.toggleWave()
            }
        }) {
            ZStack {
                // Background Card
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.06, green: 0.06, blue: 0.08))

                // Embedded Vibe Wave Visualizer
                VibeWaveCanvas(isPlaying: isWavePlaying)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Content
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(isWavePlaying ? Color(red: 0.75, green: 0.52, blue: 0.99) : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .scaleEffect(isWavePlaying ? 1.25 : 1.0)
                                .animation(
                                    isWavePlaying ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .default,
                                    value: isWavePlaying
                                )

                            Text("ПОДБОРКА ПО ВРЕМЕНИ ГОДА")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white.opacity(0.75))
                                .tracking(1.5)
                        }

                        Text("Волна")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)

                        Text("Поток треков по вайбу времени года")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Play/Pause Action Bubble
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )

                        if appVm.isLoadingWave {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: isWavePlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .offset(x: isWavePlaying ? 0 : 1.5)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .frame(height: 110)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        appVm.isWaveActive
                            ? Color.white.opacity(0.6)
                            : Color(red: 0.75, green: 0.52, blue: 0.99).opacity(0.35),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.35), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
}

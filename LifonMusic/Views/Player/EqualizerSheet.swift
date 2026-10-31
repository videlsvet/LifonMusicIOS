import SwiftUI

public struct EqualizerSheet: View {
    @ObservedObject var eq = EqualizerService.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Эквалайзер")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button("Сброс") {
                        eq.resetAll()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())

                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.leading, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Presets Horizontal Scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(eq.presets) { preset in
                            let isSelected = (eq.selectedPreset == preset.name)
                            Button(action: {
                                eq.applyPreset(preset)
                            }) {
                                Text(preset.name)
                                    .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                    .foregroundColor(isSelected ? .black : .white.opacity(0.8))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Color.white : Color.white.opacity(0.08))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // 5 Bands Sliders
                VStack(spacing: 16) {
                    ForEach(0..<eq.bandFrequencies.count, id: \.self) { band in
                        VStack(spacing: 4) {
                            HStack {
                                Text(eq.bandLabels[band])
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))

                                Spacer()

                                let gain = eq.bandGains[band]
                                Text(String(format: "%+.1f дБ", gain))
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.45))
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(eq.bandGains[band]) },
                                    set: { eq.setGain(band: band, gainDb: Float($0)) }
                                ),
                                in: -12.0...12.0,
                                step: 0.5
                            )
                            .accentColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 20)
            }
        }
    }
}

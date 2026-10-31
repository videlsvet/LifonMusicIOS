import Foundation
import AVFoundation

public struct EqualizerPreset: Identifiable, Equatable {
    public var id: String { name }
    public let name: String
    public let gainsDb: [Float] // 5 frequencies
}

public final class EqualizerService: ObservableObject {
    public static let shared = EqualizerService()

    public let bandFrequencies: [Float] = [60, 230, 910, 3600, 14000]
    public let bandLabels: [String] = ["60 Гц", "230 Гц", "910 Гц", "3.6 кГц", "14 кГц"]

    public let presets: [EqualizerPreset] = [
        EqualizerPreset(name: "Плоский", gainsDb: [0, 0, 0, 0, 0]),
        EqualizerPreset(name: "Бас", gainsDb: [8.0, 5.0, 0.0, -2.0, -3.0]),
        EqualizerPreset(name: "Вокал", gainsDb: [-3.0, 0.0, 5.0, 4.0, 0.0]),
        EqualizerPreset(name: "Рок", gainsDb: [5.0, 2.0, -3.0, 2.0, 5.0]),
        EqualizerPreset(name: "Поп", gainsDb: [-1.0, 3.0, 5.0, 3.0, -1.0]),
        EqualizerPreset(name: "Джаз", gainsDb: [3.0, 0.0, 2.0, 0.0, 3.0])
    ]

    @Published public var selectedPreset: String? = "Плоский"
    @Published public var bandGains: [Float] = [0, 0, 0, 0, 0] // Range: -12.0 ... +12.0 dB

    private let prefsKey = "eq_bands_levels"
    private let presetKey = "eq_selected_preset"

    public var avAudioUnitEQ: AVAudioUnitEQ?

    private init() {
        setupAudioUnitEQ()
        loadSavedLevels()
    }

    private func setupAudioUnitEQ() {
        let eq = AVAudioUnitEQ(numberOfBands: bandFrequencies.count)
        for (i, freq) in bandFrequencies.enumerated() {
            let band = eq.bands[i]
            band.frequency = freq
            band.bandwidth = 1.0
            band.filterType = (i == 0) ? .lowShelf : (i == bandFrequencies.count - 1 ? .highShelf : .parametric)
            band.gain = bandGains[i]
            band.bypass = false
        }
        self.avAudioUnitEQ = eq
    }

    public func setGain(band: Int, gainDb: Float) {
        guard band >= 0 && band < bandGains.count else { return }
        bandGains[band] = min(max(gainDb, -12.0), 12.0)
        selectedPreset = nil

        if let eq = avAudioUnitEQ, band < eq.bands.count {
            eq.bands[band].gain = bandGains[band]
        }
        saveLevels()
    }

    public func applyPreset(_ preset: EqualizerPreset) {
        selectedPreset = preset.name
        bandGains = preset.gainsDb
        if let eq = avAudioUnitEQ {
            for (i, gain) in preset.gainsDb.enumerated() where i < eq.bands.count {
                eq.bands[i].gain = gain
            }
        }
        saveLevels()
    }

    public func resetAll() {
        if let flat = presets.first(where: { $0.name == "Плоский" }) {
            applyPreset(flat)
        } else {
            bandGains = [0, 0, 0, 0, 0]
            selectedPreset = "Плоский"
            saveLevels()
        }
    }

    private func saveLevels() {
        UserDefaults.standard.set(bandGains, forKey: prefsKey)
        UserDefaults.standard.set(selectedPreset, forKey: presetKey)
    }

    private func loadSavedLevels() {
        if let saved = UserDefaults.standard.array(forKey: prefsKey) as? [Float], saved.count == 5 {
            self.bandGains = saved
            self.selectedPreset = UserDefaults.standard.string(forKey: presetKey)
            if let eq = avAudioUnitEQ {
                for (i, gain) in saved.enumerated() where i < eq.bands.count {
                    eq.bands[i].gain = gain
                }
            }
        }
    }
}

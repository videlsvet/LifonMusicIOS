import Foundation
import SwiftUI
import Combine

@MainActor
public final class LyricsViewModel: ObservableObject {
    @Published public private(set) var lines: [LyricsLine] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var activeLineIndex: Int?

    private var currentTrackId: Int?
    private var cancellables = Set<AnyCancellable>()

    public init() {
        // Observe player time updates
        AudioPlayerService.shared.$currentTimeMs
            .receive(on: RunLoop.main)
            .sink { [weak self] currentMs in
                self?.updateActiveLine(currentMs: currentMs)
            }
            .store(in: &cancellables)
    }

    public func loadLyrics(for trackId: Int) {
        guard currentTrackId != trackId else { return }
        self.currentTrackId = trackId
        self.lines = []
        self.activeLineIndex = nil
        self.isLoading = true

        Task {
            let loaded = await LyricsService.shared.getLyrics(for: trackId)
            await MainActor.run {
                if self.currentTrackId == trackId {
                    self.lines = loaded ?? []
                    self.isLoading = false
                    self.updateActiveLine(currentMs: AudioPlayerService.shared.currentTimeMs)
                }
            }
        }
    }

    private func updateActiveLine(currentMs: Int64) {
        guard !lines.isEmpty else {
            activeLineIndex = nil
            return
        }

        var foundIndex: Int? = nil
        for (i, line) in lines.enumerated() {
            if currentMs >= line.timeMs {
                foundIndex = i
            } else {
                break
            }
        }

        if activeLineIndex != foundIndex {
            activeLineIndex = foundIndex
        }
    }
}

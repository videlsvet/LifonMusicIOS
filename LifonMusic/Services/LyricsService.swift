import Foundation

public enum LrcParser {
    // Поддержка [MM:SS.xx], [MM:SS.xxx], [MM:SS:xx]
    private static let timePattern = try? NSRegularExpression(pattern: #"\[(\d{2}):(\d{2})[.:](\d{2,3})\]"#)

    public static func parse(_ text: String) -> [LyricsLine] {
        let lines = text.components(separatedBy: .newlines)
        var result: [LyricsLine] = []

        guard let regex = timePattern else { return [] }

        for rawLine in lines {
            let nsLine = rawLine as NSString
            let fullRange = NSRange(location: 0, length: nsLine.length)
            guard let match = regex.firstMatch(in: rawLine, range: fullRange) else { continue }

            if match.numberOfRanges >= 4 {
                let minStr = nsLine.substring(with: match.range(at: 1))
                let secStr = nsLine.substring(with: match.range(at: 2))
                let msStr = nsLine.substring(with: match.range(at: 3))

                let min = Int64(minStr) ?? 0
                let sec = Int64(secStr) ?? 0
                let msMultiplier: Int64 = (msStr.count == 2) ? 10 : 1
                let ms = (Int64(msStr) ?? 0) * msMultiplier

                let timeMs = min * 60_000 + sec * 1_000 + ms

                let textRange = NSRange(location: match.range.location + match.range.length, length: nsLine.length - (match.range.location + match.range.length))
                let text = nsLine.substring(with: textRange).trimmingCharacters(in: .whitespacesAndNewlines)

                if !text.isEmpty {
                    result.append(LyricsLine(timeMs: timeMs, text: text))
                }
            }
        }

        return result.sorted { $0.timeMs < $1.timeMs }
    }

    public static func parseAny(_ text: String) -> [LyricsLine]? {
        let timed = parse(text)
        if !timed.isEmpty { return timed }

        let plain = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if plain.isEmpty { return nil }

        // Plain lines without timecodes: 3s step
        return plain.enumerated().map { i, line in
            LyricsLine(timeMs: Int64(i) * 3_000, text: line)
        }
    }
}

public final class LyricsService {
    public static let shared = LyricsService()
    private var memoryCache: [Int: [LyricsLine]] = [:]
    private let queue = DispatchQueue(label: "com.lifon.music.lyricsCache")

    private init() {}

    public func getLyrics(for trackId: Int) async -> [LyricsLine]? {
        var cached: [LyricsLine]?
        queue.sync { cached = memoryCache[trackId] }
        if let cached = cached { return cached }

        // 1. Check bundled asset
        if let bundled = loadBundledLyrics(trackId: trackId) {
            queue.sync { memoryCache[trackId] = bundled }
            return bundled
        }

        // 2. Fetch from backend API
        if let remoteText = await ApiClient.shared.fetchRemoteLyrics(trackId: trackId),
           let parsed = LrcParser.parseAny(remoteText) {
            queue.sync { memoryCache[trackId] = parsed }
            return parsed
        }

        return nil
    }

    private func loadBundledLyrics(trackId: Int) -> [LyricsLine]? {
        let candidateNames = ["\(trackId)", "\(trackId).lrc", "\(trackId).txt"]
        for name in candidateNames {
            if let url = Bundle.main.url(forResource: name, withExtension: (name.contains(".") ? nil : "lrc"), subdirectory: "Lyrics") ??
                         Bundle.main.url(forResource: name, withExtension: (name.contains(".") ? nil : "lrc")) {
                if let data = try? Data(contentsOf: url),
                   let text = String(data: data, encoding: .utf8) {
                    return LrcParser.parseAny(text)
                }
            }
        }
        return nil
    }
}

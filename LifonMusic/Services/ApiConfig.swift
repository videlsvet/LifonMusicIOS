import Foundation

public enum ApiConfig {
    public static let base = "https://lifonmusic.lol/api"
    public static let siteOrigin: String = {
        let baseStr = base
        if let range = baseStr.range(of: "/api") {
            return String(baseStr[..<range.lowerBound])
        }
        return baseStr.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }()

    public static func toAbsoluteUrl(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty,
              raw != "null" else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
            return raw
        }
        if raw.hasPrefix("/") {
            return "\(siteOrigin)\(raw)"
        }
        return "\(siteOrigin)/\(raw)"
    }
}

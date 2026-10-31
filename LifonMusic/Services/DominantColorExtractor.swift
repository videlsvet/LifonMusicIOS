import UIKit
import SwiftUI
import CoreImage

public enum DominantColorExtractor {
    private static var colorCache: [String: Color] = [:]
    private static let lock = NSLock()

    public static let fallbackColor = Color(red: 0.165, green: 0.114, blue: 0.227) // #2A1D3A

    public static func color(from hex: String?) -> Color? {
        guard let hex = hex?.trimmingCharacters(in: CharacterSet.alphanumerics.inverted),
              hex.count == 6,
              let intVal = UInt64(hex, radix: 16) else { return nil }
        let r = Double((intVal >> 16) & 0xFF) / 255.0
        let g = Double((intVal >> 8) & 0xFF) / 255.0
        let b = Double(intVal & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    public static func extractDominantColor(from urlString: String?, glowColorHex: String? = nil) async -> Color {
        if let glowHex = glowColorHex, let color = color(from: glowHex) {
            return color
        }

        guard let urlString = urlString, let url = URL(string: urlString) else {
            return fallbackColor
        }

        lock.lock()
        if let cached = colorCache[urlString] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), let ciImage = CIImage(image: image) else {
                return fallbackColor
            }

            let extentVector = CIVector(x: ciImage.extent.origin.x,
                                       y: ciImage.extent.origin.y,
                                       z: ciImage.extent.size.width,
                                       w: ciImage.extent.size.height)
            guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: ciImage, kCIInputExtentKey: extentVector]),
                  let outputImage = filter.outputImage else {
                return fallbackColor
            }

            var bitmap = [UInt8](repeating: 0, count: 4)
            let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
            context.render(outputImage,
                           toBitmap: &bitmap,
                           rowBytes: 4,
                           bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: nil)

            let r = Double(bitmap[0]) / 255.0
            let g = Double(bitmap[1]) / 255.0
            let b = Double(bitmap[2]) / 255.0

            // Ensure not too bright for player background
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let finalColor: Color
            if luminance > 0.65 {
                finalColor = Color(red: r * 0.5, green: g * 0.5, blue: b * 0.5)
            } else {
                finalColor = Color(red: max(r, 0.1), green: max(g, 0.1), blue: max(b, 0.1))
            }

            lock.lock()
            colorCache[urlString] = finalColor
            lock.unlock()

            return finalColor
        } catch {
            return fallbackColor
        }
    }
}

import SwiftUI

public struct VibeWaveCanvas: View {
    public let isPlaying: Bool
    public var accentColor: Color = Color(red: 0.75, green: 0.52, blue: 0.99)

    public init(isPlaying: Bool, accentColor: Color = Color(red: 0.75, green: 0.52, blue: 0.99)) {
        self.isPlaying = isPlaying
        self.accentColor = accentColor
    }

    private let colors = [
        Color(hue: 50.0 / 360.0, saturation: 1.0, brightness: 0.85),
        Color(hue: 330.0 / 360.0, saturation: 0.92, brightness: 0.82),
        Color(hue: 280.0 / 360.0, saturation: 0.88, brightness: 0.86)
    ]

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = (time.remainder(dividingBy: 12.0) / 12.0) * Double.pi * 2.0
                let energy: CGFloat = isPlaying ? 0.6 : 0.2
                let width = size.width
                let height = size.height
                guard width > 0, height > 0 else { return }

                let layerCenters: [CGFloat] = [height * 0.16, height * 0.45, height * 0.78]

                for (index, color) in colors.enumerated() {
                    let base = layerCenters[index]
                    let amplitude = height * (0.12 + energy * 0.10)
                    let frequency = 1.4 + CGFloat(index) * 0.35
                    let step = max(width / 28.0, 4.0)

                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: height))

                    var x: CGFloat = 0
                    while x <= width + step {
                        let normalized = x / width
                        let y = base
                            + sin(normalized * .pi * frequency + CGFloat(phase) * (0.8 + CGFloat(index) * 0.13)) * amplitude
                            + sin(normalized * .pi * (frequency * 2.2) - CGFloat(phase) * 0.65) * amplitude * 0.28
                        let clampedY = min(max(y, -height * 0.15), height * 1.1)
                        path.addLine(to: CGPoint(x: x, y: clampedY))
                        x += step
                    }

                    path.addLine(to: CGPoint(x: width, y: height))
                    path.closeSubpath()

                    let startGrad = base - height * 0.25
                    let endGrad = base + height * 0.65

                    let gradient = Gradient(colors: [
                        color.opacity(0.14 + Double(energy) * 0.12),
                        color.opacity(0.52 + Double(energy) * 0.18),
                        color.opacity(0.04)
                    ])

                    context.fill(
                        path,
                        with: .linearGradient(
                            gradient,
                            startPoint: CGPoint(x: width / 2, y: startGrad),
                            endPoint: CGPoint(x: width / 2, y: endGrad)
                        )
                    )

                    // Soft radial glow orb
                    let orbCenter = CGPoint(x: width * (0.25 + CGFloat(index) * 0.25), y: base)
                    let orbRadius = width * 0.55
                    let orbGrad = Gradient(colors: [
                        color.opacity(0.18 + Double(energy) * 0.16),
                        Color.clear
                    ])
                    let orbRect = CGRect(x: orbCenter.x - orbRadius, y: orbCenter.y - orbRadius, width: orbRadius * 2, height: orbRadius * 2)
                    context.fill(
                        Path(ellipseIn: orbRect),
                        with: .radialGradient(
                            orbGrad,
                            center: orbCenter,
                            startRadius: 0,
                            endRadius: orbRadius
                        )
                    )
                }
            }
        }
    }
}

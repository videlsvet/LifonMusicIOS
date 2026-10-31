import SwiftUI

public struct PlayingIndicatorDots: View {
    public var isPlaying: Bool = true
    @State private var animating = false

    public init(isPlaying: Bool = true) {
        self.isPlaying = isPlaying
    }

    public var body: some View {
        HStack(spacing: 2.5) {
            bar(delay: 0.0, height1: 6, height2: 15)
            bar(delay: 0.2, height1: 15, height2: 7)
            bar(delay: 0.4, height1: 8, height2: 17)
        }
        .frame(height: 18)
        .onAppear {
            animating = isPlaying
        }
        .onChange(of: isPlaying) { playing in
            animating = playing
        }
    }

    @ViewBuilder
    private func bar(delay: Double, height1: CGFloat, height2: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(Color(red: 0.91, green: 0.835, blue: 1.0)) // Primary accent
            .frame(width: 3, height: animating ? height2 : height1)
            .animation(
                animating ? Animation.easeInOut(duration: 0.45).repeatForever(autoreverses: true).delay(delay) : .default,
                value: animating
            )
    }
}

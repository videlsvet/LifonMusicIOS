import SwiftUI

public struct MaintenanceView: View {
    public let message: String
    public let onRetry: () -> Void

    public var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.05, blue: 0.06).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.system(size: 56))
                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))

                Text("Технические работы")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button(action: onRetry) {
                    Text("Попробовать снова")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 12)
            }
        }
    }
}

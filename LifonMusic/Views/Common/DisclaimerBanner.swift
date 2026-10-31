import SwiftUI

public struct DisclaimerBanner: View {
    public let onDismiss: () -> Void

    public var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🎧 LifonMUSIC")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.white)

                Text("Данное приложение является неофициальным некоммерческим фан-проектом, созданным для слушателей группы CUPSIZE.\n\nВсе права на музыкальные композиции, торговые марки и визуальные материалы принадлежат группе CUPSIZE и их правообладателям.")
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)

                Button(action: onDismiss) {
                    Text("Всё понятно")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color(red: 0.12, green: 0.12, blue: 0.14))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .padding(28)
        }
    }
}

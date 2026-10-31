import SwiftUI

public struct AchievementsSheet: View {
    @ObservedObject var appVm = AppViewModel.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Достижения")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(appVm.achievements) { ach in
                            let earned = appVm.myAchievements.first(where: { $0.id == ach.id })
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(earned != nil ? Color(red: 0.91, green: 0.835, blue: 1.0).opacity(0.15) : Color.white.opacity(0.05))
                                        .frame(width: 48, height: 48)

                                    Text(earned != nil ? "🏆" : "🔒")
                                        .font(.system(size: 22))
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ach.name)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(earned != nil ? .white : .white.opacity(0.4))

                                    Text(ach.description)
                                        .font(.system(size: 13))
                                        .foregroundColor(.white.opacity(0.5))

                                    if let earned = earned, earned.earnedAt > 0 {
                                        let date = Date(timeIntervalSince1970: Double(earned.earnedAt) / 1000.0)
                                        Text("Получено: \(formattedDate(date))")
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0).opacity(0.7))
                                            .padding(.top, 2)
                                    }
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

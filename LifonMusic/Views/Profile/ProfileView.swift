import SwiftUI

public struct ProfileView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @State private var showAchievementsSheet = false

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.035).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Title
                        Text("Профиль")
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // User Card
                        HStack(spacing: 16) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 0.91, green: 0.835, blue: 1.0), Color(red: 0.5, green: 0.35, blue: 0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 58, height: 58)
                                .overlay(
                                    Text(String(appVm.username?.prefix(1).uppercased() ?? "L"))
                                        .font(.system(size: 24, weight: .black))
                                        .foregroundColor(.black)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(appVm.username ?? "Гость")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)

                                Text(appVm.isAuthenticated ? "Слушатель CUPSIZE" : "Войди для синхронизации")
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            if appVm.isAuthenticated {
                                Button(action: { appVm.logout() }) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.5))
                                        .padding(10)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                            } else {
                                Button(action: { appVm.showAuth = true }) {
                                    Text("Войти")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 16)

                        // Stats Grid (if authenticated)
                        if appVm.isAuthenticated {
                            HStack(spacing: 12) {
                                // Listening Time
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text("🎧")
                                        Text("Прослушано")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                    let totalMin = (appVm.stats?.totalMs ?? 0) / 60_000
                                    let hours = totalMin / 60
                                    let mins = totalMin % 60
                                    Text(hours > 0 ? "\(hours) ч \(mins) мин" : "\(mins) мин")
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                                // Achievements Card
                                Button(action: { showAchievementsSheet = true }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("🏆")
                                            Text("Достижения")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                        Text("\(appVm.myAchievements.count) из \(max(appVm.achievements.count, 1))")
                                            .font(.system(size: 18, weight: .black, design: .rounded))
                                            .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(Color.white.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)

                            // Top Tracks
                            if let top = appVm.stats?.topTracks, !top.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Твой Топ треков")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)

                                    VStack(spacing: 6) {
                                        ForEach(Array(top.prefix(5).enumerated()), id: \.element.trackId) { idx, item in
                                            let track = appVm.allTracks.first(where: { $0.id == item.trackId })
                                            HStack(spacing: 12) {
                                                Text("#\(idx + 1)")
                                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                                    .foregroundColor(idx == 0 ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.4))
                                                    .frame(width: 28, alignment: .leading)

                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(track?.title ?? "Трек #\(item.trackId)")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                    Text("\(item.playCount) прослушиваний")
                                                        .font(.system(size: 12))
                                                        .foregroundColor(.white.opacity(0.4))
                                                }

                                                Spacer()
                                            }
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                        }
                                    }
                                    .background(Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Social Links & Community
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Сообщество & Ссылки")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)

                            VStack(spacing: 8) {
                                LinkRow(
                                    title: "Telegram-канал LifonMUSIC",
                                    subtitle: "Новости, апдейты и чат",
                                    icon: "paperplane.fill",
                                    iconBg: Color(red: 0.16, green: 0.54, blue: 0.86),
                                    url: "https://t.me/dangersharktt"
                                )

                                LinkRow(
                                    title: "Официальный сайт",
                                    subtitle: "lifonmusic.lol",
                                    icon: "globe",
                                    iconBg: Color(red: 0.35, green: 0.35, blue: 0.4),
                                    url: "https://lifonmusic.lol"
                                )

                                LinkRow(
                                    title: "TikTok создателя",
                                    subtitle: "@dangeershark_t.t",
                                    icon: "play.rectangle.fill",
                                    iconBg: Color.black,
                                    url: "https://www.tiktok.com/@dangeershark_t.t"
                                )
                            }
                            .padding(.horizontal, 16)
                        }

                        // Version & Fan Project Note
                        VStack(spacing: 4) {
                            Text("LifonMUSIC iOS • Версия 2.0.0")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Неофициальный фан-проект для группы CUPSIZE")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.2))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 130)
                    }
                }
                .sheet(isPresented: $showAchievementsSheet) {
                    AchievementsSheet()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

private struct LinkRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconBg: Color
    let url: String

    var body: some View {
        Button(action: {
            if let u = URL(string: url) {
                UIApplication.shared.open(u)
            }
        }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.45))
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(12)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

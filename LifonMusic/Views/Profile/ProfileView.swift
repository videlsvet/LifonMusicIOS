import SwiftUI
import UIKit
import PhotosUI

public struct ProfileView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @State private var showAchievementsSheet = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    public init() {}

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
                            if appVm.isAuthenticated {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    avatarView
                                }
                                .buttonStyle(.plain)
                            } else {
                                avatarView
                            }

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
                                    let totalMin = appVm.serverMinutes ?? ((appVm.stats?.totalMs ?? 0) / 60_000)
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
                                            let album = appVm.albumForTrack(track)
                                            Button(action: {
                                                if let t = track {
                                                    appVm.playTrack(t, in: .allTracks)
                                                }
                                            }) {
                                                HStack(spacing: 12) {
                                                    Text("#\(idx + 1)")
                                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                                        .foregroundColor(idx == 0 ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.4))
                                                        .frame(width: 28, alignment: .leading)

                                                    if let cover = track?.coverUrl ?? album?.coverUrl, let url = URL(string: cover) {
                                                        AsyncImage(url: url) { phase in
                                                            switch phase {
                                                            case .success(let img):
                                                                img.resizable().aspectRatio(contentMode: .fill)
                                                            default:
                                                                Color.white.opacity(0.1)
                                                            }
                                                        }
                                                        .frame(width: 36, height: 36)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                                    }

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

                                                    Image(systemName: "play.circle.fill")
                                                        .font(.system(size: 18))
                                                        .foregroundColor(.white.opacity(0.35))
                                                }
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .background(Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Supporters Section ("СПАСИБО ЗА ПОДДЕРЖКУ")
                        if !appVm.supporters.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("СПАСИБО ЗА ПОДДЕРЖКУ")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white.opacity(0.35))
                                    .tracking(2)
                                    .padding(.horizontal, 16)

                                VStack(spacing: 8) {
                                    ForEach(appVm.supporters) { sup in
                                        let chipColor = Color(hex: sup.color)
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle()
                                                    .fill(chipColor.opacity(0.2))
                                                    .frame(width: 32, height: 32)
                                                    .overlay(
                                                        Circle().stroke(chipColor.opacity(0.4), lineWidth: 1)
                                                    )
                                                Text(String(sup.name.prefix(1).uppercased()))
                                                    .font(.system(size: 13, weight: .bold))
                                                    .foregroundColor(chipColor)
                                            }

                                            Text(sup.name)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.85))

                                            Spacer()

                                            if !sup.handle.isEmpty {
                                                Text(sup.handle)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.35))
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 10)
                                        .background(Color.white.opacity(0.04))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                }
                                .padding(.horizontal, 16)
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
                .onChange(of: selectedPhotoItem) { newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await appVm.uploadAvatar(imageData: data)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var avatarView: some View {
        ZStack {
            if appVm.isUploadingAvatar {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 58, height: 58)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if let urlStr = appVm.avatarUrl, let url = URL(string: urlStr) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        placeholderAvatar
                    }
                }
                .frame(width: 58, height: 58)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
            } else {
                placeholderAvatar
            }
        }
    }

    private var placeholderAvatar: some View {
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
    }
}

private extension Color {
    init(hex: String) {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: UInt64
        switch clean.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (139, 92, 246)
        }
        self.init(
            red: Double(r) / 255.0,
            green: Double(g) / 255.0,
            blue: Double(b) / 255.0
        )
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

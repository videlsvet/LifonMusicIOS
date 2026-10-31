import SwiftUI

public struct MainTabView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared

    public init() {}

    public var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Screens
            Group {
                if let maint = appVm.maintenanceMessage {
                    MaintenanceView(message: maint) {
                        Task { await appVm.loadCatalog() }
                    }
                } else if appVm.isOffline && appVm.albums.isEmpty {
                    OfflineView {
                        Task { await appVm.loadCatalog() }
                    }
                } else {
                    TabView(selection: $appVm.currentScreen) {
                        LibraryView()
                            .tag(AppScreen.library)

                        FavoritesView()
                            .tag(AppScreen.favorites)

                        ProfileView()
                            .tag(AppScreen.profile)
                    }
                }
            }

            // Floating MiniPlayer + Custom Tab Bar
            if appVm.maintenanceMessage == nil && !(appVm.isOffline && appVm.albums.isEmpty) {
                VStack(spacing: 8) {
                    MiniPlayerBar()

                    customTabBar
                }
                .padding(.bottom, 6)
            }

            // First Launch Disclaimer
            if appVm.showDisclaimer {
                DisclaimerBanner {
                    appVm.dismissDisclaimer()
                }
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $appVm.showFullPlayer) {
            FullPlayerView()
        }
        .sheet(isPresented: $appVm.showEqualizer) {
            EqualizerSheet()
        }
        .sheet(isPresented: $appVm.showCupsizeInfo) {
            CupsizeInfoSheet()
        }
        .sheet(isPresented: $appVm.showRoadmap) {
            RoadmapSheet()
        }
        .sheet(isPresented: $appVm.showAuth) {
            AuthView()
        }
    }

    private var customTabBar: some View {
        HStack {
            tabButton(
                screen: .library,
                title: "Альбомы",
                icon: "square.grid.2x2.fill"
            )

            tabButton(
                screen: .favorites,
                title: "Избранное",
                icon: "heart.fill"
            )

            tabButton(
                screen: .profile,
                title: "Профиль",
                icon: "person.fill"
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.95))
                .shadow(color: .black.opacity(0.5), radius: 15, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 28)
    }

    private func tabButton(screen: AppScreen, title: String, icon: String) -> some View {
        let isSelected = (appVm.currentScreen == screen)
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appVm.currentScreen = screen
            }
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19))
                    .foregroundColor(isSelected ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white.opacity(0.35))

                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.35))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

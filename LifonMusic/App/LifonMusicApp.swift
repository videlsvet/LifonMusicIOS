import SwiftUI

@main
struct LifonMusicApp: App {
    @StateObject private var appVm = AppViewModel.shared

    init() {
        // Enforce dark theme across all system components
        UIView.appearance().overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .task {
                    await appVm.initialize()
                }
        }
    }
}

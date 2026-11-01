import SwiftUI

public struct PlaylistPickerSheet: View {
    @ObservedObject var appVm = AppViewModel.shared
    @Environment(\.dismiss) private var dismiss

    public let track: Track?

    @State private var showCreateField = false
    @State private var newTitle = ""
    @State private var addedToId: String?

    public init(track: Track? = nil) {
        self.track = track
    }

    private var targetTrack: Track? {
        track ?? appVm.playlistPickerTrack ?? appVm.playerService.currentTrack
    }

    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.10).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Добавить в плейлист")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        if let t = targetTrack {
                            Text(t.title)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.55))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button("Готово") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.83, green: 0.74, blue: 1.0))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if !appVm.isAuthenticated {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("Войдите в аккаунт для добавления трека в плейлист")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)

                        Button(action: {
                            dismiss()
                            appVm.showAuth = true
                        }) {
                            Text("Войти")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 22)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Create inline
                    if showCreateField {
                        HStack(spacing: 10) {
                            TextField("Название нового плейлиста", text: $newTitle)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Button(action: {
                                let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !t.isEmpty else { return }
                                Task {
                                    if let created = await appVm.createPlaylist(title: t), let track = targetTrack {
                                        await appVm.addTrackToPlaylist(playlist: created, trackId: track.id)
                                        addedToId = created.publicId
                                        newTitle = ""
                                        showCreateField = false
                                        try? await Task.sleep(nanoseconds: 600_000_000)
                                        dismiss()
                                    }
                                }
                            }) {
                                Text("ОК")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Button(action: { showCreateField = true }) {
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(Color(red: 0.83, green: 0.74, blue: 1.0))
                                Text("Создать новый плейлист")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                    }

                    Divider()
                        .background(Color.white.opacity(0.08))
                        .padding(.horizontal, 20)

                    // Playlists List
                    ScrollView {
                        if appVm.playlists.isEmpty {
                            Text("Плейлистов пока нет")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 30)
                        } else {
                            VStack(spacing: 6) {
                                ForEach(appVm.playlists) { playlist in
                                    Button(action: {
                                        guard let track = targetTrack else { return }
                                        Task {
                                            await appVm.addTrackToPlaylist(playlist: playlist, trackId: track.id)
                                            addedToId = playlist.publicId
                                            try? await Task.sleep(nanoseconds: 500_000_000)
                                            dismiss()
                                        }
                                    }) {
                                        HStack(spacing: 14) {
                                            Image(systemName: "music.note")
                                                .font(.system(size: 16))
                                                .foregroundColor(Color(red: 0.83, green: 0.74, blue: 1.0))
                                                .frame(width: 32, height: 32)
                                                .background(Color.white.opacity(0.06))
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                            Text(playlist.title)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.white)
                                                .lineLimit(1)

                                            Spacer()

                                            if addedToId == playlist.publicId {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(Color(red: 0.45, green: 0.85, blue: 0.6))
                                            }
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(Color.white.opacity(0.03))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

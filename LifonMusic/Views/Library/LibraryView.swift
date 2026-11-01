import SwiftUI

public struct LibraryView: View {
    @ObservedObject var appVm = AppViewModel.shared
    @ObservedObject var player = AudioPlayerService.shared

    private let gridColumns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.03, blue: 0.035).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("LifonMUSIC")
                                    .font(.system(size: 26, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("ДИСКОГРАФИЯ CUPSIZE")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0).opacity(0.6))
                                    .tracking(1.5)
                            }

                            Spacer()

                            // Roadmap Button
                            Button(action: { appVm.showRoadmap = true }) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(width: 38, height: 38)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }

                            // Band Info Button
                            Button(action: { appVm.showCupsizeInfo = true }) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white.opacity(0.75))
                                    .frame(width: 38, height: 38)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        // Broadcast Announcement Banner (if any)
                        if let b = appVm.broadcast {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "megaphone.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(b.title)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                    Text(b.body)
                                        .font(.system(size: 12))
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                Spacer()

                                Button(action: { appVm.dismissBroadcast() }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white.opacity(0.4))
                                        .padding(4)
                                }
                            }
                            .padding(14)
                            .background(Color(red: 0.12, green: 0.10, blue: 0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(red: 0.91, green: 0.835, blue: 1.0).opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                        }

                        // Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.white.opacity(0.4))
                            TextField("Поиск трека или альбома...", text: $appVm.searchQuery)
                                .foregroundColor(.white)
                                .accentColor(Color(red: 0.91, green: 0.835, blue: 1.0))

                            if !appVm.searchQuery.isEmpty {
                                Button(action: { appVm.searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 16)

                        // If Search is Active
                        if !appVm.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            let query = appVm.searchQuery.lowercased()
                            let matchedTracks = appVm.allTracks.filter { $0.title.lowercased().contains(query) }
                            let matchedAlbums = appVm.albums.filter { $0.title.lowercased().contains(query) }

                            if matchedTracks.isEmpty && matchedAlbums.isEmpty {
                                Text("Ничего не найдено")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal, 16)
                                    .padding(.top, 20)
                            } else {
                                if !matchedTracks.isEmpty {
                                    Text("Треки")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)

                                    LazyVStack(spacing: 4) {
                                        ForEach(matchedTracks) { track in
                                            let alb = appVm.albumForTrack(track)
                                            TrackRowView(
                                                track: track,
                                                coverUrl: alb?.coverUrl,
                                                isCurrent: player.currentTrack?.id == track.id,
                                                isPlaying: player.isPlaying,
                                                isLiked: appVm.isLiked(track.id),
                                                downloadStatus: appVm.downloadManager.status(for: track.id),
                                                onPlay: { appVm.playTrack(track, in: .allTracks) },
                                                onToggleLike: { appVm.toggleLike(trackId: track.id) },
                                                onDownload: { appVm.downloadManager.downloadTrack(track) }
                                            )
                                        }
                                    }
                                }

                                if !matchedAlbums.isEmpty {
                                    Text("Альбомы")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.top, 10)

                                    LazyVGrid(columns: gridColumns, spacing: 16) {
                                        ForEach(matchedAlbums) { album in
                                            NavigationLink(destination: AlbumDetailView(album: album)) {
                                                AlbumCardView(album: album) {}
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        } else {
                            // "Волна" Hero Card
                            WaveHeroCard()

                            // Standard Library (All Albums Grid)
                            Text("Альбомы и синглы")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.top, 4)

                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(appVm.albums) { album in
                                    NavigationLink(destination: AlbumDetailView(album: album)) {
                                        AlbumCardView(album: album) {}
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.bottom, 130) // Space for floating mini player
                }
                .refreshable {
                    await appVm.loadCatalog()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

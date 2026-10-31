import SwiftUI

public struct TrackRowView: View {
    public let track: Track
    public let coverUrl: String?
    public let isCurrent: Bool
    public let isPlaying: Bool
    public let isLiked: Bool
    public let downloadStatus: DownloadStatus
    public let onPlay: () -> Void
    public let onToggleLike: () -> Void
    public let onDownload: () -> Void

    public init(
        track: Track,
        coverUrl: String? = nil,
        isCurrent: Bool = false,
        isPlaying: Bool = false,
        isLiked: Bool = false,
        downloadStatus: DownloadStatus = .none,
        onPlay: @escaping () -> Void,
        onToggleLike: @escaping () -> Void,
        onDownload: @escaping () -> Void
    ) {
        self.track = track
        self.coverUrl = coverUrl ?? track.coverUrl
        self.isCurrent = isCurrent
        self.isPlaying = isPlaying
        self.isLiked = isLiked
        self.downloadStatus = downloadStatus
        self.onPlay = onPlay
        self.onToggleLike = onToggleLike
        self.onDownload = onDownload
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Track Cover or placeholder
            ZStack {
                if let urlStr = coverUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            placeholderBox
                        }
                    }
                } else {
                    placeholderBox
                }

                if isCurrent {
                    Color.black.opacity(0.4)
                    PlayingIndicatorDots(isPlaying: isPlaying)
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // Track details
            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: isCurrent ? .bold : .medium))
                    .foregroundColor(isCurrent ? Color(red: 0.91, green: 0.835, blue: 1.0) : .white)
                    .lineLimit(1)

                Text(track.displayArtist)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Duration
            Text(track.duration)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.35))

            // Download Button
            Button(action: onDownload) {
                switch downloadStatus {
                case .none:
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 17))
                        .foregroundColor(.white.opacity(0.4))
                case .downloading:
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.8)))
                        .scaleEffect(0.75)
                        .frame(width: 17, height: 17)
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundColor(Color(red: 0.5, green: 0.8, blue: 0.77)) // Mint
                }
            }
            .buttonStyle(.plain)

            // Like Button
            Button(action: onToggleLike) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 17))
                    .foregroundColor(isLiked ? Color(red: 1.0, green: 0.42, blue: 0.54) : .white.opacity(0.35))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onPlay()
        }
    }

    private var placeholderBox: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.2))
            )
    }
}

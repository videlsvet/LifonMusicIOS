import SwiftUI

public struct AlbumCardView: View {
    public let album: Album
    public var onSelect: (() -> Void)? = nil

    public init(album: Album, onSelect: (() -> Void)? = nil) {
        self.album = album
        self.onSelect = onSelect
    }

    public var body: some View {
        if let onSelect = onSelect {
            Button(action: onSelect) {
                cardBody
            }
            .buttonStyle(.plain)
        } else {
            cardBody
        }
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover Art
            ZStack(alignment: .bottomTrailing) {
                if let urlStr = album.coverUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(1, contentMode: .fill)
                        default:
                            albumPlaceholder
                        }
                    }
                } else {
                    albumPlaceholder
                }

                // Year Badge
                Text(album.year)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .padding(8)
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(glowBorderColor, lineWidth: 1)
            )

            // Title and Track Count
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(album.tracks.count) \(pluralTracks(album.tracks.count))")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .contentShape(Rectangle())
    }

    private var glowBorderColor: Color {
        if let glow = album.glowColor, let col = DominantColorExtractor.color(from: glow) {
            return col.opacity(0.35)
        }
        return Color.white.opacity(0.08)
    }

    private var albumPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .overlay(
                Image(systemName: "opticaldisc")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.2))
            )
    }

    private func pluralTracks(_ count: Int) -> String {
        let rem10 = count % 10
        let rem100 = count % 100
        if rem100 >= 11 && rem100 <= 19 { return "треков" }
        if rem10 == 1 { return "трек" }
        if rem10 >= 2 && rem10 <= 4 { return "трека" }
        return "треков"
    }
}

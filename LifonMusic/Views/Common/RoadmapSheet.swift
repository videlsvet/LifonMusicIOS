import SwiftUI

public struct RoadmapSheet: View {
    @ObservedObject var appVm = AppViewModel.shared
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Дискография по годам")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button("Закрыть") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.91, green: 0.835, blue: 1.0))
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView {
                    let grouped = Dictionary(grouping: appVm.albums, by: { $0.year })
                    let sortedYears = grouped.keys.sorted { ($0) < ($1) }

                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(sortedYears, id: \.self) { year in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(red: 0.91, green: 0.835, blue: 1.0))
                                        .frame(width: 8, height: 8)

                                    Text(year)
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                }

                                if let yearAlbums = grouped[year] {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(yearAlbums) { album in
                                                VStack(alignment: .leading, spacing: 6) {
                                                    ZStack {
                                                        if let coverStr = album.coverUrl, let url = URL(string: coverStr) {
                                                            AsyncImage(url: url) { phase in
                                                                switch phase {
                                                                case .success(let img):
                                                                    img.resizable().aspectRatio(1, contentMode: .fill)
                                                                default:
                                                                    Rectangle().fill(Color.white.opacity(0.1))
                                                                }
                                                            }
                                                        } else {
                                                            Rectangle().fill(Color.white.opacity(0.1))
                                                        }
                                                    }
                                                    .frame(width: 110, height: 110)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                                    Text(album.title)
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(.white)
                                                        .lineLimit(1)
                                                        .frame(width: 110, alignment: .leading)

                                                    Text("\(album.tracks.count) треков")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.white.opacity(0.4))
                                                }
                                                .onTapGesture {
                                                    dismiss()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
    }
}

import SwiftUI

// A compact page list keeps each notebook readable without scrolling through
// every full-size page. Tap a row to open the complete decorated notebook page.
struct DiaryCompactPageRow: View {
    let pageNumber: Int
    let title: String
    let author: String
    let excerpt: String
    let date: Date
    var stickerCount = 0
    var photoCount = 0

    var bodyViewTitle: String {
        title.isEmpty ? "無題のページ ♡" : title
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(String(format: "%02d", max(1, pageNumber)))
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MawaruContrast.ink)
                .frame(width: 44, height: 48)
                .background(MawaruPastel.rose.opacity(0.48),
                            in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 5) {
                Text(bodyViewTitle)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(MawaruContrast.ink)
                    .lineLimit(1)
                if !excerpt.isEmpty {
                    Text(excerpt.replacingOccurrences(of: "\n", with: " "))
                        .font(.caption)
                        .foregroundStyle(MawaruContrast.secondaryInk)
                        .lineLimit(1)
                }
                HStack(spacing: 7) {
                    Text(author)
                    Text("·")
                    Text(date, format: .dateTime.month().day())
                    if stickerCount > 0 {
                        Label("\(stickerCount)", systemImage: "sparkles")
                    }
                    if photoCount > 0 {
                        Label("\(photoCount)", systemImage: "photo")
                    }
                }
                .font(.caption2)
                .foregroundStyle(MawaruContrast.secondaryInk)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(MawaruContrast.secondaryInk)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MawaruContrast.surface,
                    in: RoundedRectangle(cornerRadius: 17))
    }
}

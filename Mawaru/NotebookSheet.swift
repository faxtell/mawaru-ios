import SwiftUI
import UIKit
import UniformTypeIdentifiers

// Notebook composition shared by draft, local archive and cloud pages.
// The paper measures its real content height; stickers are overlaid at
// normalized positions and therefore can sit over text or in the margins.
enum MawaruPastel {
    static let background = Color(red: 0.995, green: 0.945, blue: 0.952)
    static let rose = Color(red: 0.98, green: 0.75, blue: 0.80)
    static let mint = Color(red: 0.76, green: 0.91, blue: 0.83)
    static let lavender = Color(red: 0.85, green: 0.81, blue: 0.95)
    static let lemon = Color(red: 1.0, green: 0.92, blue: 0.72)
    static let ink = Color(red: 0.38, green: 0.31, blue: 0.36)
}

struct MawaruSectionLabel: View {
    var step: String
    var title: String
    var symbol: String
    var body: some View {
        HStack(spacing: 10) {
            Text(step)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(MawaruPastel.ink)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(MawaruPastel.lemon, in: Capsule())
            Label(title, systemImage: symbol)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(MawaruPastel.ink)
            Spacer()
        }
    }
}

struct NostalgicNotebookPaper: View {
    let style: Int

    private var color: Color {
        switch style {
        case 1: Color(red: 1, green: 0.94, blue: 0.955)
        case 2: Color(red: 0.945, green: 0.985, blue: 0.95)
        case 3: Color(red: 0.966, green: 0.95, blue: 0.995)
        default: Color(red: 1, green: 0.99, blue: 0.952)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 23)
            .fill(color)
            .overlay {
                Canvas { context, size in
                    let rule = Color(red: 0.66, green: 0.64, blue: 0.67).opacity(0.30)
                    let lineStep = CGFloat(30)
                    for y in stride(from: CGFloat(82), through: size.height - 19, by: lineStep) {
                        var line = Path()
                        line.move(to: CGPoint(x: 22, y: y))
                        line.addLine(to: CGPoint(x: max(22, size.width - 18), y: y))
                        context.stroke(line, with: .color(rule), lineWidth: 0.7)
                    }
                    var margin = Path()
                    margin.move(to: CGPoint(x: 39, y: 0))
                    margin.addLine(to: CGPoint(x: 39, y: size.height))
                    context.stroke(margin,
                                   with: .color(MawaruPastel.rose.opacity(0.60)), lineWidth: 1.5)
                    if style == 3 {
                        for x in stride(from: CGFloat(18), through: size.width - 10, by: CGFloat(22)) {
                            for y in stride(from: CGFloat(24), through: size.height - 6, by: CGFloat(22)) {
                                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.3, height: 1.3)),
                                             with: .color(rule.opacity(0.45)))
                            }
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 23))
            }
            .overlay {
                Canvas { context, size in
                    for y in stride(from: CGFloat(58), through: size.height - 22,
                                    by: CGFloat(76)) {
                        let hole = Path(ellipseIn: CGRect(x: 8, y: y, width: 11, height: 11))
                        context.fill(hole, with: .color(MawaruPastel.background))
                        context.stroke(hole,
                                       with: .color(MawaruPastel.ink.opacity(0.10)),
                                       lineWidth: 0.7)
                    }
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(MawaruPastel.rose.opacity(0.55))
                    .frame(width: 88, height: 17)
                    .rotationEffect(.degrees(-7))
                    .offset(x: 15, y: -6)
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 23)
                    .strokeBorder(.white.opacity(0.9), lineWidth: 2)
            }
            .shadow(color: MawaruPastel.ink.opacity(0.09), radius: 14, y: 8)
    }
}

struct NostalgicNotebookPage<Content: View>: View {
    @Binding var decoration: DiaryDecoration
    var editing = false
    var cloudLocation: DiaryCloudPhotoLocation? = nil
    var bookTitle = "ひみつの交換日記"
    var pageNumber: Int? = nil
    var exchangeMode: String? = nil
    @ViewBuilder let content: () -> Content
    @State private var canvasSize = CGSize(width: 350, height: 480)
    @State private var dropTargeted = false
    @State private var dropError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 7) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 11))
                    Text(bookTitle.isEmpty ? "ひみつの交換日記" : bookTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 5)
                    if let pageNumber {
                        Text(String(format: "NO. %02d", max(1, pageNumber)))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .fixedSize()
                    } else {
                        Text("secret ♡").font(.system(size: 10, weight: .semibold))
                    }
                }
                HStack(spacing: 6) {
                    Text("mawaru")
                        .font(.system(size: 9, weight: .bold, design: .serif))
                    Image(systemName: "heart.fill").font(.system(size: 7))
                    if let exchangeMode {
                        Text(exchangeMode).font(.system(size: 9, weight: .medium, design: .rounded))
                    }
                    Spacer()
                    Text("a page for us ✿")
                        .font(.system(size: 9, weight: .medium, design: .serif))
                }
                Rectangle()
                    .fill(MawaruPastel.rose.opacity(0.40))
                    .frame(height: 1)
            }
            .foregroundStyle(MawaruPastel.ink.opacity(0.65))
            .padding(.leading, 25)
            .padding(.trailing, 6)
            .padding(.bottom, 14)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 18)

            HStack(spacing: 5) {
                Image(systemName: "heart.fill").font(.system(size: 8))
                Text("きょうの思い出を、次の人へ")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                Spacer(minLength: 5)
                Text("mawaru  ✦")
                    .font(.system(size: 10, weight: .medium, design: .serif))
            }
            .foregroundStyle(MawaruPastel.ink.opacity(0.47))
        }
        .padding(.top, 20)
        .padding(.bottom, 19)
        .padding(.leading, 52)
        .padding(.trailing, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 540, alignment: .topLeading)
        .background { NostalgicNotebookPaper(style: decoration.paper) }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { canvasSize = proxy.size }
                    .onChange(of: proxy.size) { _, next in canvasSize = next }
            }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    ForEach($decoration.stickers) { $sticker in
                        DiaryMovableSticker(
                            sticker: $sticker, canvasSize: geometry.size,
                            editing: editing
                        ) {
                            decoration.stickers.removeAll { $0.id == sticker.id }
                        }
                    }
                    ForEach($decoration.photos) { $photo in
                        DiaryPastedPhotoView(
                            photo: $photo, canvasSize: geometry.size,
                            editing: editing, cloudLocation: cloudLocation
                        ) {
                            decoration.photos.removeAll { $0.id == photo.id }
                        }
                    }
                }
            }
        }
        .overlay {
            if editing && dropTargeted {
                RoundedRectangle(cornerRadius: 23)
                    .strokeBorder(MawaruPastel.rose, style: StrokeStyle(lineWidth: 4, dash: [10, 6]))
                    .background(MawaruPastel.rose.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 23))
                    .overlay {
                        Label("ここにペタッ ♡", systemImage: "photo.on.rectangle.angled")
                            .font(.headline.bold())
                            .padding(15)
                            .background(.white.opacity(0.92), in: Capsule())
                    }
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [UTType.image], isTargeted: $dropTargeted) { providers, location in
            guard editing, decoration.photos.count < 4 else { return false }
            return DiaryImageDropHandler.receive(providers, at: location, on: canvasSize) { image, point in
                guard decoration.photos.count < 4 else {
                    dropError = "写真は1ページ4枚までだよ。"
                    return
                }
                do {
                    var clipping = try DiaryPhotoVault.add(image, preferPNG: true)
                    clipping.x = Double(point.x)
                    clipping.y = Double(point.y)
                    decoration.photos.append(clipping)
                } catch {
                    dropError = error.localizedDescription
                }
            } onFailure: { message in
                dropError = message
            }
        }
        .alert("写真を貼れませんでした", isPresented: Binding(
            get: { dropError != nil },
            set: { if !$0 { dropError = nil } }
        )) {
            Button("OK") { dropError = nil }
        } message: {
            Text(dropError ?? "")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(editing ? "画像をドロップできるノートのページ" : "交換日記のページ")
    }
}

// Both modes call the same writing-content view so all text frames,
// margins, and line layout match exactly after a page is passed.
struct NostalgicNotebookEditor: View {
    @Binding var title: String
    @Binding var text: String
    @Binding var decoration: DiaryDecoration
    var author = "わたし"
    var date = Date.now
    var bookTitle = "ひみつの交換日記"
    var pageNumber: Int? = nil
    var exchangeMode: String? = nil

    var body: some View {
        NostalgicNotebookPage(
            decoration: $decoration, editing: true,
            bookTitle: bookTitle, pageNumber: pageNumber,
            exchangeMode: exchangeMode
        ) {
            DiaryPageWritingContent(
                title: $title, text: $text, decoration: decoration,
                editable: true, author: author, date: date
            )
        }
    }
}

struct NostalgicNotebookReadPage: View {
    var title: String
    var text: String
    var author: String
    var date: Date
    var decoration: DiaryDecoration
    var attachedPhoto: UIImage? = nil
    var cloudLocation: DiaryCloudPhotoLocation? = nil
    var bookTitle = "ひみつの交換日記"
    var pageNumber: Int? = nil
    var exchangeMode: String? = nil

    var body: some View {
        VStack(spacing: 14) {
            NostalgicNotebookPage(
                decoration: .constant(decoration),
                editing: false, cloudLocation: cloudLocation,
                bookTitle: bookTitle, pageNumber: pageNumber,
                exchangeMode: exchangeMode
            ) {
                DiaryPageWritingContent(
                    title: .constant(title.isEmpty ? "無題のページ ♡" : title),
                    text: .constant(text), decoration: decoration,
                    editable: false, author: author, date: date
                )
            }
            // Legacy fixed attachments stay OUTSIDE the positioned page.
            // Otherwise a photo changes canvas height and moves all stickers.
            if let attachedPhoto {
                Image(uiImage: attachedPhoto)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
                    .padding(12)
                    .background(.white.opacity(0.88),
                                in: RoundedRectangle(cornerRadius: 20))
            }
        }
    }
}

struct MawaruHomeHeader: View {
    var headline: String
    var subtitle: String
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 25)
                .fill(LinearGradient(colors: [.white, MawaruPastel.rose.opacity(0.47),
                                              MawaruPastel.lavender.opacity(0.35)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            VStack(alignment: .leading, spacing: 8) {
                Text("mawaru  ✧  交換日記")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(MawaruPastel.ink.opacity(0.68))
                Text(headline)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .foregroundStyle(MawaruPastel.ink)
                Text(subtitle)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(MawaruPastel.ink.opacity(0.73))
                HStack(spacing: 7) {
                    Text("手書き風ノート")
                    Text("✦")
                    Text("シールでデコ")
                }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.75), in: Capsule())
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 0) {
                Text("🎀").rotationEffect(.degrees(-13))
                Text("🌷").offset(y: 10)
            }
            .font(.system(size: 26))
            .padding(12)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

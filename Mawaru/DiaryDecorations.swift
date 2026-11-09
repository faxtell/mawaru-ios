import SwiftUI

// A sticker is data, not a flattened screenshot: each member sees the same layout.
// Positions are normalized to a 0–1 canvas so they survive different iPhone sizes.
struct DiarySticker: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: String
    var x: Double
    var y: Double
    var scale: Double = 1
    var rotation: Double = 0
}

struct DiaryDecoration: Codable, Equatable {
    var paper: Int = 0
    var stickers: [DiarySticker] = []
    var photos: [DiaryPastedPhoto] = []
    var fontStyle: Int = 0
    var fontSize: Double = 18
    var inkStyle: Int = 0
    var textAlignment: Int = 0

    // Older diary archives (v0.1–v0.3) contain no "photos" key.
    init(paper: Int = 0, stickers: [DiarySticker] = [], photos: [DiaryPastedPhoto] = [],
         fontStyle: Int = 0, fontSize: Double = 18, inkStyle: Int = 0, textAlignment: Int = 0) {
        self.paper = paper
        self.stickers = stickers
        self.photos = photos
        self.fontStyle = fontStyle
        self.fontSize = fontSize
        self.inkStyle = inkStyle
        self.textAlignment = textAlignment
    }
    private enum CodingKeys: String, CodingKey {
        case paper, stickers, photos, fontStyle, fontSize, inkStyle, textAlignment
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        paper = try values.decodeIfPresent(Int.self, forKey: .paper) ?? 0
        stickers = try values.decodeIfPresent([DiarySticker].self, forKey: .stickers) ?? []
        photos = try values.decodeIfPresent([DiaryPastedPhoto].self, forKey: .photos) ?? []
        fontStyle = try values.decodeIfPresent(Int.self, forKey: .fontStyle) ?? 0
        fontSize = try values.decodeIfPresent(Double.self, forKey: .fontSize) ?? 18
        inkStyle = try values.decodeIfPresent(Int.self, forKey: .inkStyle) ?? 0
        textAlignment = try values.decodeIfPresent(Int.self, forKey: .textAlignment) ?? 0
    }

    mutating func addSticker(_ kind: String) {
        guard stickers.count < 24, DiaryStickerCatalog.items.contains(where: { $0.id == kind }) else { return }
        let offset = Double(stickers.count % 6) * 0.065
        stickers.append(DiarySticker(kind: kind, x: 0.42 + offset, y: 0.38 + offset))
    }

    var cloudValue: [String: Any] {
        [
            "paper": paper,
            "fontStyle": fontStyle,
            "fontSize": fontSize,
            "inkStyle": inkStyle,
            "textAlignment": textAlignment,
            "stickers": stickers.map {
                [
                    "id": $0.id.uuidString,
                    "kind": $0.kind,
                    "x": $0.x,
                    "y": $0.y,
                    "scale": $0.scale,
                    "rotation": $0.rotation
                ] as [String: Any]
            },
            "photos": photos.map { $0.cloudValue }
        ]
    }

    static func fromCloud(_ raw: Any?) -> DiaryDecoration {
        guard let map = raw as? [String: Any] else { return DiaryDecoration() }
        let p = (map["paper"] as? Int) ?? 0
        let validPaper = (0...3).contains(p) ? p : 0
        let elements = (map["stickers"] as? [[String: Any]] ?? []).prefix(24).compactMap { item -> DiarySticker? in
            guard let idString = item["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let kind = item["kind"] as? String,
                  DiaryStickerCatalog.items.contains(where: { $0.id == kind }),
                  let x = item["x"] as? Double,
                  let y = item["y"] as? Double,
                  let scale = item["scale"] as? Double,
                  let rotation = item["rotation"] as? Double,
                  x.isFinite, y.isFinite, scale.isFinite, rotation.isFinite else { return nil }
            return DiarySticker(id: id, kind: kind,
                x: min(0.93, max(0.07, x)),
                y: min(0.90, max(0.10, y)),
                scale: min(2.5, max(0.5, scale)),
                rotation: min(180, max(-180, rotation)))
        }
        let photos = (map["photos"] as? [[String: Any]] ?? []).prefix(4).compactMap {
            raw -> DiaryPastedPhoto? in
            guard let idText = raw["id"] as? String, let id = UUID(uuidString: idText),
                  let format = raw["format"] as? String, ["jpg", "png"].contains(format),
                  let x = raw["x"] as? Double, x.isFinite,
                  let y = raw["y"] as? Double, y.isFinite,
                  let scale = raw["scale"] as? Double, scale.isFinite,
                  let rotation = raw["rotation"] as? Double, rotation.isFinite else { return nil }
            return DiaryPastedPhoto(id: id, format: format,
                                    x: min(0.93, max(0.07, x)),
                                    y: min(0.9, max(0.1, y)),
                                    scale: min(2.5, max(0.5, scale)),
                                    rotation: min(180, max(-180, rotation)))
        }
        let style = (map["fontStyle"] as? Int ?? 0)
        let size = (map["fontSize"] as? Double ?? 18)
        let ink = (map["inkStyle"] as? Int ?? 0)
        let align = (map["textAlignment"] as? Int ?? 0)
        return DiaryDecoration(
            paper: validPaper, stickers: Array(elements), photos: Array(photos),
            fontStyle: (0...3).contains(style) ? style : 0,
            fontSize: size.isFinite ? min(30, max(14, size)) : 18,
            inkStyle: (0...3).contains(ink) ? ink : 0,
            textAlignment: (0...2).contains(align) ? align : 0
        )
    }
}

struct DiaryStickerKind: Identifiable {
    let id: String
    let visual: String
    let name: String
    let tint: Color
}

enum DiaryStickerCatalog {
    static let items: [DiaryStickerKind] = [
        .init(id: "heart", visual: "💗", name: "ハート", tint: .pink),
        .init(id: "ribbon", visual: "🎀", name: "リボン", tint: .pink),
        .init(id: "bear", visual: "🧸", name: "くま", tint: .brown),
        .init(id: "strawberry", visual: "🍓", name: "いちご", tint: .pink),
        .init(id: "flower", visual: "🌷", name: "お花", tint: .pink),
        .init(id: "sparkles", visual: "✨", name: "きらきら", tint: .yellow),
        .init(id: "cloud", visual: "☁️", name: "雲", tint: .blue),
        .init(id: "star", visual: "⭐️", name: "星", tint: .yellow),
        .init(id: "paw", visual: "🐾", name: "肉球", tint: .brown),
        .init(id: "letter", visual: "💌", name: "お手紙", tint: .pink),
        .init(id: "cake", visual: "🍰", name: "ケーキ", tint: .orange),
        .init(id: "rainbow", visual: "🌈", name: "虹", tint: .blue),
        .init(id: "cat", visual: "🐱", name: "ねこ", tint: .orange),
        .init(id: "coffee", visual: "☕️", name: "コーヒー", tint: .brown),
        .init(id: "tapePink", visual: "PINK", name: "ピンクのテープ", tint: Color(red: 0.97, green: 0.67, blue: 0.73)),
        .init(id: "tapeMint", visual: "MINT", name: "ミントのテープ", tint: Color(red: 0.65, green: 0.82, blue: 0.73)),
        .init(id: "tapeLavender", visual: "LOVE", name: "紫のテープ", tint: Color(red: 0.77, green: 0.71, blue: 0.89))
    ]
    static func item(_ kind: String) -> DiaryStickerKind? {
        items.first { $0.id == kind }
    }
}

private struct DiaryPaperBackground: View {
    let style: Int

    private var paperColor: Color {
        switch style {
        case 1: Color(red: 1.0, green: 0.94, blue: 0.95)
        case 2: Color(red: 0.93, green: 0.97, blue: 0.94)
        case 3: Color(red: 0.96, green: 0.94, blue: 1.0)
        default: Color(red: 1.0, green: 0.985, blue: 0.94)
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(paperColor)
            .overlay {
                Canvas { context, size in
                    let ink = Color(red: 0.64, green: 0.57, blue: 0.58).opacity(0.23)
                    if style == 2 {
                        for x in stride(from: CGFloat(0), through: size.width, by: CGFloat(24)) {
                            var line = Path()
                            line.move(to: CGPoint(x: x, y: 0))
                            line.addLine(to: CGPoint(x: x, y: size.height))
                            context.stroke(line, with: .color(ink), lineWidth: 0.7)
                        }
                    }
                    for y in stride(from: CGFloat(28), through: size.height, by: CGFloat(24)) {
                        if style == 3 {
                            for x in stride(from: CGFloat(15), through: size.width, by: CGFloat(24)) {
                                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2, height: 2)),
                                    with: .color(ink))
                            }
                        } else {
                            var line = Path()
                            line.move(to: CGPoint(x: 16, y: y))
                            line.addLine(to: CGPoint(x: size.width - 16, y: y))
                            context.stroke(line, with: .color(ink), lineWidth: 0.7)
                        }
                    }
                    var margin = Path()
                    margin.move(to: CGPoint(x: 34, y: 0))
                    margin.addLine(to: CGPoint(x: 34, y: size.height))
                    context.stroke(margin,
                        with: .color(Color(red: 0.9, green: 0.55, blue: 0.57).opacity(0.23)),
                        lineWidth: 1.2)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(.brown.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct DiaryStickerShape: View {
    let item: DiaryStickerKind
    var body: some View {
        Group {
            if item.id.hasPrefix("tape") {
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.tint.opacity(0.76))
                    .frame(width: 94, height: 28)
                    .overlay {
                        HStack(spacing: 7) {
                            Image(systemName: "heart.fill").font(.system(size: 9))
                            Text(item.visual).font(.system(size: 10, weight: .black, design: .rounded))
                            Image(systemName: "heart.fill").font(.system(size: 9))
                        }
                        .foregroundStyle(MawaruContrast.ink)
                    }
            } else {
                Text(item.visual)
                    .font(.system(size: 49))
                    .frame(width: 64, height: 64)
                    .contentShape(Rectangle())
            }
        }
        .shadow(color: .brown.opacity(0.14), radius: 1.5, y: 2)
    }
}

// Each sticker supports drag, pinch, and rotate; values are written back to the model.
struct DiaryMovableSticker: View {
    @Binding var sticker: DiarySticker
    let canvasSize: CGSize
    let editing: Bool
    let onRemove: () -> Void

    @State private var dragged = CGSize.zero
    @State private var pinched: CGFloat = 1
    @State private var spun = Angle.zero

    private var drag: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { dragged = $0.translation }
            .onEnded { value in
                let w = max(canvasSize.width, 1)
                let h = max(canvasSize.height, 1)
                sticker.x = min(0.93, max(0.07, sticker.x + value.translation.width / w))
                sticker.y = min(0.90, max(0.10, sticker.y + value.translation.height / h))
                dragged = .zero
            }
    }
    private var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { pinched = $0 }
            .onEnded { value in
                sticker.scale = min(2.5, max(0.5, sticker.scale * Double(value)))
                pinched = 1
            }
    }
    private var rotate: some Gesture {
        RotationGesture()
            .onChanged { spun = $0 }
            .onEnded { value in
                let angle = sticker.rotation + value.degrees
                sticker.rotation = min(180, max(-180, angle))
                spun = .zero
            }
    }

    private var shape: some View {
        Group {
            if let item = DiaryStickerCatalog.item(sticker.kind) {
                DiaryStickerShape(item: item)
            }
        }
        .scaleEffect(sticker.scale * Double(pinched))
        .rotationEffect(.degrees(sticker.rotation + spun.degrees))
        .offset(dragged)
        .position(x: canvasSize.width * sticker.x, y: canvasSize.height * sticker.y)
        .accessibilityLabel(DiaryStickerCatalog.item(sticker.kind)?.name ?? "シール")
    }

    var body: some View {
        if editing {
            shape
                .gesture(drag)
                .simultaneousGesture(pinch)
                .simultaneousGesture(rotate)
                .contextMenu {
                    Button {
                        sticker.rotation = 0
                        sticker.scale = 1
                    } label: {
                        Label("向きと大きさを戻す", systemImage: "arrow.counterclockwise")
                    }
                    Button {
                        sticker.x = 0.5
                        sticker.y = 0.4
                    } label: {
                        Label("ノート中央へ移動", systemImage: "scope")
                    }
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("シールを剥がす", systemImage: "trash")
                    }
                }
        } else {
            shape.allowsHitTesting(false)
        }
    }
}

struct DiaryStickerBoard: View {
    @Binding var decoration: DiaryDecoration
    var editing = false
    var cloudLocation: DiaryCloudPhotoLocation? = nil
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DiaryPaperBackground(style: decoration.paper)
                VStack {
                    HStack {
                        Image(systemName: "heart.text.square")
                        Text("little memories")
                            .font(.system(.caption, design: .serif, weight: .semibold))
                        Spacer()
                        Image(systemName: "sparkles")
                    }
                    .foregroundStyle(.brown.opacity(0.47))
                    .padding(.horizontal, 48)
                    .padding(.top, 13)
                    Spacer()
                    Text("a page just for us ♡")
                        .font(.system(.caption2, design: .serif))
                        .foregroundStyle(.brown.opacity(0.38))
                        .padding(.bottom, 14)
                }
                ForEach($decoration.stickers) { $sticker in
                    DiaryMovableSticker(sticker: $sticker, canvasSize: geometry.size,
                                        editing: editing) {
                        decoration.stickers.removeAll { $0.id == sticker.id }
                    }
                }
                ForEach($decoration.photos) { $photo in
                    DiaryPastedPhotoView(photo: $photo, canvasSize: geometry.size,
                                         editing: editing, cloudLocation: cloudLocation) {
                        decoration.photos.removeAll { $0.id == photo.id }
                    }
                }
            }
        }
        .frame(height: 254)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(editing ? "シールを貼るキャンバス" : "日記のデコレーション")
    }
}

struct DiaryDecorationEditor: View {
    @Binding var decoration: DiaryDecoration
    var showsPreview = true

    private let paperNames = ["クリーム", "さくら", "ミント", "ラベンダー"]
    private let paperColors: [Color] = [
        Color(red: 1, green: 0.98, blue: 0.92),
        Color(red: 1, green: 0.92, blue: 0.94),
        Color(red: 0.90, green: 0.97, blue: 0.92),
        Color(red: 0.94, green: 0.92, blue: 0.99)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("あつめたシールを貼ろう", systemImage: "sparkles").font(.system(.headline, design: .rounded, weight: .bold))
                Spacer()
                if !decoration.stickers.isEmpty || !decoration.photos.isEmpty {
                    Menu {
                        if !decoration.stickers.isEmpty {
                            Button {
                                decoration.stickers.removeLast()
                            } label: {
                                Label("最後のシールを1枚戻す", systemImage: "arrow.uturn.backward")
                            }
                            Button(role: .destructive) {
                                decoration.stickers.removeAll()
                            } label: {
                                Label("シールだけ全部剥がす", systemImage: "trash")
                            }
                        }
                        if !decoration.photos.isEmpty {
                            Button(role: .destructive) {
                                for photo in decoration.photos {
                                    DiaryPhotoVault.remove(photo)
                                }
                                decoration.photos.removeAll()
                            } label: {
                                Label("写真だけ全部剥がす", systemImage: "photo.badge.minus")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("デコレーション操作")
                    }
                }
            }
            if showsPreview {
                DiaryStickerBoard(decoration: $decoration, editing: true)
            }
            DiaryPhotoInsertionControls(decoration: $decoration)
            Text("上のノートに、文字を隠すようにペタッ。写真もシールもドラッグ・拡大・回転できるよ ♡")
                .font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(DiaryStickerCatalog.items) { sticker in
                        Button {
                            decoration.addSticker(sticker.id)
                        } label: {
                            VStack(spacing: 5) {
                                DiaryStickerShape(item: sticker)
                                    .scaleEffect(0.74)
                                    .frame(width: 67, height: 52)
                                Text(sticker.name).font(.system(size: 10)).lineLimit(1)
                            }
                            .frame(width: 76, height: 76)
                            .background(MawaruContrast.surface, in: RoundedRectangle(cornerRadius: 13))
                        }
                        .buttonStyle(.plain)
                        .disabled(decoration.stickers.count >= 24)
                        .accessibilityLabel("\(sticker.name)を貼る")
                    }
                }
            }
            HStack {
                Text("シール \(decoration.stickers.count)/24枚")
                Spacer()
                Text("貼り付け画像 \(decoration.photos.count)/4枚")
            }
            .font(.caption)
            .foregroundStyle(MawaruContrast.secondaryInk)
            Text("ノートの紙").font(.subheadline.bold())
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    Button {
                        decoration.paper = index
                    } label: {
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(paperColors[index])
                                .frame(height: 38)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 9)
                                        .strokeBorder(decoration.paper == index ? DiaryStyle.ink : Color.gray.opacity(0.14),
                                                      lineWidth: decoration.paper == index ? 2 : 1)
                                }
                            Text(paperNames[index])
                                .font(.system(size: 10))
                                .foregroundStyle(MawaruContrast.secondaryInk)
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(MawaruPastel.lemon.opacity(0.30), in: RoundedRectangle(cornerRadius: 22))
    }
}

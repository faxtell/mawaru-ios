import SwiftUI
import UIKit
import CoreText

// User-selectable Japanese handwriting fonts. Fonts are embedded in the IPA
// by the Actions font installation step, with their OFL license files.
enum DiaryFonts {
    static let names = ["まる文字", "よもぎ", "クレー", "クレナイド"]
    private static let fileNames = ["Yomogi-Regular", "KleeOne-Regular", "ZenKurenaido-Regular"]
    private static let postScriptNames = ["Yomogi-Regular", "KleeOne-Regular", "ZenKurenaido-Regular"]

    static func register() {
        for name in fileNames {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") ??
                Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
            else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func font(_ decoration: DiaryDecoration, size: CGFloat? = nil) -> Font {
        let size = size ?? CGFloat(decoration.fontSize)
        if (1...3).contains(decoration.fontStyle) {
            let name = postScriptNames[decoration.fontStyle - 1]
            if UIFont(name: name, size: size) != nil {
                return .custom(name, size: size)
            }
        }
        return .system(size: size, design: .rounded)
    }

    static func uiFont(_ decoration: DiaryDecoration, size: CGFloat? = nil) -> UIFont {
        let requested = size ?? CGFloat(decoration.fontSize)
        let pointSize = min(40, max(12, requested))
        if (1...3).contains(decoration.fontStyle),
           let selected = UIFont(name: postScriptNames[decoration.fontStyle - 1], size: pointSize) {
            return selected
        }
        let normal = UIFont.systemFont(ofSize: pointSize)
        guard let rounded = normal.fontDescriptor.withDesign(.rounded) else { return normal }
        return UIFont(descriptor: rounded, size: pointSize)
    }

    static func uiAlignment(_ decoration: DiaryDecoration) -> NSTextAlignment {
        switch decoration.textAlignment {
        case 1: .center
        case 2: .right
        default: .left
        }
    }

    static func ink(_ decoration: DiaryDecoration) -> Color {
        switch decoration.inkStyle {
        case 1: Color(red: 0.19, green: 0.35, blue: 0.61)
        case 2: Color(red: 0.66, green: 0.34, blue: 0.44)
        case 3: Color(red: 0.30, green: 0.48, blue: 0.39)
        default: MawaruPastel.ink
        }
    }

    static func alignment(_ decoration: DiaryDecoration) -> TextAlignment {
        switch decoration.textAlignment {
        case 1: .center
        case 2: .trailing
        default: .leading
        }
    }
}

struct DiaryTypographyControls: View {
    @Binding var decoration: DiaryDecoration
    var resetToSavedPreference = false

    private let inkNames = ["こげ茶", "ブルー", "ピンク", "グリーン"]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("文字をもっとかわいく ♡", systemImage: "textformat")
                .font(.system(.headline, design: .rounded, weight: .bold))

            Text("フォント")
                .font(.caption.bold())
                .foregroundStyle(MawaruContrast.secondaryInk)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 9) {
                    ForEach(DiaryFonts.names.indices, id: \.self) { index in
                        Button { decoration.fontStyle = index } label: {
                            VStack(spacing: 5) {
                                Text("あいうえお")
                                    .font(DiaryFonts.font(DiaryDecoration(fontStyle: index), size: 17))
                                    .foregroundStyle(MawaruPastel.ink)
                                Text(DiaryFonts.names[index])
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .frame(width: 101, height: 64)
                            .background(decoration.fontStyle == index ?
                                        MawaruPastel.rose.opacity(0.38) : Color.white.opacity(0.86),
                                        in: RoundedRectangle(cornerRadius: 15))
                            .overlay {
                                RoundedRectangle(cornerRadius: 15)
                                    .strokeBorder(decoration.fontStyle == index ?
                                        MawaruPastel.ink.opacity(0.35) : .clear, lineWidth: 1.5)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(DiaryFonts.names[index])を選択")
                    }
                }
            }

            HStack {
                Text("文字サイズ").font(.caption.bold())
                Spacer()
                Text("\(Int(decoration.fontSize)) pt")
                    .font(.caption.monospacedDigit())
            }
            Slider(value: $decoration.fontSize, in: 14...30, step: 1)
                .tint(MawaruPastel.ink)

            Text("インクの色").font(.caption.bold())
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Button { decoration.inkStyle = index } label: {
                        Circle().fill(DiaryFonts.ink(DiaryDecoration(inkStyle: index)))
                            .frame(width: 31, height: 31)
                            .padding(5)
                            .overlay {
                                Circle().strokeBorder(decoration.inkStyle == index ?
                                    MawaruPastel.ink : .clear, lineWidth: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(inkNames[index])のインク")
                }
                Spacer()
            }

            HStack {
                Text("文字の位置").font(.caption.bold())
                Spacer()
                Picker("文字の位置", selection: $decoration.textAlignment) {
                    Label("左", systemImage: "text.alignleft").tag(0)
                    Label("中央", systemImage: "text.aligncenter").tag(1)
                    Label("右", systemImage: "text.alignright").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 230)
            }

            Button(resetToSavedPreference ? "いつもの設定に戻す" : "初期設定に戻す",
                   systemImage: "arrow.counterclockwise") {
                let stored = resetToSavedPreference ?
                    DiaryTypographyPreferences.load() : DiaryDecoration()
                decoration.fontStyle = stored.fontStyle
                decoration.fontSize = stored.fontSize
                decoration.inkStyle = stored.inkStyle
                decoration.textAlignment = stored.textAlignment
            }
            .font(.footnote)
            .foregroundStyle(MawaruContrast.secondaryInk)
        }
        .padding(16)
        .background(MawaruPastel.lavender.opacity(0.27),
                    in: RoundedRectangle(cornerRadius: 22))
    }
}

// User-wide defaults are applied ONLY when starting a new page. Each page
// retains its own typography, so past diaries never change when defaults do.
enum DiaryTypographyPreferences {
    static let paperKey = "mawaru.page.defaultPaper"
    static let fontStyleKey = "mawaru.fonts.defaultStyle"
    static let fontSizeKey = "mawaru.fonts.defaultSize"
    static let inkStyleKey = "mawaru.fonts.defaultInk"
    static let alignmentKey = "mawaru.fonts.defaultAlignment"

    static func load() -> DiaryDecoration {
        let prefs = UserDefaults.standard
        let paper = prefs.object(forKey: paperKey) as? Int ?? 0
        let style = prefs.object(forKey: fontStyleKey) as? Int ?? 0
        let size = prefs.object(forKey: fontSizeKey) as? Double ?? 18
        let ink = prefs.object(forKey: inkStyleKey) as? Int ?? 0
        let alignment = prefs.object(forKey: alignmentKey) as? Int ?? 0
        return DiaryDecoration(
            paper: (0...3).contains(paper) ? paper : 0,
            fontStyle: (0...3).contains(style) ? style : 0,
            fontSize: size.isFinite ? min(30, max(14, size)) : 18,
            inkStyle: (0...3).contains(ink) ? ink : 0,
            textAlignment: (0...2).contains(alignment) ? alignment : 0
        )
    }
}

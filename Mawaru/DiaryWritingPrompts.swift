import SwiftUI

// Optional prompts: playful, slightly chaotic, but never required to answer.
// Keep the editor short by showing only three at once, behind a disclosure.
struct DiaryWritingPromptPicker: View {
    @Binding var text: String
    @State private var expanded = false
    @State private var category: Category = .hard
    @State private var startIndex = 0

    private enum Category: String, CaseIterable, Identifiable {
        case daily = "日常"
        case hard = "人生ハード"
        case romance = "恋バナ"
        case chaos = "黒歴史"
        var id: String { rawValue }
    }

    private let topics: [Category: [String]] = [
        .daily: [
            "今日、いちばん笑ったことは？",
            "最近ハマっているものは？",
            "次に一緒にしたいことは？",
            "今週ちょっと嬉しかったことは？",
            "最近の小さなご褒美は？",
            "明日だけ何でもサボれるなら何する？"
        ],
        .hard: [
            "滞納したサービスは？",
            "給料日前、口座残高を見て何を思った？",
            "解約し忘れているサブスク、正直いくつ？",
            "今月いちばん後悔した課金は？",
            "通知が来ると心臓がキュッとなるアプリは？",
            "今月の『生活費、聞いてない』出費は？",
            "金欠なのに、なぜか買ってしまったものは？",
            "最近『人生、難易度設定バグってない？』と思った瞬間は？"
        ],
        .romance: [
            "好きな人への返信、何分寝かせる派？",
            "脈ありだと勘違いしたエピソードは？",
            "既読がつかない時間、最長どれくらい耐えた？",
            "デート中に『帰りたい』と思った瞬間は？",
            "理想の恋人の条件、現実的に3つ選ぶなら？",
            "恋愛の黒歴史、今なら笑える？"
        ],
        .chaos: [
            "一生消したいSNSの投稿は？",
            "過去の自分に『それは投稿するな』と言いたい瞬間は？",
            "人生でいちばん苦しい寝坊の言い訳は？",
            "大人のふりをして盛大に失敗した話は？",
            "誰にも見せたくないスクショは何の画面？",
            "最近の自分、ちょっと主人公補正なさすぎない？"
        ]
    ]

    private var visible: [String] {
        let options = topics[category] ?? []
        guard !options.isEmpty else { return [] }
        return (0..<min(3, options.count)).map { options[(startIndex + $0) % options.count] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                    Text("何を書こう？ きょうのお題")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Spacer()
                    Text("人生ハードもあるよ")
                        .font(.caption2)
                        .foregroundStyle(MawaruContrast.secondaryInk)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(MawaruContrast.ink)
            }
            .buttonStyle(.plain)

            if expanded {
                Picker("お題のジャンル", selection: $category) {
                    ForEach(Category.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: category) { _, _ in startIndex = 0 }

                Text("答えたくないお題はスルーでOK。タップすると本文に追加するよ。")
                    .font(.caption)
                    .foregroundStyle(MawaruContrast.secondaryInk)

                ForEach(visible, id: \.self) { question in
                    Button {
                        let separator = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "" : "\n\n"
                        text += separator + "♡ " + question + "\n"
                    } label: {
                        HStack(spacing: 9) {
                            Text(category == .hard ? "💸" : "💭")
                            Text(question)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Image(systemName: "plus.circle.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(MawaruContrast.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(MawaruContrast.surface,
                                    in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    let count = topics[category]?.count ?? 0
                    if count > 0 {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            startIndex = (startIndex + 3) % count
                        }
                    }
                } label: {
                    Label("別のお題を見せて", systemImage: "shuffle")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .tint(MawaruContrast.ink)
            }
        }
        .padding(14)
        .background(MawaruPastel.lemon.opacity(0.42),
                    in: RoundedRectangle(cornerRadius: 19))
    }
}

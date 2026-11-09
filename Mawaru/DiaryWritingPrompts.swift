import SwiftUI

// Lightweight optional inspiration for students; never writes until tapped.
struct DiaryWritingPromptPicker: View {
    @Binding var text: String
    @State private var expanded = false

    private let prompts = [
        "今日、いちばん笑ったことは？",
        "最近ハマっているものは？",
        "次に一緒にしたいことは？",
        "いま聞いてほしい秘密は？",
        "今週ちょっと嬉しかったことは？",
        "10年後の自分にひとこと！"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Label("何を書こう？ きょうのお題", systemImage: "lightbulb.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                }
                .foregroundStyle(MawaruPastel.ink)
            }
            .buttonStyle(.plain)
            if expanded {
                Text("気になったお題を選ぶと本文に追加されるよ。")
                    .font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
                ForEach(prompts, id: \.self) { prompt in
                    Button {
                        let separator = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "" : "\n\n"
                        text += separator + "♡ " + prompt + "\n"
                    } label: {
                        HStack(spacing: 8) {
                            Text("💭")
                            Text(prompt)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                        }
                        .font(.subheadline)
                        .foregroundStyle(MawaruPastel.ink)
                        .padding(10)
                        .background(MawaruContrast.surface,
                                    in: RoundedRectangle(cornerRadius: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(MawaruPastel.lemon.opacity(0.37),
                    in: RoundedRectangle(cornerRadius: 20))
    }
}

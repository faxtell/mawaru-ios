import SwiftUI
import UIKit

// A single UIKit text renderer is used in the editable and finished diary.
// That removes TextEditor-vs-Text glyph metrics, padding and line-height drift.
// The height is calculated from the same UITextView in both modes.
struct DiaryPageTextView: UIViewRepresentable {
    @Binding var text: String
    var decoration: DiaryDecoration
    var editable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isOpaque = false
        view.isScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 12, right: 4)
        view.textContainer.lineFragmentPadding = 0
        view.keyboardDismissMode = .interactive
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.accessibilityLabel = editable ? "日記の本文" : "完成した日記の本文"
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        view.isEditable = editable
        view.isSelectable = true
        let targetFont = DiaryFonts.uiFont(decoration)
        if view.font?.fontName != targetFont.fontName ||
           view.font?.pointSize != targetFont.pointSize {
            view.font = targetFont
        }
        view.textColor = UIColor(DiaryFonts.ink(decoration))
        view.textAlignment = DiaryFonts.uiAlignment(decoration)
        // Do not reset the caret while the user is typing Japanese with an IME.
        if view.text != text && view.markedTextRange == nil {
            view.text = text
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView,
                      context: Context) -> CGSize? {
        let width = max(120, proposal.width ?? 300)
        let measured = uiView.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: max(344, ceil(measured.height)))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DiaryPageTextView
        init(_ parent: DiaryPageTextView) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text {
                parent.text = textView.text
            }
        }
    }
}

// Identical header, title, text origin and measured text view in both modes.
// Content is never a different SwiftUI Text layout after passing the baton.
struct DiaryPageWritingContent: View {
    @Binding var title: String
    @Binding var text: String
    var decoration: DiaryDecoration
    var editable: Bool
    var author: String
    var date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(date, format: .dateTime.year().month().day())
                Spacer(minLength: 8)
                Text("from  \(author)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(MawaruPastel.ink.opacity(0.70))

            TextField("きょうのタイトル ♡", text: $title, axis: .vertical)
                .font(DiaryFonts.font(decoration,
                       size: CGFloat(decoration.fontSize + 5)))
                .foregroundStyle(DiaryFonts.ink(decoration))
                .multilineTextAlignment(DiaryFonts.alignment(decoration))
                .lineLimit(1...3)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .allowsHitTesting(editable)

            Rectangle()
                .fill(MawaruPastel.rose.opacity(0.65))
                .frame(height: 1)

            ZStack(alignment: .topLeading) {
                if editable && text.isEmpty {
                    Text("今日はどんな1日だった？\n学校・仕事・恋バナ、なんでも書いてね ♡")
                        .font(DiaryFonts.font(decoration))
                        .foregroundStyle(DiaryFonts.ink(decoration).opacity(0.42))
                        .padding(.top, 15)
                        .padding(.leading, 7)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                DiaryPageTextView(
                    text: $text, decoration: decoration, editable: editable
                )
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

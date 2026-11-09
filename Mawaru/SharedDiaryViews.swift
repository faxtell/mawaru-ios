import SwiftUI
import AuthenticationServices
import FirebaseFirestore
import UIKit

// Cloud-backed exchange diaries. The original on-device tab remains available.
struct SharedHomeScreen: View {
    @EnvironmentObject private var shared: SharedDiaryStore
    @State private var creating = false
    @State private var joining = false

    var body: some View {
        Group {
            if !shared.configured {
                ContentUnavailableView {
                    Label("共有機能の準備中", systemImage: "icloud.slash")
                } description: {
                    Text("Firebaseの接続設定を追加すると、Appleでサインインして別のiPhoneと日記を交換できます。今は「日記帳」タブでローカルデモを利用できます。")
                }
                .padding()
            } else if shared.uid == nil {
                VStack(spacing: 22) {
                    Image(systemName: "book.pages").font(.system(size: 65))
                        .foregroundStyle(DiaryStyle.ink)
                    Text("大切な人と、\n一冊をまわそう。")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .multilineTextAlignment(.center)
                    Text("招待コードでつながる、少人数の交換日記。")
                        .foregroundStyle(.secondary)
                    SignInWithAppleButton(.signIn,
                        onRequest: { shared.prepareAppleRequest($0) },
                        onCompletion: { shared.finishAppleSignIn($0) })
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 52)
                        .frame(maxWidth: 320)
                        .accessibilityLabel("Appleでサインイン")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(30)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        MawaruHomeHeader(
                            headline: "ふたりで1冊、\nひみつの日記帳 ♡",
                            subtitle: "ゆるく、かわいく。大切な人にバトンを渡そう。"
                        )
                        Text("サインイン中：\(shared.displayName)")
                            .foregroundStyle(.secondary)
                        if shared.books.isEmpty {
                            ContentUnavailableView("共有日記はまだありません",
                                systemImage: "book.closed",
                                description: Text("日記帳を作るか、届いた招待コードで参加してね。"))
                        }
                        ForEach(shared.books) { book in
                            NavigationLink {
                                SharedBookScreen(bookID: book.id)
                            } label: {
                                HStack(spacing: 16) {
                                    SharedCover(book: book)
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(book.title).font(.headline).foregroundStyle(.primary)
                                        Text(book.paused ? "おやすみ中" :
                                            book.memberIDs.count < 2 ? "相手の参加待ち" :
                                            book.isMyTurn(shared.uid) ? "あなたの番です ✨" :
                                            "\(book.currentWriter)の番です")
                                            .font(.subheadline).foregroundStyle(.secondary)
                                        Text("\(book.memberIDs.count)人・共有中")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .padding(15)
                                .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 22))
                            }.buttonStyle(.plain)
                        }
                        Button { creating = true } label: {
                            Label("新しい共有日記を作る", systemImage: "plus")
                                .frame(maxWidth: .infinity).padding(13)
                        }.buttonStyle(.borderedProminent).tint(DiaryStyle.ink)
                        Button { joining = true } label: {
                            Label("招待コードから参加", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity).padding(11)
                        }.buttonStyle(.bordered)
                        Text("共有日記は参加者だけが閲覧できます。文章とシール・紙のデザインを同期。写真・通知は次の段階で対応します。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }.padding(20)
                }
                .background(DiaryStyle.background.opacity(0.55))
            }
        }
        .navigationTitle("共有日記")
        .sheet(isPresented: $creating) { SharedCreateScreen() }
        .sheet(isPresented: $joining) { SharedJoinScreen() }
        .alert("共有機能のエラー",
               isPresented: Binding(
                get: { shared.errorMessage != nil },
                set: { if !$0 { shared.errorMessage = nil } })
        ) {
            Button("OK") { shared.errorMessage = nil }
        } message: {
            Text(shared.errorMessage ?? "")
        }
    }
}

private struct SharedCover: View {
    let book: SharedBook
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(DiaryStyle.colors[max(0, book.cover) % DiaryStyle.colors.count])
            .overlay {
                VStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                    Text(book.title).font(.system(size: 10, weight: .semibold, design: .serif))
                        .lineLimit(3).multilineTextAlignment(.center)
                }.foregroundStyle(.white).padding(5)
            }
            .frame(width: 74, height: 95)
            .accessibilityLabel("共有日記帳 \(book.title)")
    }
}

struct SharedCreateScreen: View {
    @EnvironmentObject private var shared: SharedDiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var name = "わたし"
    @State private var cover = 0
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("日記帳") {
                    TextField("例：ふたりの交換日記", text: $title)
                        .textInputAutocapitalization(.never)
                    TextField("日記に表示する名前", text: $name)
                }
                Section("表紙の色") {
                    HStack {
                        ForEach(0..<DiaryStyle.colors.count, id: \.self) { index in
                            Button { cover = index } label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(DiaryStyle.colors[index]).frame(height: 55)
                                    .overlay {
                                        if cover == index {
                                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.white)
                                        }
                                    }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Text("作成後に招待コードを送ります。相手が参加するまでは投稿できません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("共有日記を作る")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "作成中" : "作成") {
                        busy = true
                        Task {
                            do {
                                try await shared.createBook(title: title, cover: cover, name: name)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    }
                    .disabled(busy || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              title.count > 60 || name.count > 30)
                }
            }
            .onAppear { name = shared.displayName }
            .alert("作成できませんでした", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

struct SharedJoinScreen: View {
    @EnvironmentObject private var shared: SharedDiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var name = "わたし"
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("招待コード") {
                    TextField("24文字のコード", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Text("招待コードは7日間有効・1回限りです。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("名前") {
                    TextField("日記に表示する名前", text: $name)
                }
                Section {
                    Button(busy ? "参加中…" : "この日記帳に参加する") {
                        busy = true
                        Task {
                            do {
                                try await shared.join(code: code, name: name)
                                dismiss()
                            } catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    }
                    .disabled(busy || code.trimmingCharacters(in: .whitespacesAndNewlines).count != 24 ||
                              name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("招待から参加")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
            .onAppear { name = shared.displayName }
            .alert("参加できませんでした", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

struct SharedBookScreen: View {
    @EnvironmentObject private var shared: SharedDiaryStore
    let bookID: String
    @State private var pages: [SharedPage] = []
    @State private var listener: ListenerRegistration?
    @State private var editing = false
    @State private var inviteCode: String?
    @State private var busy = false
    @State private var error: String?

    private var book: SharedBook? { shared.books.first { $0.id == bookID } }

    var body: some View {
        ScrollView {
            if let book {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .center, spacing: 20) {
                        SharedCover(book: book)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(book.title).font(.system(.title2, design: .serif, weight: .bold))
                            Text(book.paused ? "おやすみ中" :
                                book.memberIDs.count < 2 ? "相手の参加を待っています" :
                                book.isMyTurn(shared.uid) ? "あなたの番です ✨" :
                                "\(book.currentWriter)の番です")
                                .foregroundStyle(DiaryStyle.ink)
                        }
                    }
                    VStack(alignment: .leading, spacing: 11) {
                        Text("バトンの順番").font(.headline)
                        ForEach(book.memberNames.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: index == book.currentTurn ? "circle.inset.filled" : "circle")
                                Text(book.memberNames[index])
                                if book.memberIDs[index] == shared.uid {
                                    Text("あなた").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if index == book.currentTurn { Text("執筆担当").font(.caption) }
                            }
                        }
                    }.padding(16)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    if book.isMyTurn(shared.uid) {
                        Button { editing = true } label: {
                            Label("日記を書いて渡す", systemImage: "pencil.line")
                                .frame(maxWidth: .infinity).padding(13)
                        }.buttonStyle(.borderedProminent).tint(DiaryStyle.ink)
                    }
                    Button {
                        busy = true
                        Task {
                            do { inviteCode = try await shared.createInvite(bookID: bookID) }
                            catch { self.error = error.localizedDescription }
                            busy = false
                        }
                    } label: {
                        Label(busy ? "作成中…" : "招待コードを発行する", systemImage: "person.badge.plus")
                    }.disabled(busy || book.memberIDs.count >= 5)
                    Text("ページ \(pages.count)件（最新100件を表示）").font(.headline)
                    if pages.isEmpty {
                        ContentUnavailableView("まだ白紙の一冊", systemImage: "book.closed")
                    } else {
                        ForEach(pages) { page in
                            NostalgicNotebookReadPage(
                                title: page.title, text: page.body,
                                author: page.author, date: page.createdAt,
                                decoration: page.decoration,
                                cloudLocation: DiaryCloudPhotoLocation(
                                    bookID: bookID, entryID: page.id, authorID: page.authorID
                                )
                            )
                        }
                    }
                }.padding(18)
            } else {
                ContentUnavailableView("日記帳が見つかりません", systemImage: "book.closed")
            }
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle(book?.title ?? "共有日記")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let book, book.ownerID == shared.uid {
                    Button(book.paused ? "再開" : "休止") {
                        Task {
                            do { try await shared.setPaused(bookID: bookID, paused: !book.paused) }
                            catch { self.error = error.localizedDescription }
                        }
                    }
                }
            }
        }
        .onAppear {
            listener?.remove()
            listener = shared.listenToPages(bookID: bookID) { pages = $0 }
        }
        .onDisappear {
            listener?.remove()
            listener = nil
        }
        .sheet(isPresented: $editing) { SharedEditorScreen(bookID: bookID) }
        .sheet(item: Binding<InviteSheet?>(
            get: { inviteCode.map { InviteSheet(code: $0) } },
            set: { inviteCode = $0?.code }
        )) { item in
            NavigationStack {
                VStack(spacing: 22) {
                    Image(systemName: "envelope.open.fill")
                        .font(.system(size: 50)).foregroundStyle(DiaryStyle.ink)
                    Text("大切な人に招待を送ろう").font(.title2.bold())
                    Text(item.code).font(.system(.title3, design: .monospaced))
                        .textSelection(.enabled)
                    ShareLink(item: "「まわる」で交換日記を一緒に書こう！\n招待コード：\(item.code)\nアプリの「共有日記」→「招待コードから参加」で入力してね。") {
                        Label("招待コードを共有", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.borderedProminent).tint(DiaryStyle.ink)
                    Button("コードをコピー") { UIPasteboard.general.string = item.code }
                    Text("7日間有効・先着1名が参加できます。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding()
                .navigationTitle("招待")
                .toolbar { ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { inviteCode = nil }
                }}
            }
            .presentationDetents([.medium, .large])
        }
        .alert("操作できませんでした", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }
}
private struct InviteSheet: Identifiable {
    let code: String
    var id: String { code }
}

struct SharedEditorScreen: View {
    @EnvironmentObject private var shared: SharedDiaryStore
    @Environment(\.dismiss) private var dismiss
    let bookID: String
    @State private var title = ""
    @State private var bodyText = ""
    @State private var requestID = UUID().uuidString
    @State private var decoration = DiaryDecoration()
    @State private var preview = false
    @State private var showTextTools = false
    @State private var confirmPass = false
    @State private var ready = false
    @State private var busy = false
    @State private var error: String?

    private var key: String {
        "mawaru.shared.draft.\(shared.uid ?? "unknown").\(bookID)"
    }
    private func saveDraft() {
        guard ready else { return }
        let decorationData = (try? JSONEncoder().encode(decoration)) ?? Data()
        UserDefaults.standard.set(["title": title, "body": bodyText, "id": requestID,
                                   "decoration": decorationData] as [String: Any], forKey: key)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    MawaruSectionLabel(step: "01", title: "きょうのノート", symbol: "pencil.and.scribble")
                    HStack {
                        Spacer()
                        Button {
                            preview.toggle()
                            saveDraft()
                        } label: {
                            Label(preview ? "編集に戻る" : "完成プレビュー",
                                  systemImage: preview ? "pencil" : "eye")
                        }
                        .buttonStyle(.bordered)
                        .tint(DiaryStyle.ink)
                    }
                    if preview {
                        NostalgicNotebookReadPage(
                            title: title, text: bodyText,
                            author: shared.displayName,
                            date: .now, decoration: decoration
                        )
                    } else {
                        NostalgicNotebookEditor(
                            title: $title, text: $bodyText, decoration: $decoration,
                            author: shared.displayName
                        )
                        .onChange(of: title) { _, _ in saveDraft() }
                        .onChange(of: bodyText) { _, _ in saveDraft() }
                    }
                    DisclosureGroup(isExpanded: $showTextTools) {
                        DiaryTypographyControls(
                            decoration: $decoration, resetToSavedPreference: true
                        )
                        .padding(.top, 8)
                    } label: {
                        MawaruSectionLabel(step: "02",
                            title: "このページだけ文字を変更", symbol: "textformat")
                    }
                    .tint(DiaryStyle.ink)
                    .onChange(of: decoration) { _, _ in saveDraft() }
                    MawaruSectionLabel(step: "03", title: "好きなシールを貼ろう", symbol: "sparkles")
                    DiaryDecorationEditor(decoration: $decoration, showsPreview: false)
                    Text("送信するとページは参加メンバー全員に公開され、順番が次の人に移ります。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("写真・コピーした画像も最大4枚まで貼れて、共有すると相手にも表示されます。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(18)
            }
            .background(DiaryStyle.background.opacity(0.55))
            .navigationTitle("きょうの交換日記")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { saveDraft(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "送信中" : "次へ渡す") {
                        saveDraft()
                        confirmPass = true
                    }
                    .disabled(busy ||
                              (bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                               decoration.photos.isEmpty) ||
                              bodyText.count > 5000 || title.count > 80)
                }
            }
            .onAppear {
                if let draft = UserDefaults.standard.dictionary(forKey: key) {
                    title = draft["title"] as? String ?? ""
                    bodyText = draft["body"] as? String ?? ""
                    requestID = draft["id"] as? String ?? UUID().uuidString
                    if let data = draft["decoration"] as? Data,
                       let saved = try? JSONDecoder().decode(DiaryDecoration.self, from: data) {
                        decoration = saved
                    } else {
                        decoration = DiaryTypographyPreferences.load()
                    }
                } else {
                    decoration = DiaryTypographyPreferences.load()
                }
                ready = true
            }
            .confirmationDialog("このページを次の人へ渡す？",
                                isPresented: $confirmPass) {
                Button("デコったページを渡す ♡") {
                    guard !busy else { return }
                    busy = true
                    saveDraft()
                    Task {
                        do {
                            try await shared.submit(bookID: bookID,
                                requestID: requestID, title: title, body: bodyText,
                                decoration: decoration)
                            UserDefaults.standard.removeObject(forKey: key)
                            dismiss()
                        } catch {
                            self.error = error.localizedDescription
                        }
                        busy = false
                    }
                }
            } message: {
                Text("送信すると、メンバーに公開されて次の人の番になります。")
            }
            .alert("日記を渡せませんでした", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } })) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

import SwiftUI
import PhotosUI
import UIKit

// MARK: - Local demo models (no multi-device sharing yet)
struct DiaryBook: Codable, Identifiable {
    var id = UUID()
    var title: String
    var members: [String]
    var cover: Int
    var createdAt = Date()
    var turnIndex = 0
    var activeMemberIndex = 0
    var paused = false
    var demoCode = String(UUID().uuidString.prefix(8))
    var currentWriter: String { members.indices.contains(turnIndex) ? members[turnIndex] : "―" }
    var isMyTurn: Bool { !paused && turnIndex == activeMemberIndex }
}

struct DiaryEntry: Codable, Identifiable {
    var id = UUID()
    var bookID: UUID
    var author: String
    var title: String
    var text: String
    var date = Date()
    var photoFilename: String?
    var decoration: DiaryDecoration?
    var hearted = false
    var favorite = false
}

struct DiaryDraft: Codable {
    var title: String
    var text: String
    var decoration: DiaryDecoration?
}

final class DiaryStore: ObservableObject {
    @Published var books: [DiaryBook] = [] { didSet { save() } }
    @Published var entries: [DiaryEntry] = [] { didSet { save() } }

    private var folder: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Mawaru", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    private struct Archive: Codable { var books: [DiaryBook]; var entries: [DiaryEntry] }
    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let file = base.appendingPathComponent("Mawaru").appendingPathComponent("diary.json")
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder().decode(Archive.self, from: data) {
            books = saved.books
            entries = saved.entries
        }
    }
    private func save() {
        let data = try? JSONEncoder().encode(Archive(books: books, entries: entries))
        if let data { try? data.write(to: folder.appendingPathComponent("diary.json"), options: .atomic) }
    }
    func addBook(title: String, members: [String], cover: Int) {
        let names = members.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard (2...5).contains(names.count), names.allSatisfy({ !$0.isEmpty }) else { return }
        books.insert(DiaryBook(title: title.trimmingCharacters(in: .whitespacesAndNewlines), members: names, cover: cover), at: 0)
    }
    func pages(of id: UUID) -> [DiaryEntry] {
        entries.filter { $0.bookID == id }.sorted { $0.date > $1.date }
    }
    func setActive(bookID: UUID, index: Int) {
        guard let i = books.firstIndex(where: { $0.id == bookID }), books[i].members.indices.contains(index) else { return }
        books[i].activeMemberIndex = index
    }
    func togglePause(_ id: UUID) {
        guard let i = books.firstIndex(where: { $0.id == id }) else { return }
        books[i].paused.toggle()
    }
    @discardableResult func submit(bookID: UUID, title: String, text: String, photo: Data?, decoration: DiaryDecoration = DiaryDecoration()) -> Bool {
        guard let i = books.firstIndex(where: { $0.id == bookID }), books[i].isMyTurn,
              (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
               photo != nil || !decoration.photos.isEmpty) else { return false }
        let author = books[i].currentWriter
        var item = DiaryEntry(bookID: bookID, author: author, title: title, text: text)
        item.decoration = decoration
        if let photo {
            let filename = item.id.uuidString + ".jpg"
            do {
                try photo.write(to: folder.appendingPathComponent(filename), options: .atomic)
                item.photoFilename = filename
            } catch { return false }
        }
        entries.insert(item, at: 0)
        books[i].turnIndex = (books[i].turnIndex + 1) % books[i].members.count
        return true
    }
    func image(for entry: DiaryEntry) -> UIImage? {
        guard let filename = entry.photoFilename,
              let data = try? Data(contentsOf: folder.appendingPathComponent(filename)) else { return nil }
        return UIImage(data: data)
    }
    func heart(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].hearted.toggle()
    }
    func favorite(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].favorite.toggle()
    }
    func exportJSON() -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(Archive(books: books, entries: entries)) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
    func eraseAll() {
        let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
        for folderName in ["Mawaru", "MawaruClippings", "MawaruDraftAttachments"] {
            try? FileManager.default.removeItem(
                at: applicationSupport.appendingPathComponent(folderName, isDirectory: true)
            )
        }
        for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix("mawaru.draft.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        books = []
        entries = []
    }
}

enum DiaryStyle {
    static let background = MawaruPastel.background
    static let ink = MawaruPastel.ink
    static let blush = MawaruPastel.rose
    static let colors: [Color] = [
        MawaruPastel.rose, MawaruPastel.mint,
        MawaruPastel.lavender, MawaruPastel.lemon
    ]
}

@main struct MawaruApp: App {
    @StateObject private var store = DiaryStore()
    @StateObject private var shared = SharedDiaryStore()
    @StateObject private var nearby = NearbyDiaryStore()
    init() {
        DiaryFonts.register()
    }
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { ExchangeHomeScreen() }
                    .tabItem { Label("交換する", systemImage: "arrow.left.arrow.right.circle.fill") }
                NavigationStack { MemoriesScreen() }
                    .tabItem { Label("思い出", systemImage: "heart.text.square") }
                NavigationStack { SettingsScreen() }
                    .tabItem { Label("設定", systemImage: "gearshape") }
            }
            .tint(DiaryStyle.ink)
            .environmentObject(store)
            .environmentObject(shared)
            .environmentObject(nearby)
        }
    }
}

struct BookCover: View {
    let book: DiaryBook
    var small = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 17).fill(DiaryStyle.colors[abs(book.cover) % DiaryStyle.colors.count].gradient)
                .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.85), lineWidth: 2) }
                .shadow(color: .black.opacity(0.10), radius: 7, y: 5)
            HStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.28)).frame(width: 8)
                Spacer()
            }.padding(.leading, 12)
            VStack(spacing: 8) {
                Text("my secret diary")
                    .font(.system(size: small ? 8 : 10, weight: .black, design: .rounded))
                Image(systemName: "heart.text.square.fill").font(small ? .title3 : .largeTitle)
                Text(book.title).font(.system(size: small ? 12 : 17, weight: .bold, design: .rounded))
                    .lineLimit(2).multilineTextAlignment(.center).padding(.horizontal, 8)
            }.foregroundStyle(DiaryStyle.ink)
        }
        .frame(width: small ? 75 : 115, height: small ? 100 : 150)
        .accessibilityLabel("日記帳の表紙、\(book.title)")
    }
}

struct HomeScreen: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var creating = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("日記帳")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(MawaruContrast.ink)
                Button { creating = true } label: {
                    Label("新しい日記帳を作る", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(DiaryStyle.ink)
                if store.books.isEmpty {
                    Label("まだ日記帳はありません。最初の1冊を作ろう。",
                          systemImage: "book.closed")
                        .font(.footnote)
                        .foregroundStyle(MawaruContrast.secondaryInk)
                        .padding(15)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(MawaruContrast.surface,
                                    in: RoundedRectangle(cornerRadius: 16))
                }
                ForEach(store.books) { book in
                    NavigationLink {
                        BookScreen(bookID: book.id)
                    } label: {
                        HStack(spacing: 18) {
                            BookCover(book: book, small: true)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title).font(.headline).foregroundStyle(MawaruContrast.ink)
                                Text(book.paused ? "おやすみ中" : (book.isMyTurn ? "あなたの番です ✨" : "\(book.currentWriter)の番です"))
                                    .font(.subheadline)
                                    .foregroundStyle(book.isMyTurn ? DiaryStyle.ink : .secondary)
                                Text("\(store.pages(of: book.id).count)ページ・\(book.members.count)人")
                                    .font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(MawaruContrast.surface, in: RoundedRectangle(cornerRadius: 23))
                    }.buttonStyle(.plain)
                }
                Text("この端末だけで試すデモモードです。")
                    .font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
            }.padding(20)
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle("まわる")
        .sheet(isPresented: $creating) { CreateBookScreen() }
    }
}

struct CreateBookScreen: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var members = ["わたし", "あなた"]
    @State private var cover = 0
    var body: some View {
        NavigationStack {
            Form {
                Section("日記帳の名前") {
                    TextField("例：ふたりの交換日記", text: $title)
                }
                Section("表紙") {
                    HStack {
                        ForEach(0..<4, id: \.self) { i in
                            Button { cover = i } label: {
                                RoundedRectangle(cornerRadius: 10).fill(DiaryStyle.colors[i])
                                    .frame(height: 58)
                                    .overlay { if cover == i { Image(systemName: "checkmark.circle.fill").foregroundStyle(MawaruContrast.ink) } }
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 8)
                }
                Section("メンバー（2〜5人）") {
                    ForEach(members.indices, id: \.self) { i in
                        TextField("メンバー\(i + 1)", text: $members[i])
                    }
                    HStack {
                        if members.count < 5 {
                            Button("メンバーを追加") { members.append("") }
                        }
                        Spacer()
                        if members.count > 2 {
                            Button("最後を削除", role: .destructive) { members.removeLast() }
                        }
                    }
                }
                Section {
                    Text("この日記帳は端末内で交換を試すモードです。実際の招待は「共有」タブから行えます。")
                        .font(.footnote).foregroundStyle(MawaruContrast.secondaryInk)
                }
            }
            .navigationTitle("新しい日記帳")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        store.addBook(title: title, members: members, cover: cover)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              members.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
                }
            }
        }
    }
}

struct BookScreen: View {
    @EnvironmentObject private var store: DiaryStore
    let bookID: UUID
    @State private var editing = false
    @State private var showingDemoCode = false
    private var book: DiaryBook? { store.books.first(where: { $0.id == bookID }) }
    var body: some View {
        ScrollView {
            if let book {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 13) {
                        BookCover(book: book, small: true)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(book.title).font(.title2.bold())
                            Text("\(book.members.count)人でつづる交換日記")
                                .font(.subheadline).foregroundStyle(MawaruContrast.secondaryInk)
                            Text(book.paused ? "おやすみ中" : (book.isMyTurn ? "あなたの番です" : "\(book.currentWriter)の番です"))
                                .font(.headline).foregroundStyle(DiaryStyle.ink)
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("バトンの順番").font(.headline)
                        ScrollView(.horizontal) {
                            HStack(spacing: 12) {
                                ForEach(book.members.indices, id: \.self) { i in
                                    VStack(spacing: 5) {
                                        ZStack {
                                            Circle().fill(i == book.turnIndex ? DiaryStyle.blush : Color.gray.opacity(0.15))
                                            Text(String(book.members[i].prefix(1))).font(.headline)
                                        }.frame(width: 52, height: 52)
                                            .overlay { Circle().stroke(i == book.activeMemberIndex ? DiaryStyle.ink : .clear, lineWidth: 2) }
                                        Text(book.members[i]).font(.caption).lineLimit(1)
                                    }.frame(width: 75)
                                }
                            }
                        }
                        Menu {
                            ForEach(book.members.indices, id: \.self) { i in
                                Button(book.members[i]) { store.setActive(bookID: bookID, index: i) }
                            }
                        } label: {
                            Label("操作する人：\(book.members[book.activeMemberIndex])（デモ）", systemImage: "person.crop.circle")
                                .font(.footnote)
                        }
                    }.padding(16).background(MawaruContrast.surface, in: RoundedRectangle(cornerRadius: 18))
                    if book.isMyTurn {
                        Button { editing = true } label: {
                            Label("日記を書いて、次の人へ渡す", systemImage: "pencil.line")
                                .font(.headline).frame(maxWidth: .infinity).padding(14)
                        }.buttonStyle(.borderedProminent).tint(DiaryStyle.ink)
                    } else {
                        Label(book.paused ? "この日記帳はおやすみ中です" : "\(book.currentWriter)が書くのを待っています",
                              systemImage: "hourglass")
                            .foregroundStyle(MawaruContrast.secondaryInk)
                    }
                    HStack {
                        Text("ページをめくろう").font(.title3.bold())
                        Spacer()
                        Text("\(store.pages(of: bookID).count)ページ")
                            .foregroundStyle(MawaruContrast.secondaryInk)
                    }
                    if store.pages(of: bookID).isEmpty {
                        Label("まだ白紙の一冊。最初のページを書いてみよう。",
                              systemImage: "text.book.closed")
                            .font(.footnote)
                            .foregroundStyle(MawaruContrast.secondaryInk)
                            .padding(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(MawaruContrast.surface,
                                        in: RoundedRectangle(cornerRadius: 15))
                    } else {
                        ForEach(store.pages(of: bookID)) { page in
                            NavigationLink { DiaryPageScreen(entryID: page.id) } label: {
                                DiaryCompactPageRow(
                                    pageNumber: store.pages(of: bookID)
                                        .sorted { $0.date < $1.date }
                                        .firstIndex(where: { $0.id == page.id })
                                        .map { $0 + 1 } ?? 1,
                                    title: page.title, author: page.author,
                                    excerpt: page.text, date: page.date,
                                    stickerCount: page.decoration?.stickers.count ?? 0,
                                    photoCount: (page.decoration?.photos.count ?? 0) +
                                        (page.photoFilename == nil ? 0 : 1)
                                )
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(18)
            }
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle(book?.title ?? "日記帳")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if let book {
                    Menu {
                        Button("招待コード（デモ）", systemImage: "person.badge.plus") { showingDemoCode = true }
                        Button(book.paused ? "再開する" : "おやすみする", systemImage: book.paused ? "play" : "pause") {
                            store.togglePause(bookID)
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
        }
        .sheet(isPresented: $editing) { DiaryEditorScreen(bookID: bookID) }
        .alert("招待コード（デモ）", isPresented: $showingDemoCode) {
            Button("コピー") {
                UIPasteboard.general.string = book?.demoCode
            }
            Button("閉じる", role: .cancel) {}
        } message: {
            Text("\(book?.demoCode ?? "")\nこの番号は実際の招待には利用できません。")
        }
    }
}

struct DiaryEditorScreen: View {
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss
    let bookID: UUID
    @State private var title = ""
    @State private var text = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photo: Data?
    @State private var ready = false
    @State private var failed = false
    @State private var decoration = DiaryDecoration()
    @State private var preview = false
    @State private var showTextTools = false
    @State private var confirmPass = false
    private var draftKey: String { "mawaru.draft.\(bookID.uuidString)" }
    private func saveDraft() {
        guard ready else { return }
        if let data = try? JSONEncoder().encode(DiaryDraft(title: title, text: text, decoration: decoration)) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    MawaruSectionLabel(step: "01", title: "ノートに書こう", symbol: "pencil.and.scribble")
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
                            title: title, text: text,
                            author: store.books.first(where: { $0.id == bookID })?.currentWriter ?? "わたし",
                            date: .now, decoration: decoration,
                            attachedPhoto: photo.flatMap { UIImage(data: $0) },
                            bookTitle: store.books.first(where: { $0.id == bookID })?.title ?? "交換日記",
                            pageNumber: store.pages(of: bookID).count + 1,
                            exchangeMode: "おためし"
                        )
                    } else {
                        NostalgicNotebookEditor(
                            title: $title, text: $text, decoration: $decoration,
                            author: store.books.first(where: { $0.id == bookID })?.currentWriter ?? "わたし",
                            bookTitle: store.books.first(where: { $0.id == bookID })?.title ?? "交換日記",
                            pageNumber: store.pages(of: bookID).count + 1,
                            exchangeMode: "おためし"
                        )
                        .onChange(of: title) { _, _ in saveDraft() }
                        .onChange(of: text) { _, _ in saveDraft() }
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
                    DiaryWritingPromptPicker(text: $text)
                    MawaruSectionLabel(step: "03", title: "写真とシールでデコろう", symbol: "sparkles")
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxHeight: 240)
                        Button("写真を取り消す", role: .destructive) {
                            self.photo = nil
                            DiaryDraftAttachmentStorage.remove(bookID: bookID)
                        }
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("写真を1枚添える", systemImage: "photo.badge.plus")
                    }
                    DiaryDecorationEditor(decoration: $decoration, showsPreview: false)
                    HStack {
                        Text("本文 \(text.count)/5000文字")
                        Spacer()
                        Text("タイトル \(title.count)/80文字")
                    }
                    .font(.caption)
                    .foregroundStyle(text.count > 5000 || title.count > 80 ? Color.red : Color.secondary)
                    Text("シールは文字の上にも貼れるよ。完成したらバトンを渡そう ♡")
                        .font(.footnote).foregroundStyle(MawaruContrast.secondaryInk)
                }.padding(18)
            }
            .background(DiaryStyle.background.opacity(0.55))
            .navigationTitle("きょうの交換日記")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { saveDraft(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("次へ渡す") {
                        saveDraft()
                        confirmPass = true
                    }
                    .fontWeight(.semibold)
                    .disabled((text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                               photo == nil && decoration.photos.isEmpty) ||
                              text.count > 5000 || title.count > 80)
                }
            }
            .onAppear {
                photo = DiaryDraftAttachmentStorage.load(bookID: bookID)
                if let data = UserDefaults.standard.data(forKey: draftKey),
                   let draft = try? JSONDecoder().decode(DiaryDraft.self, from: data) {
                    title = draft.title
                    text = draft.text
                    decoration = draft.decoration ?? DiaryTypographyPreferences.load()
                } else {
                    decoration = DiaryTypographyPreferences.load()
                }
                ready = true
            }
            .confirmationDialog("このページを次の人へ渡す？",
                                isPresented: $confirmPass) {
                Button("デコったページを渡す ♡") {
                    if store.submit(bookID: bookID, title: title, text: text,
                                    photo: photo, decoration: decoration) {
                        UserDefaults.standard.removeObject(forKey: draftKey)
                        DiaryDraftAttachmentStorage.remove(bookID: bookID)
                        dismiss()
                    } else {
                        failed = true
                    }
                }
            } message: {
                Text("一度渡すとこのページは編集できないよ。")
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       data.count <= 8_000_000,
                       let image = UIImage(data: data),
                       let jpeg = image.jpegData(compressionQuality: 0.75),
                       jpeg.count <= 8_000_000 {
                        do {
                            try DiaryDraftAttachmentStorage.save(jpeg, bookID: bookID)
                            photo = jpeg
                        } catch {
                            failed = true
                        }
                    } else if item != nil { failed = true }
                }
            }
            .alert("保存できませんでした", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: { Text("写真は8MB以下にしてください。空き容量も確認してください。") }
        }
    }
}

struct DiaryPageScreen: View {
    @EnvironmentObject private var store: DiaryStore
    let entryID: UUID
    private var page: DiaryEntry? { store.entries.first(where: { $0.id == entryID }) }
    var body: some View {
        ScrollView {
            if let page {
                VStack(alignment: .leading, spacing: 19) {
                    NostalgicNotebookReadPage(
                        title: page.title, text: page.text, author: page.author,
                        date: page.date, decoration: page.decoration ?? DiaryDecoration(),
                        attachedPhoto: store.image(for: page),
                        bookTitle: store.books.first(where: { $0.id == page.bookID })?.title ?? "交換日記",
                        pageNumber: store.pages(of: page.bookID).sorted { $0.date < $1.date }
                            .firstIndex(where: { $0.id == page.id }).map { $0 + 1 },
                        exchangeMode: "おためし"
                    )
                    Divider()
                    HStack {
                        Button { store.heart(entryID) } label: {
                            Label(page.hearted ? "ありがとう" : "ハート", systemImage: page.hearted ? "heart.fill" : "heart")
                        }
                        Spacer()
                        Button { store.favorite(entryID) } label: {
                            Label(page.favorite ? "保存済み" : "お気に入り",
                                  systemImage: page.favorite ? "bookmark.fill" : "bookmark")
                        }
                    }.buttonStyle(.bordered).tint(DiaryStyle.ink)
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle("日記のページ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MemoriesScreen: View {
    @EnvironmentObject private var store: DiaryStore
    @State private var search = ""
    private var results: [DiaryEntry] {
        let all = store.entries.sorted { $0.date > $1.date }
        return search.isEmpty ? all : all.filter {
            $0.title.localizedCaseInsensitiveContains(search) ||
            $0.text.localizedCaseInsensitiveContains(search) ||
            $0.author.localizedCaseInsensitiveContains(search)
        }
    }
    var body: some View {
        List {
            if results.isEmpty {
                ContentUnavailableView("思い出はこれから", systemImage: "heart.text.square")
            }
            ForEach(results) { page in
                NavigationLink {
                    DiaryPageScreen(entryID: page.id)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(page.title.isEmpty ? "無題のページ" : page.title).font(.headline)
                        Text(page.text).lineLimit(2).font(.subheadline).foregroundStyle(MawaruContrast.secondaryInk)
                        Text("\(page.author)・\(page.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
                    }.padding(.vertical, 5)
                }
            }
        }
        .searchable(text: $search, prompt: "日記を検索")
        .navigationTitle("思い出")
    }
}

struct SettingsScreen: View {
    @EnvironmentObject private var store: DiaryStore
    @AppStorage(DiaryTypographyPreferences.paperKey) private var defaultPaper = 0
    @AppStorage(DiaryTypographyPreferences.fontStyleKey) private var defaultFontStyle = 0
    @AppStorage(DiaryTypographyPreferences.fontSizeKey) private var defaultFontSize = 18.0
    @AppStorage(DiaryTypographyPreferences.inkStyleKey) private var defaultInkStyle = 0
    @AppStorage(DiaryTypographyPreferences.alignmentKey) private var defaultAlignment = 0
    @State private var confirmErase = false

    private var typographyBinding: Binding<DiaryDecoration> {
        Binding(
            get: {
                DiaryDecoration(
                    paper: defaultPaper,
                    fontStyle: defaultFontStyle, fontSize: defaultFontSize,
                    inkStyle: defaultInkStyle, textAlignment: defaultAlignment
                )
            },
            set: { value in
                defaultPaper = value.paper
                defaultFontStyle = value.fontStyle
                defaultFontSize = value.fontSize
                defaultInkStyle = value.inkStyle
                defaultAlignment = value.textAlignment
            }
        )
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("いつもの文字を選ぼう ♡")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Text("ここで選んだフォント・大きさ・色は、これから書く日記に自動で使われます。毎回選び直す必要はないよ。")
                        .font(.footnote).foregroundStyle(MawaruContrast.secondaryInk)
                    Picker("いつものノート用紙", selection: $defaultPaper) {
                        Text("クリーム").tag(0)
                        Text("さくら").tag(1)
                        Text("ミント").tag(2)
                        Text("ラベンダー").tag(3)
                    }
                    .pickerStyle(.segmented)
                    DiaryTypographyControls(decoration: typographyBinding)
                    Text("きょうも楽しい一日になりますように。")
                        .font(DiaryFonts.font(typographyBinding.wrappedValue))
                        .foregroundStyle(DiaryFonts.ink(typographyBinding.wrappedValue))
                        .multilineTextAlignment(DiaryFonts.alignment(typographyBinding.wrappedValue))
                        .frame(maxWidth: .infinity)
                        .padding(15)
                        .background(MawaruPastel.lemon.opacity(0.28),
                                    in: RoundedRectangle(cornerRadius: 14))
                    Text("過去の日記や保存中の下書きの文字設定は変わりません。日記を書いている途中でも、そのページだけ変更できます。")
                        .font(.caption).foregroundStyle(MawaruContrast.secondaryInk)
                }
                .padding(.vertical, 6)
            } header: {
                Label("日記の標準フォント・文字設定", systemImage: "character.cursor.ibeam")
            }
            Section("アプリについて") {
                LabeledContent("アプリ名", value: "まわる")
                LabeledContent("バージョン", value: "0.7.0")
                LabeledContent("ローカル日記", value: "このiPhone内")
            }
            Section("データ管理") {
                ShareLink(item: store.exportJSON()) {
                    Label("日記データをテキストで共有", systemImage: "square.and.arrow.up")
                }
                Button("この端末の日記データを削除", role: .destructive) {
                    confirmErase = true
                }
            }
            Section {
                Text("ローカル日記の画像はこのiPhone内に保存されます。共有日記はFirebaseを設定した場合のみ使えます。エクスポートには画像本体を含みません。")
                    .font(.footnote).foregroundStyle(MawaruContrast.secondaryInk)
            }
        }
        .scrollContentBackground(.hidden)
        .background(DiaryStyle.background.opacity(0.45))
        .navigationTitle("設定")
        .confirmationDialog("すべての日記を削除しますか？", isPresented: $confirmErase) {
            Button("すべて削除", role: .destructive) { store.eraseAll() }
        } message: {
            Text("この端末の日記データを削除します。元には戻せません。")
        }
    }
}

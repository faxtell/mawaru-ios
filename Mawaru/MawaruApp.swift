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
        try? FileManager.default.removeItem(at: folder)
        books = []
        entries = []
    }
}

enum DiaryStyle {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.94)
    static let ink = Color(red: 0.41, green: 0.32, blue: 0.29)
    static let blush = Color(red: 0.94, green: 0.76, blue: 0.72)
    static let colors: [Color] = [
        Color(red: 0.93, green: 0.66, blue: 0.63),
        Color(red: 0.70, green: 0.78, blue: 0.67),
        Color(red: 0.76, green: 0.74, blue: 0.89),
        Color(red: 0.75, green: 0.82, blue: 0.89)
    ]
}

@main struct MawaruApp: App {
    @StateObject private var store = DiaryStore()
    @StateObject private var shared = SharedDiaryStore()
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { HomeScreen() }
                    .tabItem { Label("日記帳", systemImage: "books.vertical.fill") }
                NavigationStack { SharedHomeScreen() }
                    .tabItem { Label("共有", systemImage: "person.2.fill") }
                NavigationStack { MemoriesScreen() }
                    .tabItem { Label("思い出", systemImage: "heart.text.square") }
                NavigationStack { SettingsScreen() }
                    .tabItem { Label("設定", systemImage: "gearshape") }
            }
            .tint(DiaryStyle.ink)
            .environmentObject(store)
            .environmentObject(shared)
        }
    }
}

struct BookCover: View {
    let book: DiaryBook
    var small = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14).fill(DiaryStyle.colors[abs(book.cover) % DiaryStyle.colors.count])
                .shadow(color: .black.opacity(0.12), radius: 6, y: 4)
            HStack(spacing: 0) {
                Rectangle().fill(.white.opacity(0.28)).frame(width: 8)
                Spacer()
            }.padding(.leading, 12)
            VStack(spacing: 8) {
                Image(systemName: "heart.fill").font(small ? .title3 : .largeTitle)
                Text(book.title).font(.system(size: small ? 12 : 17, weight: .semibold, design: .serif))
                    .lineLimit(2).multilineTextAlignment(.center).padding(.horizontal, 10)
            }.foregroundStyle(.white)
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
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今日の気持ちを、\n次のページへ。")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                    Text("大切な人と、ゆっくりつづる交換日記。")
                        .foregroundStyle(.secondary)
                }.padding(.top, 14)
                if store.books.isEmpty {
                    ContentUnavailableView("まだ日記帳がありません", systemImage: "book.closed",
                        description: Text("まずは一冊、作ってみよう。"))
                }
                ForEach(store.books) { book in
                    NavigationLink {
                        BookScreen(bookID: book.id)
                    } label: {
                        HStack(spacing: 18) {
                            BookCover(book: book, small: true)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.title).font(.headline).foregroundStyle(.primary)
                                Text(book.paused ? "おやすみ中" : (book.isMyTurn ? "あなたの番です ✨" : "\(book.currentWriter)の番です"))
                                    .font(.subheadline)
                                    .foregroundStyle(book.isMyTurn ? DiaryStyle.ink : .secondary)
                                Text("\(store.pages(of: book.id).count)ページ・\(book.members.count)人")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }.buttonStyle(.plain)
                }
                Button { creating = true } label: {
                    Label("新しい日記帳を作る", systemImage: "plus")
                        .font(.headline).frame(maxWidth: .infinity).padding(14)
                }.buttonStyle(.borderedProminent).tint(DiaryStyle.ink)
                Text("このタブは端末内デモです。別のiPhoneと交換するには「共有」タブを利用してください。")
                    .font(.footnote).foregroundStyle(.secondary)
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
                                    .overlay { if cover == i { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white) } }
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
                        .font(.footnote).foregroundStyle(.secondary)
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
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 18) {
                        BookCover(book: book)
                        VStack(alignment: .leading, spacing: 7) {
                            Text(book.title).font(.title2.bold())
                            Text("\(book.members.count)人でつづる交換日記")
                                .font(.subheadline).foregroundStyle(.secondary)
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
                    }.padding(16).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    if book.isMyTurn {
                        Button { editing = true } label: {
                            Label("日記を書いて、次の人へ渡す", systemImage: "pencil.line")
                                .font(.headline).frame(maxWidth: .infinity).padding(14)
                        }.buttonStyle(.borderedProminent).tint(DiaryStyle.ink)
                    } else {
                        Label(book.paused ? "この日記帳はおやすみ中です" : "\(book.currentWriter)が書くのを待っています",
                              systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("ページをめくろう").font(.title3.bold())
                        Spacer()
                        Text("\(store.pages(of: bookID).count)ページ")
                            .foregroundStyle(.secondary)
                    }
                    if store.pages(of: bookID).isEmpty {
                        ContentUnavailableView("まだ白紙の一冊", systemImage: "text.book.closed",
                            description: Text("最初のページを書いてみよう。"))
                    } else {
                        ForEach(store.pages(of: bookID)) { page in
                            NavigationLink { DiaryPageScreen(entryID: page.id) } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(page.author).font(.caption)
                                        Spacer()
                                        Text(page.date, style: .date).font(.caption)
                                    }.foregroundStyle(.secondary)
                                    Text(page.title.isEmpty ? "無題のページ" : page.title)
                                        .font(.system(.title3, design: .serif, weight: .semibold))
                                    Text(page.text).font(.body).lineLimit(3)
                                    if page.photoFilename != nil { Label("写真付き", systemImage: "photo").font(.caption) }
                                    if let decor = page.decoration, !decor.stickers.isEmpty {
                                        Label("シール \(decor.stickers.count)枚", systemImage: "sparkles").font(.caption)
                                    }
                                    if let decor = page.decoration, !decor.photos.isEmpty {
                                        Label("貼り付け画像 \(decor.photos.count)枚", systemImage: "photo.on.rectangle")
                                            .font(.caption)
                                    }
                                    HStack {
                                        if page.hearted { Image(systemName: "heart.fill") }
                                        if page.favorite { Image(systemName: "bookmark.fill") }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.primary).padding(18)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 17))
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
                    Text(Date.now, format: .dateTime.year().month().day().weekday(.wide))
                        .font(.subheadline).foregroundStyle(.secondary)
                    TextField("今日のタイトル", text: $title)
                        .font(.system(.title2, design: .serif, weight: .bold))
                        .onChange(of: title) { _, _ in saveDraft() }
                    Divider()
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 280)
                        .onChange(of: text) { _, _ in saveDraft() }
                        .onChange(of: decoration) { _, _ in saveDraft() }
                        .overlay(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("今日はどんな一日だった？")
                                    .foregroundStyle(.tertiary).padding(.top, 9)
                                    .allowsHitTesting(false)
                            }
                        }
                    if let photo, let image = UIImage(data: photo) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxHeight: 240)
                        Button("写真を取り消す", role: .destructive) { self.photo = nil }
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("写真を1枚添える", systemImage: "photo.badge.plus")
                    }
                    DiaryDecorationEditor(decoration: $decoration)
                    Text("次の人へ渡すと、このページは編集できません。")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                    .padding(16)
            }
            .background(DiaryStyle.background.opacity(0.55))
            .navigationTitle("新しいページ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { saveDraft(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("次へ渡す") {
                        if store.submit(bookID: bookID, title: title, text: text, photo: photo, decoration: decoration) {
                            UserDefaults.standard.removeObject(forKey: draftKey)
                            dismiss()
                        } else { failed = true }
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                              photo == nil && decoration.photos.isEmpty)
                }
            }
            .onAppear {
                if let data = UserDefaults.standard.data(forKey: draftKey),
                   let draft = try? JSONDecoder().decode(DiaryDraft.self, from: data) {
                    title = draft.title; text = draft.text
                    decoration = draft.decoration ?? DiaryDecoration()
                }
                ready = true
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self),
                       data.count <= 8_000_000,
                       let image = UIImage(data: data),
                       let jpeg = image.jpegData(compressionQuality: 0.75),
                       jpeg.count <= 8_000_000 {
                        photo = jpeg
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
                    Text(page.date, format: .dateTime.year().month().day())
                        .font(.subheadline).foregroundStyle(.secondary)
                    DiaryStickerBoard(decoration: .constant(page.decoration ?? DiaryDecoration()))
                    Text(page.title.isEmpty ? "無題のページ" : page.title)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                    Text("written by \(page.author)")
                        .font(.caption).foregroundStyle(.secondary)
                    Divider()
                    Text(page.text).font(.system(.body, design: .serif))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let image = store.image(for: page) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
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
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(18)
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
                        Text(page.text).lineLimit(2).font(.subheadline).foregroundStyle(.secondary)
                        Text("\(page.author)・\(page.date.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption).foregroundStyle(.secondary)
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
    @State private var confirmErase = false
    var body: some View {
        Form {
            Section("アプリについて") {
                LabeledContent("アプリ名", value: "まわる")
                LabeledContent("バージョン", value: "0.4.0")
                LabeledContent("データ保存", value: "このiPhone内")
            }
            Section("データ管理") {
                ShareLink(item: store.exportJSON()) {
                    Label("日記データをテキストで共有", systemImage: "square.and.arrow.up")
                }
                Button("この端末の日記データを削除", role: .destructive) { confirmErase = true }
            }
            Section {
                Text("ローカル日記はこのiPhone内に保存されます。シールや紙のデコレーションに対応。共有機能はFirebase接続後に使えます。通知、課金、写真を含む完全なデータ出力は未対応です。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("設定")
        .confirmationDialog("すべての日記を削除しますか？", isPresented: $confirmErase) {
            Button("すべて削除", role: .destructive) { store.eraseAll() }
        } message: { Text("この端末のデータを削除します。元には戻せません。") }
    }
}

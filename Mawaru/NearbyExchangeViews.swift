import SwiftUI
import MultipeerConnectivity

struct ExchangeHubScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryService
    @EnvironmentObject private var store: DiaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MawaruHomeHeader(
                    headline: "日記のバトン、\nどうやって渡す？ ♡",
                    subtitle: "会える日も、離れている日も。好きな交換方法を選んでね。"
                )
                .padding(.top, 8)

                NavigationLink {
                    NearbyExchangeScreen()
                } label: {
                    ExchangeModeTile(
                        emoji: "📮", label: "ちかくで交換",
                        slogan: "会えたときに、直接わたそう",
                        description: "近くのiPhoneを探して、相手が受け取るまで手渡し。インターネットやアカウントは必要ありません。",
                        tint: MawaruPastel.mint,
                        details: "Bluetooth・近距離Wi‑Fi"
                    )
                }.buttonStyle(.plain)

                NavigationLink {
                    SharedHomeScreen()
                } label: {
                    ExchangeModeTile(
                        emoji: "💌", label: "はなれて交換",
                        slogan: "距離があっても、気持ちは届く",
                        description: "Appleでサインイン。招待コードでつながり、日記をクラウドで順番に回せます。",
                        tint: MawaruPastel.lavender,
                        details: "Firebase・インターネット"
                    )
                }.buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 9) {
                    Label("交換日記のルール", systemImage: "heart.text.square.fill")
                        .font(.headline)
                        .foregroundStyle(MawaruPastel.ink)
                    Text("一冊を2〜5人で使うよ。バトンを持っている人だけが次のページを書ける仕組み。近距離交換は双方の端末で承認、遠距離交換はサーバーで順番を管理するよ。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .background(.white.opacity(0.77),
                            in: RoundedRectangle(cornerRadius: 20))
            }
            .padding(19)
        }
        .background(MawaruPastel.background)
        .navigationTitle("交換する")
    }
}

private struct ExchangeModeTile: View {
    let emoji: String
    let label: String
    let slogan: String
    let description: String
    let tint: Color
    let details: String
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .center, spacing: 14) {
                Text(emoji)
                    .font(.system(size: 35))
                    .frame(width: 66, height: 66)
                    .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 18))
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.system(.title2, design: .rounded, weight: .black))
                    Text(slogan).font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right.circle.fill").font(.title2)
            }
            Text(description)
                .font(.subheadline)
                .foregroundStyle(MawaruPastel.ink.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Label(details, systemImage: "checkmark.circle.fill")
                    .font(.caption.bold())
                Spacer()
                Text("はじめる").font(.caption.bold())
            }
            .foregroundStyle(MawaruPastel.ink.opacity(0.7))
        }
        .padding(19)
        .foregroundStyle(MawaruPastel.ink)
        .background(tint.opacity(0.53), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.white.opacity(0.95), lineWidth: 2)
        }
    }
}

struct NearbyExchangeScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryService
    @EnvironmentObject private var store: DiaryStore
    @State private var creating = false

    private var books: [DiaryBook] { store.books.filter { $0.mode == "nearby" } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("📮")
                        .font(.system(size: 46))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ちかくで交換")
                            .font(.system(.title, design: .rounded, weight: .black))
                        Text("近くにいるときだけ、バトンを手渡し。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Label("近くの端末", systemImage: "iphone.radiowaves.left.and.right")
                            .font(.headline)
                        Spacer()
                        if nearby.isDiscovering {
                            Button("検索を止める") { nearby.stop() }
                                .font(.caption)
                        } else {
                            Button("探す") { nearby.start() }
                                .font(.caption.bold())
                        }
                    }
                    Text("この端末の名前：\(nearby.deviceName)")
                        .font(.caption).foregroundStyle(.secondary)
                    if nearby.connectedPeers.isEmpty && nearby.foundPeers.isEmpty {
                        ContentUnavailableView(
                            "相手を探しています",
                            systemImage: "dot.radiowaves.left.and.right",
                            description: Text("2台とも「まわる」を開いて、ちかくで交換を選んでね。初回はローカルネットワークへのアクセスを許可してください。")
                        )
                        .frame(minHeight: 125)
                    }
                    ForEach(nearby.connectedPeers, id: \.self) { peer in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading) {
                                Text(peer.displayName).font(.subheadline.bold())
                                Text("接続済み・交換できます")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            TagPill(title: "つながった ♡", color: MawaruPastel.mint)
                        }
                    }
                    ForEach(nearby.foundPeers.filter {
                        !nearby.connectedPeers.contains($0)
                    }, id: \.self) { peer in
                        HStack {
                            Image(systemName: "iphone").font(.title3)
                            Text(peer.displayName).font(.subheadline)
                            Spacer()
                            Button("接続する") { nearby.invite(peer) }
                                .buttonStyle(.bordered)
                                .tint(MawaruPastel.ink)
                        }
                    }
                    if let message = nearby.message {
                        Text(message).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(17)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 23))

                HStack {
                    Text("近くでまわす日記帳").font(.headline)
                    Spacer()
                    Text("\(books.count)冊")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if books.isEmpty {
                    ContentUnavailableView(
                        "まだ白紙の日記帳",
                        systemImage: "book.closed",
                        description: Text("一冊作って最初のページを書こう。相手が近くに来たら渡せるよ。")
                    )
                } else {
                    ForEach(books) { book in
                        NavigationLink {
                            BookScreen(bookID: book.id)
                        } label: {
                            HStack(spacing: 14) {
                                BookCover(book: book, small: true)
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(book.title).font(.headline).foregroundStyle(.primary)
                                    Text(book.isMyTurn ?
                                         "今はあなたの番 ✏️" :
                                         "\(book.currentWriter)の番を待っています")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("\(store.pages(of: book.id).count)ページ・\(book.members.count)人")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(15)
                            .background(.white.opacity(0.86),
                                        in: RoundedRectangle(cornerRadius: 21))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button { creating = true } label: {
                    Label("ちかくで交換する日記を作る", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity).padding(14)
                }
                .buttonStyle(.borderedProminent).tint(MawaruPastel.ink)

                Text("近くの端末が見つかる必要があります。AirDropと同様に近距離の無線を使いますが、AirDropそのものではなく、アプリ内で安全に直接交換します。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(18)
        }
        .background(MawaruPastel.background)
        .navigationTitle("ちかく")
        .onAppear {
            nearby.store = store
            nearby.start()
        }
        .sheet(isPresented: $creating) {
            CreateBookScreen(preferredMode: "nearby")
        }
    }
}

struct NearbyDiaryEditorScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryService
    @EnvironmentObject private var store: DiaryStore
    @Environment(\.dismiss) private var dismiss

    let bookID: UUID
    @State private var title = ""
    @State private var text = ""
    @State private var decoration = DiaryDecoration()
    @State private var ready = false
    @State private var showTextTools = false
    @State private var preview = false
    @State private var outgoingID: UUID?
    @State private var error: String?
    @State private var confirmingPeer: MCPeerID?

    private var book: DiaryBook? { store.books.first(where: { $0.id == bookID }) }
    private var key: String { "mawaru.nearby.draft.\(bookID.uuidString)" }
    private struct Draft: Codable {
        let title: String
        let text: String
        let decoration: DiaryDecoration
    }

    private func saveDraft() {
        guard ready, outgoingID == nil else { return }
        if let data = try? JSONEncoder().encode(Draft(
            title: title, text: text, decoration: decoration)) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    MawaruSectionLabel(step: "01", title: "近くでまわす日記", symbol: "pencil.and.scribble")
                    HStack {
                        TagPill(title: "📮 ちかくで交換", color: MawaruPastel.mint)
                        Spacer()
                        Button {
                            preview.toggle()
                            saveDraft()
                        } label: {
                            Label(preview ? "編集へ戻る" : "完成プレビュー",
                                  systemImage: preview ? "pencil" : "eye")
                        }.buttonStyle(.bordered)
                    }
                    if preview {
                        NostalgicNotebookReadPage(
                            title: title, text: text, author: book?.currentWriter ?? "",
                            date: .now, decoration: decoration,
                            groupTitle: book?.title ?? "交換日記",
                            pageNumber: store.pages(of: bookID).count + 1
                        )
                    } else {
                        NostalgicNotebookEditor(
                            title: $title, text: $text, decoration: $decoration,
                            author: book?.currentWriter ?? "",
                            groupTitle: book?.title ?? "交換日記",
                            pageNumber: store.pages(of: bookID).count + 1
                        )
                        .onChange(of: title) { _, _ in saveDraft() }
                        .onChange(of: text) { _, _ in saveDraft() }
                    }
                    DisclosureGroup(isExpanded: $showTextTools) {
                        DiaryTypographyControls(decoration: $decoration, resetToSavedPreference: true)
                            .padding(.top, 8)
                    } label: {
                        MawaruSectionLabel(step: "02", title: "このページだけ文字を変更",
                                           symbol: "textformat")
                    }
                    .tint(MawaruPastel.ink)
                    .onChange(of: decoration) { _, _ in saveDraft() }

                    DiaryWritingPromptPicker(text: $text)
                    MawaruSectionLabel(step: "03", title: "デコレーション",
                                       symbol: "sparkles")
                    DiaryDecorationEditor(decoration: $decoration, showsPreview: false)

                    VStack(alignment: .leading, spacing: 11) {
                        Label("次の人に直接渡す", systemImage: "paperplane.fill")
                            .font(.headline)
                        Text("相手にアプリを開いてもらい、近くの端末に接続してね。相手が受け取るまで、バトンは進まないよ。")
                            .font(.footnote).foregroundStyle(.secondary)
                        if let book {
                            Text("次の人：\(book.members[(book.turnIndex + 1) % book.members.count])")
                                .font(.subheadline.bold())
                        }
                        if let outgoingID {
                            Label("受取確認を待っています… \(outgoingID.uuidString.prefix(8))",
                                  systemImage: "hourglass")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if nearby.connectedPeers.isEmpty {
                            Label("接続したiPhoneがありません。「交換」→「ちかく」から探してね。",
                                  systemImage: "wifi.slash")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        ForEach(nearby.connectedPeers, id: \.self) { peer in
                            Button {
                                saveDraft()
                                confirmingPeer = peer
                            } label: {
                                HStack {
                                    Image(systemName: "iphone")
                                    Text("\(peer.displayName) に日記を渡す")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                                .frame(maxWidth: .infinity).padding(12)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(MawaruPastel.ink)
                            .disabled(outgoingID != nil || (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                                                           decoration.photos.isEmpty) ||
                                      text.count > 5000 || title.count > 80)
                        }
                    }
                    .padding(17)
                    .background(MawaruPastel.mint.opacity(0.35),
                                in: RoundedRectangle(cornerRadius: 22))
                }
                .padding(18)
            }
            .background(MawaruPastel.background)
            .navigationTitle("近くで日記を書く")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { saveDraft(); dismiss() }
                }
            }
            .onAppear {
                nearby.store = store
                if let data = UserDefaults.standard.data(forKey: key),
                   let draft = try? JSONDecoder().decode(Draft.self, from: data) {
                    title = draft.title
                    text = draft.text
                    decoration = draft.decoration
                } else {
                    decoration = DiaryTypographyPreferences.load()
                }
                ready = true
            }
            .onChange(of: nearby.lastAcknowledged) { _, id in
                if let id, id == outgoingID {
                    outgoingID = nil
                    dismiss()
                }
            }
            .confirmationDialog(
                "このiPhoneに日記を渡しますか？",
                isPresented: Binding(
                    get: { confirmingPeer != nil },
                    set: { if !$0 { confirmingPeer = nil } }
                )
            ) {
                if let peer = confirmingPeer {
                    Button("\(peer.displayName) に渡す") {
                        do {
                            let packet = try store.prepareNearby(
                                bookID: bookID, title: title, text: text,
                                decoration: decoration
                            )
                            try nearby.send(packet, to: peer)
                            outgoingID = packet.id
                        } catch {
                            self.error = error.localizedDescription
                        }
                        confirmingPeer = nil
                    }
                }
            } message: {
                Text("相手が受け取ると、このページは確定して次の人の番になります。")
            }
            .alert("渡せませんでした", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) {
                Button("OK") { error = nil }
            } message: { Text(error ?? "") }
        }
    }
}

struct NearbyIncomingDiarySheet: View {
    @EnvironmentObject private var nearby: NearbyDiaryService
    let offer: NearbyIncomingDiary
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("💌").font(.system(size: 64))
                    Text("新しいページが届いたよ")
                        .font(.system(.title2, design: .rounded, weight: .black))
                    Text("\(offer.peer.displayName) から")
                        .font(.subheadline).foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("グループ").foregroundStyle(.secondary)
                            Spacer()
                            Text(offer.packet.book.title).fontWeight(.semibold)
                        }
                        HStack {
                            Text("いまのページ").foregroundStyle(.secondary)
                            Spacer()
                            Text(offer.packet.newEntry.title.isEmpty ?
                                 "無題のページ" : offer.packet.newEntry.title)
                                .fontWeight(.semibold)
                        }
                        HStack {
                            Text("次の担当").foregroundStyle(.secondary)
                            Spacer()
                            Text(offer.packet.recipientName + "（あなた）")
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.subheadline)
                    .padding(18)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 18))

                    Text("受け取ると、この端末が「\(offer.packet.recipientName)」の担当になります。相手の端末とグループ名を確認してから承認してね。")
                        .font(.footnote).foregroundStyle(.secondary)

                    Button {
                        nearby.acceptDiary()
                    } label: {
                        Label("日記を受け取る ♡", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity).padding(12)
                    }
                    .buttonStyle(.borderedProminent).tint(MawaruPastel.ink)

                    Button("今回は受け取らない", role: .cancel) {
                        nearby.rejectDiary()
                    }
                    .foregroundStyle(.secondary)
                }.padding(22)
            }
            .background(MawaruPastel.background)
            .navigationTitle("近くの交換日記")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { nearby.rejectDiary() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

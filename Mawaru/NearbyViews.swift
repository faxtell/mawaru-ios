import SwiftUI
import MultipeerConnectivity

// The first screen makes the two *real* handoff modes unmistakable.
// The older on-device demo remains reachable, but is not labelled "nearby".
struct ExchangeHomeScreen: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MawaruHomeHeader(
                    headline: "きょうのページ、\n誰にまわす？ ♡",
                    subtitle: "会えたときも、離れているときも。ふたりだけの交換日記。"
                )
                Text("交換する方法をえらぼう")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(DiaryStyle.ink)
                NavigationLink {
                    NearbyHomeScreen()
                } label: {
                    ExchangeModeCard(
                        symbol: "wave.3.right",
                        title: "近くの人",
                        subtitle: "会えたときだけ、手渡しみたいに。",
                        detail: "近距離通信・ネット不要・その場でバトンタッチ",
                        tint: MawaruPastel.mint,
                        marker: "01"
                    )
                }
                .buttonStyle(.plain)
                NavigationLink {
                    SharedHomeScreen()
                } label: {
                    ExchangeModeCard(
                        symbol: "globe.asia.australia.fill",
                        title: "遠くの人",
                        subtitle: "離れていても、ひみつのノートを。",
                        detail: "オンライン・招待コード・最大5人",
                        tint: MawaruPastel.lavender,
                        marker: "02"
                    )
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 9) {
                    Label("ふたりのルール ♡", systemImage: "heart.text.square")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text("ページを書いて、シールで飾って、次の人へ。近くの人は会って通信できたときに、遠くの人はオンラインでバトンが進むよ。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20))
                NavigationLink {
                    HomeScreen()
                } label: {
                    Label("ひとりで試す・これまでの端末内日記", systemImage: "book.closed")
                        .font(.footnote)
                }
                .foregroundStyle(.secondary)
                .padding(.bottom, 10)
            }
            .padding(20)
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle("まわる")
    }
}

private struct ExchangeModeCard: View {
    var symbol: String
    var title: String
    var subtitle: String
    var detail: String
    var tint: Color
    var marker: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.68))
                    .frame(width: 80, height: 94)
                Image(systemName: symbol)
                    .font(.system(size: 33, weight: .medium))
                    .foregroundStyle(DiaryStyle.ink)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(marker + "  " + title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(DiaryStyle.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DiaryStyle.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(DiaryStyle.ink.opacity(0.74))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(DiaryStyle.ink)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.78), in: RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .strokeBorder(.white.opacity(0.85), lineWidth: 2)
        }
    }
}

struct NearbyInboxAlerts: ViewModifier {
    @EnvironmentObject private var nearby: NearbyDiaryStore
    func body(content: Content) -> some View {
        content
            .alert("交換日記が届いたよ ♡", isPresented: Binding(
                get: { nearby.incoming != nil },
                set: { if !$0 { nearby.rejectIncoming() } }
            )) {
                Button("受け取ってノートに保存") { nearby.acceptIncoming() }
                Button("受け取らない", role: .cancel) { nearby.rejectIncoming() }
            } message: {
                if let request = nearby.incoming {
                    let kind = request.packet.kind == "pair" ? "日記帳への招待" : "新しい日記のページ"
                    Text("\(request.packet.book.title)\n\(kind)を \(request.peer.displayName) から受信しました。")
                }
            }
            .alert("近くの交換でエラー", isPresented: Binding(
                get: { nearby.errorMessage != nil },
                set: { if !$0 { nearby.errorMessage = nil } }
            )) {
                Button("OK") { nearby.errorMessage = nil }
            } message: { Text(nearby.errorMessage ?? "") }
    }
}

struct NearbyConnectionPanel: View {
    @ObservedObject var transport: NearbyConnectionManager
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("近くにいる端末", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.headline)
                Spacer()
                Text("近距離のみ")
                    .font(.caption2.bold())
                    .foregroundStyle(DiaryStyle.ink)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(MawaruPastel.mint, in: Capsule())
            }
            if transport.connected.isEmpty && transport.discovered.isEmpty {
                Text("相手も「まわる」の近くの人モードを開いてね。見つかったら「接続する」を押そう。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(transport.connected, id: \.displayName) { peer in
                HStack {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(peer.displayName).font(.subheadline.weight(.medium))
                    Spacer()
                    Text("接続中").font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(transport.discovered.filter { !transport.connected.contains($0) },
                    id: \.displayName) { peer in
                HStack {
                    Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                        .foregroundStyle(DiaryStyle.ink)
                    Text(peer.displayName).font(.subheadline)
                    Spacer()
                    Button("接続する") { transport.connect(to: peer) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Text("接続にはBluetooth・ローカルネットワークの許可が必要です。相手が承認して初めて交換できます。")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 20))
        .alert("近くの人から接続リクエスト", isPresented: Binding(
            get: { transport.incomingInvitationPeer != nil },
            set: { if !$0 { transport.respondToInvitation(accept: false) } }
        )) {
            Button("接続を許可") { transport.respondToInvitation(accept: true) }
            Button("拒否", role: .cancel) { transport.respondToInvitation(accept: false) }
        } message: {
            Text("\(transport.incomingInvitationPeer?.displayName ?? "近くの端末") と日記を交換するために接続しますか？")
        }
        .alert("近距離通信エラー", isPresented: Binding(
            get: { transport.errorMessage != nil },
            set: { if !$0 { transport.errorMessage = nil } }
        )) {
            Button("OK") { transport.errorMessage = nil }
        } message: { Text(transport.errorMessage ?? "") }
    }
}

struct NearbyHomeScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var creating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                MawaruHomeHeader(
                    headline: "会えたときだけ、\nまわせるノート ♡",
                    subtitle: "近くにいるiPhoneと直接つながって交換しよう。"
                )
                NearbyConnectionPanel(transport: nearby.transport)
                HStack {
                    Text("近くでまわす日記帳")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                    Spacer()
                    Text("\(nearby.books.count)冊").font(.caption).foregroundStyle(.secondary)
                }
                if nearby.books.isEmpty {
                    ContentUnavailableView("まだ日記帳がないよ", systemImage: "book.closed",
                        description: Text("日記帳を作って、近くにいる友だちを招待しよう。"))
                }
                ForEach(nearby.books) { book in
                    NavigationLink {
                        NearbyBookScreen(bookID: book.id)
                    } label: {
                        HStack(spacing: 15) {
                            NearbyBookCover(book: book)
                            VStack(alignment: .leading, spacing: 6) {
                                Text(book.title)
                                    .font(.headline).foregroundStyle(DiaryStyle.ink)
                                Text(!book.isPaired ? "相手の参加待ち" :
                                    book.isMyTurn(nearby.deviceID) ? "あなたの番 ♡" :
                                    "\(book.currentWriter)の番")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                Text("\(nearby.pages(in: book.id).count)ページ・近距離")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                        }
                        .padding(14)
                        .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                }
                Button { creating = true } label: {
                    Label("近くでまわす日記帳を作る", systemImage: "plus")
                        .frame(maxWidth: .infinity).padding(13)
                }
                .buttonStyle(.borderedProminent)
                .tint(DiaryStyle.ink)
                Text("日記の本文・シール・切り抜き写真は接続した端末へ直接送られます。インターネットへアップロードしません。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle("近くの人")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $creating) { NearbyCreateScreen() }
        .onAppear { nearby.transport.start() }
        .onDisappear { nearby.transport.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { nearby.transport.start() }
            else { nearby.transport.stop() }
        }
        .modifier(NearbyInboxAlerts())
    }
}

struct NearbyBookCover: View {
    var book: NearbyBook
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(DiaryStyle.colors[max(0, book.cover) % DiaryStyle.colors.count])
            VStack(spacing: 6) {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                Text(book.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .lineLimit(3).multilineTextAlignment(.center)
                Text("mawaru ♡")
                    .font(.system(size: 9, weight: .medium, design: .serif))
            }
            .foregroundStyle(DiaryStyle.ink)
            .padding(6)
        }
        .frame(width: 75, height: 98)
    }
}

struct NearbyCreateScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("mawaru.nearby.nickname") private var myName = "わたし"
    @State private var title = "ふたりの交換日記"
    @State private var otherName = ""
    @State private var cover = 1
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("日記帳のグループ名") {
                    TextField("例：放課後のひみつノート", text: $title)
                    Text("この名前が表紙とすべてのページの上に表示されるよ。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("ふたりの名前") {
                    TextField("あなたのニックネーム", text: $myName)
                    TextField("交換する相手の名前", text: $otherName)
                }
                Section("ノートの色") {
                    HStack(spacing: 12) {
                        ForEach(0..<4, id: \.self) { index in
                            Button { cover = index } label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(DiaryStyle.colors[index])
                                    .frame(height: 55)
                                    .overlay {
                                        if cover == index {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }.buttonStyle(.plain)
                        }
                    }
                }
                Section {
                    Text("近くの人モードは2人用。相手と接続して日記帳を送ると、同じノートが相手のiPhoneにも作られます。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("日記帳を作る")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        do {
                            try nearby.create(title: title, myName: myName,
                                              otherName: otherName, cover: cover)
                            dismiss()
                        } catch { error = error.localizedDescription }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              myName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              otherName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              title.count > 60 || myName.count > 30 || otherName.count > 30)
                }
            }
            .alert("作成できませんでした", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("OK") { error = nil } }
            message: { Text(error ?? "") }
        }
    }
}

struct NearbyBookScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryStore
    let bookID: UUID
    @State private var editing = false
    @State private var error: String?
    private var book: NearbyBook? { nearby.book(bookID) }

    var body: some View {
        ScrollView {
            if let book {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 16) {
                        NearbyBookCover(book: book)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(book.title)
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text(book.isPaired ? "ふたりのノート ♡" : "相手とまだつながっていません")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("NO. \(nearby.pages(in: bookID).count + 1)  ·  近くで交換")
                                .font(.caption).foregroundStyle(DiaryStyle.ink)
                        }
                        Spacer(minLength: 0)
                    }
                    NearbyConnectionPanel(transport: nearby.transport)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("バトンの順番")
                            .font(.headline)
                        ForEach(book.members.indices, id: \.self) { index in
                            HStack {
                                Image(systemName: index == book.currentTurn ?
                                      "heart.circle.fill" : "circle")
                                    .foregroundStyle(DiaryStyle.ink)
                                Text(book.members[index].name)
                                if book.members[index].id == nearby.deviceID {
                                    Text("あなた").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if index == book.currentTurn {
                                    Text("次に書く人")
                                        .font(.caption)
                                        .foregroundStyle(DiaryStyle.ink)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))

                    if let waiting = nearby.pendingTransfer(for: bookID) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("相手の受け取り確認を待っています",
                                  systemImage: "hourglass.circle")
                                .font(.headline)
                            Text("相手が承認するとバトンが進むよ。通信が切れた場合は、同じ端末へ再送してね。")
                                .font(.footnote).foregroundStyle(.secondary)
                            NearbyPeerActionMenu(
                                transport: nearby.transport,
                                label: "受け渡しを再送",
                                symbol: "arrow.clockwise"
                            ) { peer in
                                do { try nearby.retry(bookID: bookID, to: peer) }
                                catch { error = error.localizedDescription }
                            }
                            Text("宛先：\(waiting.targetPeerName)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(MawaruPastel.lemon.opacity(0.40),
                                    in: RoundedRectangle(cornerRadius: 20))
                    } else if !book.isPaired {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("① 相手のiPhoneと接続する")
                                .font(.subheadline.weight(.semibold))
                            Text("② この日記帳を相手へ送る")
                                .font(.subheadline.weight(.semibold))
                            NearbyPeerActionMenu(
                                transport: nearby.transport,
                                label: "相手を日記帳に招待",
                                symbol: "person.crop.circle.badge.plus"
                            ) { peer in
                                do { try nearby.sendPair(bookID: bookID, to: peer) }
                                catch { error = error.localizedDescription }
                            }
                        }
                        .padding(16)
                        .background(MawaruPastel.mint.opacity(0.48),
                                    in: RoundedRectangle(cornerRadius: 20))
                    } else if book.isMyTurn(nearby.deviceID) {
                        Button { editing = true } label: {
                            Label("ページを書いて、会ったときに渡す ♡", systemImage: "pencil.line")
                                .frame(maxWidth: .infinity).padding(14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(DiaryStyle.ink)
                    } else {
                        Label("\(book.currentWriter)が書く番だよ。次に会ったときに受け取ろう ♡",
                              systemImage: "heart")
                            .font(.subheadline)
                            .foregroundStyle(DiaryStyle.ink)
                            .padding(14)
                    }

                    HStack {
                        Text("ページをめくろう")
                            .font(.system(.title3, design: .rounded, weight: .bold))
                        Spacer()
                        Text("\(nearby.pages(in: bookID).count)ページ")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if nearby.pages(in: bookID).isEmpty {
                        ContentUnavailableView("まだ白紙のノート", systemImage: "book.closed",
                            description: Text("最初の1ページが待っているよ。"))
                    }
                    ForEach(nearby.pages(in: bookID)) { page in
                        NostalgicNotebookReadPage(
                            title: page.title, text: page.body, author: page.author,
                            date: page.createdAt, decoration: page.decoration,
                            bookTitle: book.title, pageNumber: max(1, page.sequence - 1),
                            exchangeMode: "近くで交換"
                        )
                    }
                }
                .padding(18)
            }
        }
        .background(DiaryStyle.background.opacity(0.55))
        .navigationTitle(book?.title ?? "近くの日記帳")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            NearbyEditorScreen(bookID: bookID)
        }
        .onAppear { nearby.transport.start() }
        .onDisappear { nearby.transport.stop() }
        .modifier(NearbyInboxAlerts())
        .alert("操作できませんでした", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) { Button("OK") { error = nil } }
        message: { Text(error ?? "") }
    }
}

private struct NearbyPeerActionMenu: View {
    @ObservedObject var transport: NearbyConnectionManager
    var label: String
    var symbol: String
    var action: (MCPeerID) -> Void

    var body: some View {
        Menu {
            if transport.connected.isEmpty {
                Text("近くの人と先に接続してください")
            } else {
                ForEach(transport.connected, id: \.displayName) { peer in
                    Button(peer.displayName) { action(peer) }
                }
            }
        } label: {
            Label(label, systemImage: symbol)
                .frame(maxWidth: .infinity).padding(12)
        }
        .buttonStyle(.borderedProminent)
        .tint(DiaryStyle.ink)
        .disabled(transport.connected.isEmpty)
    }
}

struct NearbyEditorScreen: View {
    @EnvironmentObject private var nearby: NearbyDiaryStore
    @Environment(\.dismiss) private var dismiss
    let bookID: UUID
    @State private var title = ""
    @State private var bodyText = ""
    @State private var decoration = DiaryDecoration()
    @State private var preview = false
    @State private var showTextTools = false
    @State private var ready = false
    @State private var targetPeer: MCPeerID?
    @State private var confirmSend = false
    @State private var outgoingID: UUID?
    @State private var error: String?

    private var book: NearbyBook? { nearby.book(bookID) }
    private var draftKey: String { "mawaru.nearby.draft.\(bookID.uuidString)" }
    private struct Draft: Codable {
        var title: String
        var body: String
        var decoration: DiaryDecoration
    }

    private func saveDraft() {
        guard ready else { return }
        if let bytes = try? JSONEncoder().encode(
            Draft(title: title, body: bodyText, decoration: decoration)
        ) {
            UserDefaults.standard.set(bytes, forKey: draftKey)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    MawaruSectionLabel(step: "01", title: "きょうのノート", symbol: "pencil.and.scribble")
                    HStack {
                        Text("会えたときに渡せる下書き ♡")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            preview.toggle()
                            saveDraft()
                        } label: {
                            Label(preview ? "編集へ" : "完成プレビュー",
                                  systemImage: preview ? "pencil" : "eye")
                        }
                        .buttonStyle(.bordered)
                    }
                    if preview {
                        NostalgicNotebookReadPage(
                            title: title, text: bodyText,
                            author: book?.currentWriter ?? "わたし",
                            date: .now, decoration: decoration,
                            bookTitle: book?.title ?? "交換日記",
                            pageNumber: nearby.pages(in: bookID).count + 1,
                            exchangeMode: "近くで交換"
                        )
                    } else {
                        NostalgicNotebookEditor(
                            title: $title, text: $bodyText, decoration: $decoration,
                            author: book?.currentWriter ?? "わたし",
                            bookTitle: book?.title ?? "交換日記",
                            pageNumber: nearby.pages(in: bookID).count + 1,
                            exchangeMode: "近くで交換"
                        )
                    }
                    DisclosureGroup(isExpanded: $showTextTools) {
                        DiaryTypographyControls(
                            decoration: $decoration, resetToSavedPreference: true
                        )
                        .padding(.top, 8)
                    } label: {
                        MawaruSectionLabel(step: "02", title: "このページだけ文字を変更",
                                           symbol: "textformat")
                    }
                    .tint(DiaryStyle.ink)
                    DiaryWritingPromptPicker(text: $bodyText)
                    MawaruSectionLabel(step: "03", title: "シールや写真でデコろう",
                                       symbol: "sparkles")
                    DiaryDecorationEditor(decoration: $decoration, showsPreview: false)
                    HStack {
                        Text("本文 \(bodyText.count)/5000文字")
                        Spacer()
                        Text("タイトル \(title.count)/80文字")
                    }
                    .font(.caption)
                    .foregroundStyle(bodyText.count > 5000 || title.count > 80 ?
                                     Color.red : Color.secondary)
                    Text("送るまでは自分のiPhoneに下書きを保存。会えたときにバトンを渡せるよ。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .padding(18)
            }
            .background(DiaryStyle.background.opacity(0.55))
            .navigationTitle(book?.title ?? "きょうの交換日記")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { saveDraft(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Menu {
                        if nearby.transport.connected.isEmpty {
                            Text("相手のiPhoneと接続してください")
                        } else {
                            ForEach(nearby.transport.connected, id: \.displayName) { peer in
                                Button("\(peer.displayName)へ渡す") {
                                    targetPeer = peer
                                    confirmSend = true
                                }
                            }
                        }
                    } label: {
                        Text("次へ渡す")
                            .fontWeight(.semibold)
                    }
                    .disabled(nearby.transport.connected.isEmpty ||
                              nearby.pendingTransfer(for: bookID) != nil ||
                              (bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                               decoration.photos.isEmpty) ||
                              bodyText.count > 5000 || title.count > 80)
                }
            }
            .onAppear {
                if let data = UserDefaults.standard.data(forKey: draftKey),
                   let draft = try? JSONDecoder().decode(Draft.self, from: data) {
                    title = draft.title
                    bodyText = draft.body
                    decoration = draft.decoration
                } else {
                    decoration = DiaryTypographyPreferences.load()
                }
                ready = true
            }
            .onChange(of: title) { _, _ in saveDraft() }
            .onChange(of: bodyText) { _, _ in saveDraft() }
            .onChange(of: decoration) { _, _ in saveDraft() }
            .onChange(of: nearby.lastCompletedTransfer) { _, next in
                if next != nil && next == outgoingID {
                    UserDefaults.standard.removeObject(forKey: draftKey)
                    dismiss()
                }
            }
            .confirmationDialog("このページを近くの相手に渡す？",
                                isPresented: $confirmSend) {
                Button("バトンを渡す ♡") {
                    guard let peer = targetPeer else { return }
                    saveDraft()
                    do {
                        outgoingID = try nearby.sendPage(
                            bookID: bookID, title: title, body: bodyText,
                            decoration: decoration, to: peer
                        )
                    } catch {
                        error = error.localizedDescription
                    }
                }
            } message: {
                Text("相手が受け取りを承認すると、次の人の番になります。")
            }
            .alert("送信できませんでした", isPresented: Binding(
                get: { error != nil }, set: { if !$0 { error = nil } }
            )) { Button("OK") { error = nil } }
            message: { Text(error ?? "") }
        }
    }
}

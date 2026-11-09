import Foundation
import SwiftUI
import MultipeerConnectivity
import UIKit

// Nearby exchanges use only an encrypted MultipeerConnectivity session.
// There is no server fallback: a connected nearby device must acknowledge
// each handoff before the sending phone advances the baton.
struct NearbyMember: Codable, Equatable {
    var id: String
    var name: String
}

struct NearbyBook: Codable, Identifiable {
    var id = UUID()
    var title: String
    var cover: Int
    var members: [NearbyMember]
    var currentTurn = 0
    var revision = 0
    var createdAt = Date()
    var updatedAt = Date()

    var isPaired: Bool { members.count == 2 && !members[1].id.isEmpty }
    var currentWriter: String { members.indices.contains(currentTurn) ? members[currentTurn].name : "―" }
    func isMyTurn(_ deviceID: String) -> Bool {
        isPaired && members.indices.contains(currentTurn) &&
            members[currentTurn].id == deviceID
    }
}

struct NearbyPage: Codable, Identifiable {
    var id = UUID()
    var bookID: UUID
    var sequence: Int
    var authorID: String
    var author: String
    var title: String
    var body: String
    var decoration: DiaryDecoration
    var createdAt = Date()
}

struct NearbyPacket: Codable {
    var kind: String // "pair", "page", "ack"
    var transactionID: UUID
    var senderID: String
    var book: NearbyBook
    var page: NearbyPage?
    var images: [String: Data]
}

struct NearbyPendingTransfer: Codable {
    var packet: NearbyPacket
    var targetPeerName: String
}

struct NearbyIncoming: Identifiable {
    let packet: NearbyPacket
    let peer: MCPeerID
    var id: UUID { packet.transactionID }
}

enum NearbyError: LocalizedError {
    case notConnected, notYourTurn, invalidPacket, pendingTransfer, missingImage, tooLarge
    var errorDescription: String? {
        switch self {
        case .notConnected: "近くの相手と接続してください。両方の端末で「近くの人」を開いてね。"
        case .notYourTurn: "今はこの日記を書く順番ではありません。"
        case .invalidPacket: "受信した日記の内容を確認できませんでした。"
        case .pendingTransfer: "前の受け渡しが確認待ちです。先に再送してください。"
        case .missingImage: "貼り付け画像が見つかりません。"
        case .tooLarge: "日記のデータが大きすぎます。写真を減らしてください。"
        }
    }
}

final class NearbyConnectionManager: NSObject, ObservableObject {
    private static let service = "mawaru-diary"
    @Published private(set) var discovered: [MCPeerID] = []
    @Published private(set) var connected: [MCPeerID] = []
    @Published var incomingInvitationPeer: MCPeerID?
    @Published var errorMessage: String?
    var onPacket: ((Data, MCPeerID) -> Void)?

    let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private var started = false

    override init() {
        let defaults = UserDefaults.standard
        let key = "mawaru.nearby.deviceID"
        let id: String
        if let saved = defaults.string(forKey: key), UUID(uuidString: saved) != nil {
            id = saved
        } else {
            id = UUID().uuidString
            defaults.set(id, forKey: key)
        }
        let peer = MCPeerID(displayName: "まわる-" + String(id.prefix(6)))
        peerID = peer
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: nil,
                                               serviceType: Self.service)
        browser = MCNearbyServiceBrowser(peer: peer, serviceType: Self.service)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    var deviceID: String {
        UserDefaults.standard.string(forKey: "mawaru.nearby.deviceID") ?? ""
    }

    func start() {
        guard !started else { return }
        started = true
        advertiser.startAdvertisingPeer()
        browser.startBrowsingForPeers()
    }

    func stop() {
        guard started else { return }
        started = false
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        discovered = []
    }

    func connect(to peer: MCPeerID) {
        guard discovered.contains(peer) else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 35)
    }

    func respondToInvitation(accept: Bool) {
        let handler = invitationHandler
        invitationHandler = nil
        incomingInvitationPeer = nil
        handler?(accept, accept ? session : nil)
    }

    func send(_ packet: NearbyPacket, to peer: MCPeerID) throws {
        guard session.connectedPeers.contains(peer) else { throw NearbyError.notConnected }
        let data = try JSONEncoder().encode(packet)
        guard data.count <= 8_000_000 else { throw NearbyError.tooLarge }
        try session.send(data, toPeers: [peer], with: .reliable)
    }

    deinit {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
        session.disconnect()
    }
}

extension NearbyConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async {
            if !self.discovered.contains(peerID) { self.discovered.append(peerID) }
        }
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { self.discovered.removeAll { $0 == peerID } }
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }
}

extension NearbyConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            if let old = self.invitationHandler {
                old(false, nil)
            }
            self.invitationHandler = invitationHandler
            self.incomingInvitationPeer = peerID
        }
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async { self.errorMessage = error.localizedDescription }
    }
}

extension NearbyConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { self.connected = session.connectedPeers }
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard data.count <= 8_000_000 else { return }
        DispatchQueue.main.async { self.onPacket?(data, peerID) }
    }
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

@MainActor
final class NearbyDiaryStore: ObservableObject {
    @Published private(set) var books: [NearbyBook] = []
    @Published private(set) var pages: [NearbyPage] = []
    @Published var incoming: NearbyIncoming?
    @Published var errorMessage: String?
    @Published private(set) var pending: [NearbyPendingTransfer] = []
    @Published private(set) var lastCompletedTransfer: UUID?
    let transport = NearbyConnectionManager()

    private struct Archive: Codable {
        var books: [NearbyBook]
        var pages: [NearbyPage]
        var pending: [NearbyPendingTransfer]
    }
    private var archiveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("MawaruNearby", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("nearby.json")
    }
    var deviceID: String { transport.deviceID }

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("MawaruNearby", isDirectory: true)
        let file = dir.appendingPathComponent("nearby.json")
        if let data = try? Data(contentsOf: file),
           let archive = try? JSONDecoder().decode(Archive.self, from: data) {
            books = archive.books
            pages = archive.pages
            pending = archive.pending
        }
        transport.onPacket = { [weak self] data, peer in
            self?.handle(data, from: peer)
        }
    }

    private func save() throws {
        let data = try JSONEncoder().encode(Archive(books: books, pages: pages, pending: pending))
        try data.write(to: archiveURL, options: .atomic)
    }

    func book(_ id: UUID) -> NearbyBook? { books.first { $0.id == id } }
    func pages(in id: UUID) -> [NearbyPage] {
        pages.filter { $0.bookID == id }.sorted { $0.sequence > $1.sequence }
    }
    func pendingTransfer(for id: UUID) -> NearbyPendingTransfer? {
        pending.first { $0.packet.book.id == id }
    }

    func create(title: String, myName: String, otherName: String, cover: Int) throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let me = myName.trimmingCharacters(in: .whitespacesAndNewlines)
        let other = otherName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, title.count <= 60,
              !me.isEmpty, me.count <= 30,
              !other.isEmpty, other.count <= 30 else { throw NearbyError.invalidPacket }
        let book = NearbyBook(title: title, cover: min(3, max(0, cover)),
                              members: [NearbyMember(id: deviceID, name: me),
                                        NearbyMember(id: "", name: other)])
        books.insert(book, at: 0)
        try save()
    }

    private func makeImages(for page: NearbyPage) throws -> [String: Data] {
        var images: [String: Data] = [:]
        guard page.decoration.photos.count <= 4 else { throw NearbyError.invalidPacket }
        for photo in page.decoration.photos {
            guard let bytes = DiaryPhotoVault.data(for: photo),
                  bytes.count <= 1_500_000 else { throw NearbyError.missingImage }
            images[photo.id.uuidString] = bytes
        }
        return images
    }

    @discardableResult
    func sendPair(bookID: UUID, to peer: MCPeerID) throws -> UUID {
        guard let book = book(bookID), !book.isPaired else { throw NearbyError.invalidPacket }
        guard pendingTransfer(for: bookID) == nil else { throw NearbyError.pendingTransfer }
        let packet = NearbyPacket(kind: "pair", transactionID: UUID(), senderID: deviceID,
                                  book: book, page: nil, images: [:])
        try stage(packet, to: peer)
        return packet.transactionID
    }

    @discardableResult
    func sendPage(bookID: UUID, title: String, body: String,
                  decoration: DiaryDecoration, to peer: MCPeerID) throws -> UUID {
        guard var book = book(bookID), book.isMyTurn(deviceID) else {
            throw NearbyError.notYourTurn
        }
        guard pendingTransfer(for: bookID) == nil else { throw NearbyError.pendingTransfer }
        guard title.count <= 80, body.count <= 5000,
              !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                !decoration.photos.isEmpty,
              decoration.photos.count <= 4, decoration.stickers.count <= 24 else {
            throw NearbyError.invalidPacket
        }
        let page = NearbyPage(bookID: bookID, sequence: book.revision + 1,
                              authorID: deviceID, author: book.currentWriter,
                              title: title, body: body, decoration: decoration)
        let images = try makeImages(for: page)
        book.revision += 1
        book.currentTurn = (book.currentTurn + 1) % 2
        book.updatedAt = .now
        let packet = NearbyPacket(kind: "page", transactionID: UUID(), senderID: deviceID,
                                  book: book, page: page, images: images)
        try stage(packet, to: peer)
        return packet.transactionID
    }

    private func stage(_ packet: NearbyPacket, to peer: MCPeerID) throws {
        guard transport.connected.contains(peer) else { throw NearbyError.notConnected }
        let candidate = NearbyPendingTransfer(packet: packet, targetPeerName: peer.displayName)
        pending.append(candidate)
        do {
            try save() // Never send an unpersisted handoff.
            try transport.send(packet, to: peer)
        } catch {
            // Keep the persisted transfer so it can be retried after reconnecting.
            errorMessage = "受け渡しの確認待ちです。接続後に再送してください。"
            throw error
        }
    }

    func retry(bookID: UUID, to peer: MCPeerID) throws {
        guard let waiting = pendingTransfer(for: bookID) else { throw NearbyError.invalidPacket }
        guard waiting.targetPeerName == peer.displayName else { throw NearbyError.invalidPacket }
        try transport.send(waiting.packet, to: peer)
    }

    private func handle(_ data: Data, from peer: MCPeerID) {
        guard let packet = try? JSONDecoder().decode(NearbyPacket.self, from: data),
              packet.book.members.count == 2,
              packet.book.title.count <= 60,
              packet.book.title.count > 0,
              packet.book.revision >= 0,
              packet.book.currentTurn >= 0 && packet.book.currentTurn < 2,
              packet.images.count <= 4,
              packet.images.values.reduce(0, { $0 + $1.count }) <= 6_000_000
        else {
            errorMessage = "受信したデータを読み取れませんでした。"
            return
        }
        if packet.kind == "ack" {
            acceptAck(packet, from: peer)
            return
        }
        if packet.kind == "decline" {
            if let index = pending.firstIndex(where: {
                $0.packet.transactionID == packet.transactionID &&
                $0.targetPeerName == peer.displayName
            }) {
                pending.remove(at: index)
                try? save()
                errorMessage = "相手が受け取りを見送りました。日記の下書きはそのまま残っています。"
            }
            return
        }
        guard packet.kind == "pair" || packet.kind == "page" else { return }
        // A repeated reliable message after an acknowledgement was lost
        // must be acknowledged again without duplicating the page.
        if packet.kind == "pair",
           let existing = book(packet.book.id),
           existing.members[0].id == packet.senderID,
           existing.members[1].id == deviceID,
           existing.revision == 1 {
            sendAck(transactionID: packet.transactionID, book: existing, to: peer)
            return
        }
        if packet.kind == "page",
           let existing = book(packet.book.id),
           let page = packet.page,
           pages.contains(where: { $0.id == page.id }),
           existing.revision == packet.book.revision {
            sendAck(transactionID: packet.transactionID, book: existing, to: peer)
            return
        }
        guard incoming == nil else { return }
        incoming = NearbyIncoming(packet: packet, peer: peer)
    }

    func rejectIncoming() {
        guard let incoming else { return }
        let decline = NearbyPacket(
            kind: "decline", transactionID: incoming.packet.transactionID,
            senderID: deviceID, book: incoming.packet.book,
            page: nil, images: [:]
        )
        try? transport.send(decline, to: incoming.peer)
        self.incoming = nil
    }

    func acceptIncoming() {
        guard let incoming else { return }
        defer { self.incoming = nil }
        let packet = incoming.packet
        let peer = incoming.peer
        do {
            if packet.kind == "pair" {
                guard book(packet.book.id) == nil,
                      packet.book.members[0].id == packet.senderID,
                      packet.book.members[1].id.isEmpty,
                      packet.book.revision == 0 else { throw NearbyError.invalidPacket }
                var newBook = packet.book
                newBook.members[1].id = deviceID
                newBook.revision = 1
                newBook.updatedAt = .now
                books.insert(newBook, at: 0)
                try save()
                sendAck(transactionID: packet.transactionID, book: newBook, to: peer)
            } else if packet.kind == "page" {
                guard let old = book(packet.book.id),
                      old.isPaired,
                      old.members == packet.book.members,
                      old.members[old.currentTurn].id == packet.senderID,
                      old.members.contains(where: { $0.id == deviceID }),
                      packet.book.revision == old.revision + 1,
                      packet.book.currentTurn == (old.currentTurn + 1) % 2,
                      let page = packet.page,
                      page.bookID == old.id,
                      page.sequence == packet.book.revision,
                      page.authorID == packet.senderID,
                      page.author == old.currentWriter,
                      page.title.count <= 80, page.body.count <= 5000,
                      page.decoration.photos.count <= 4,
                      page.decoration.stickers.count <= 24,
                      packet.images.count == page.decoration.photos.count
                else { throw NearbyError.invalidPacket }
                for photo in page.decoration.photos {
                    guard let bytes = packet.images[photo.id.uuidString],
                          bytes.count <= 1_500_000 else { throw NearbyError.invalidPacket }
                    try DiaryPhotoVault.cache(bytes, for: photo)
                }
                pages.insert(page, at: 0)
                if let i = books.firstIndex(where: { $0.id == old.id }) {
                    books[i] = packet.book
                }
                try save()
                sendAck(transactionID: packet.transactionID, book: packet.book, to: peer)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func sendAck(transactionID: UUID, book: NearbyBook, to peer: MCPeerID) {
        let packet = NearbyPacket(kind: "ack", transactionID: transactionID,
                                  senderID: deviceID, book: book, page: nil, images: [:])
        do { try transport.send(packet, to: peer) }
        catch { errorMessage = "受け取りは保存しました。相手に再送してもらうと確認できます。" }
    }

    private func acceptAck(_ ack: NearbyPacket, from peer: MCPeerID) {
        guard let i = pending.firstIndex(where: {
            $0.packet.transactionID == ack.transactionID &&
            $0.targetPeerName == peer.displayName
        }) else { return }
        let waiting = pending[i].packet
        guard transport.connected.contains(peer),
              ack.book.id == waiting.book.id,
              ack.book.members.count == 2,
              ack.book.members[0].id == waiting.book.members[0].id,
              ack.book.currentTurn == waiting.book.currentTurn else { return }
        if waiting.kind == "pair" {
            guard ack.book.members[1].id == ack.senderID else { return }
        } else {
            guard ack.book.members[ack.book.currentTurn].id == ack.senderID else { return }
        }
        if waiting.kind == "pair" {
            guard ack.book.revision == 1,
                  ack.book.members[0] == waiting.book.members[0],
                  ack.book.members[1].name == waiting.book.members[1].name,
                  book(ack.book.id)?.revision == 0 else { return }
        } else {
            guard waiting.kind == "page",
                  ack.book.revision == waiting.book.revision,
                  ack.book.members == waiting.book.members,
                  book(ack.book.id)?.revision == waiting.book.revision - 1,
                  let page = waiting.page else { return }
            pages.insert(page, at: 0)
        }
        if let index = books.firstIndex(where: { $0.id == ack.book.id }) {
            books[index] = ack.book
        }
        pending.remove(at: i)
        do {
            try save()
            if waiting.kind == "page" {
                UserDefaults.standard.removeObject(
                    forKey: "mawaru.nearby.draft.\(ack.book.id.uuidString)"
                )
            }
            lastCompletedTransfer = ack.transactionID
        } catch {
            errorMessage = "受け渡しは完了しましたが、保存に失敗しました。"
        }
    }
}

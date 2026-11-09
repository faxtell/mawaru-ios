import Foundation
import MultipeerConnectivity

// Peer-to-peer transfer intentionally requires both people to be online on
// their local radios and to explicitly approve the invitation and diary.
// Unlike Firebase this never uploads a nearby diary to a server.
struct NearbyDiaryPacket: Codable, Identifiable {
    var id: UUID
    var book: DiaryBook
    var newEntry: DiaryEntry
    var pages: [DiaryEntry]
    var assets: [String: Data]
    var senderIndex: Int
    var recipientIndex: Int

    var recipientName: String {
        book.members.indices.contains(recipientIndex) ?
            book.members[recipientIndex] : "メンバー"
    }
}

struct NearbyWireMessage: Codable {
    var type: String
    var packet: NearbyDiaryPacket?
    var acknowledgement: UUID?
}

struct NearbyIncomingInvite: Identifiable {
    let id = UUID()
    var peer: MCPeerID
}

struct NearbyIncomingDiary: Identifiable {
    var id: UUID { packet.id }
    let packet: NearbyDiaryPacket
    let peer: MCPeerID
}

enum NearbyDiaryProblem: LocalizedError {
    case notNearby, notYourTurn, oversized, incomplete, invalidPacket
    var errorDescription: String? {
        switch self {
        case .notNearby: "相手のiPhoneと接続してください。"
        case .notYourTurn: "この日記帳は、いま自分の番ではありません。"
        case .oversized: "この日記帳の写真が多すぎます。画像を減らすかオンライン交換をご利用ください。"
        case .incomplete: "写真の読み込みに失敗しました。もう一度貼り直してください。"
        case .invalidPacket: "受信した交換日記を検証できませんでした。"
        }
    }
}

@MainActor
final class NearbyDiaryService: NSObject, ObservableObject {
    private static let serviceType = "mawaru-diary"
    private static let maxWireBytes = 12_000_000

    @Published private(set) var isDiscovering = false
    @Published private(set) var foundPeers: [MCPeerID] = []
    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published var incomingInvite: NearbyIncomingInvite?
    @Published var incomingDiary: NearbyIncomingDiary?
    @Published var message: String?
    @Published private(set) var lastAcknowledged: UUID?

    private let myPeer: MCPeerID
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let advertiser: MCNearbyServiceAdvertiser
    private var invitationHandler: ((Bool, MCSession?) -> Void)?
    private var pendingSent: (packet: NearbyDiaryPacket, peer: MCPeerID)?
    weak var store: DiaryStore?

    override init() {
        let defaults = UserDefaults.standard
        let name: String
        if let existing = defaults.string(forKey: "mawaru.nearby.deviceName") {
            name = existing
        } else {
            name = "まわる-" + String(UUID().uuidString.prefix(4))
            defaults.set(name, forKey: "mawaru.nearby.deviceName")
        }
        myPeer = MCPeerID(displayName: name)
        session = MCSession(peer: myPeer, securityIdentity: nil,
                            encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: myPeer, serviceType: Self.serviceType)
        advertiser = MCNearbyServiceAdvertiser(peer: myPeer,
                                                discoveryInfo: ["version": "1"],
                                                serviceType: Self.serviceType)
        super.init()
        session.delegate = self
        browser.delegate = self
        advertiser.delegate = self
    }

    var deviceName: String { myPeer.displayName }

    func start() {
        guard !isDiscovering else { return }
        browser.startBrowsingForPeers()
        advertiser.startAdvertisingPeer()
        isDiscovering = true
    }
    func stop() {
        browser.stopBrowsingForPeers()
        advertiser.stopAdvertisingPeer()
        isDiscovering = false
        foundPeers = []
    }
    func invite(_ peer: MCPeerID) {
        guard foundPeers.contains(peer) else { return }
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
        message = "\(peer.displayName) に接続をリクエストしました。"
    }
    func answerInvitation(accept: Bool) {
        invitationHandler?(accept, accept ? session : nil)
        invitationHandler = nil
        incomingInvite = nil
    }

    func send(_ packet: NearbyDiaryPacket, to peer: MCPeerID) throws {
        guard connectedPeers.contains(peer) else { throw NearbyDiaryProblem.notNearby }
        guard pendingSent == nil else {
            message = "前の受け渡しの返事を待っています。"
            return
        }
        let wire = NearbyWireMessage(type: "offer", packet: packet, acknowledgement: nil)
        let data = try JSONEncoder().encode(wire)
        guard data.count <= Self.maxWireBytes else { throw NearbyDiaryProblem.oversized }
        try session.send(data, toPeers: [peer], with: .reliable)
        pendingSent = (packet, peer)
        message = "\(peer.displayName) に日記を送りました。相手の承認を待っています。"
    }

    func acceptDiary() {
        guard let incomingDiary, let store else { return }
        let packet = incomingDiary.packet
        do {
            try store.acceptNearby(packet)
            let ack = NearbyWireMessage(type: "receipt", packet: nil, acknowledgement: packet.id)
            let data = try JSONEncoder().encode(ack)
            try session.send(data, toPeers: [incomingDiary.peer], with: .reliable)
            message = "「\(packet.book.title)」を受け取りました ♡ 次はあなたの番です。"
            self.incomingDiary = nil
        } catch {
            message = "保存または返事の送信に失敗しました：\(error.localizedDescription)"
        }
    }
    func rejectDiary() {
        incomingDiary = nil
    }
    private func receive(_ data: Data, from peer: MCPeerID) {
        guard data.count <= Self.maxWireBytes,
              let wire = try? JSONDecoder().decode(NearbyWireMessage.self, from: data)
        else {
            message = "受信データを読み込めませんでした。"
            return
        }
        if wire.type == "offer", let packet = wire.packet {
            guard connectedPeers.contains(peer),
                  packet.book.mode == "nearby",
                  packet.book.members.count >= 2,
                  packet.book.members.count <= 5,
                  packet.recipientIndex == packet.book.turnIndex,
                  packet.book.members.indices.contains(packet.senderIndex),
                  packet.newEntry.bookID == packet.book.id,
                  packet.newEntry.author == packet.book.members[packet.senderIndex],
                  packet.pages.contains(where: { $0.id == packet.newEntry.id }),
                  packet.assets.values.reduce(0, { $0 + $1.count }) < Self.maxWireBytes
            else {
                message = "安全確認に失敗した交換日記は受け取れません。"
                return
            }
            incomingDiary = NearbyIncomingDiary(packet: packet, peer: peer)
        } else if wire.type == "receipt", let id = wire.acknowledgement,
                  let sent = pendingSent, sent.packet.id == id, sent.peer == peer {
            do {
                try store?.completeNearby(sent.packet)
                UserDefaults.standard.removeObject(
                    forKey: "mawaru.nearby.draft.\(sent.packet.book.id.uuidString)"
                )
                pendingSent = nil
                lastAcknowledged = id
                message = "日記を無事に渡せました ♡"
            } catch {
                message = "受取確認は届きましたが、端末への保存に失敗しました：\(error.localizedDescription)"
            }
        }
    }
}

extension NearbyDiaryService: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              foundPeer peerID: MCPeerID,
                              withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            guard peerID != self.myPeer else { return }
            if !self.foundPeers.contains(peerID) { self.foundPeers.append(peerID) }
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.foundPeers.removeAll { $0 == peerID }
        }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser,
                              didNotStartBrowsingForPeers error: Error) {
        Task { @MainActor in
            self.message = "近くの端末を検索できません：\(error.localizedDescription)"
            self.isDiscovering = false
        }
    }
}

extension NearbyDiaryService: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                 didReceiveInvitationFromPeer peerID: MCPeerID,
                                 withContext context: Data?,
                                 invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            guard self.incomingInvite == nil else {
                invitationHandler(false, nil)
                return
            }
            self.invitationHandler = invitationHandler
            self.incomingInvite = NearbyIncomingInvite(peer: peerID)
        }
    }
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                 didNotStartAdvertisingPeer error: Error) {
        Task { @MainActor in
            self.message = "近くで交換する機能を開始できません：\(error.localizedDescription)"
        }
    }
}

extension NearbyDiaryService: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID,
                              didChange state: MCSessionState) {
        Task { @MainActor in
            self.connectedPeers = session.connectedPeers
            if state == .connected {
                self.message = "\(peerID.displayName) と接続しました。"
            } else if state == .notConnected,
                      let pending = self.pendingSent,
                      pending.peer == peerID {
                self.pendingSent = nil
                self.message = "接続が切れました。下書きは残っています。再接続後に同じページを送ってください。"
            }
        }
    }
    nonisolated func session(_ session: MCSession, didReceive data: Data,
                              fromPeer peerID: MCPeerID) {
        Task { @MainActor in self.receive(data, from: peerID) }
    }
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream,
                              withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession,
                              didStartReceivingResourceWithName resourceName: String,
                              fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession,
                              didFinishReceivingResourceWithName resourceName: String,
                              fromPeer peerID: MCPeerID, at localURL: URL?,
                              withError error: Error?) {}
}

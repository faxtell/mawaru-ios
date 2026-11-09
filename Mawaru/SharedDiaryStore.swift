import SwiftUI
import AuthenticationServices
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import CryptoKit
import Security

// Shared diaries are intentionally separate from the v0.1 on-device demo.
// A Firebase project is optional at compile time; this feature enables only
// after the app bundles its own GoogleService-Info.plist.
struct SharedBook: Identifiable {
    let id: String
    let title: String
    let cover: Int
    let ownerID: String
    let memberIDs: [String]
    let memberNames: [String]
    let currentTurn: Int
    let lastSequence: Int
    let paused: Bool
    let updatedAt: Date

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let title = data["title"] as? String,
              let cover = data["cover"] as? Int,
              let ownerID = data["ownerId"] as? String,
              let memberIDs = data["memberIds"] as? [String],
              let memberNames = data["memberNames"] as? [String],
              let currentTurn = data["currentTurn"] as? Int,
              memberIDs.count == memberNames.count else { return nil }
        self.id = document.documentID
        self.title = title
        self.cover = cover
        self.ownerID = ownerID
        self.memberIDs = memberIDs
        self.memberNames = memberNames
        self.currentTurn = currentTurn
        self.lastSequence = data["lastSequence"] as? Int ?? 0
        self.paused = data["paused"] as? Bool ?? false
        self.updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? .distantPast
    }
    var currentWriter: String {
        memberNames.indices.contains(currentTurn) ? memberNames[currentTurn] : "―"
    }
    func isMyTurn(_ uid: String?) -> Bool {
        guard let uid, memberIDs.count >= 2, !paused,
              memberIDs.indices.contains(currentTurn) else { return false }
        return memberIDs[currentTurn] == uid
    }
}

struct SharedPage: Identifiable {
    let id: String
    let author: String
    let authorID: String
    let title: String
    let body: String
    let sequence: Int
    let decoration: DiaryDecoration
    let createdAt: Date

    init?(document: QueryDocumentSnapshot) {
        let data = document.data()
        guard let author = data["authorName"] as? String,
              let authorID = data["authorId"] as? String,
              let title = data["title"] as? String,
              let body = data["body"] as? String else { return nil }
        id = document.documentID
        self.author = author
        self.authorID = authorID
        self.title = title
        self.body = body
        sequence = data["sequence"] as? Int ?? 0
        decoration = DiaryDecoration.fromCloud(data["decoration"])
        createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? .distantPast
    }
}

@MainActor
final class SharedDiaryStore: ObservableObject {
    @Published private(set) var configured = false
    @Published private(set) var uid: String?
    @Published private(set) var displayName = "わたし"
    @Published private(set) var books: [SharedBook] = []
    @Published var errorMessage: String?

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var booksHandle: ListenerRegistration?
    private var pendingNonce: String?
    private var functions: Functions? {
        guard configured else { return nil }
        return Functions.functions(region: "asia-northeast1")
    }

    init() {
        // Not checking in a Firebase config is deliberate for the public repo.
        configured = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
        guard configured else { return }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.applyAuthUser(user) }
        }
    }

    private func applyAuthUser(_ user: User?) {
        booksHandle?.remove()
        booksHandle = nil
        uid = user?.uid
        displayName = user?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (user?.displayName ?? "わたし") : "わたし"
        books = []
        guard let uid = user?.uid else { return }
        booksHandle = Firestore.firestore().collection("notebooks")
            .whereField("memberIds", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                let list = snapshot?.documents.compactMap(SharedBook.init(document:))
                    .sorted { $0.updatedAt > $1.updatedAt } ?? []
                Task { @MainActor in
                    self?.books = list
                    if let error { self?.errorMessage = error.localizedDescription }
                }
            }
    }

    private func secureNonce() -> String? {
        let alphabet = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else { return nil }
        return String(bytes.map { alphabet[Int($0) % alphabet.count] })
    }
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard let nonce = secureNonce() else {
            errorMessage = "安全なログインの準備に失敗しました。"
            return
        }
        pendingNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }.joined()
    }

    func finishAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard configured else { return }
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let authorization):
            guard let apple = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = apple.identityToken,
                  let token = String(data: tokenData, encoding: .utf8),
                  let nonce = pendingNonce else {
                errorMessage = "Appleから認証情報を取得できませんでした。"
                return
            }
            pendingNonce = nil
            let credential = OAuthProvider.appleCredential(
                withIDToken: token, rawNonce: nonce, fullName: apple.fullName)
            Task {
                do {
                    _ = try await Auth.auth().signIn(with: credential)
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    func signOut() {
        do { try Auth.auth().signOut() }
        catch { errorMessage = error.localizedDescription }
    }

    private func call(_ name: String, data: [String: Any]) async throws -> [String: Any] {
        guard let functions else { throw SharedDiaryError.notConfigured }
        let result = try await functions.httpsCallable(name).call(data)
        guard let payload = result.data as? [String: Any] else {
            throw SharedDiaryError.invalidResponse
        }
        return payload
    }

    func createBook(title: String, cover: Int, name: String) async throws {
        _ = try await call("createNotebook", data: [
            "title": title, "cover": cover, "displayName": name
        ])
    }
    func join(code: String, name: String) async throws {
        _ = try await call("redeemInvitation", data: [
            "code": code.trimmingCharacters(in: .whitespacesAndNewlines),
            "displayName": name
        ])
    }
    func createInvite(bookID: String) async throws -> String {
        let response = try await call("createInvitation", data: ["bookId": bookID])
        guard let code = response["code"] as? String else { throw SharedDiaryError.invalidResponse }
        return code
    }
    func submit(bookID: String, requestID: String, title: String, body: String, decoration: DiaryDecoration) async throws {
        guard let uid else { throw DiaryPhotoError.notConfigured }
        let location = DiaryCloudPhotoLocation(bookID: bookID, entryID: requestID, authorID: uid)
        // Keep the same requestID for retries. The server verifies these objects
        // exist and belong to the current writer before committing the baton.
        for photo in decoration.photos {
            try await DiaryCloudPhotos.upload(photo, location: location)
        }
        _ = try await call("submitEntry", data: [
            "bookId": bookID, "requestId": requestID,
            "title": title, "body": body, "decoration": decoration.cloudValue
        ])
    }
    func setPaused(bookID: String, paused: Bool) async throws {
        _ = try await call("setNotebookPaused", data: [
            "bookId": bookID, "paused": paused
        ])
    }

    func listenToPages(bookID: String, onUpdate: @escaping ([SharedPage]) -> Void) -> ListenerRegistration? {
        guard configured, uid != nil else { return nil }
        return Firestore.firestore().collection("notebooks").document(bookID)
            .collection("entries").order(by: "sequence", descending: true).limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                let pages = snapshot?.documents.compactMap(SharedPage.init(document:)) ?? []
                Task { @MainActor in
                    onUpdate(pages)
                    if let error { self?.errorMessage = error.localizedDescription }
                }
            }
    }
}

enum SharedDiaryError: LocalizedError {
    case notConfigured, invalidResponse
    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Firebaseの接続設定が必要です。"
        case .invalidResponse: return "サーバーから予期しない応答がありました。"
        }
    }
}

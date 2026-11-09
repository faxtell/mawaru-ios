import Foundation

// The optional, full-width legacy photo is not kept in UserDefaults.
// Draft image bytes are saved atomically next to the local draft and removed
// only after a successful baton pass, so closing the editor is safe.
enum DiaryDraftAttachmentStorage {
    private static var directory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
            .appendingPathComponent("MawaruDraftAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static func url(for bookID: UUID) -> URL {
        directory.appendingPathComponent(bookID.uuidString + ".jpg")
    }
    static func load(bookID: UUID) -> Data? {
        try? Data(contentsOf: url(for: bookID))
    }
    static func save(_ jpeg: Data, bookID: UUID) throws {
        try jpeg.write(to: url(for: bookID), options: .atomic)
    }
    static func remove(bookID: UUID) {
        try? FileManager.default.removeItem(at: url(for: bookID))
    }
}

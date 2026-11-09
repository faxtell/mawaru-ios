import SwiftUI
import PhotosUI
import UIKit
import FirebaseStorage

// A photo is a separate movable layer, rather than a fixed attachment to the text.
// Its UUID is retained in the diary JSON. Image bytes live outside UserDefaults.
struct DiaryPastedPhoto: Codable, Identifiable, Equatable {
    var id = UUID()
    var format: String = "jpg"
    var x: Double = 0.5
    var y: Double = 0.5
    var scale: Double = 1
    var rotation: Double = 0

    var cloudValue: [String: Any] {
        [
            "id": id.uuidString,
            "format": format,
            "x": x, "y": y,
            "scale": scale, "rotation": rotation
        ]
    }
}

enum DiaryPhotoError: LocalizedError {
    case unsupported, tooLarge, missingLocalImage, notConfigured
    var errorDescription: String? {
        switch self {
        case .unsupported: "画像を読み込めませんでした。写真またはPNG画像を選んでください。"
        case .tooLarge: "画像を圧縮できませんでした。もう少し小さな画像を使ってください。"
        case .missingLocalImage: "貼り付けた画像が端末に見つかりません。もう一度画像を追加してください。"
        case .notConfigured: "共有画像を保存するにはFirebaseの接続設定が必要です。"
        }
    }
}

enum DiaryPhotoVault {
    static let maxBytes = 1_500_000

    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("MawaruClippings", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func fileURL(_ photo: DiaryPastedPhoto) -> URL {
        folder.appendingPathComponent(photo.id.uuidString + "." + photo.format)
    }

    static func data(for photo: DiaryPastedPhoto) -> Data? {
        guard ["jpg", "png"].contains(photo.format) else { return nil }
        return try? Data(contentsOf: fileURL(photo))
    }

    static func image(for photo: DiaryPastedPhoto) -> UIImage? {
        data(for: photo).flatMap { UIImage(data: $0) }
    }

    static func cache(_ raw: Data, for photo: DiaryPastedPhoto) throws {
        guard raw.count <= 2_000_000, !raw.isEmpty,
              UIImage(data: raw) != nil,
              ["jpg", "png"].contains(photo.format) else { throw DiaryPhotoError.unsupported }
        try raw.write(to: fileURL(photo), options: .atomic)
    }

    static func add(_ image: UIImage, preferPNG: Bool = false) throws -> DiaryPastedPhoto {
        let isTransparent: Bool = {
            guard let alpha = image.cgImage?.alphaInfo else { return preferPNG }
            switch alpha {
            case .first, .last, .premultipliedFirst, .premultipliedLast:
                return true
            default: return preferPNG
            }
        }()
        guard image.size.width > 0, image.size.height > 0 else {
            throw DiaryPhotoError.unsupported
        }
        // Trim large copied images so that a few stickers do not bloat the archive.
        for maxDimension in [1024.0, 800.0, 600.0, 420.0] {
            let factor = min(1, maxDimension / max(image.size.width, image.size.height))
            let resized = CGSize(width: max(1, (image.size.width * factor).rounded()),
                                 height: max(1, (image.size.height * factor).rounded()))
            let format = UIGraphicsImageRendererFormat.default()
            format.opaque = !isTransparent
            format.scale = 1
            let rendered = UIGraphicsImageRenderer(size: resized, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: resized))
            }
            let bytes: Data?
            if isTransparent {
                bytes = rendered.pngData()
            } else {
                bytes = rendered.jpegData(compressionQuality: 0.72)
            }
            if let bytes, bytes.count <= maxBytes {
                let photo = DiaryPastedPhoto(format: isTransparent ? "png" : "jpg")
                try cache(bytes, for: photo)
                return photo
            }
        }
        throw DiaryPhotoError.tooLarge
    }

    static func add(_ data: Data) throws -> DiaryPastedPhoto {
        guard let image = UIImage(data: data) else { throw DiaryPhotoError.unsupported }
        return try add(image)
    }
}

struct DiaryCloudPhotoLocation {
    let bookID: String
    let entryID: String
    let authorID: String

    func path(for photo: DiaryPastedPhoto) -> String {
        "notebooks/\(bookID)/entry-assets/\(entryID)/\(authorID)/\(photo.id.uuidString).\(photo.format)"
    }
}

enum DiaryCloudPhotos {
    static func upload(_ photo: DiaryPastedPhoto, location: DiaryCloudPhotoLocation) async throws {
        guard let bytes = DiaryPhotoVault.data(for: photo) else {
            throw DiaryPhotoError.missingLocalImage
        }
        let ref = Storage.storage().reference(withPath: location.path(for: photo))
        let metadata = StorageMetadata()
        metadata.contentType = photo.format == "png" ? "image/png" : "image/jpeg"
        metadata.customMetadata = ["ownerUid": location.authorID]
        do {
            _ = try await ref.putDataAsync(bytes, metadata: metadata)
        } catch {
            // A successful first upload followed by a network retry must not
            // fail simply because Storage forbids overwriting published assets.
            if let existing = try? await ref.getMetadata(),
               existing.customMetadata?["ownerUid"] == location.authorID,
               existing.contentType == metadata.contentType {
                return
            }
            throw error
        }
    }

    static func download(_ photo: DiaryPastedPhoto,
                         location: DiaryCloudPhotoLocation) async throws -> UIImage {
        if let image = DiaryPhotoVault.image(for: photo) { return image }
        let ref = Storage.storage().reference(withPath: location.path(for: photo))
        let bytes: Data = try await withCheckedThrowingContinuation { continuation in
            _ = ref.getData(maxSize: 2_000_000) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: DiaryPhotoError.unsupported)
                }
            }
        }
        try DiaryPhotoVault.cache(bytes, for: photo)
        guard let image = UIImage(data: bytes) else { throw DiaryPhotoError.unsupported }
        return image
    }
}

struct DiaryPastedPhotoView: View {
    @Binding var photo: DiaryPastedPhoto
    let canvasSize: CGSize
    let editing: Bool
    let cloudLocation: DiaryCloudPhotoLocation?
    let onRemove: () -> Void

    @State private var loadedImage: UIImage?
    @State private var dragged = CGSize.zero
    @State private var pinched: CGFloat = 1
    @State private var spun = Angle.zero

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { dragged = $0.translation }
            .onEnded { value in
                photo.x = min(0.93, max(0.07, photo.x + value.translation.width / max(canvasSize.width, 1)))
                photo.y = min(0.90, max(0.10, photo.y + value.translation.height / max(canvasSize.height, 1)))
                dragged = .zero
            }
    }
    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { pinched = $0 }
            .onEnded { value in
                photo.scale = min(2.5, max(0.5, photo.scale * Double(value)))
                pinched = 1
            }
    }
    private var rotateGesture: some Gesture {
        RotationGesture()
            .onChanged { spun = $0 }
            .onEnded { value in
                photo.rotation = min(180, max(-180, photo.rotation + value.degrees))
                spun = .zero
            }
    }

    private var photoAppearance: some View {
        Group {
            if photo.format == "png" {
                // iOS Photos' cut-out subject already contains an alpha channel.
                // Do not add a white rectangle or circle behind the cut-out.
                Group {
                    if let loadedImage {
                        Image(uiImage: loadedImage).resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 126, height: 126)
                .shadow(color: .black.opacity(0.15), radius: 3, y: 3)
            } else {
                Group {
                    if let loadedImage {
                        Image(uiImage: loadedImage).resizable().scaledToFit()
                    } else {
                        Image(systemName: "photo")
                            .font(.title2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 108, height: 104)
                .padding(5)
                .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 7))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 3)
            }
        }
        .contentShape(Rectangle())
        .scaleEffect(photo.scale * Double(pinched))
        .rotationEffect(.degrees(photo.rotation + spun.degrees))
        .offset(dragged)
        .position(x: canvasSize.width * photo.x, y: canvasSize.height * photo.y)
        .accessibilityLabel(photo.format == "png" ? "切り抜いた画像" : "貼り付けた写真")
    }

    var body: some View {
        Group {
            if editing {
                photoAppearance
                    .gesture(moveGesture)
                    .simultaneousGesture(pinchGesture)
                    .simultaneousGesture(rotateGesture)
                    .contextMenu {
                        Button {
                            photo.rotation = min(180, max(-180, photo.rotation + 15))
                        } label: {
                            Label("右に15°回転", systemImage: "rotate.right")
                        }
                        Button {
                            photo.scale = min(2.5, photo.scale + 0.2)
                        } label: {
                            Label("少し大きく", systemImage: "plus.magnifyingglass")
                        }
                        Button {
                            photo.scale = max(0.5, photo.scale - 0.2)
                        } label: {
                            Label("少し小さく", systemImage: "minus.magnifyingglass")
                        }
                        Button(role: .destructive) {
                            onRemove()
                        } label: {
                            Label("写真を剥がす", systemImage: "trash")
                        }
                    }
            } else {
                photoAppearance.allowsHitTesting(false)
            }
        }
        .task(id: photo.id) {
            if let image = DiaryPhotoVault.image(for: photo) {
                loadedImage = image
            } else if let cloudLocation {
                loadedImage = try? await DiaryCloudPhotos.download(photo, location: cloudLocation)
            }
        }
    }
}

struct DiaryPhotoInsertionControls: View {
    @Binding var decoration: DiaryDecoration
    @State private var pickerItem: PhotosPickerItem?
    @State private var errorMessage: String?

    private var full: Bool { decoration.photos.count >= 4 }
    private func add(_ image: UIImage, preferPNG: Bool = false) {
        guard !full else { return }
        do {
            let photo = try DiaryPhotoVault.add(image, preferPNG: preferPNG)
            decoration.photos.append(photo)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("自分の画像を貼る", systemImage: "photo.on.rectangle.angled")
                .font(.subheadline.bold())
            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("写真から", systemImage: "photo.badge.plus")
                }
                .buttonStyle(.bordered)
                .disabled(full)
                Button {
                    // UIPasteboard is only read after an explicit user tap.
                    if let copied = UIPasteboard.general.image {
                        add(copied, preferPNG: true)
                    } else {
                        errorMessage = "画像がコピーされていないようです。写真やイラストをコピーしてから試してね。"
                    }
                } label: {
                    Label("ペースト", systemImage: "document.on.clipboard")
                }
                .buttonStyle(.bordered)
                .disabled(full)
            }
            Text("写真アプリで被写体を長押しして、そのままノートへドラッグ＆ドロップもできるよ！ 透明PNGは背景なしで貼れます。最大4枚。")
                .font(.caption).foregroundStyle(.secondary)
            Text("\(decoration.photos.count)/4枚")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .onChange(of: pickerItem) { _, selection in
            guard let selection else { return }
            Task {
                do {
                    guard let data = try await selection.loadTransferable(type: Data.self) else {
                        throw DiaryPhotoError.unsupported
                    }
                    // A downloaded photo may be HEIC; UIKit normalizes it before saving.
                    let photo = try DiaryPhotoVault.add(data)
                    if decoration.photos.count < 4 {
                        decoration.photos.append(photo)
                    }
                } catch {
                    errorMessage = error.localizedDescription
                }
                pickerItem = nil
            }
        }
        .alert("画像を貼れませんでした", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
}

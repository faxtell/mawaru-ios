import SwiftUI
import UniformTypeIdentifiers
import UIKit

// Photos cut-out subjects are delivered as NSItemProvider image data.
// Start loading before the onDrop closure returns, as required by UIKit.
enum DiaryImageDropHandler {
    static func receive(
        _ providers: [NSItemProvider],
        at point: CGPoint,
        on size: CGSize,
        onLoaded: @escaping @MainActor (UIImage, CGPoint) -> Void,
        onFailure: @escaping @MainActor (String) -> Void
    ) -> Bool {
        guard let provider = providers.first(where: {
            $0.canLoadObject(ofClass: UIImage.self) ||
            $0.hasItemConformingToTypeIdentifier(UTType.png.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.image.identifier)
        }) else { return false }
        let location = CGPoint(
            x: min(0.9, max(0.1, point.x / max(size.width, 1))),
            y: min(0.9, max(0.1, point.y / max(size.height, 1)))
        )
        if provider.canLoadObject(ofClass: UIImage.self) {
            _ = provider.loadObject(ofClass: UIImage.self) { object, error in
                Task { @MainActor in
                    if let image = object as? UIImage {
                        onLoaded(image, location)
                    } else {
                        onFailure(error?.localizedDescription ?? "切り抜いた画像を読み込めませんでした。")
                    }
                }
            }
        } else {
            let type = provider.hasItemConformingToTypeIdentifier(UTType.png.identifier) ?
                UTType.png.identifier : UTType.image.identifier
            provider.loadDataRepresentation(forTypeIdentifier: type) { data, error in
                Task { @MainActor in
                    if let data, let image = UIImage(data: data) {
                        onLoaded(image, location)
                    } else {
                        onFailure(error?.localizedDescription ?? "画像データを読み込めませんでした。")
                    }
                }
            }
        }
        return true
    }
}

import Foundation
import UIKit

// @covers AC-HOME-06, AC-HOME-07, FR-HOME-01

@MainActor
final class HomePhotoCache {
    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL

    init() {
        memory.countLimit = 32
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = base.appendingPathComponent("HomePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func image(for storagePath: String) -> UIImage? {
        let key = storagePath as NSString
        if let cached = memory.object(forKey: key) {
            return cached
        }
        guard let data = try? Data(contentsOf: fileURL(for: storagePath)),
              let image = UIImage(data: data) else {
            return nil
        }
        memory.setObject(image, forKey: key)
        return image
    }

    func store(_ data: Data, for storagePath: String) throws {
        try data.write(to: fileURL(for: storagePath), options: .atomic)
        if let image = UIImage(data: data) {
            memory.setObject(image, forKey: storagePath as NSString)
        }
    }

    func remove(for storagePath: String) {
        memory.removeObject(forKey: storagePath as NSString)
        try? FileManager.default.removeItem(at: fileURL(for: storagePath))
    }

    private func fileURL(for storagePath: String) -> URL {
        let safeName = storagePath
            .replacingOccurrences(of: "/", with: "_")
            .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? storagePath
        return directory.appendingPathComponent("\(safeName).jpg")
    }
}

enum HomePhotoProcessor {
    /// Keeps uploads small enough for hero cards while preserving edit quality.
    static func jpegData(from data: Data, maxPixelSize: CGFloat, compressionQuality: CGFloat = 0.82) throws -> Data {
        guard let image = UIImage(data: data),
              let jpeg = resizedImage(image, maxPixelSize: maxPixelSize)?
            .jpegData(compressionQuality: compressionQuality) else {
            throw HomePhotoError.invalidImage
        }
        return jpeg
    }

    static func resizedImage(_ image: UIImage, maxPixelSize: CGFloat) -> UIImage? {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let longest = max(size.width, size.height)
        guard longest > maxPixelSize else { return image }

        let scale = maxPixelSize / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

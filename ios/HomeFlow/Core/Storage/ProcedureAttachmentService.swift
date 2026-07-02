import Foundation
import Supabase
import UIKit

// @covers FR-PROC-03

@MainActor
final class ProcedureAttachmentService {
    private let client: SupabaseClient
    private let cache = HomePhotoCache(directoryName: "ProcedureAttachments")
    private var signedURLCache: [String: CachedSignedURL] = [:]

    private static let bucket = "procedure-attachments"
    private static let uploadMaxPixelSize: CGFloat = 1280
    private static let signedURLTTL: TimeInterval = 3600
    private static let signedURLRefreshLead: TimeInterval = 300

    init(client: SupabaseClient) {
        self.client = client
    }

    func cachedImage(storagePath: String) -> UIImage? {
        cache.image(for: storagePath)
    }

    func loadImage(storagePath: String) async throws -> UIImage {
        if let cached = cache.image(for: storagePath) {
            return cached
        }

        let signedURL = try await signedURL(for: storagePath)
        let (data, _) = try await URLSession.shared.data(from: signedURL)
        guard let image = UIImage(data: data) else {
            throw ProcedureAttachmentError.invalidImage
        }
        if let jpeg = image.jpegData(compressionQuality: 0.92) {
            try? cache.store(jpeg, for: storagePath)
        }
        return image
    }

    func uploadPhoto(homeId: UUID, procedureId: UUID, imageData: Data) async throws -> String {
        let jpeg = try HomePhotoProcessor.jpegData(
            from: imageData,
            maxPixelSize: Self.uploadMaxPixelSize
        )
        let path = "\(homeId.uuidString)/\(procedureId.uuidString)/\(UUID().uuidString).jpg"
        try await client.storage
            .from(Self.bucket)
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: true))
        try cache.store(jpeg, for: path)
        return path
    }

    func signedURL(for storagePath: String) async throws -> URL {
        let now = Date()
        if let cached = signedURLCache[storagePath],
           cached.expiresAt.timeIntervalSince(now) > Self.signedURLRefreshLead {
            return cached.url
        }

        let url = try await client.storage
            .from(Self.bucket)
            .createSignedURL(path: storagePath, expiresIn: Int(Self.signedURLTTL))

        signedURLCache[storagePath] = CachedSignedURL(
            url: url,
            expiresAt: now.addingTimeInterval(Self.signedURLTTL)
        )
        return url
    }
}

private struct CachedSignedURL {
    let url: URL
    let expiresAt: Date
}

enum ProcedureAttachmentError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Could not process the selected photo."
        }
    }
}

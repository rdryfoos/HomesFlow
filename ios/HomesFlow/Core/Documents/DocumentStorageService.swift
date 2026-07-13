import Foundation
import Supabase

// @covers FR-HOME-03, AC-HOME-06

@MainActor
final class DocumentStorageService {
    private let client: SupabaseClient
    private var signedURLCache: [String: CachedSignedURL] = [:]

    private static let bucket = "documents"
    private static let signedURLTTL: TimeInterval = 3600
    private static let signedURLRefreshLead: TimeInterval = 300

    init(client: SupabaseClient) {
        self.client = client
    }

    func upload(homeId: UUID, documentId: UUID, fileName: String, data: Data) async throws -> String {
        let safeName = fileName.replacingOccurrences(of: "/", with: "_")
        let path = "\(homeId.uuidString)/\(documentId.uuidString)/\(safeName)"
        try await client.storage
            .from(Self.bucket)
            .upload(path, data: data, options: FileOptions(contentType: mimeType(for: safeName), upsert: true))
        return path
    }

    func delete(storagePath: String) async throws {
        try await client.storage.from(Self.bucket).remove(paths: [storagePath])
        signedURLCache.removeValue(forKey: storagePath)
    }

    func signedURL(for storagePath: String) async throws -> URL {
        if let cached = signedURLCache[storagePath], cached.expiresAt.timeIntervalSinceNow > Self.signedURLRefreshLead {
            return cached.url
        }
        let url = try await client.storage
            .from(Self.bucket)
            .createSignedURL(path: storagePath, expiresIn: Int(Self.signedURLTTL))
        signedURLCache[storagePath] = CachedSignedURL(url: url, expiresAt: .now.addingTimeInterval(Self.signedURLTTL))
        return url
    }

    private func mimeType(for fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "pdf": "application/pdf"
        case "jpg", "jpeg": "image/jpeg"
        case "png": "image/png"
        case "heic": "image/heic"
        case "txt": "text/plain"
        default: "application/octet-stream"
        }
    }
}

private struct CachedSignedURL {
    let url: URL
    let expiresAt: Date
}

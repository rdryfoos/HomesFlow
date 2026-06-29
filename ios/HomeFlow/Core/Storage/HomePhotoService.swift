import Foundation
import Supabase
import UIKit

// @covers AC-HOME-01, FR-HOME-01

@MainActor
final class HomePhotoService {
    private let client: SupabaseClient
    private static let bucket = "home-photos"

    init(client: SupabaseClient) {
        self.client = client
    }

    func uploadPhoto(homeId: UUID, imageData: Data) async throws -> String {
        let jpeg = try normalizedJPEG(from: imageData)
        let path = "\(homeId.uuidString)/\(UUID().uuidString).jpg"
        try await client.storage
            .from(Self.bucket)
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: true))
        return path
    }

    func signedURL(for storagePath: String) async throws -> URL {
        try await client.storage
            .from(Self.bucket)
            .createSignedURL(path: storagePath, expiresIn: 3600)
    }

    private func normalizedJPEG(from data: Data) throws -> Data {
        guard let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85) else {
            throw HomePhotoError.invalidImage
        }
        return jpeg
    }
}

enum HomePhotoError: LocalizedError {
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .invalidImage: "Could not process the selected photo."
        }
    }
}

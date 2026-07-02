import Foundation

// @covers FR-HOME-03, AC-GUEST-01

struct DocumentDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let title: String
    let category: String?
    let storagePath: String?
    let visibility: Visibility
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, category, visibility
        case homeId = "home_id"
        case storagePath = "storage_path"
        case updatedAt = "updated_at"
    }
}

struct DocumentSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let homeId: UUID
    let title: String
    let category: String?
    let storagePath: String?
    let visibility: Visibility

    var fileExtension: String? {
        guard let storagePath else { return nil }
        let ext = (storagePath as NSString).pathExtension
        return ext.isEmpty ? nil : ext.uppercased()
    }
}

struct DocumentDraft: Sendable, Equatable {
    var title = ""
    var category = ""
    var visibility: Visibility = .manager

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum DocumentError: LocalizedError {
    case notAuthorized
    case notFound
    case offlineUpload
    case missingFile

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "You don't have permission to manage this file."
        case .notFound: "File not found."
        case .offlineUpload: "Upload files while connected to the internet."
        case .missingFile: "Choose a file to upload."
        }
    }
}

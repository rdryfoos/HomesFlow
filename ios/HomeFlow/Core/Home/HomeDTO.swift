import Foundation

struct HomeDTO: Codable, Sendable {
    let id: UUID
    let name: String
    let streetAddress: String
    let photoURL: String?
    let createdBy: UUID
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name
        case streetAddress = "street_address"
        case photoURL = "photo_url"
        case createdBy = "created_by"
        case updatedAt = "updated_at"
    }
}

struct HomeSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let streetAddress: String
    let photoURL: String?
}

enum HomeValidationError: LocalizedError, Equatable {
    case nameRequired
    case addressRequired

    var errorDescription: String? {
        switch self {
        case .nameRequired: "Home name is required."
        case .addressRequired: "Street address is required."
        }
    }
}

enum HomeValidator {
    /// @covers AC-HOME-02
    static func validate(name: String, streetAddress: String) -> Result<Void, HomeValidationError> {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.nameRequired)
        }
        if streetAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.addressRequired)
        }
        return .success(())
    }
}

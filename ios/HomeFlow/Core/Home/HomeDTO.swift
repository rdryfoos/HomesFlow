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
    let isPendingSync: Bool
    let currentUserRole: HomeRole?

    init(
        id: UUID,
        name: String,
        streetAddress: String,
        photoURL: String? = nil,
        isPendingSync: Bool = false,
        currentUserRole: HomeRole? = nil
    ) {
        self.id = id
        self.name = name
        self.streetAddress = streetAddress
        self.photoURL = photoURL
        self.isPendingSync = isPendingSync
        self.currentUserRole = currentUserRole
    }

    /// Full address when short; otherwise city/state from comma-separated address.
    var locationLabel: String {
        let trimmed = streetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return streetAddress }
        if trimmed.count <= 48 { return trimmed }
        let parts = trimmed.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.count >= 2 {
            return parts.suffix(2).joined(separator: ", ")
        }
        return trimmed
    }
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

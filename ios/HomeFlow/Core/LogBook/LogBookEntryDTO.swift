import Foundation

// @covers FR-LOG-02, AC-LOG-01, AC-LOG-02, AC-LOG-03

struct LogBookEntryDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let procedureId: UUID?
    let authorId: UUID
    let body: String
    let createdAt: Date
    let receivedAt: Date
    let editedAt: Date?
    let profiles: AuthorProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case procedureId = "procedure_id"
        case authorId = "author_id"
        case body
        case createdAt = "created_at"
        case receivedAt = "received_at"
        case editedAt = "edited_at"
        case profiles
    }

    struct AuthorProfile: Codable, Sendable {
        let displayName: String?
        let email: String?

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case email
        }
    }
}

struct LogBookEntrySummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let homeId: UUID
    let procedureId: UUID?
    let authorId: UUID
    let authorLabel: String
    let body: String
    let createdAt: Date
    let receivedAt: Date?
    let editedAt: Date?
    let procedureTitle: String?

    var scopeLabel: String {
        if let procedureTitle {
            return procedureTitle
        }
        return "Household"
    }
}

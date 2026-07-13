import Foundation

// @covers FR-LOG-01

struct ActivityLogDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let actorId: UUID
    let entityType: String
    let entityId: UUID?
    let action: String
    let summary: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, action, summary
        case homeId = "home_id"
        case actorId = "actor_id"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case createdAt = "created_at"
    }
}

struct ActivityLogSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let summary: String
    let createdAt: Date
}

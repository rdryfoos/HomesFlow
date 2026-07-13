import Foundation

struct ProfileDTO: Codable, Sendable {
    let email: String?
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case email
        case displayName = "display_name"
    }
}

struct MembershipDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let userId: UUID
    let role: HomeRole
    let updatedAt: Date?
    let profiles: ProfileDTO?

    enum CodingKeys: String, CodingKey {
        case id, role, profiles
        case homeId = "home_id"
        case userId = "user_id"
        case updatedAt = "updated_at"
    }
}

struct InviteDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let email: String
    let role: HomeRole
    let token: String
    let status: InviteStatus
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, email, role, token, status
        case homeId = "home_id"
        case updatedAt = "updated_at"
    }
}

struct MemberSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let userId: UUID
    let email: String
    let displayName: String
    let role: HomeRole
}

struct InviteSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let email: String
    let role: HomeRole
    let token: String
    let status: InviteStatus
}

struct HomeMembersSnapshot: Sendable {
    let members: [MemberSummary]
    let pendingInvites: [InviteSummary]
    let currentUserRole: HomeRole?
}

import Foundation

// @covers AC-USER-01, AC-USER-02, AC-USER-06, AC-USER-07

/// Client-side invite rules. Server-side enforcement lives in the
/// `accept_invite` RPC and RLS policies (migration 002); these mirror the
/// same rules so the UI fails fast with actionable errors.
enum InvitePolicy {

    /// AC-USER-01: only Owners create invites, and only for Manager/Guest roles.
    static func validate(email: String, role: HomeRole, currentUserRole: HomeRole?) throws {
        guard currentUserRole == .owner else { throw MemberError.notAuthorized }
        guard role == .manager || role == .guest else { throw MemberError.invalidInviteRole }
        guard normalizedEmail(email).contains("@") else { throw MemberError.invalidEmail }
    }

    static func normalizedEmail(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Opaque single-use token; 32 hex characters, no separators.
    static func generateToken() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    /// AC-USER-02: only pending invites can be accepted; a revoked or
    /// already-accepted token is invalid.
    static func isAcceptable(status: InviteStatus) -> Bool {
        status == .pending
    }

    /// AC-USER-07: accept either a bare token or a pasted invite link
    /// (`homeflow://invite?token=…`). Returns nil when no token is present.
    static func inviteLink(token: String) -> URL {
        URL(string: "homeflow://invite?token=\(token)")!
    }

    /// AC-USER-02: destructive revoke copy for confirmation dialogs.
    static func revokeConfirmationMessage(email: String) -> String {
        "They won't be able to join with this invite link."
    }

    static func extractToken(fromPastedText text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let components = URLComponents(string: trimmed),
           components.scheme != nil,
           let token = components.queryItems?.first(where: { $0.name == "token" })?.value,
           !token.isEmpty {
            return token
        }

        guard !trimmed.contains("://") else { return nil }
        return trimmed
    }
}

/// AC-USER-06: audit summaries record the prior role so owner-visible
/// history shows what a member's access used to be.
enum RoleChangeAudit {
    static func summary(email: String, from previous: HomeRole, to next: HomeRole) -> String {
        "Changed \(email) from \(previous.rawValue) to \(next.rawValue)"
    }
}

/// AC-USER-06: memberships are server-authoritative — role changes require
/// connectivity, so the server row (most recent accepted write) always
/// replaces the local cache on merge.
enum MembershipMerge {
    static func apply(_ row: MembershipDTO, to cached: CachedMembership) {
        cached.role = row.role.rawValue
        cached.displayEmail = row.profiles?.email
        cached.displayName = row.profiles?.displayName
        cached.serverUpdatedAt = row.updatedAt
    }
}

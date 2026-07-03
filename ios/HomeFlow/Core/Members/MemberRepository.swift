import Foundation
import SwiftData
import Supabase

// @covers FR-USER-02, AC-USER-01, AC-USER-02, AC-USER-04…06

@MainActor
final class MemberRepository: ObservableObject {
    private let modelContext: ModelContext
    private let auth: SupabaseClientProvider
    private let activityLog: ActivityLogService

    init(
        modelContext: ModelContext,
        auth: SupabaseClientProvider,
        activityLog: ActivityLogService
    ) {
        self.modelContext = modelContext
        self.auth = auth
        self.activityLog = activityLog
    }

    func fetchHomeMembers(homeId: UUID) async throws -> HomeMembersSnapshot {
        if NetworkMonitor.shared.isConnected {
            try await pullMembersAndInvites(homeId: homeId)
        }
        return cachedSnapshot(homeId: homeId)
    }

    func createInvite(homeId: UUID, email: String, role: HomeRole) async throws -> InviteSummary {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }

        let snapshot = try await fetchHomeMembers(homeId: homeId)
        try InvitePolicy.validate(email: email, role: role, currentUserRole: snapshot.currentUserRole)
        let trimmedEmail = InvitePolicy.normalizedEmail(email)

        struct InviteInsert: Encodable {
            let home_id: UUID
            let email: String
            let role: HomeRole
            let token: String
            let invited_by: UUID
        }

        let token = InvitePolicy.generateToken()
        let row = InviteInsert(
            home_id: homeId,
            email: trimmedEmail,
            role: role,
            token: token,
            invited_by: userId
        )

        let created: InviteDTO = try await auth.client
            .from("invites")
            .insert(row)
            .select()
            .single()
            .execute()
            .value

        try await pullMembersAndInvites(homeId: homeId)

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "invite",
            entityId: created.id,
            action: "created",
            summary: "Invited \(trimmedEmail) as \(role.rawValue)"
        )

        return InviteSummary(
            id: created.id,
            email: created.email,
            role: created.role,
            token: created.token,
            status: created.status
        )
    }

    func revokeInvite(homeId: UUID, inviteId: UUID) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        let snapshot = try await fetchHomeMembers(homeId: homeId)
        guard snapshot.currentUserRole == .owner else { throw MemberError.notAuthorized }

        struct RevokeUpdate: Encodable {
            let status: InviteStatus = .revoked
        }

        try await auth.client
            .from("invites")
            .update(RevokeUpdate())
            .eq("id", value: inviteId.uuidString)
            .execute()

        try await pullMembersAndInvites(homeId: homeId)

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "invite",
            entityId: inviteId,
            action: "revoked",
            summary: "Revoked pending invite"
        )
    }

    func updateMemberRole(homeId: UUID, membershipId: UUID, role: HomeRole) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard role != .owner else { throw MemberError.cannotAssignOwner }

        let snapshot = try await fetchHomeMembers(homeId: homeId)
        guard snapshot.currentUserRole == .owner else { throw MemberError.notAuthorized }
        guard let member = snapshot.members.first(where: { $0.id == membershipId }) else {
            throw MemberError.notFound
        }

        struct RoleUpdate: Encodable {
            let role: HomeRole
        }

        try await auth.client
            .from("memberships")
            .update(RoleUpdate(role: role))
            .eq("id", value: membershipId.uuidString)
            .execute()

        try await pullMembersAndInvites(homeId: homeId)

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "membership",
            entityId: membershipId,
            action: "role_changed",
            summary: RoleChangeAudit.summary(email: member.email, from: member.role, to: role)
        )
    }

    /// FR-USER-02: Owner removes a member; RLS `memberships_delete` enforces
    /// owner-only server-side. Revoked user loses access on next sync
    /// (`is_home_member` fails closed once the membership row is gone).
    func removeMember(homeId: UUID, membershipId: UUID) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard NetworkMonitor.shared.isConnected else { throw MemberError.offlineRemoval }

        let snapshot = try await fetchHomeMembers(homeId: homeId)
        guard let member = snapshot.members.first(where: { $0.id == membershipId }) else {
            throw MemberError.notFound
        }
        try MemberRemovalPolicy.validate(
            currentUserRole: snapshot.currentUserRole,
            memberRole: member.role
        )

        try await auth.client
            .from("memberships")
            .delete()
            .eq("id", value: membershipId.uuidString)
            .execute()

        try await pullMembersAndInvites(homeId: homeId)

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "membership",
            entityId: membershipId,
            action: "removed",
            summary: "Removed \(member.email) (\(member.role.rawValue)) from home"
        )
    }

    func acceptInvite(token: String) async throws -> UUID {
        guard auth.session != nil else { throw AuthError.notSignedIn }

        struct AcceptParams: Encodable {
            let p_token: String
        }

        let membershipId: UUID = try await auth.client
            .rpc("accept_invite", params: AcceptParams(p_token: token))
            .execute()
            .value

        return membershipId
    }

    private func pullMembersAndInvites(homeId: UUID) async throws {
        let memberships: [MembershipDTO] = try await auth.client
            .from("memberships")
            .select("*, profiles(email, display_name)")
            .eq("home_id", value: homeId.uuidString)
            .execute()
            .value

        let invites: [InviteDTO] = try await auth.client
            .from("invites")
            .select()
            .eq("home_id", value: homeId.uuidString)
            .eq("status", value: InviteStatus.pending.rawValue)
            .execute()
            .value

        mergeCachedMemberships(homeId: homeId, rows: memberships)
        mergeCachedInvites(homeId: homeId, rows: invites)
        try modelContext.save()
    }

    private func mergeCachedMemberships(homeId: UUID, rows: [MembershipDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedMembership>(
            predicate: #Predicate<CachedMembership> { $0.homeId == homeTarget }
        ))) ?? []

        let incomingIds = Set(rows.map(\.id))
        for stale in existing where !incomingIds.contains(stale.id) {
            modelContext.delete(stale)
        }

        for row in rows {
            if let cached = existing.first(where: { $0.id == row.id }) {
                MembershipMerge.apply(row, to: cached)
            } else {
                modelContext.insert(CachedMembership(
                    id: row.id,
                    homeId: row.homeId,
                    userId: row.userId,
                    role: row.role,
                    displayEmail: row.profiles?.email,
                    displayName: row.profiles?.displayName,
                    serverUpdatedAt: row.updatedAt
                ))
            }
        }
    }

    private func mergeCachedInvites(homeId: UUID, rows: [InviteDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedInvite>(
            predicate: #Predicate<CachedInvite> { $0.homeId == homeTarget }
        ))) ?? []

        let incomingIds = Set(rows.map(\.id))
        for stale in existing where !incomingIds.contains(stale.id) {
            modelContext.delete(stale)
        }

        for row in rows {
            if let cached = existing.first(where: { $0.id == row.id }) {
                cached.email = row.email
                cached.role = row.role.rawValue
                cached.token = row.token
                cached.status = row.status.rawValue
            } else {
                modelContext.insert(CachedInvite(
                    id: row.id,
                    homeId: row.homeId,
                    email: row.email,
                    role: row.role,
                    token: row.token,
                    status: row.status
                ))
            }
        }
    }

    private func cachedSnapshot(homeId: UUID) -> HomeMembersSnapshot {
        let homeTarget = homeId
        let userId = auth.session?.user.id

        let memberships = (try? modelContext.fetch(FetchDescriptor<CachedMembership>(
            predicate: #Predicate<CachedMembership> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.displayEmail)]
        ))) ?? []

        let invites = (try? modelContext.fetch(FetchDescriptor<CachedInvite>(
            predicate: #Predicate<CachedInvite> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.email)]
        ))) ?? []

        let members = memberships.map {
            MemberSummary(
                id: $0.id,
                userId: $0.userId,
                email: $0.displayEmail ?? "Unknown",
                displayName: $0.displayName ?? ($0.displayEmail ?? "Member"),
                role: $0.homeRole
            )
        }

        let pendingInvites = invites
            .filter { InvitePolicy.isAcceptable(status: $0.inviteStatus) }
            .map {
                InviteSummary(
                    id: $0.id,
                    email: $0.email,
                    role: $0.homeRole,
                    token: $0.token,
                    status: $0.inviteStatus
                )
            }

        let currentRole = memberships.first(where: { $0.userId == userId })?.homeRole

        return HomeMembersSnapshot(
            members: members,
            pendingInvites: pendingInvites,
            currentUserRole: currentRole
        )
    }
}

enum MemberError: LocalizedError {
    case notAuthorized
    case invalidEmail
    case invalidInviteRole
    case cannotAssignOwner
    case cannotRemoveOwner
    case offlineRemoval
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "You don't have permission to manage members."
        case .invalidEmail: "Enter a valid email address."
        case .invalidInviteRole: "Invites can only assign Manager or Guest roles."
        case .cannotAssignOwner: "Owner role is assigned to the home creator only."
        case .cannotRemoveOwner: "The home owner can't be removed."
        case .offlineRemoval: "Connect to the internet to remove a member."
        case .notFound: "Member not found."
        }
    }
}

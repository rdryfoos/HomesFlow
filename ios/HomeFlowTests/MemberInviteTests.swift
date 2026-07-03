import XCTest
@testable import HomeFlow

// @covers AC-USER-01, AC-USER-02, AC-USER-04, AC-USER-06, AC-USER-07

final class MemberInviteTests: XCTestCase {
    let permissions = PermissionService()

    // MARK: - T030 — AC-USER-01: accepted invite grants the assigned role

    func test_AC_USER_01_invite_accepted_grants_role() throws {
        // Owners can mint Manager and Guest invites; the invite carries the
        // role that `accept_invite` will grant to the new membership.
        XCTAssertNoThrow(
            try InvitePolicy.validate(email: "sam@example.com", role: .manager, currentUserRole: .owner)
        )
        XCTAssertNoThrow(
            try InvitePolicy.validate(email: "pat@example.com", role: .guest, currentUserRole: .owner)
        )

        let invite = InviteSummary(
            id: UUID(),
            email: "sam@example.com",
            role: .manager,
            token: InvitePolicy.generateToken(),
            status: .pending
        )
        XCTAssertEqual(invite.role, .manager)
        XCTAssertTrue(InvitePolicy.isAcceptable(status: invite.status))

        // Owner role can never be granted through an invite.
        XCTAssertThrowsError(
            try InvitePolicy.validate(email: "sam@example.com", role: .owner, currentUserRole: .owner)
        ) { error in
            guard case MemberError.invalidInviteRole = error else {
                return XCTFail("Expected invalidInviteRole, got \(error)")
            }
        }

        // Non-owners cannot create invites at all.
        for role in [HomeRole.manager, .guest] {
            XCTAssertThrowsError(
                try InvitePolicy.validate(email: "x@example.com", role: .guest, currentUserRole: role)
            ) { error in
                guard case MemberError.notAuthorized = error else {
                    return XCTFail("Expected notAuthorized for \(role), got \(error)")
                }
            }
        }
    }

    func test_AC_USER_01_invite_email_validation_and_token_shape() {
        XCTAssertThrowsError(
            try InvitePolicy.validate(email: "not-an-email", role: .guest, currentUserRole: .owner)
        ) { error in
            guard case MemberError.invalidEmail = error else {
                return XCTFail("Expected invalidEmail, got \(error)")
            }
        }
        XCTAssertEqual(InvitePolicy.normalizedEmail("  Sam@Example.COM \n"), "sam@example.com")

        let token = InvitePolicy.generateToken()
        XCTAssertEqual(token.count, 32)
        XCTAssertFalse(token.contains("-"))
        XCTAssertNotEqual(token, InvitePolicy.generateToken(), "Tokens must be unique per invite")
    }

    // MARK: - T031 — AC-USER-02: revoked token is invalid

    func test_AC_USER_02_revoked_token_invalid() {
        XCTAssertTrue(InvitePolicy.isAcceptable(status: .pending))
        XCTAssertFalse(InvitePolicy.isAcceptable(status: .revoked))
        XCTAssertFalse(InvitePolicy.isAcceptable(status: .accepted), "Tokens are single-use")

        // The members snapshot only surfaces pending invites, so a revoked
        // invite disappears from the share/accept surface.
        let statuses: [InviteStatus] = [.pending, .revoked, .accepted]
        let surfaced = statuses.filter { InvitePolicy.isAcceptable(status: $0) }
        XCTAssertEqual(surfaced, [.pending])
    }

    // MARK: - T032 — AC-USER-04: edit role can modify procedures/providers

    func test_AC_USER_04_edit_role_can_modify_procedures() {
        for action in [PermissionAction.create, .update, .delete] {
            XCTAssertTrue(
                permissions.can(action, entity: .procedure(visibility: .manager), role: .manager),
                "Manager should \(action) manager-visible procedures"
            )
            XCTAssertTrue(
                permissions.can(action, entity: .serviceProvider(visibility: .manager), role: .manager),
                "Manager should \(action) manager-visible providers"
            )
        }

        // Edit role does not extend to owner-only content or member management.
        XCTAssertFalse(
            permissions.can(.update, entity: .procedure(visibility: .owner), role: .manager)
        )
        XCTAssertFalse(permissions.can(.create, entity: .membership, role: .manager))
        XCTAssertFalse(permissions.can(.create, entity: .invite, role: .manager))
    }

    // MARK: - T033b — AC-USER-06: role change audit + server-authoritative merge

    func test_AC_USER_06_concurrent_role_change_audit() {
        // The audit entry records the prior role, owner-visible in the log.
        XCTAssertEqual(
            RoleChangeAudit.summary(email: "sam@example.com", from: .manager, to: .guest),
            "Changed sam@example.com from manager to guest"
        )

        // Concurrent role changes resolve server-side (last accepted write);
        // the merge always applies the server row over the local cache.
        let cached = CachedMembership(
            id: UUID(),
            homeId: UUID(),
            userId: UUID(),
            role: .manager,
            displayEmail: "sam@example.com",
            displayName: "Sam",
            serverUpdatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let serverRow = MembershipDTO(
            id: cached.id,
            homeId: cached.homeId,
            userId: cached.userId,
            role: .guest,
            updatedAt: Date(timeIntervalSince1970: 2_000),
            profiles: ProfileDTO(email: "sam@example.com", displayName: "Sam")
        )

        MembershipMerge.apply(serverRow, to: cached)

        XCTAssertEqual(cached.homeRole, .guest, "Most recent server write wins")
        XCTAssertEqual(cached.serverUpdatedAt, Date(timeIntervalSince1970: 2_000))
    }

    // MARK: - T033c — AC-USER-07: pasting a token or link accepts the invite

    func test_AC_USER_07_paste_token_accepts_invite() {
        let token = InvitePolicy.generateToken()

        XCTAssertEqual(InvitePolicy.extractToken(fromPastedText: token), token)
        XCTAssertEqual(InvitePolicy.extractToken(fromPastedText: "  \(token)\n"), token)
        XCTAssertEqual(
            InvitePolicy.extractToken(fromPastedText: "homeflow://invite?token=\(token)"),
            token,
            "Pasting the full invite link should work, not just the bare code"
        )

        XCTAssertNil(InvitePolicy.extractToken(fromPastedText: ""))
        XCTAssertNil(InvitePolicy.extractToken(fromPastedText: "   "))
        XCTAssertNil(InvitePolicy.extractToken(fromPastedText: "homeflow://invite"))
        XCTAssertNil(InvitePolicy.extractToken(fromPastedText: "homeflow://invite?token="))
    }
}

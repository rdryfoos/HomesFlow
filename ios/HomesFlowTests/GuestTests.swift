import XCTest
@testable import HomesFlow

// @covers AC-GUEST-01, AC-GUEST-02, AC-GUEST-03, AC-GUEST-04, AC-GUEST-05, AC-USER-05

final class GuestTests: XCTestCase {
    let permissions = PermissionService()

    // T062 — AC-GUEST-01: Guests only see guest-visible entities.
    func test_AC_GUEST_01_guest_fields_only() {
        XCTAssertTrue(
            permissions.can(.read, entity: .serviceProvider(visibility: .guest), role: .guest)
        )
        XCTAssertTrue(
            permissions.can(.read, entity: .procedure(visibility: .guest), role: .guest)
        )
        XCTAssertTrue(
            permissions.can(.read, entity: .document(visibility: .guest), role: .guest)
        )

        XCTAssertFalse(
            permissions.can(.read, entity: .serviceProvider(visibility: .manager), role: .guest)
        )
        XCTAssertFalse(
            permissions.can(.read, entity: .procedure(visibility: .owner), role: .guest)
        )
        XCTAssertFalse(
            permissions.can(.read, entity: .document(visibility: .manager), role: .guest)
        )

        XCTAssertFalse(
            permissions.can(.create, entity: .serviceProvider(visibility: .guest), role: .guest)
        )
        XCTAssertFalse(
            permissions.can(.update, entity: .procedure(visibility: .guest), role: .guest)
        )
    }

    // T063a — AC-GUEST-02: Restricted visibility is denied at the permission layer.
    func test_AC_GUEST_02_restricted_deep_link_denied() {
        XCTAssertFalse(
            permissions.can(.read, entity: .procedure(visibility: .manager), role: .guest)
        )
        XCTAssertFalse(
            permissions.can(.read, entity: .document(visibility: .owner), role: .guest)
        )
    }

    // T063b — AC-GUEST-03: Newer server timestamps win over stale local state.
    func test_AC_GUEST_03_offline_visibility_sync() {
        let older = Date(timeIntervalSince1970: 1_000)
        let newer = Date(timeIntervalSince1970: 2_000)

        XCTAssertTrue(
            ProviderConflictResolver.shouldApplyServer(
                localPending: false,
                localUpdatedAt: older,
                serverUpdatedAt: newer
            )
        )
        XCTAssertFalse(
            ProviderConflictResolver.shouldApplyServer(
                localPending: true,
                localUpdatedAt: newer,
                serverUpdatedAt: older
            )
        )
    }

    // T063c — AC-GUEST-04: Guest procedures are read-only.
    func test_AC_GUEST_04_guest_procedure_read_only() {
        XCTAssertFalse(
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: .guest),
                role: .guest
            )
        )
        XCTAssertFalse(
            permissions.can(.create, entity: .procedureStep(procedureVisibility: .guest), role: .guest)
        )
        XCTAssertTrue(
            permissions.can(.read, entity: .procedureStep(procedureVisibility: .guest), role: .guest)
        )
    }

    // T033 — AC-USER-05: Guest role is read-only across management surfaces.
    func test_AC_USER_05_guest_role_read_only() {
        XCTAssertEqual(HomeTab.visibleTabs(for: .guest), [.procedures, .contacts, .files])
        XCTAssertEqual(HomeTab.visibleTabs(for: .owner), HomeTab.allCases)
        XCTAssertFalse(permissions.can(.read, entity: .activityLog, role: .guest))
        XCTAssertFalse(permissions.can(.create, entity: .membership, role: .guest))
    }
}

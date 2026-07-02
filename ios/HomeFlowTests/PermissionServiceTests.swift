import XCTest
@testable import HomeFlow

final class PermissionServiceTests: XCTestCase {
    let permissions = PermissionService()

    func test_AC_GUEST_05_guest_cannot_update_step() {
        XCTAssertFalse(
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: .guest),
                role: .guest
            )
        )
    }

    func test_AC_USER_04_manager_can_update_step() {
        XCTAssertTrue(
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: .manager),
                role: .manager
            )
        )
    }

    func test_AC_PROC_02_manager_cannot_update_owner_only_step() {
        XCTAssertFalse(
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: .owner),
                role: .manager
            )
        )
    }

    func test_AC_PROC_02_guest_cannot_update_guest_visible_step() {
        XCTAssertFalse(
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: .guest),
                role: .guest
            )
        )
    }
}

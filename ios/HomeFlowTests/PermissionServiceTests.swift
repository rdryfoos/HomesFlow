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

    func test_AC_USER_04_edit_can_update_step() {
        XCTAssertTrue(
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: .edit),
                role: .edit
            )
        )
    }
}

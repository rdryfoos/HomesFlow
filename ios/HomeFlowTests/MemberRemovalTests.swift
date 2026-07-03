import XCTest
@testable import HomeFlow

// @covers FR-USER-02

final class MemberRemovalTests: XCTestCase {

    // T068 — FR-USER-02: only the Owner can remove members.

    func test_owner_can_remove_manager_and_guest() {
        XCTAssertTrue(MemberRemovalPolicy.canRemove(currentUserRole: .owner, memberRole: .manager))
        XCTAssertTrue(MemberRemovalPolicy.canRemove(currentUserRole: .owner, memberRole: .guest))
        XCTAssertNoThrow(try MemberRemovalPolicy.validate(currentUserRole: .owner, memberRole: .manager))
        XCTAssertNoThrow(try MemberRemovalPolicy.validate(currentUserRole: .owner, memberRole: .guest))
    }

    func test_owner_membership_cannot_be_removed() {
        XCTAssertFalse(MemberRemovalPolicy.canRemove(currentUserRole: .owner, memberRole: .owner))
        XCTAssertEqual(
            MemberRemovalPolicy.denialReason(currentUserRole: .owner, memberRole: .owner),
            .cannotRemoveOwner
        )
        XCTAssertThrowsError(
            try MemberRemovalPolicy.validate(currentUserRole: .owner, memberRole: .owner)
        ) { error in
            guard case MemberError.cannotRemoveOwner = error else {
                return XCTFail("Expected cannotRemoveOwner, got \(error)")
            }
        }
    }

    func test_non_owner_cannot_remove_anyone() {
        for role in [HomeRole.manager, .guest] {
            for target in [HomeRole.owner, .manager, .guest] {
                XCTAssertFalse(
                    MemberRemovalPolicy.canRemove(currentUserRole: role, memberRole: target),
                    "\(role) should not remove \(target)"
                )
            }
        }
        XCTAssertEqual(
            MemberRemovalPolicy.denialReason(currentUserRole: .manager, memberRole: .guest),
            .notOwner
        )
        XCTAssertThrowsError(
            try MemberRemovalPolicy.validate(currentUserRole: .guest, memberRole: .manager)
        ) { error in
            guard case MemberError.notAuthorized = error else {
                return XCTFail("Expected notAuthorized, got \(error)")
            }
        }
    }

    func test_unknown_role_fails_closed() {
        XCTAssertFalse(MemberRemovalPolicy.canRemove(currentUserRole: nil, memberRole: .guest))
        XCTAssertEqual(
            MemberRemovalPolicy.denialReason(currentUserRole: nil, memberRole: .guest),
            .notOwner
        )
    }

    func test_removal_errors_carry_actionable_guidance() {
        XCTAssertNotNil(MemberError.cannotRemoveOwner.errorDescription)
        XCTAssertNotNil(MemberError.offlineRemoval.errorDescription)
        XCTAssertNotNil(MemberError.notAuthorized.errorDescription)
    }
}

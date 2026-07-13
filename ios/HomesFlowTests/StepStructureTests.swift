import XCTest
@testable import HomesFlow

// @covers AC-PROC-04, AC-PROC-05, AC-PROC-06, AC-PROC-07

final class StepStructurePermissionTests: XCTestCase {
    let permissions = PermissionService()

    // T050a — AC-PROC-04: Owner and Manager can create, rename, reorder, and delete steps.
    func test_AC_PROC_04_owner_can_manage_step_structure() {
        for action in [PermissionAction.create, .update, .delete] {
            XCTAssertTrue(
                permissions.can(
                    action,
                    entity: .procedureStep(procedureVisibility: .owner),
                    role: .owner
                ),
                "Owner should be allowed to \(action) steps"
            )
        }
    }

    func test_AC_PROC_04_manager_can_manage_step_structure() {
        for action in [PermissionAction.create, .update, .delete] {
            XCTAssertTrue(
                permissions.can(
                    action,
                    entity: .procedureStep(procedureVisibility: .manager),
                    role: .manager
                ),
                "Manager should be allowed to \(action) steps on manager-visible procedures"
            )
        }
    }

    func test_AC_PROC_04_manager_cannot_manage_owner_only_procedure_steps() {
        for action in [PermissionAction.create, .update, .delete] {
            XCTAssertFalse(
                permissions.can(
                    action,
                    entity: .procedureStep(procedureVisibility: .owner),
                    role: .manager
                ),
                "Manager should not be allowed to \(action) steps on owner-only procedures"
            )
        }
    }

    // T050c — AC-PROC-07: Guests never get step structure rights, even on guest-visible procedures.
    func test_AC_PROC_07_guest_cannot_manage_step_structure() {
        for visibility in Visibility.allCases {
            for action in [PermissionAction.create, .update, .delete] {
                XCTAssertFalse(
                    permissions.can(
                        action,
                        entity: .procedureStep(procedureVisibility: visibility),
                        role: .guest
                    ),
                    "Guest should never be allowed to \(action) steps (\(visibility))"
                )
            }
        }
    }
}

final class StepStructureOrderingTests: XCTestCase {
    // T050b — AC-PROC-05: New steps append at the end of the list.
    func test_AC_PROC_05_new_step_appends_at_end() {
        XCTAssertEqual(StepStructure.nextSortOrder(existing: [1, 2, 3]), 4)
        XCTAssertEqual(StepStructure.nextSortOrder(existing: [2, 5, 3]), 6)
        XCTAssertEqual(StepStructure.nextSortOrder(existing: []), 1)
    }

    func test_AC_PROC_05_move_up_swaps_with_previous_step() {
        let steps = makeSteps(count: 3)
        let target = StepStructure.swapTarget(for: steps[1].id, direction: .up, in: steps)
        XCTAssertEqual(target?.id, steps[0].id)
    }

    func test_AC_PROC_05_move_down_swaps_with_next_step() {
        let steps = makeSteps(count: 3)
        let target = StepStructure.swapTarget(for: steps[1].id, direction: .down, in: steps)
        XCTAssertEqual(target?.id, steps[2].id)
    }

    func test_AC_PROC_05_move_is_noop_at_list_boundaries() {
        let steps = makeSteps(count: 3)
        XCTAssertNil(StepStructure.swapTarget(for: steps[0].id, direction: .up, in: steps))
        XCTAssertNil(StepStructure.swapTarget(for: steps[2].id, direction: .down, in: steps))
    }

    // AC-PROC-06: Structure changes produce a human-readable activity log entry.
    func test_AC_PROC_06_structure_changes_produce_activity_summaries() {
        XCTAssertEqual(
            StepStructure.activitySummary(action: .created, stepTitle: "Flip breaker", procedureTitle: "Open the pool"),
            "Added step \"Flip breaker\" to Open the pool"
        )
        XCTAssertEqual(
            StepStructure.activitySummary(action: .renamed, stepTitle: "Flip breaker", procedureTitle: "Open the pool"),
            "Renamed step to \"Flip breaker\" in Open the pool"
        )
        XCTAssertEqual(
            StepStructure.activitySummary(action: .deleted, stepTitle: "Flip breaker", procedureTitle: "Open the pool"),
            "Deleted step \"Flip breaker\" from Open the pool"
        )
        XCTAssertEqual(
            StepStructure.activitySummary(action: .reordered, stepTitle: "Flip breaker", procedureTitle: "Open the pool"),
            "Moved step \"Flip breaker\" in Open the pool"
        )
    }

    private func makeSteps(count: Int) -> [ProcedureStepSummary] {
        (1...count).map { order in
            ProcedureStepSummary(
                id: UUID(),
                procedureId: UUID(),
                sortOrder: order,
                title: "Step \(order)",
                status: .notStarted,
                notes: nil,
                photoURL: nil
            )
        }
    }
}

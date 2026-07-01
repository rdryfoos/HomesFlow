import XCTest
@testable import HomeFlow

final class ProcedureAggregatorTests: XCTestCase {
    func test_AC_PROC_01_completed_step_counts_toward_progress() {
        let steps = [
            makeStep(status: .complete),
            makeStep(status: .notStarted),
            makeStep(status: .na)
        ]

        XCTAssertEqual(ProcedureAggregator.completedCount(for: steps), 2)
        XCTAssertEqual(ProcedureAggregator.aggregateStatus(for: steps), .inProgress)
    }

    func test_all_steps_complete_marks_procedure_complete() {
        let steps = [
            makeStep(status: .complete),
            makeStep(status: .complete)
        ]

        XCTAssertEqual(ProcedureAggregator.aggregateStatus(for: steps), .complete)
    }

    private func makeStep(status: StepStatus) -> ProcedureStepSummary {
        ProcedureStepSummary(
            id: UUID(),
            procedureId: UUID(),
            sortOrder: 1,
            title: "Step",
            status: status,
            notes: nil
        )
    }
}

final class ProcedureStepConflictTests: XCTestCase {
    func test_AC_PROC_03_server_newer_overwrites_pending_local() {
        let localDate = Date(timeIntervalSince1970: 100)
        let serverDate = Date(timeIntervalSince1970: 200)
        XCTAssertTrue(
            HomeConflictResolver.shouldApplyServer(
                localPending: true,
                localUpdatedAt: localDate,
                serverUpdatedAt: serverDate
            )
        )
    }

    func test_AC_PROC_03_local_newer_keeps_pending_local() {
        let localDate = Date(timeIntervalSince1970: 300)
        let serverDate = Date(timeIntervalSince1970: 200)
        XCTAssertFalse(
            HomeConflictResolver.shouldApplyServer(
                localPending: true,
                localUpdatedAt: localDate,
                serverUpdatedAt: serverDate
            )
        )
    }
}

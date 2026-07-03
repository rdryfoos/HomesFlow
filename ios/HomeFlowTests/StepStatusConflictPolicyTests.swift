import XCTest
@testable import HomeFlow

// @covers AC-SYNC-05, AC-SYNC-06

final class StepStatusConflictPolicyTests: XCTestCase {

    private let t100 = Date(timeIntervalSince1970: 100)
    private let t200 = Date(timeIntervalSince1970: 200)
    private let t300 = Date(timeIntervalSince1970: 300)

    // T074a — AC-SYNC-05: terminal statuses never silently regress.

    func test_AC_SYNC_05_terminal_status_never_silently_regressed() {
        XCTAssertTrue(StepStatusConflictPolicy.isTerminal(.complete))
        XCTAssertTrue(StepStatusConflictPolicy.isTerminal(.na))
        XCTAssertFalse(StepStatusConflictPolicy.isTerminal(.notStarted))
        XCTAssertFalse(StepStatusConflictPolicy.isTerminal(.inProgress))

        struct RegressionScenario {
            let name: String
            let local: StepStatus
            let server: StepStatus
            let expectRegression: Bool
        }

        let regressionMatrix: [RegressionScenario] = [
            .init(name: "Complete → Not started", local: .complete, server: .notStarted, expectRegression: true),
            .init(name: "Complete → In progress", local: .complete, server: .inProgress, expectRegression: true),
            .init(name: "N/A → Not started", local: .na, server: .notStarted, expectRegression: true),
            .init(name: "Complete → N/A", local: .complete, server: .na, expectRegression: true),
            .init(name: "N/A → Complete", local: .na, server: .complete, expectRegression: true),
            .init(name: "Complete → Complete", local: .complete, server: .complete, expectRegression: false),
            .init(name: "Not started → Complete", local: .notStarted, server: .complete, expectRegression: false),
            .init(name: "In progress → N/A", local: .inProgress, server: .na, expectRegression: false),
        ]

        for scenario in regressionMatrix {
            XCTAssertEqual(
                StepStatusConflictPolicy.wouldRegressTerminal(
                    localStatus: scenario.local,
                    serverStatus: scenario.server
                ),
                scenario.expectRegression,
                scenario.name
            )
        }

        // AC-SYNC-05 blocks timestamp-wins when it would regress a terminal local status.
        XCTAssertFalse(
            StepStatusConflictPolicy.shouldApplyServerStep(
                localStatus: .complete,
                localPending: true,
                localUpdatedAt: t100,
                serverStatus: .notStarted,
                serverUpdatedAt: t200
            ),
            "Newer server timestamp must not regress local Complete"
        )

        // Non-terminal local edits still follow timestamp-wins (T075 covers loser notify).
        XCTAssertTrue(
            StepStatusConflictPolicy.shouldApplyServerStep(
                localStatus: .inProgress,
                localPending: true,
                localUpdatedAt: t100,
                serverStatus: .complete,
                serverUpdatedAt: t200
            )
        )

        XCTAssertFalse(
            StepStatusConflictPolicy.shouldApplyServerStep(
                localStatus: .inProgress,
                localPending: true,
                localUpdatedAt: t300,
                serverStatus: .complete,
                serverUpdatedAt: t200
            ),
            "Local-newer pending edit still wins when no terminal regression"
        )

        let message = StepStatusConflictPolicy.surfaceMessage(stepTitle: "Shut off water", keptStatus: .complete)
        XCTAssertTrue(message.contains("Shut off water"))
        XCTAssertTrue(message.contains("Complete"))
    }

    // T075a — AC-SYNC-06: losing user gets re-apply guidance + activity-log reference.

    func test_AC_SYNC_06_losing_user_notified_with_reapply_guidance() {
        let notification = StepStatusConflictPolicy.autoResolveLoserMessage(
            stepTitle: "Shut off water",
            winningStatus: .complete,
            losingStatus: .inProgress
        )
        XCTAssertTrue(notification.contains("Shut off water"))
        XCTAssertTrue(notification.contains("In progress"))
        XCTAssertTrue(notification.contains("Complete"))
        XCTAssertTrue(notification.localizedCaseInsensitiveContains("activity log"))
        XCTAssertTrue(notification.localizedCaseInsensitiveContains("re-apply"))

        let audit = StepStatusConflictPolicy.autoResolveActivitySummary(
            stepTitle: "Shut off water",
            procedureTitle: "Winterize",
            winningStatus: .complete,
            losingStatus: .inProgress
        )
        XCTAssertTrue(audit.contains("Winterize"))
        XCTAssertTrue(audit.contains("kept Complete over In progress"))
    }
}

import XCTest
@testable import HomeFlow

/// T072 — scripted sync conflict matrix (SC-04: ≥95% of scripted scenarios
/// resolve correctly). Every scenario is asserted individually, and the
/// aggregate pass rate is checked against the SC-04 target so the suite
/// documents the success criterion it verifies.
final class SyncConflictMatrixTests: XCTestCase {

    private struct TimestampScenario {
        let name: String
        let localPending: Bool
        let localUpdatedAt: Date
        let serverUpdatedAt: Date?
        let expectServerWins: Bool
    }

    private let t100 = Date(timeIntervalSince1970: 100)
    private let t200 = Date(timeIntervalSince1970: 200)
    private let t300 = Date(timeIntervalSince1970: 300)

    // MARK: - AC-SYNC-01 — timestamp-wins matrix

    private var timestampScenarios: [TimestampScenario] {
        [
            .init(name: "synced row, server newer", localPending: false, localUpdatedAt: t100, serverUpdatedAt: t200, expectServerWins: true),
            .init(name: "synced row, server older", localPending: false, localUpdatedAt: t300, serverUpdatedAt: t200, expectServerWins: true),
            .init(name: "synced row, server timestamp missing", localPending: false, localUpdatedAt: t100, serverUpdatedAt: nil, expectServerWins: true),
            .init(name: "pending edit, server newer", localPending: true, localUpdatedAt: t100, serverUpdatedAt: t200, expectServerWins: true),
            .init(name: "pending edit, local newer", localPending: true, localUpdatedAt: t300, serverUpdatedAt: t200, expectServerWins: false),
            .init(name: "pending edit, equal timestamps keep local", localPending: true, localUpdatedAt: t200, serverUpdatedAt: t200, expectServerWins: false),
            .init(name: "pending edit, server timestamp missing keeps local", localPending: true, localUpdatedAt: t100, serverUpdatedAt: nil, expectServerWins: false),
            .init(name: "pending edit, distant past local loses", localPending: true, localUpdatedAt: .distantPast, serverUpdatedAt: t100, expectServerWins: true),
            .init(name: "pending edit, distant future local wins", localPending: true, localUpdatedAt: .distantFuture, serverUpdatedAt: t300, expectServerWins: false)
        ]
    }

    func test_AC_SYNC_01_home_timestamp_wins_matrix() {
        runTimestampMatrix(named: "home") {
            HomeConflictResolver.shouldApplyServer(
                localPending: $0.localPending,
                localUpdatedAt: $0.localUpdatedAt,
                serverUpdatedAt: $0.serverUpdatedAt
            )
        }
    }

    func test_AC_SYNC_01_provider_timestamp_wins_matrix() {
        runTimestampMatrix(named: "provider") {
            ProviderConflictResolver.shouldApplyServer(
                localPending: $0.localPending,
                localUpdatedAt: $0.localUpdatedAt,
                serverUpdatedAt: $0.serverUpdatedAt
            )
        }
    }

    /// A flaky reconnect replays the same pull; the decision must not change
    /// when evaluated repeatedly with identical inputs (idempotent sync).
    func test_AC_SYNC_01_conflict_decision_is_idempotent() {
        for scenario in timestampScenarios {
            let first = HomeConflictResolver.shouldApplyServer(
                localPending: scenario.localPending,
                localUpdatedAt: scenario.localUpdatedAt,
                serverUpdatedAt: scenario.serverUpdatedAt
            )
            for _ in 0..<3 {
                let repeated = HomeConflictResolver.shouldApplyServer(
                    localPending: scenario.localPending,
                    localUpdatedAt: scenario.localUpdatedAt,
                    serverUpdatedAt: scenario.serverUpdatedAt
                )
                XCTAssertEqual(repeated, first, "decision changed on replay: \(scenario.name)")
            }
        }
    }

    // MARK: - AC-SYNC-01 / AC-HOME-05 — delete-wins matrix

    func test_AC_SYNC_01_server_delete_matrix() {
        struct DeleteScenario {
            let name: String
            let localPending: Bool
            let everSynced: Bool
            let expected: ProviderMissingOutcome
        }

        let scenarios: [DeleteScenario] = [
            .init(name: "local-only insert survives pull", localPending: true, everSynced: false, expected: .keepPendingInsert),
            .init(name: "unsynced row without pending flag still local-only", localPending: false, everSynced: false, expected: .keepPendingInsert),
            .init(name: "server delete beats pending edit, editor notified", localPending: true, everSynced: true, expected: .deleteWinsNotify),
            .init(name: "server delete of clean row removes silently", localPending: false, everSynced: true, expected: .removeSilently)
        ]

        var passed = 0
        for scenario in scenarios {
            let outcome = ProviderConflictResolver.resolveMissingFromServer(
                localPending: scenario.localPending,
                everSynced: scenario.everSynced
            )
            XCTAssertEqual(outcome, scenario.expected, scenario.name)
            if outcome == scenario.expected { passed += 1 }
        }
        assertMeetsSC04(passed: passed, total: scenarios.count, matrix: "server delete")
    }

    // MARK: - AC-SYNC-01 — loser notification on timestamp-wins overwrite

    func test_AC_SYNC_01_offline_overwrite_notifies_loser() {
        struct NotifyScenario {
            let name: String
            let localPending: Bool
            let localUpdatedAt: Date
            let serverUpdatedAt: Date?
            let expectNotify: Bool
        }

        let scenarios: [NotifyScenario] = [
            .init(name: "pending edit, server newer notifies", localPending: true, localUpdatedAt: t100, serverUpdatedAt: t200, expectNotify: true),
            .init(name: "pending edit, local newer keeps edit silent", localPending: true, localUpdatedAt: t300, serverUpdatedAt: t200, expectNotify: false),
            .init(name: "pending edit, equal timestamps keeps edit silent", localPending: true, localUpdatedAt: t200, serverUpdatedAt: t200, expectNotify: false),
            .init(name: "pending edit, missing server timestamp keeps edit silent", localPending: true, localUpdatedAt: t100, serverUpdatedAt: nil, expectNotify: false),
            .init(name: "synced row, server newer does not notify", localPending: false, localUpdatedAt: t100, serverUpdatedAt: t200, expectNotify: false)
        ]

        for scenario in scenarios {
            let notify = OverwriteNotificationPolicy.shouldNotifyLoser(
                localPending: scenario.localPending,
                localUpdatedAt: scenario.localUpdatedAt,
                serverUpdatedAt: scenario.serverUpdatedAt
            )
            XCTAssertEqual(notify, scenario.expectNotify, scenario.name)
        }

        let homeMessage = OverwriteNotificationPolicy.message(for: .home(name: "Lake Cabin"))
        XCTAssertTrue(homeMessage.contains("Lake Cabin"))
        XCTAssertTrue(homeMessage.localizedCaseInsensitiveContains("overwritten"))

        let stepMessage = OverwriteNotificationPolicy.message(for: .procedureStep(title: "Shut off water"))
        XCTAssertTrue(stepMessage.contains("Shut off water"))

        let providerMessage = OverwriteNotificationPolicy.message(for: .serviceProvider(name: "Acme HVAC"))
        XCTAssertTrue(providerMessage.contains("Acme HVAC"))
    }

    func test_AC_HOME_03_older_pending_edit_does_not_push_over_newer_server() {
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 200)
        XCTAssertFalse(
            OutboxSyncPolicy.shouldPushPendingUpdate(localUpdatedAt: older, serverUpdatedAt: newer),
            "Queued edit must not push when the server copy is newer"
        )
        XCTAssertTrue(
            OutboxSyncPolicy.shouldPushPendingUpdate(localUpdatedAt: newer, serverUpdatedAt: older)
        )
    }

    // MARK: - AC-SYNC-03 — permission revert matrix

    func test_AC_SYNC_03_permission_denied_revert_matrix() {
        struct RevertScenario {
            let name: String
            let op: OutboxOperation?
            let expected: PermissionRevertAction
        }

        let scenarios: [RevertScenario] = [
            .init(name: "rejected insert discards local-only row", op: .insert, expected: .discardLocal),
            .init(name: "rejected update keeps server version", op: .update, expected: .markSynced),
            .init(name: "rejected delete keeps server version", op: .delete, expected: .markSynced),
            .init(name: "unknown operation defaults to keeping server version", op: nil, expected: .markSynced)
        ]

        var passed = 0
        for scenario in scenarios {
            let action = PermissionRevertPolicy.action(for: scenario.op)
            XCTAssertEqual(action, scenario.expected, scenario.name)
            if action == scenario.expected { passed += 1 }
        }
        assertMeetsSC04(passed: passed, total: scenarios.count, matrix: "permission revert")
    }

    // MARK: - Helpers

    private func runTimestampMatrix(
        named entity: String,
        decide: (TimestampScenario) -> Bool
    ) {
        var passed = 0
        for scenario in timestampScenarios {
            let serverWins = decide(scenario)
            XCTAssertEqual(serverWins, scenario.expectServerWins, "\(entity): \(scenario.name)")
            if serverWins == scenario.expectServerWins { passed += 1 }
        }
        assertMeetsSC04(passed: passed, total: timestampScenarios.count, matrix: "\(entity) timestamp-wins")
    }

    private func assertMeetsSC04(passed: Int, total: Int, matrix: String) {
        let rate = Double(passed) / Double(total)
        XCTAssertGreaterThanOrEqual(
            rate, 0.95,
            "SC-04 requires ≥95%% of scripted \(matrix) scenarios to resolve correctly (got \(passed)/\(total))"
        )
    }
}

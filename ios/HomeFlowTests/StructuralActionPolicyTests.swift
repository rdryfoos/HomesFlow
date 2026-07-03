import XCTest
@testable import HomeFlow

// @covers AC-SYNC-07

final class StructuralActionPolicyTests: XCTestCase {

    func test_AC_SYNC_07_structural_actions_blocked_offline() {
        XCTAssertFalse(StructuralActionPolicy.canPerformStructuralActions(isConnected: false))
        XCTAssertTrue(StructuralActionPolicy.canPerformStructuralActions(isConnected: true))

        XCTAssertThrowsError(
            try StructuralActionPolicy.assertConnectivity(isConnected: false, context: .steps)
        ) { error in
            XCTAssertEqual(
                error as? StructuralActionError,
                .requiresConnectivity(context: .steps)
            )
            XCTAssertEqual(
                error.localizedDescription,
                StructuralActionPolicy.offlineMessage(for: .steps)
            )
        }

        XCTAssertNoThrow(try StructuralActionPolicy.assertConnectivity(isConnected: true))
    }

    func test_offline_messages_are_actionable_per_context() {
        for context: StructuralActionPolicy.Context in [.general, .steps, .contacts, .members] {
            let message = StructuralActionPolicy.offlineMessage(for: context)
            XCTAssertFalse(message.isEmpty)
            XCTAssertTrue(message.localizedCaseInsensitiveContains("internet"))
        }
    }
}

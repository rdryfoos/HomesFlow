import XCTest
@testable import HomeFlow

// @covers AC-SYNC-04

final class SyncIndicatorTests: XCTestCase {

    private func home(_ name: String, pending: Bool) -> HomeSummary {
        HomeSummary(
            id: UUID(),
            name: name,
            streetAddress: "1 Main St, Lakeville, MN",
            isPendingSync: pending
        )
    }

    // T040a — AC-SYNC-04: pending changes are visible on the dashboard.

    func test_AC_SYNC_04_pending_sync_visible_on_dashboard() {
        let synced = home("Cabin", pending: false)
        let unsynced = home("Beach House", pending: true)

        XCTAssertTrue(
            SyncIndicatorPolicy.showsPendingBanner(homes: [synced, unsynced]),
            "Banner appears when any home hasn't reached the server"
        )
        XCTAssertFalse(SyncIndicatorPolicy.showsPendingBanner(homes: [synced]))
        XCTAssertFalse(SyncIndicatorPolicy.showsPendingBanner(homes: []))

        XCTAssertTrue(SyncIndicatorPolicy.showsBadge(for: unsynced))
        XCTAssertFalse(SyncIndicatorPolicy.showsBadge(for: synced))
    }

    func test_AC_SYNC_04_pending_state_announced_to_voiceover() {
        let unsynced = home("Beach House", pending: true)
        let synced = home("Cabin", pending: false)

        XCTAssertTrue(
            SyncIndicatorPolicy.accessibilityLabel(for: unsynced).contains("Not synced"),
            "Pending state must be announced, not conveyed by icon alone"
        )
        XCTAssertFalse(
            SyncIndicatorPolicy.accessibilityLabel(for: synced).contains("Not synced")
        )
    }
}

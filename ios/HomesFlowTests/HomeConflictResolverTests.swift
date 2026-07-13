import XCTest
@testable import HomesFlow

final class HomeConflictResolverTests: XCTestCase {
    func test_AC_HOME_03_server_newer_overwrites_pending_local() {
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

    func test_AC_HOME_03_local_newer_keeps_pending_local() {
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

    func test_AC_HOME_03_synced_home_applies_server() {
        XCTAssertTrue(
            HomeConflictResolver.shouldApplyServer(
                localPending: false,
                localUpdatedAt: .now,
                serverUpdatedAt: nil
            )
        )
    }
}

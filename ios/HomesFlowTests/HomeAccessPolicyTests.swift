import XCTest
@testable import HomesFlow

// @covers NFR-SEC-01, FR-USER-01

final class HomeAccessPolicyTests: XCTestCase {
    private let ownerId = UUID()
    private let inviteeId = UUID()
    private let homeA = UUID()
    private let homeB = UUID()

    func test_member_sees_only_their_homes() {
        let homes = [
            makeHome(id: homeA, createdBy: ownerId, sync: .synced),
            makeHome(id: homeB, createdBy: ownerId, sync: .synced),
        ]
        let memberships = [
            CachedMembership(homeId: homeB, userId: inviteeId, role: .guest),
        ]

        let visible = HomeAccessPolicy.authorizedHomes(
            from: homes,
            memberships: memberships,
            userId: inviteeId
        )

        XCTAssertEqual(visible.map(\.id), [homeB])
    }

    func test_owner_pending_create_visible_before_membership_sync() {
        let homes = [
            makeHome(id: homeA, createdBy: ownerId, sync: .pending),
        ]

        let visible = HomeAccessPolicy.authorizedHomes(
            from: homes,
            memberships: [],
            userId: ownerId
        )

        XCTAssertEqual(visible.map(\.id), [homeA])
    }

    func test_stale_cached_home_hidden_without_membership() {
        let homes = [
            makeHome(id: homeA, createdBy: ownerId, sync: .synced),
        ]

        let visible = HomeAccessPolicy.authorizedHomes(
            from: homes,
            memberships: [],
            userId: inviteeId
        )

        XCTAssertTrue(visible.isEmpty)
    }

    func test_server_home_ids_allow_synced_home_before_membership_cache() {
        let homes = [
            makeHome(id: homeB, createdBy: ownerId, sync: .synced),
        ]

        let visible = HomeAccessPolicy.authorizedHomes(
            from: homes,
            memberships: [],
            userId: inviteeId,
            serverHomeIds: [homeB]
        )

        XCTAssertEqual(visible.map(\.id), [homeB])
    }

    func test_nil_user_sees_nothing() {
        let homes = [makeHome(id: homeA, createdBy: ownerId, sync: .synced)]

        XCTAssertTrue(
            HomeAccessPolicy.authorizedHomes(from: homes, memberships: [], userId: nil).isEmpty
        )
    }

    private func makeHome(id: UUID, createdBy: UUID, sync: SyncStatus) -> CachedHome {
        CachedHome(
            id: id,
            name: "Home",
            streetAddress: "1 Main",
            createdBy: createdBy,
            syncStatus: sync
        )
    }
}

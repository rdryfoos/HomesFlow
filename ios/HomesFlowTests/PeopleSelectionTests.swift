import XCTest
@testable import HomesFlow

// @covers AC-HOME-10, AC-USER-02

final class PeopleSelectionTests: XCTestCase {

    func test_member_and_invite_with_same_uuid_are_distinct_selections() {
        let id = UUID()
        XCTAssertNotEqual(PeopleSelection.member(id), PeopleSelection.invite(id))
    }

    func test_repair_keeps_valid_member_selection() {
        let id = UUID()
        let other = UUID()
        let result = PeopleSelectionRepair.repair(
            current: .member(id),
            memberIds: [id, other],
            inviteIds: []
        )
        XCTAssertEqual(result, .member(id))
    }

    func test_repair_falls_back_to_invite_when_selected_member_removed() {
        let memberId = UUID()
        let inviteId = UUID()
        let result = PeopleSelectionRepair.repair(
            current: .member(memberId),
            memberIds: [],
            inviteIds: [inviteId]
        )
        XCTAssertEqual(result, .invite(inviteId))
    }

    func test_repair_clears_stale_invite_after_revoke() {
        let inviteId = UUID()
        let memberId = UUID()
        let result = PeopleSelectionRepair.repair(
            current: .invite(inviteId),
            memberIds: [memberId],
            inviteIds: []
        )
        XCTAssertEqual(result, .member(memberId))
    }
}

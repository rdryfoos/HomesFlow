import Foundation

// @covers FR-NAV-01, AC-USER-02, AC-HOME-10

/// Tagged selection for the People tab on iPad split view.
///
/// Members and pending invites both use `UUID` ids — never bind selection to a
/// bare `UUID?` or taps can show the wrong detail panel. Always tag rows with
/// `PeopleSelection.member(id)` or `.invite(id)`.
///
/// **Compact width (iPhone):** selection is unused; pending invites open
/// `PendingInviteDetailView` in a sheet instead. See `MembersView`.
enum PeopleSelection: Hashable, Sendable {
    case member(UUID)
    case invite(UUID)
}

enum PeopleSelectionRepair {
    /// Keeps iPad detail in sync when members or invites reload.
    static func repair(
        current: PeopleSelection?,
        memberIds: [UUID],
        inviteIds: [UUID]
    ) -> PeopleSelection? {
        switch current {
        case .member(let id):
            if memberIds.contains(id) { return current }
            return memberIds.first.map(PeopleSelection.member)
                ?? inviteIds.first.map(PeopleSelection.invite)
        case .invite(let id):
            if inviteIds.contains(id) { return current }
            return inviteIds.first.map(PeopleSelection.invite)
                ?? memberIds.first.map(PeopleSelection.member)
        case nil:
            return memberIds.first.map(PeopleSelection.member)
                ?? inviteIds.first.map(PeopleSelection.invite)
        }
    }
}

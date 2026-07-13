import Foundation

// @covers FR-USER-02

/// Pure gating rules for removing a member from a home (FR-USER-02):
/// only the Owner may remove members, and the Owner membership itself
/// (the home creator) can never be removed.
enum MemberRemovalPolicy {
    enum Denial: Equatable {
        case notOwner
        case cannotRemoveOwner
    }

    static func denialReason(
        currentUserRole: HomeRole?,
        memberRole: HomeRole
    ) -> Denial? {
        guard currentUserRole == .owner else { return .notOwner }
        guard memberRole != .owner else { return .cannotRemoveOwner }
        return nil
    }

    static func canRemove(currentUserRole: HomeRole?, memberRole: HomeRole) -> Bool {
        denialReason(currentUserRole: currentUserRole, memberRole: memberRole) == nil
    }

    static func validate(currentUserRole: HomeRole?, memberRole: HomeRole) throws {
        switch denialReason(currentUserRole: currentUserRole, memberRole: memberRole) {
        case .notOwner:
            throw MemberError.notAuthorized
        case .cannotRemoveOwner:
            throw MemberError.cannotRemoveOwner
        case nil:
            break
        }
    }
}

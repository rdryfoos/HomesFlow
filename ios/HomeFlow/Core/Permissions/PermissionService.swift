import Foundation

// @covers FR-USER-01, FR-GUEST-01, AC-PROC-02, AC-PROC-04, AC-PROC-07, AC-GUEST-02

struct PermissionService: Sendable {
    func can(_ action: PermissionAction, entity: PermissionEntity, role: HomeRole) -> Bool {
        switch (action, entity, role) {
        case (.create, .home, .owner):
            return true
        case (.update, .home, .owner), (.delete, .home, .owner):
            return true
        case (.read, .home, _):
            return true

        case (.create, .membership, .owner), (.update, .membership, .owner), (.delete, .membership, .owner):
            return true
        case (.read, .membership, _):
            return true

        case (_, .invite, .owner):
            return true
        case (_, .invite, _):
            return false

        // AC-PROC-02 / AC-USER-04: Managers modify only content whose
        // visibility they can see; owner-only content fails closed.
        case (.read, .serviceProvider(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.create, .serviceProvider(let vis), .owner),
             (.update, .serviceProvider(let vis), .owner),
             (.delete, .serviceProvider(let vis), .owner):
            return visibilityAllows(role: .owner, visibility: vis)
        case (.create, .serviceProvider(let vis), .manager),
             (.update, .serviceProvider(let vis), .manager),
             (.delete, .serviceProvider(let vis), .manager):
            return visibilityAllows(role: .manager, visibility: vis)

        case (.read, .document(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.create, .document(let vis), .owner),
             (.update, .document(let vis), .owner),
             (.delete, .document(let vis), .owner):
            return visibilityAllows(role: .owner, visibility: vis)
        case (.create, .document(let vis), .manager),
             (.update, .document(let vis), .manager),
             (.delete, .document(let vis), .manager):
            return visibilityAllows(role: .manager, visibility: vis)

        case (.read, .procedure(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.create, .procedure(let vis), .owner),
             (.update, .procedure(let vis), .owner),
             (.delete, .procedure(let vis), .owner):
            return visibilityAllows(role: .owner, visibility: vis)
        case (.create, .procedure(let vis), .manager),
             (.update, .procedure(let vis), .manager),
             (.delete, .procedure(let vis), .manager):
            return visibilityAllows(role: .manager, visibility: vis)

        case (.read, .procedureStep(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.updateStepStatus, .procedureStep(let vis), .owner):
            return visibilityAllows(role: .owner, visibility: vis)
        case (.updateStepStatus, .procedureStep(let vis), .manager):
            return visibilityAllows(role: .manager, visibility: vis)
        case (.updateStepStatus, .procedureStep, .guest):
            return false

        // Step structure (create/rename/reorder/delete) — AC-PROC-04…07
        case (.create, .procedureStep(let vis), .owner),
             (.update, .procedureStep(let vis), .owner),
             (.delete, .procedureStep(let vis), .owner):
            return visibilityAllows(role: .owner, visibility: vis)
        case (.create, .procedureStep(let vis), .manager),
             (.update, .procedureStep(let vis), .manager),
             (.delete, .procedureStep(let vis), .manager):
            return visibilityAllows(role: .manager, visibility: vis)
        case (.create, .procedureStep, .guest),
             (.update, .procedureStep, .guest),
             (.delete, .procedureStep, .guest):
            return false

        case (.read, .activityLog, .guest):
            return false
        case (_, .activityLog, _):
            return true

        default:
            return false
        }
    }

    func visibilityAllows(role: HomeRole, visibility: Visibility) -> Bool {
        switch role {
        case .owner:
            return true
        case .manager:
            return visibility == .manager || visibility == .guest
        case .guest:
            return visibility == .guest
        }
    }
}

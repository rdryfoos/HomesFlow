import Foundation

// @covers FR-USER-01, FR-GUEST-01, AC-PROC-02, AC-GUEST-02

struct PermissionService: Sendable {
    func can(_ action: PermissionAction, entity: PermissionEntity, role: HomeRole) -> Bool {
        switch (action, entity, role) {
        case (.create, .home, .admin):
            return true
        case (.update, .home, .admin), (.delete, .home, .admin):
            return true
        case (.read, .home, _):
            return true

        case (.create, .membership, .admin), (.update, .membership, .admin), (.delete, .membership, .admin):
            return true
        case (.read, .membership, _):
            return true

        case (_, .invite, .admin):
            return true
        case (_, .invite, _):
            return false

        case (.read, .serviceProvider(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.create, .serviceProvider, .admin), (.create, .serviceProvider, .edit):
            return true
        case (.update, .serviceProvider, .admin), (.update, .serviceProvider, .edit):
            return true
        case (.delete, .serviceProvider, .admin), (.delete, .serviceProvider, .edit):
            return true

        case (.read, .document(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.create, .document, .admin), (.create, .document, .edit):
            return true
        case (.update, .document, .admin), (.update, .document, .edit):
            return true
        case (.delete, .document, .admin), (.delete, .document, .edit):
            return true

        case (.read, .procedure(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.create, .procedure, .admin), (.create, .procedure, .edit):
            return true
        case (.update, .procedure, .admin), (.update, .procedure, .edit):
            return true
        case (.delete, .procedure, .admin), (.delete, .procedure, .edit):
            return true

        case (.read, .procedureStep(let vis), let r):
            return visibilityAllows(role: r, visibility: vis)
        case (.updateStepStatus, .procedureStep(let vis), .admin):
            return visibilityAllows(role: .admin, visibility: vis)
        case (.updateStepStatus, .procedureStep(let vis), .edit):
            return visibilityAllows(role: .edit, visibility: vis)
        case (.updateStepStatus, .procedureStep, .guest):
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
        case .admin:
            return true
        case .edit:
            return visibility == .edit || visibility == .guest
        case .guest:
            return visibility == .guest
        }
    }
}

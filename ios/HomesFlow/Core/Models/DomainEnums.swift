import Foundation

enum HomeRole: String, Codable, CaseIterable, Sendable {
    case owner
    case manager
    case guest

    /// Maps legacy persisted values (`admin` / `edit`) after the Owner/Manager rename.
    init?(migratingRawValue raw: String) {
        switch raw {
        case "owner", "admin": self = .owner
        case "manager", "edit": self = .manager
        case "guest": self = .guest
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .owner: "Owner"
        case .manager: "Manager"
        case .guest: "Guest"
        }
    }
}

enum StepStatus: String, Codable, CaseIterable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case complete
    case na
}

enum ProcedureStatus: String, Codable, CaseIterable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case complete
    case na
}

enum Visibility: String, Codable, CaseIterable, Sendable {
    case owner
    case manager
    case guest

    init?(migratingRawValue raw: String) {
        switch raw {
        case "owner", "admin": self = .owner
        case "manager", "edit": self = .manager
        case "guest": self = .guest
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .owner: "Owners only"
        case .manager: "Owners & Managers"
        case .guest: "Everyone (incl. guests)"
        }
    }
}

enum InviteStatus: String, Codable, Sendable {
    case pending
    case accepted
    case revoked
}

enum SyncStatus: String, Codable, Sendable {
    case synced
    case pending
    case conflict
}

enum OutboxOperation: String, Codable, Sendable {
    case insert
    case update
    case delete
}

enum EntityType: String, Codable, Sendable {
    case home
    case membership
    case invite
    case serviceProvider = "service_providers"
    case document
    case procedure
    case procedureStep = "procedure_steps"
    case logBookEntry = "log_book_entries"
}

enum PermissionAction: Sendable {
    case read
    case create
    case update
    case delete
    case updateStepStatus
}

enum PermissionEntity: Sendable {
    case home
    case membership
    case invite
    case serviceProvider(visibility: Visibility)
    case document(visibility: Visibility)
    case procedure(visibility: Visibility)
    case procedureStep(procedureVisibility: Visibility)
    case activityLog
    case logBook
}

import Foundation

enum HomeRole: String, Codable, CaseIterable, Sendable {
    case admin
    case edit
    case guest
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
    case admin
    case edit
    case guest
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
}

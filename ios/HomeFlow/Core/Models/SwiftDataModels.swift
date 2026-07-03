import Foundation
import SwiftData

// @covers FR-HOME-01, FR-USER-01, FR-PROC-01, NFR-OFFL-01

@Model
final class CachedHome {
    @Attribute(.unique) var id: UUID
    var name: String
    var streetAddress: String
    var photoURL: String?
    var createdBy: UUID
    var syncStatus: String
    var localUpdatedAt: Date
    var serverUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        streetAddress: String,
        photoURL: String? = nil,
        createdBy: UUID,
        syncStatus: SyncStatus = .pending,
        localUpdatedAt: Date = .now,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.streetAddress = streetAddress
        self.photoURL = photoURL
        self.createdBy = createdBy
        self.syncStatus = syncStatus.rawValue
        self.localUpdatedAt = localUpdatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    var sync: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

@Model
final class CachedMembership {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var userId: UUID
    var role: String
    var displayEmail: String?
    var displayName: String?
    var syncStatus: String
    var serverUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        homeId: UUID,
        userId: UUID,
        role: HomeRole,
        displayEmail: String? = nil,
        displayName: String? = nil,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.homeId = homeId
        self.userId = userId
        self.role = role.rawValue
        self.displayEmail = displayEmail
        self.displayName = displayName
        self.syncStatus = SyncStatus.synced.rawValue
        self.serverUpdatedAt = serverUpdatedAt
    }

    var homeRole: HomeRole {
        get { HomeRole(migratingRawValue: role) ?? .guest }
        set { role = newValue.rawValue }
    }
}

@Model
final class CachedInvite {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var email: String
    var role: String
    var token: String
    var status: String

    init(
        id: UUID = UUID(),
        homeId: UUID,
        email: String,
        role: HomeRole,
        token: String,
        status: InviteStatus
    ) {
        self.id = id
        self.homeId = homeId
        self.email = email
        self.role = role.rawValue
        self.token = token
        self.status = status.rawValue
    }

    var homeRole: HomeRole {
        get { HomeRole(migratingRawValue: role) ?? .guest }
        set { role = newValue.rawValue }
    }

    var inviteStatus: InviteStatus {
        get { InviteStatus(rawValue: status) ?? .revoked }
        set { status = newValue.rawValue }
    }
}

@Model
final class MutationOutboxEntry {
    @Attribute(.unique) var id: UUID
    var entityType: String
    var entityId: UUID
    var operation: String
    var payloadJSON: String
    var clientUpdatedAt: Date

    init(
        id: UUID = UUID(),
        entityType: EntityType,
        entityId: UUID,
        operation: OutboxOperation,
        payload: [String: String],
        clientUpdatedAt: Date = .now
    ) {
        self.id = id
        self.entityType = entityType.rawValue
        self.entityId = entityId
        self.operation = operation.rawValue
        self.payloadJSON = (try? JSONEncoder().encode(payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.clientUpdatedAt = clientUpdatedAt
    }

    var entity: EntityType? { EntityType(rawValue: entityType) }
    var op: OutboxOperation? { OutboxOperation(rawValue: operation) }

    var payload: [String: String] {
        guard
            let data = payloadJSON.data(using: .utf8),
            let dict = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return dict
    }
}

@Model
final class CachedProcedure {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var title: String
    var category: String?
    var procedureDescription: String?
    var status: String
    var visibility: String
    var syncStatus: String
    var serverUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        homeId: UUID,
        title: String,
        category: String? = nil,
        procedureDescription: String? = nil,
        status: ProcedureStatus = .notStarted,
        visibility: Visibility = .manager,
        syncStatus: SyncStatus = .synced,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.homeId = homeId
        self.title = title
        self.category = category
        self.procedureDescription = procedureDescription
        self.status = status.rawValue
        self.visibility = visibility.rawValue
        self.syncStatus = syncStatus.rawValue
        self.serverUpdatedAt = serverUpdatedAt
    }

    var procedureStatus: ProcedureStatus {
        get { ProcedureStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }

    var procedureVisibility: Visibility {
        get { Visibility(migratingRawValue: visibility) ?? .manager }
        set { visibility = newValue.rawValue }
    }

    var sync: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

@Model
final class CachedProcedureStep {
    @Attribute(.unique) var id: UUID
    var procedureId: UUID
    var sortOrder: Int
    var title: String
    var status: String
    var notes: String?
    var photoURL: String?
    var syncStatus: String
    var localUpdatedAt: Date
    var serverUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        procedureId: UUID,
        sortOrder: Int,
        title: String,
        status: StepStatus = .notStarted,
        notes: String? = nil,
        photoURL: String? = nil,
        syncStatus: SyncStatus = .synced,
        localUpdatedAt: Date = .now,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.procedureId = procedureId
        self.sortOrder = sortOrder
        self.title = title
        self.status = status.rawValue
        self.notes = notes
        self.photoURL = photoURL
        self.syncStatus = syncStatus.rawValue
        self.localUpdatedAt = localUpdatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    var stepStatus: StepStatus {
        get { StepStatus(rawValue: status) ?? .notStarted }
        set { status = newValue.rawValue }
    }

    var sync: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

@Model
final class CachedServiceProvider {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var companyName: String
    var serviceType: String
    var accountNumber: String?
    var phone: String?
    var website: String?
    var hours: String?
    var notes: String?
    var visibility: String
    var syncStatus: String
    var localUpdatedAt: Date
    var serverUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        homeId: UUID,
        companyName: String,
        serviceType: String,
        accountNumber: String? = nil,
        phone: String? = nil,
        website: String? = nil,
        hours: String? = nil,
        notes: String? = nil,
        visibility: Visibility = .manager,
        syncStatus: SyncStatus = .pending,
        localUpdatedAt: Date = .now,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.homeId = homeId
        self.companyName = companyName
        self.serviceType = serviceType
        self.accountNumber = accountNumber
        self.phone = phone
        self.website = website
        self.hours = hours
        self.notes = notes
        self.visibility = visibility.rawValue
        self.syncStatus = syncStatus.rawValue
        self.localUpdatedAt = localUpdatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    var providerVisibility: Visibility {
        get { Visibility(migratingRawValue: visibility) ?? .manager }
        set { visibility = newValue.rawValue }
    }

    var sync: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

@Model
final class CachedDocument {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var title: String
    var category: String?
    var storagePath: String?
    var visibility: String
    var syncStatus: String
    var localUpdatedAt: Date
    var serverUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        homeId: UUID,
        title: String,
        category: String? = nil,
        storagePath: String? = nil,
        visibility: Visibility = .manager,
        syncStatus: SyncStatus = .pending,
        localUpdatedAt: Date = .now,
        serverUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.homeId = homeId
        self.title = title
        self.category = category
        self.storagePath = storagePath
        self.visibility = visibility.rawValue
        self.syncStatus = syncStatus.rawValue
        self.localUpdatedAt = localUpdatedAt
        self.serverUpdatedAt = serverUpdatedAt
    }

    var documentVisibility: Visibility {
        get { Visibility(migratingRawValue: visibility) ?? .manager }
        set { visibility = newValue.rawValue }
    }

    var sync: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

@Model
final class CachedActivityLogEntry {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var actorId: UUID
    var entityType: String
    var entityId: UUID?
    var action: String
    var summary: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        homeId: UUID,
        actorId: UUID,
        entityType: String,
        entityId: UUID?,
        action: String,
        summary: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.homeId = homeId
        self.actorId = actorId
        self.entityType = entityType
        self.entityId = entityId
        self.action = action
        self.summary = summary
        self.createdAt = createdAt
    }
}

@Model
final class CachedLogBookEntry {
    @Attribute(.unique) var id: UUID
    var homeId: UUID
    var procedureId: UUID?
    var authorId: UUID
    var authorLabel: String
    var body: String
    var createdAt: Date
    var receivedAt: Date?
    var editedAt: Date?
    var procedureTitle: String?
    var syncStatus: String

    init(
        id: UUID = UUID(),
        homeId: UUID,
        procedureId: UUID? = nil,
        authorId: UUID,
        authorLabel: String,
        body: String,
        createdAt: Date = .now,
        receivedAt: Date? = nil,
        editedAt: Date? = nil,
        procedureTitle: String? = nil,
        syncStatus: SyncStatus = .pending
    ) {
        self.id = id
        self.homeId = homeId
        self.procedureId = procedureId
        self.authorId = authorId
        self.authorLabel = authorLabel
        self.body = body
        self.createdAt = createdAt
        self.receivedAt = receivedAt
        self.editedAt = editedAt
        self.procedureTitle = procedureTitle
        self.syncStatus = syncStatus.rawValue
    }

    var sync: SyncStatus {
        get { SyncStatus(rawValue: syncStatus) ?? .pending }
        set { syncStatus = newValue.rawValue }
    }
}

enum SwiftDataContainer {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CachedHome.self,
            CachedMembership.self,
            CachedInvite.self,
            CachedProcedure.self,
            CachedProcedureStep.self,
            CachedServiceProvider.self,
            CachedDocument.self,
            MutationOutboxEntry.self,
            CachedActivityLogEntry.self,
            CachedLogBookEntry.self
        ])
        return try ModelContainer(for: schema)
    }
}

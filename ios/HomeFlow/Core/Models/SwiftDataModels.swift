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
    var syncStatus: String
    var serverUpdatedAt: Date?

    init(id: UUID = UUID(), homeId: UUID, userId: UUID, role: HomeRole) {
        self.id = id
        self.homeId = homeId
        self.userId = userId
        self.role = role.rawValue
        self.syncStatus = SyncStatus.synced.rawValue
    }

    var homeRole: HomeRole {
        get { HomeRole(rawValue: role) ?? .guest }
        set { role = newValue.rawValue }
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

enum SwiftDataContainer {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            CachedHome.self,
            CachedMembership.self,
            MutationOutboxEntry.self,
            CachedActivityLogEntry.self
        ])
        return try ModelContainer(for: schema)
    }
}

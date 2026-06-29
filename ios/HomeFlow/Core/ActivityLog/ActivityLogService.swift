import Foundation
import SwiftData

// @covers FR-LOG-01

@MainActor
final class ActivityLogService {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func append(
        homeId: UUID,
        actorId: UUID,
        entityType: String,
        entityId: UUID?,
        action: String,
        summary: String
    ) {
        let entry = CachedActivityLogEntry(
            homeId: homeId,
            actorId: actorId,
            entityType: entityType,
            entityId: entityId,
            action: action,
            summary: summary
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    func recent(for homeId: UUID, limit: Int = 20) -> [CachedActivityLogEntry] {
        let descriptor = FetchDescriptor<CachedActivityLogEntry>(
            predicate: #Predicate { $0.homeId == homeId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.prefix(limit).map { $0 } ?? []
    }
}

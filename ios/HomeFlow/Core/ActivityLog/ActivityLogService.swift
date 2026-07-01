import Foundation
import SwiftData
import Supabase

// @covers FR-LOG-01, AC-PROC-01

@MainActor
final class ActivityLogService {
    private let modelContext: ModelContext
    private let client: SupabaseClient

    init(modelContext: ModelContext, client: SupabaseClient) {
        self.modelContext = modelContext
        self.client = client
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

        Task {
            await pushEntry(entry)
        }
    }

    func pull(homeId: UUID) async throws {
        let rows: [ActivityLogDTO] = try await client
            .from("activity_log")
            .select()
            .eq("home_id", value: homeId.uuidString)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value

        mergeCached(homeId: homeId, rows: rows)
        try modelContext.save()
    }

    func recent(for homeId: UUID, limit: Int = 20) -> [ActivityLogSummary] {
        let homeTarget = homeId
        let descriptor = FetchDescriptor<CachedActivityLogEntry>(
            predicate: #Predicate<CachedActivityLogEntry> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let entries = (try? modelContext.fetch(descriptor)) ?? []
        return entries.prefix(limit).map(summary(from:))
    }

    func recentForProcedure(
        homeId: UUID,
        procedureId: UUID,
        stepIds: Set<UUID>,
        limit: Int = 10
    ) -> [ActivityLogSummary] {
        let homeTarget = homeId
        let descriptor = FetchDescriptor<CachedActivityLogEntry>(
            predicate: #Predicate<CachedActivityLogEntry> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let entries = (try? modelContext.fetch(descriptor)) ?? []

        return entries
            .filter { entry in
                if entry.entityType == "procedure", entry.entityId == procedureId {
                    return true
                }
                if entry.entityType == "procedure_step",
                   let entityId = entry.entityId,
                   stepIds.contains(entityId) {
                    return true
                }
                return false
            }
            .prefix(limit)
            .map(summary(from:))
    }

    private func pushEntry(_ entry: CachedActivityLogEntry) async {
        guard NetworkMonitor.shared.isConnected else { return }

        struct ActivityLogInsert: Encodable {
            let id: UUID
            let home_id: UUID
            let actor_id: UUID
            let entity_type: String
            let entity_id: UUID?
            let action: String
            let summary: String
        }

        let row = ActivityLogInsert(
            id: entry.id,
            home_id: entry.homeId,
            actor_id: entry.actorId,
            entity_type: entry.entityType,
            entity_id: entry.entityId,
            action: entry.action,
            summary: entry.summary
        )

        do {
            try await client.from("activity_log").insert(row).execute()
        } catch {
            // Local cache remains the source for offline; pull reconciles on next refresh.
        }
    }

    private func mergeCached(homeId: UUID, rows: [ActivityLogDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedActivityLogEntry>(
            predicate: #Predicate<CachedActivityLogEntry> { $0.homeId == homeTarget }
        ))) ?? []

        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIds = Set(rows.map(\.id))

        for stale in existing where stale.homeId == homeId && !incomingIds.contains(stale.id) {
            // Keep local-only entries that haven't synced yet; only prune very old server-only duplicates later.
            continue
        }

        for row in rows {
            if let cached = existingById[row.id] {
                cached.summary = row.summary
                cached.action = row.action
                cached.entityType = row.entityType
                cached.entityId = row.entityId
                cached.createdAt = row.createdAt
            } else {
                modelContext.insert(CachedActivityLogEntry(
                    id: row.id,
                    homeId: row.homeId,
                    actorId: row.actorId,
                    entityType: row.entityType,
                    entityId: row.entityId,
                    action: row.action,
                    summary: row.summary,
                    createdAt: row.createdAt
                ))
            }
        }
    }

    private func summary(from entry: CachedActivityLogEntry) -> ActivityLogSummary {
        ActivityLogSummary(id: entry.id, summary: entry.summary, createdAt: entry.createdAt)
    }
}

import Foundation
import SwiftData
import Supabase

// @covers NFR-OFFL-01, AC-SYNC-01, AC-SYNC-02, AC-SYNC-03

struct SyncNotification: Identifiable, Sendable {
    let id = UUID()
    let message: String
}

@MainActor
final class SyncEngine: ObservableObject {
    @Published var lastNotification: SyncNotification?

    private let modelContext: ModelContext
    private let client: SupabaseClient
    private let activityLog: ActivityLogService

    init(modelContext: ModelContext, client: SupabaseClient, activityLog: ActivityLogService) {
        self.modelContext = modelContext
        self.client = client
        self.activityLog = activityLog
    }

    func enqueue(
        entityType: EntityType,
        entityId: UUID,
        operation: OutboxOperation,
        payload: [String: String] = [:]
    ) {
        let entry = MutationOutboxEntry(
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payload: payload
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }

    /// Runs push then pull. Returns a user-facing message when sync failed.
    @discardableResult
    func run() async -> String? {
        await pushOutbox()
        await pullChanges()
        return lastNotification?.message
    }

    func clearNotification() {
        lastNotification = nil
    }

    func postNotification(_ message: String) {
        lastNotification = SyncNotification(message: message)
    }

    func isHomeSynced(_ homeId: UUID) -> Bool {
        let targetId = homeId
        guard let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first else { return false }
        return home.sync == .synced
    }

    private func pushOutbox() async {
        let descriptor = FetchDescriptor<MutationOutboxEntry>(
            sortBy: [SortDescriptor(\.clientUpdatedAt)]
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        for entry in entries {
            do {
                switch entry.entity {
                case .home:
                    guard entry.op != .delete else {
                        modelContext.delete(entry)
                        continue
                    }
                    try await pushHome(entry)
                case .procedureStep:
                    guard entry.op == .update else {
                        modelContext.delete(entry)
                        continue
                    }
                    try await pushProcedureStep(entry)
                default:
                    continue
                }
                modelContext.delete(entry)
                try? modelContext.save()
            } catch let error as PostgrestError where error.code == "42501" {
                revertPermissionDenied(entry: entry, message: error.message)
            } catch {
                lastNotification = SyncNotification(message: "Sync failed: \(error.localizedDescription)")
            }
        }
    }

    private func pushHome(_ entry: MutationOutboxEntry) async throws {
        let targetId = entry.entityId
        guard
            let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
                predicate: #Predicate<CachedHome> { $0.id == targetId }
            )).first
        else { return }

        struct HomeRow: Encodable {
            let id: UUID
            let name: String
            let street_address: String
            let photo_url: String?
            let created_by: UUID
        }

        let row = HomeRow(
            id: home.id,
            name: home.name,
            street_address: home.streetAddress,
            photo_url: home.photoURL,
            created_by: home.createdBy
        )

        if entry.op == .insert {
            try await client.from("homes").insert(row).execute()
        } else {
            try await client.from("homes").update(row).eq("id", value: home.id.uuidString).execute()
        }
        home.sync = .synced
        home.serverUpdatedAt = .now
        try? modelContext.save()
    }

    private func pushProcedureStep(_ entry: MutationOutboxEntry) async throws {
        let stepId = entry.entityId
        guard
            let step = try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.id == stepId }
            )).first
        else { return }

        struct StepRow: Encodable {
            let status: StepStatus
            let notes: String?
        }

        try await client
            .from("procedure_steps")
            .update(StepRow(status: step.stepStatus, notes: step.notes))
            .eq("id", value: step.id.uuidString)
            .execute()

        step.sync = .synced
        step.serverUpdatedAt = .now

        let procedureId = UUID(uuidString: entry.payload["procedure_id"] ?? "") ?? step.procedureId
        let procTarget = procedureId
        if let procedure = try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
        )).first {
            let steps = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procTarget },
                sortBy: [SortDescriptor(\.sortOrder)]
            ))) ?? []
            let summaries = steps.map {
                ProcedureStepSummary(
                    id: $0.id,
                    procedureId: $0.procedureId,
                    sortOrder: $0.sortOrder,
                    title: $0.title,
                    status: $0.stepStatus,
                    notes: $0.notes
                )
            }
            let aggregate = ProcedureAggregator.aggregateStatus(for: summaries)

            struct ProcedureRow: Encodable {
                let status: ProcedureStatus
            }

            try await client
                .from("procedures")
                .update(ProcedureRow(status: aggregate))
                .eq("id", value: procedure.id.uuidString)
                .execute()

            procedure.procedureStatus = aggregate
            procedure.sync = SyncStatus.synced
            procedure.serverUpdatedAt = Date.now
        }

        try? modelContext.save()
    }

    private func pullChanges() async {
        do {
            let rows: [HomeDTO] = try await client
                .from("homes")
                .select()
                .execute()
                .value
            for row in rows {
                mergeHome(row)
            }
            try? modelContext.save()
        } catch {
            lastNotification = SyncNotification(message: "Could not refresh homes: \(error.localizedDescription)")
        }
    }

    private func mergeHome(_ dto: HomeDTO) {
        let targetId = dto.id
        let existing = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first

        if let existing {
            if existing.sync == .pending {
                if HomeConflictResolver.shouldApplyServer(
                    localPending: true,
                    localUpdatedAt: existing.localUpdatedAt,
                    serverUpdatedAt: dto.updatedAt
                ) {
                    activityLog.append(
                        homeId: dto.id,
                        actorId: dto.createdBy,
                        entityType: "home",
                        entityId: dto.id,
                        action: "conflict_resolved",
                        summary: "Home edit conflict — server version kept for \(dto.name)"
                    )
                    applyServerHome(dto, to: existing)
                }
                return
            }
            if let server = dto.updatedAt, let local = existing.serverUpdatedAt, server <= local {
                return
            }
            applyServerHome(dto, to: existing)
        } else {
            let home = CachedHome(
                id: dto.id,
                name: dto.name,
                streetAddress: dto.streetAddress,
                photoURL: dto.photoURL,
                createdBy: dto.createdBy,
                syncStatus: .synced,
                serverUpdatedAt: dto.updatedAt
            )
            modelContext.insert(home)
        }
    }

    private func applyServerHome(_ dto: HomeDTO, to existing: CachedHome) {
        existing.name = dto.name
        existing.streetAddress = dto.streetAddress
        existing.photoURL = dto.photoURL
        existing.serverUpdatedAt = dto.updatedAt
        existing.sync = .synced
    }

    private func revertPermissionDenied(entry: MutationOutboxEntry, message: String?) {
        let targetId = entry.entityId
        switch entry.entity {
        case .home:
            if let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
                predicate: #Predicate<CachedHome> { $0.id == targetId }
            )).first {
                home.sync = .synced
            }
        case .procedureStep:
            if let step = try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.id == targetId }
            )).first {
                step.sync = .synced
            }
        default:
            break
        }
        modelContext.delete(entry)
        try? modelContext.save()
        lastNotification = SyncNotification(
            message: message ?? "You no longer have permission for that change. It was reverted."
        )
    }
}

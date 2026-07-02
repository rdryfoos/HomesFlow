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
                    switch entry.op {
                    case .insert:
                        try await insertProcedureStep(entry)
                    case .update:
                        try await pushProcedureStep(entry)
                    case .delete:
                        try await deleteProcedureStep(entry)
                    case nil:
                        modelContext.delete(entry)
                        continue
                    }
                case .serviceProvider:
                    switch entry.op {
                    case .insert, .update:
                        try await pushServiceProvider(entry)
                    case .delete:
                        try await client
                            .from("service_providers")
                            .delete()
                            .eq("id", value: entry.entityId.uuidString)
                            .execute()
                    case nil:
                        modelContext.delete(entry)
                        continue
                    }
                case .document:
                    switch entry.op {
                    case .insert, .update:
                        try await pushDocument(entry)
                    case .delete:
                        try await deleteDocument(entry)
                    case nil:
                        modelContext.delete(entry)
                        continue
                    }
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

    private func insertProcedureStep(_ entry: MutationOutboxEntry) async throws {
        let stepId = entry.entityId
        guard
            let step = try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.id == stepId }
            )).first
        else { return }

        struct NewStepRow: Encodable {
            let id: UUID
            let procedure_id: UUID
            let sort_order: Int
            let title: String
            let status: StepStatus
            let notes: String?
            let photo_url: String?
        }

        try await client
            .from("procedure_steps")
            .insert(NewStepRow(
                id: step.id,
                procedure_id: step.procedureId,
                sort_order: step.sortOrder,
                title: step.title,
                status: step.stepStatus,
                notes: step.notes,
                photo_url: step.photoURL
            ))
            .execute()

        step.sync = .synced
        step.serverUpdatedAt = .now
        try await refreshAggregateStatus(procedureId: step.procedureId)
        try? modelContext.save()
    }

    private func deleteProcedureStep(_ entry: MutationOutboxEntry) async throws {
        try await client
            .from("procedure_steps")
            .delete()
            .eq("id", value: entry.entityId.uuidString)
            .execute()

        if let procedureId = UUID(uuidString: entry.payload["procedure_id"] ?? "") {
            try await refreshAggregateStatus(procedureId: procedureId)
        }
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
            let sort_order: Int
            let title: String
            let status: StepStatus
            let notes: String?
            let photo_url: String?
        }

        try await client
            .from("procedure_steps")
            .update(StepRow(
                sort_order: step.sortOrder,
                title: step.title,
                status: step.stepStatus,
                notes: step.notes,
                photo_url: step.photoURL
            ))
            .eq("id", value: step.id.uuidString)
            .execute()

        step.sync = .synced
        step.serverUpdatedAt = .now

        let procedureId = UUID(uuidString: entry.payload["procedure_id"] ?? "") ?? step.procedureId
        try await refreshAggregateStatus(procedureId: procedureId)
        try? modelContext.save()
    }

    private func refreshAggregateStatus(procedureId: UUID) async throws {
        let procTarget = procedureId
        guard let procedure = try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
        )).first else { return }

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
                notes: $0.notes,
                photoURL: $0.photoURL
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

    private func pushServiceProvider(_ entry: MutationOutboxEntry) async throws {
        let targetId = entry.entityId
        guard
            let provider = try? modelContext.fetch(FetchDescriptor<CachedServiceProvider>(
                predicate: #Predicate<CachedServiceProvider> { $0.id == targetId }
            )).first
        else { return }

        struct ProviderRow: Encodable {
            let id: UUID
            let home_id: UUID
            let company_name: String
            let service_type: String
            let account_number: String?
            let phone: String?
            let website: String?
            let hours: String?
            let notes: String?
            let visibility: Visibility
        }

        let row = ProviderRow(
            id: provider.id,
            home_id: provider.homeId,
            company_name: provider.companyName,
            service_type: provider.serviceType,
            account_number: provider.accountNumber,
            phone: provider.phone,
            website: provider.website,
            hours: provider.hours,
            notes: provider.notes,
            visibility: provider.providerVisibility
        )

        if entry.op == .insert {
            try await client.from("service_providers").insert(row).execute()
        } else {
            try await client
                .from("service_providers")
                .update(row)
                .eq("id", value: provider.id.uuidString)
                .execute()
        }

        provider.sync = .synced
        provider.serverUpdatedAt = .now
        try? modelContext.save()
    }

    private func pushDocument(_ entry: MutationOutboxEntry) async throws {
        let targetId = entry.entityId
        guard
            let document = try? modelContext.fetch(FetchDescriptor<CachedDocument>(
                predicate: #Predicate<CachedDocument> { $0.id == targetId }
            )).first
        else { return }

        struct DocumentRow: Encodable {
            let id: UUID
            let home_id: UUID
            let title: String
            let category: String?
            let storage_path: String?
            let visibility: Visibility
        }

        let row = DocumentRow(
            id: document.id,
            home_id: document.homeId,
            title: document.title,
            category: document.category,
            storage_path: document.storagePath,
            visibility: document.documentVisibility
        )

        if entry.op == .insert {
            try await client.from("documents").insert(row).execute()
        } else {
            try await client
                .from("documents")
                .update(row)
                .eq("id", value: document.id.uuidString)
                .execute()
        }

        document.sync = .synced
        document.serverUpdatedAt = .now
        try? modelContext.save()
    }

    private func deleteDocument(_ entry: MutationOutboxEntry) async throws {
        if let path = entry.payload["storage_path"], !path.isEmpty {
            try? await client.storage.from("documents").remove(paths: [path])
        }
        try await client
            .from("documents")
            .delete()
            .eq("id", value: entry.entityId.uuidString)
            .execute()
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
                if entry.op == .insert {
                    // Local-only step that the server rejected — discard it.
                    modelContext.delete(step)
                } else {
                    step.sync = .synced
                }
            }
        case .serviceProvider:
            if let provider = try? modelContext.fetch(FetchDescriptor<CachedServiceProvider>(
                predicate: #Predicate<CachedServiceProvider> { $0.id == targetId }
            )).first {
                if entry.op == .insert {
                    modelContext.delete(provider)
                } else {
                    provider.sync = .synced
                }
            }
        case .document:
            if let document = try? modelContext.fetch(FetchDescriptor<CachedDocument>(
                predicate: #Predicate<CachedDocument> { $0.id == targetId }
            )).first {
                if entry.op == .insert {
                    modelContext.delete(document)
                } else {
                    document.sync = .synced
                }
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

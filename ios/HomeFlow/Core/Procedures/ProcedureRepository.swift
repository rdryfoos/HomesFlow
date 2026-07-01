import Foundation
import SwiftData
import Supabase

// @covers FR-PROC-01, FR-PROC-02, AC-PROC-01, AC-PROC-02

@MainActor
final class ProcedureRepository: ObservableObject {
    private let modelContext: ModelContext
    private let auth: SupabaseClientProvider
    private let activityLog: ActivityLogService
    private let syncEngine: SyncEngine
    private let permissions = PermissionService()

    init(
        modelContext: ModelContext,
        auth: SupabaseClientProvider,
        activityLog: ActivityLogService,
        syncEngine: SyncEngine
    ) {
        self.modelContext = modelContext
        self.auth = auth
        self.activityLog = activityLog
        self.syncEngine = syncEngine
    }

    func fetchProcedures(homeId: UUID, userRole: HomeRole) async throws -> [ProcedureSummary] {
        if NetworkMonitor.shared.isConnected {
            try await pullProcedures(homeId: homeId)
        }
        return cachedSummaries(homeId: homeId, userRole: userRole)
    }

    func fetchProcedureDetail(
        procedureId: UUID,
        homeId: UUID,
        userRole: HomeRole
    ) async throws -> ProcedureDetail? {
        if NetworkMonitor.shared.isConnected {
            try await pullProcedures(homeId: homeId)
        }
        return cachedDetail(procedureId: procedureId, userRole: userRole)
    }

    func canUpdateSteps(for procedure: ProcedureDetail, userRole: HomeRole) -> Bool {
        procedure.steps.contains { step in
            permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: procedure.visibility),
                role: userRole
            )
        }
    }

    func canViewActivityLog(userRole: HomeRole) -> Bool {
        permissions.can(.read, entity: .activityLog, role: userRole)
    }

    func fetchProcedureActivity(
        procedureId: UUID,
        homeId: UUID,
        userRole: HomeRole
    ) async throws -> [ActivityLogSummary] {
        guard canViewActivityLog(userRole: userRole) else { return [] }

        if NetworkMonitor.shared.isConnected {
            try await activityLog.pull(homeId: homeId)
        }

        guard let detail = cachedDetail(procedureId: procedureId, userRole: userRole) else {
            return []
        }

        let stepIds = Set(detail.steps.map(\.id))
        return activityLog.recentForProcedure(
            homeId: homeId,
            procedureId: procedureId,
            stepIds: stepIds,
            limit: 10
        )
    }

    func updateStepNotes(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        notes: String?,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }

        guard let detail = cachedDetail(procedureId: procedureId, userRole: userRole) else {
            throw ProcedureError.notFound
        }

        guard permissions.can(
            .updateStepStatus,
            entity: .procedureStep(procedureVisibility: detail.visibility),
            role: userRole
        ) else {
            throw ProcedureError.notAuthorized
        }

        guard let step = detail.steps.first(where: { $0.id == stepId }) else {
            throw ProcedureError.notFound
        }

        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = (trimmed?.isEmpty == false) ? trimmed : nil
        let previousNotes = step.notes

        guard normalizedNotes != previousNotes else { return }

        let stepTarget = stepId
        guard let cachedStep = try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
            predicate: #Predicate<CachedProcedureStep> { $0.id == stepTarget }
        )).first else {
            throw ProcedureError.notFound
        }

        cachedStep.notes = normalizedNotes
        cachedStep.localUpdatedAt = .now
        cachedStep.sync = .pending

        syncEngine.enqueue(
            entityType: .procedureStep,
            entityId: stepId,
            operation: .update,
            payload: ["procedure_id": procedureId.uuidString]
        )

        try modelContext.save()

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "procedure_step",
            entityId: stepId,
            action: "notes_updated",
            summary: "Updated notes for \"\(step.title)\" in \(detail.title)"
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    func updateStepStatus(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        status: StepStatus,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }

        guard let detail = cachedDetail(procedureId: procedureId, userRole: userRole) else {
            throw ProcedureError.notFound
        }

        guard permissions.can(
            .updateStepStatus,
            entity: .procedureStep(procedureVisibility: detail.visibility),
            role: userRole
        ) else {
            throw ProcedureError.notAuthorized
        }

        guard let step = detail.steps.first(where: { $0.id == stepId }) else {
            throw ProcedureError.notFound
        }

        let stepTarget = stepId
        guard let cachedStep = try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
            predicate: #Predicate<CachedProcedureStep> { $0.id == stepTarget }
        )).first else {
            throw ProcedureError.notFound
        }

        let previousStatus = cachedStep.stepStatus
        cachedStep.stepStatus = status
        cachedStep.localUpdatedAt = .now
        cachedStep.sync = .pending

        let procTarget = procedureId
        if let cachedProcedure = try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
        )).first {
            let updatedSteps = detail.steps.map { summary in
                if summary.id == stepId {
                    return ProcedureStepSummary(
                        id: summary.id,
                        procedureId: summary.procedureId,
                        sortOrder: summary.sortOrder,
                        title: summary.title,
                        status: status,
                        notes: summary.notes
                    )
                }
                return summary
            }
            cachedProcedure.procedureStatus = ProcedureAggregator.aggregateStatus(for: updatedSteps)
            cachedProcedure.sync = .pending
        }

        syncEngine.enqueue(
            entityType: .procedureStep,
            entityId: stepId,
            operation: .update,
            payload: ["procedure_id": procedureId.uuidString]
        )

        try modelContext.save()

        if status == .complete && previousStatus != .complete {
            activityLog.append(
                homeId: homeId,
                actorId: userId,
                entityType: "procedure_step",
                entityId: stepId,
                action: "completed",
                summary: "Completed step \"\(step.title)\" in \(detail.title)"
            )
        }

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    private func pullProcedures(homeId: UUID) async throws {
        let procedures: [ProcedureDTO] = try await auth.client
            .from("procedures")
            .select()
            .eq("home_id", value: homeId.uuidString)
            .execute()
            .value

        let procedureIds = procedures.map(\.id)
        var steps: [ProcedureStepDTO] = []
        if !procedureIds.isEmpty {
            steps = try await auth.client
                .from("procedure_steps")
                .select()
                .in("procedure_id", values: procedureIds.map(\.uuidString))
                .execute()
                .value
        }

        mergeCachedProcedures(homeId: homeId, rows: procedures)
        mergeCachedSteps(procedureIds: procedureIds, rows: steps)
        try modelContext.save()
    }

    private func mergeCachedProcedures(homeId: UUID, rows: [ProcedureDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.homeId == homeTarget }
        ))) ?? []

        let incomingIds = Set(rows.map(\.id))
        for stale in existing where !incomingIds.contains(stale.id) {
            deleteSteps(for: stale.id)
            modelContext.delete(stale)
        }

        for row in rows {
            if let cached = existing.first(where: { $0.id == row.id }) {
                if cached.sync == .pending { continue }
                cached.title = row.title
                cached.category = row.category
                cached.procedureDescription = row.description
                cached.procedureStatus = row.status
                cached.procedureVisibility = row.visibility
                cached.serverUpdatedAt = row.updatedAt
            } else {
                modelContext.insert(CachedProcedure(
                    id: row.id,
                    homeId: row.homeId,
                    title: row.title,
                    category: row.category,
                    procedureDescription: row.description,
                    status: row.status,
                    visibility: row.visibility,
                    syncStatus: .synced,
                    serverUpdatedAt: row.updatedAt
                ))
            }
        }
    }

    private func mergeCachedSteps(procedureIds: [UUID], rows: [ProcedureStepDTO]) {
        let idSet = Set(procedureIds)
        for procedureId in procedureIds {
            let procTarget = procedureId
            let existing = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procTarget }
            ))) ?? []

            let incoming = rows.filter { $0.procedureId == procedureId }
            let incomingIds = Set(incoming.map(\.id))
            for stale in existing where !incomingIds.contains(stale.id) {
                modelContext.delete(stale)
            }

            for row in incoming {
                if let cached = existing.first(where: { $0.id == row.id }) {
                    if cached.sync == .pending { continue }
                    cached.sortOrder = row.sortOrder
                    cached.title = row.title
                    cached.stepStatus = row.status
                    cached.notes = row.notes
                    cached.serverUpdatedAt = row.updatedAt
                } else {
                    modelContext.insert(CachedProcedureStep(
                        id: row.id,
                        procedureId: row.procedureId,
                        sortOrder: row.sortOrder,
                        title: row.title,
                        status: row.status,
                        notes: row.notes,
                        syncStatus: .synced,
                        serverUpdatedAt: row.updatedAt
                    ))
                }
            }
        }

        // Remove orphaned steps if procedure was deleted elsewhere
        let allSteps = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>())) ?? []
        for step in allSteps where !idSet.contains(step.procedureId) {
            modelContext.delete(step)
        }
    }

    private func deleteSteps(for procedureId: UUID) {
        let procTarget = procedureId
        let steps = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
            predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procTarget }
        ))) ?? []
        for step in steps {
            modelContext.delete(step)
        }
    }

    private func cachedSummaries(homeId: UUID, userRole: HomeRole) -> [ProcedureSummary] {
        let homeTarget = homeId
        let procedures = (try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.title)]
        ))) ?? []

        return procedures.compactMap { procedure in
            guard permissions.can(
                .read,
                entity: .procedure(visibility: procedure.procedureVisibility),
                role: userRole
            ) else { return nil }

            let steps = cachedSteps(for: procedure.id)
            let stepSummaries = steps.map(stepSummary(from:))
            let completed = ProcedureAggregator.completedCount(for: stepSummaries)

            return ProcedureSummary(
                id: procedure.id,
                homeId: procedure.homeId,
                title: procedure.title,
                category: procedure.category,
                status: procedure.procedureStatus,
                visibility: procedure.procedureVisibility,
                completedSteps: completed,
                totalSteps: stepSummaries.count
            )
        }
    }

    private func cachedDetail(procedureId: UUID, userRole: HomeRole) -> ProcedureDetail? {
        let procTarget = procedureId
        guard let procedure = try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
        )).first else { return nil }

        guard permissions.can(
            .read,
            entity: .procedure(visibility: procedure.procedureVisibility),
            role: userRole
        ) else { return nil }

        let steps = cachedSteps(for: procedureId).map(stepSummary(from:))

        return ProcedureDetail(
            id: procedure.id,
            homeId: procedure.homeId,
            title: procedure.title,
            category: procedure.category,
            description: procedure.procedureDescription,
            status: procedure.procedureStatus,
            visibility: procedure.procedureVisibility,
            steps: steps
        )
    }

    private func cachedSteps(for procedureId: UUID) -> [CachedProcedureStep] {
        let procTarget = procedureId
        return (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
            predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procTarget },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
    }

    private func stepSummary(from cached: CachedProcedureStep) -> ProcedureStepSummary {
        ProcedureStepSummary(
            id: cached.id,
            procedureId: cached.procedureId,
            sortOrder: cached.sortOrder,
            title: cached.title,
            status: cached.stepStatus,
            notes: cached.notes
        )
    }
}

enum ProcedureError: LocalizedError {
    case notAuthorized
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "You don't have permission to update this procedure."
        case .notFound: "Procedure not found."
        }
    }
}

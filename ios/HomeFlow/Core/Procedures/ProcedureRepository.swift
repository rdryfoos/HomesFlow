import Foundation
import SwiftData
import Supabase
import UIKit

// @covers FR-PROC-01, FR-PROC-02, FR-PROC-03, AC-PROC-01, AC-PROC-02, AC-PROC-03, AC-PROC-04, AC-PROC-05, AC-PROC-06, AC-PROC-07, AC-GUEST-03, AC-GUEST-05, FR-GUEST-01

@MainActor
final class ProcedureRepository: ObservableObject {
    /// Bumped when procedure list summaries (status/progress) may have changed.
    @Published private(set) var listRevision = 0

    private let modelContext: ModelContext
    private let auth: SupabaseClientProvider
    private let activityLog: ActivityLogService
    private let syncEngine: SyncEngine
    private let attachmentService: ProcedureAttachmentService
    private let permissions = PermissionService()

    init(
        modelContext: ModelContext,
        auth: SupabaseClientProvider,
        activityLog: ActivityLogService,
        syncEngine: SyncEngine,
        attachmentService: ProcedureAttachmentService
    ) {
        self.modelContext = modelContext
        self.auth = auth
        self.activityLog = activityLog
        self.syncEngine = syncEngine
        self.attachmentService = attachmentService
    }

    func cachedStepPhoto(for storagePath: String) -> UIImage? {
        attachmentService.cachedImage(storagePath: storagePath)
    }

    func loadStepPhoto(storagePath: String) async throws -> UIImage {
        try await attachmentService.loadImage(storagePath: storagePath)
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

    /// Whether a procedure exists in cache and is readable for the role (AC-GUEST-02).
    func procedureAccessState(procedureId: UUID, userRole: HomeRole) -> EntityAccessState {
        guard let procedure = rawCachedProcedure(procedureId) else { return .notFound }
        guard permissions.can(
            .read,
            entity: .procedure(visibility: procedure.procedureVisibility),
            role: userRole
        ) else {
            return .accessDenied
        }
        return .allowed
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

    // @covers AC-PROC-07
    func canManageStepStructure(for procedure: ProcedureDetail, userRole: HomeRole) -> Bool {
        permissions.can(
            .create,
            entity: .procedureStep(procedureVisibility: procedure.visibility),
            role: userRole
        )
    }

    // MARK: - Step structure (create, rename, reorder, delete) — AC-PROC-04…06

    func createStep(
        homeId: UUID,
        procedureId: UUID,
        title: String,
        userRole: HomeRole
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let (userId, detail) = try authorizedStructureContext(
            action: .create,
            procedureId: procedureId,
            userRole: userRole
        )

        let sortOrder = StepStructure.nextSortOrder(existing: detail.steps.map(\.sortOrder))
        let step = CachedProcedureStep(
            procedureId: procedureId,
            sortOrder: sortOrder,
            title: trimmed,
            syncStatus: .pending
        )
        modelContext.insert(step)

        syncEngine.enqueue(
            entityType: .procedureStep,
            entityId: step.id,
            operation: .insert,
            payload: ["procedure_id": procedureId.uuidString]
        )

        refreshAggregateAfterStructureChange(procedureId: procedureId)
        try modelContext.save()

        logStructureChange(
            .created,
            homeId: homeId,
            actorId: userId,
            stepId: step.id,
            stepTitle: trimmed,
            procedureTitle: detail.title
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    func renameStep(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        title: String,
        userRole: HomeRole
    ) async throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let (userId, detail) = try authorizedStructureContext(
            action: .update,
            procedureId: procedureId,
            userRole: userRole
        )

        guard let cachedStep = cachedStep(stepId) else { throw ProcedureError.notFound }
        guard cachedStep.title != trimmed else { return }

        cachedStep.title = trimmed
        cachedStep.localUpdatedAt = .now
        cachedStep.sync = .pending

        syncEngine.enqueue(
            entityType: .procedureStep,
            entityId: stepId,
            operation: .update,
            payload: ["procedure_id": procedureId.uuidString]
        )

        try modelContext.save()

        logStructureChange(
            .renamed,
            homeId: homeId,
            actorId: userId,
            stepId: stepId,
            stepTitle: trimmed,
            procedureTitle: detail.title
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    func deleteStep(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        userRole: HomeRole
    ) async throws {
        let (userId, detail) = try authorizedStructureContext(
            action: .delete,
            procedureId: procedureId,
            userRole: userRole
        )

        guard let cachedStep = cachedStep(stepId) else { throw ProcedureError.notFound }
        let stepTitle = cachedStep.title
        let existedOnServer = cachedStep.serverUpdatedAt != nil

        removeOutboxEntry(for: stepId)
        modelContext.delete(cachedStep)

        if existedOnServer {
            syncEngine.enqueue(
                entityType: .procedureStep,
                entityId: stepId,
                operation: .delete,
                payload: ["procedure_id": procedureId.uuidString]
            )
        }

        refreshAggregateAfterStructureChange(procedureId: procedureId)
        try modelContext.save()

        logStructureChange(
            .deleted,
            homeId: homeId,
            actorId: userId,
            stepId: stepId,
            stepTitle: stepTitle,
            procedureTitle: detail.title
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    func moveStep(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        direction: StepMoveDirection,
        userRole: HomeRole
    ) async throws {
        let (userId, detail) = try authorizedStructureContext(
            action: .update,
            procedureId: procedureId,
            userRole: userRole
        )

        guard let neighbor = StepStructure.swapTarget(
            for: stepId,
            direction: direction,
            in: detail.steps
        ) else { return }

        guard
            let movingStep = cachedStep(stepId),
            let neighborStep = cachedStep(neighbor.id)
        else { throw ProcedureError.notFound }

        let movingOrder = movingStep.sortOrder
        movingStep.sortOrder = neighborStep.sortOrder
        neighborStep.sortOrder = movingOrder

        for step in [movingStep, neighborStep] {
            step.localUpdatedAt = .now
            step.sync = .pending
            syncEngine.enqueue(
                entityType: .procedureStep,
                entityId: step.id,
                operation: .update,
                payload: ["procedure_id": procedureId.uuidString]
            )
        }

        try modelContext.save()

        logStructureChange(
            .reordered,
            homeId: homeId,
            actorId: userId,
            stepId: stepId,
            stepTitle: movingStep.title,
            procedureTitle: detail.title
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    private func authorizedStructureContext(
        action: PermissionAction,
        procedureId: UUID,
        userRole: HomeRole
    ) throws -> (userId: UUID, detail: ProcedureDetail) {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard let detail = cachedDetail(procedureId: procedureId, userRole: userRole) else {
            throw ProcedureError.notFound
        }
        guard permissions.can(
            action,
            entity: .procedureStep(procedureVisibility: detail.visibility),
            role: userRole
        ) else {
            throw ProcedureError.notAuthorized
        }
        return (userId, detail)
    }

    private func logStructureChange(
        _ action: StepStructureAction,
        homeId: UUID,
        actorId: UUID,
        stepId: UUID,
        stepTitle: String,
        procedureTitle: String
    ) {
        activityLog.append(
            homeId: homeId,
            actorId: actorId,
            entityType: "procedure_step",
            entityId: stepId,
            action: action.rawValue,
            summary: StepStructure.activitySummary(
                action: action,
                stepTitle: stepTitle,
                procedureTitle: procedureTitle
            )
        )
    }

    private func refreshAggregateAfterStructureChange(procedureId: UUID) {
        let procTarget = procedureId
        guard let procedure = try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
        )).first else { return }
        let summaries = cachedSteps(for: procedureId).map(stepSummary(from:))
        procedure.procedureStatus = ProcedureAggregator.aggregateStatus(for: summaries)
        procedure.sync = .pending
        notifyProcedureListChanged()
    }

    private func cachedStep(_ stepId: UUID) -> CachedProcedureStep? {
        let stepTarget = stepId
        return try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
            predicate: #Predicate<CachedProcedureStep> { $0.id == stepTarget }
        )).first
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

    func updateStepDetails(
        homeId: UUID,
        procedureId: UUID,
        stepId: UUID,
        title: String?,
        notes: String?,
        photoChange: StepPhotoChange,
        canEditTitle: Bool,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }

        guard let detail = cachedDetail(procedureId: procedureId, userRole: userRole) else {
            throw ProcedureError.notFound
        }

        guard let step = detail.steps.first(where: { $0.id == stepId }) else {
            throw ProcedureError.notFound
        }

        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedTitle = (trimmedTitle?.isEmpty == false) ? trimmedTitle : nil
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = (trimmedNotes?.isEmpty == false) ? trimmedNotes : nil

        let titleChanging = canEditTitle && normalizedTitle != nil && normalizedTitle != step.title
        let notesChanging = normalizedNotes != step.notes
        let photoChanging: Bool = switch photoChange {
        case .unchanged: false
        case .set: true
        case .remove: step.photoURL != nil
        }

        guard titleChanging || notesChanging || photoChanging else { return }

        if titleChanging {
            guard permissions.can(
                .update,
                entity: .procedureStep(procedureVisibility: detail.visibility),
                role: userRole
            ) else {
                throw ProcedureError.notAuthorized
            }
        }

        if notesChanging || photoChanging {
            guard permissions.can(
                .updateStepStatus,
                entity: .procedureStep(procedureVisibility: detail.visibility),
                role: userRole
            ) else {
                if userRole == .guest {
                    logUnauthorizedStepAttempt(
                        homeId: homeId,
                        actorId: userId,
                        stepId: stepId,
                        stepTitle: step.title,
                        procedureTitle: detail.title,
                        attemptedAction: "edit"
                    )
                }
                throw ProcedureError.notAuthorized
            }
        }

        guard let cachedStep = cachedStep(stepId) else { throw ProcedureError.notFound }

        var newPhotoURL = step.photoURL
        if photoChanging {
            switch photoChange {
            case .unchanged:
                break
            case .remove:
                newPhotoURL = nil
            case .set(let data):
                guard NetworkMonitor.shared.isConnected else {
                    throw ProcedureError.photoRequiresOnline
                }
                if cachedStep.sync == .pending {
                    _ = await syncEngine.run()
                }
                if cachedStep.sync == .pending {
                    throw ProcedureError.photoRequiresSync
                }
                do {
                    newPhotoURL = try await attachmentService.uploadPhoto(
                        homeId: homeId,
                        procedureId: procedureId,
                        imageData: data
                    )
                } catch {
                    throw ProcedureError.photoUploadFailed(error.localizedDescription)
                }
            }
        }

        if titleChanging, let normalizedTitle {
            cachedStep.title = normalizedTitle
        }
        if notesChanging {
            cachedStep.notes = normalizedNotes
        }
        if photoChanging {
            cachedStep.photoURL = newPhotoURL
        }

        cachedStep.localUpdatedAt = .now
        cachedStep.sync = .pending

        syncEngine.enqueue(
            entityType: .procedureStep,
            entityId: stepId,
            operation: .update,
            payload: ["procedure_id": procedureId.uuidString]
        )

        try modelContext.save()

        if titleChanging, let normalizedTitle {
            logStructureChange(
                .renamed,
                homeId: homeId,
                actorId: userId,
                stepId: stepId,
                stepTitle: normalizedTitle,
                procedureTitle: detail.title
            )
        }

        if notesChanging || photoChanging {
            var parts: [String] = []
            if notesChanging { parts.append("notes") }
            if photoChanging {
                if case .remove = photoChange {
                    parts.append("removed photo")
                } else {
                    parts.append("photo")
                }
            }
            activityLog.append(
                homeId: homeId,
                actorId: userId,
                entityType: "procedure_step",
                entityId: stepId,
                action: "details_updated",
                summary: "Updated \(parts.joined(separator: " and ")) for \"\(cachedStep.title)\" in \(detail.title)"
            )
        }

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
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
            if userRole == .guest, let step = detail.steps.first(where: { $0.id == stepId }) {
                logUnauthorizedStepAttempt(
                    homeId: homeId,
                    actorId: userId,
                    stepId: stepId,
                    stepTitle: step.title,
                    procedureTitle: detail.title,
                    attemptedAction: "edit notes on"
                )
            }
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
            if userRole == .guest, let step = detail.steps.first(where: { $0.id == stepId }) {
                logUnauthorizedStepAttempt(
                    homeId: homeId,
                    actorId: userId,
                    stepId: stepId,
                    stepTitle: step.title,
                    procedureTitle: detail.title,
                    attemptedAction: "update"
                )
            }
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
                        notes: summary.notes,
                        photoURL: summary.photoURL
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

        notifyProcedureListChanged()
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
        mergeCachedSteps(homeId: homeId, procedureIds: procedureIds, rows: steps)
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
                if cached.sync == .pending {
                    guard let serverAt = row.updatedAt,
                          let priorServerAt = cached.serverUpdatedAt,
                          serverAt > priorServerAt else { continue }
                    removeOutboxEntries(for: cached.id)
                    syncEngine.postNotification(
                        "Your offline edit to \(row.title) was overwritten by a newer update."
                    )
                }
                cached.title = row.title
                cached.category = row.category
                cached.procedureDescription = row.description
                cached.procedureStatus = row.status
                cached.procedureVisibility = row.visibility
                cached.serverUpdatedAt = row.updatedAt
                cached.sync = .synced
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

    private func mergeCachedSteps(homeId: UUID, procedureIds: [UUID], rows: [ProcedureStepDTO]) {
        let idSet = Set(procedureIds)
        let pendingDeletes = pendingStepDeleteIds()
        for procedureId in procedureIds {
            let procTarget = procedureId
            let procedure = try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
                predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
            )).first

            let existing = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procTarget }
            ))) ?? []

            let incoming = rows.filter { $0.procedureId == procedureId }
            let incomingIds = Set(incoming.map(\.id))
            for stale in existing where !incomingIds.contains(stale.id) {
                // Keep locally created steps that haven't been pushed yet.
                if stale.sync == .pending { continue }
                modelContext.delete(stale)
            }

            for row in incoming {
                // Skip rows the user deleted locally while the delete is still queued.
                if pendingDeletes.contains(row.id) { continue }
                if let cached = existing.first(where: { $0.id == row.id }) {
                    if cached.sync == .pending {
                        if HomeConflictResolver.shouldApplyServer(
                            localPending: true,
                            localUpdatedAt: cached.localUpdatedAt,
                            serverUpdatedAt: row.updatedAt
                        ) {
                            resolveStepConflict(
                                homeId: homeId,
                                procedureTitle: procedure?.title ?? "Procedure",
                                server: row,
                                local: cached
                            )
                        }
                        continue
                    }
                    applyServerStep(row, to: cached)
                } else {
                    modelContext.insert(CachedProcedureStep(
                        id: row.id,
                        procedureId: row.procedureId,
                        sortOrder: row.sortOrder,
                        title: row.title,
                        status: row.status,
                        notes: row.notes,
                        photoURL: row.photoURL,
                        syncStatus: .synced,
                        serverUpdatedAt: row.updatedAt
                    ))
                }
            }

            if let procedure {
                refreshProcedureAggregateStatus(procedure)
            }
        }

        // Remove orphaned steps if procedure was deleted elsewhere
        let allSteps = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>())) ?? []
        for step in allSteps where !idSet.contains(step.procedureId) {
            modelContext.delete(step)
        }
    }

    private func resolveStepConflict(
        homeId: UUID,
        procedureTitle: String,
        server: ProcedureStepDTO,
        local: CachedProcedureStep
    ) {
        applyServerStep(server, to: local)
        removeOutboxEntry(for: local.id)

        if let userId = auth.session?.user.id {
            activityLog.append(
                homeId: homeId,
                actorId: userId,
                entityType: "procedure_step",
                entityId: server.id,
                action: "conflict_resolved",
                summary: "Step conflict — server version kept for \"\(server.title)\" in \(procedureTitle)"
            )
        }

        syncEngine.postNotification(
            "Your offline change to \"\(server.title)\" was overwritten by a newer update."
        )
    }

    private func applyServerStep(_ row: ProcedureStepDTO, to cached: CachedProcedureStep) {
        cached.sortOrder = row.sortOrder
        cached.title = row.title
        cached.stepStatus = row.status
        cached.notes = row.notes
        cached.photoURL = row.photoURL
        cached.serverUpdatedAt = row.updatedAt
        cached.sync = .synced
    }

    private func refreshProcedureAggregateStatus(_ procedure: CachedProcedure) {
        let procTarget = procedure.id
        let steps = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
            predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procTarget },
            sortBy: [SortDescriptor(\.sortOrder)]
        ))) ?? []
        let summaries = steps.map(stepSummary(from:))
        procedure.procedureStatus = ProcedureAggregator.aggregateStatus(for: summaries)
        if procedure.sync != .pending {
            procedure.sync = .synced
        }
    }

    private func pendingStepDeleteIds() -> Set<UUID> {
        let stepEntity = EntityType.procedureStep.rawValue
        let deleteOp = OutboxOperation.delete.rawValue
        let entries = (try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>())) ?? []
        return Set(
            entries
                .filter { $0.entityType == stepEntity && $0.operation == deleteOp }
                .map(\.entityId)
        )
    }

    private func removeOutboxEntry(for stepId: UUID) {
        let targetId = stepId
        let stepEntity = EntityType.procedureStep.rawValue
        guard let entries = try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>()) else { return }
        for entry in entries where entry.entityId == targetId && entry.entityType == stepEntity {
            modelContext.delete(entry)
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

    private func rawCachedProcedure(_ procedureId: UUID) -> CachedProcedure? {
        let procTarget = procedureId
        return try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.id == procTarget }
        )).first
    }

    private func logUnauthorizedStepAttempt(
        homeId: UUID,
        actorId: UUID,
        stepId: UUID,
        stepTitle: String,
        procedureTitle: String,
        attemptedAction: String
    ) {
        activityLog.append(
            homeId: homeId,
            actorId: actorId,
            entityType: "procedure_step",
            entityId: stepId,
            action: "unauthorized_attempt",
            summary: "Unauthorized attempt to \(attemptedAction) step \"\(stepTitle)\" in \(procedureTitle)"
        )
    }

    private func removeOutboxEntries(for entityId: UUID) {
        let entries = (try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>())) ?? []
        for entry in entries where entry.entityId == entityId {
            modelContext.delete(entry)
        }
    }

    private func cachedDetail(procedureId: UUID, userRole: HomeRole) -> ProcedureDetail? {
        guard let procedure = rawCachedProcedure(procedureId) else { return nil }

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
            notes: cached.notes,
            photoURL: cached.photoURL
        )
    }

    private func notifyProcedureListChanged() {
        listRevision += 1
    }
}

enum ProcedureError: LocalizedError {
    case notAuthorized
    case notFound
    case photoRequiresOnline
    case photoRequiresSync
    case photoUploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "You don't have permission to update this procedure."
        case .notFound: "Procedure not found."
        case .photoRequiresOnline:
            "You're offline. Connect to the internet before attaching a photo."
        case .photoRequiresSync:
            "Sync this step before attaching a photo."
        case .photoUploadFailed(let message):
            "Photo upload failed: \(message)"
        }
    }
}

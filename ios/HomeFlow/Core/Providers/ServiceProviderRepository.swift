import Foundation
import SwiftData
import Supabase

// @covers FR-HOME-02, AC-HOME-04, AC-GUEST-01, FR-GUEST-01, AC-HOME-05, AC-SYNC-01

@MainActor
final class ServiceProviderRepository: ObservableObject {
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

    // MARK: - Queries

    func fetchProviders(homeId: UUID, userRole: HomeRole) async throws -> [ServiceProviderSummary] {
        if NetworkMonitor.shared.isConnected {
            try await pullProviders(homeId: homeId)
        }
        return cachedSummaries(homeId: homeId, userRole: userRole)
    }

    func providerAccessState(providerId: UUID, userRole: HomeRole) -> EntityAccessState {
        guard let provider = cachedProvider(providerId) else { return .notFound }
        guard permissions.can(
            .read,
            entity: .serviceProvider(visibility: provider.providerVisibility),
            role: userRole
        ) else {
            return .accessDenied
        }
        return .allowed
    }

    func canManageProviders(userRole: HomeRole) -> Bool {
        permissions.can(.create, entity: .serviceProvider(visibility: .manager), role: userRole)
    }

    // MARK: - Mutations

    func createProvider(
        homeId: UUID,
        draft: ServiceProviderDraft,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard draft.isValid else { return }
        guard permissions.can(
            .create,
            entity: .serviceProvider(visibility: draft.visibility),
            role: userRole
        ) else {
            throw ProviderError.notAuthorized
        }

        let provider = CachedServiceProvider(
            homeId: homeId,
            companyName: draft.normalized(draft.companyName) ?? "",
            serviceType: draft.normalized(draft.serviceType) ?? "",
            accountNumber: draft.normalized(draft.accountNumber),
            phone: draft.normalized(draft.phone),
            website: draft.normalized(draft.website),
            hours: draft.normalized(draft.hours),
            notes: draft.normalized(draft.notes),
            visibility: draft.visibility,
            syncStatus: .pending
        )
        modelContext.insert(provider)

        syncEngine.enqueue(
            entityType: .serviceProvider,
            entityId: provider.id,
            operation: .insert,
            payload: ["home_id": homeId.uuidString]
        )
        try modelContext.save()

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "provider",
            entityId: provider.id,
            action: "created",
            summary: "Added contact \(provider.companyName)"
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    func updateProvider(
        homeId: UUID,
        providerId: UUID,
        draft: ServiceProviderDraft,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard draft.isValid else { return }
        guard let cached = cachedProvider(providerId) else { throw ProviderError.notFound }
        guard permissions.can(
            .update,
            entity: .serviceProvider(visibility: cached.providerVisibility),
            role: userRole
        ) else {
            throw ProviderError.notAuthorized
        }

        cached.companyName = draft.normalized(draft.companyName) ?? cached.companyName
        cached.serviceType = draft.normalized(draft.serviceType) ?? cached.serviceType
        cached.accountNumber = draft.normalized(draft.accountNumber)
        cached.phone = draft.normalized(draft.phone)
        cached.website = draft.normalized(draft.website)
        cached.hours = draft.normalized(draft.hours)
        cached.notes = draft.normalized(draft.notes)
        cached.providerVisibility = draft.visibility
        cached.localUpdatedAt = .now
        cached.sync = .pending

        syncEngine.enqueue(
            entityType: .serviceProvider,
            entityId: providerId,
            operation: .update,
            payload: ["home_id": homeId.uuidString]
        )
        try modelContext.save()

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "provider",
            entityId: providerId,
            action: "updated",
            summary: "Updated contact \(cached.companyName)"
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    func deleteProvider(
        homeId: UUID,
        providerId: UUID,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard let cached = cachedProvider(providerId) else { throw ProviderError.notFound }
        guard permissions.can(
            .delete,
            entity: .serviceProvider(visibility: cached.providerVisibility),
            role: userRole
        ) else {
            throw ProviderError.notAuthorized
        }

        let companyName = cached.companyName
        let everSynced = cached.serverUpdatedAt != nil

        removeOutboxEntries(for: providerId)
        modelContext.delete(cached)

        if everSynced {
            syncEngine.enqueue(
                entityType: .serviceProvider,
                entityId: providerId,
                operation: .delete,
                payload: ["home_id": homeId.uuidString]
            )
        }
        try modelContext.save()

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "provider",
            entityId: providerId,
            action: "deleted",
            summary: "Deleted contact \(companyName)"
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    // MARK: - Pull & merge (AC-HOME-04 propagation, AC-HOME-05 delete wins)

    private func pullProviders(homeId: UUID) async throws {
        let rows: [ServiceProviderDTO] = try await auth.client
            .from("service_providers")
            .select()
            .eq("home_id", value: homeId.uuidString)
            .execute()
            .value

        mergeProviders(homeId: homeId, rows: rows)
        try modelContext.save()
    }

    private func mergeProviders(homeId: UUID, rows: [ServiceProviderDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedServiceProvider>(
            predicate: #Predicate<CachedServiceProvider> { $0.homeId == homeTarget }
        ))) ?? []

        let pendingDeletes = pendingDeleteIds()
        let incomingIds = Set(rows.map(\.id))

        for stale in existing where !incomingIds.contains(stale.id) {
            switch ProviderConflictResolver.resolveMissingFromServer(
                localPending: stale.sync == .pending,
                everSynced: stale.serverUpdatedAt != nil
            ) {
            case .keepPendingInsert:
                continue
            case .deleteWinsNotify:
                notifyEditRemoved(provider: stale, homeId: homeId)
                removeOutboxEntries(for: stale.id)
                modelContext.delete(stale)
            case .removeSilently:
                modelContext.delete(stale)
            }
        }

        for row in rows {
            if pendingDeletes.contains(row.id) { continue }
            if let cached = existing.first(where: { $0.id == row.id }) {
                if ProviderConflictResolver.shouldApplyServer(
                    localPending: cached.sync == .pending,
                    localUpdatedAt: cached.localUpdatedAt,
                    serverUpdatedAt: row.updatedAt
                ) {
                    if cached.sync == .pending {
                        removeOutboxEntries(for: cached.id)
                        syncEngine.postNotification(
                            OverwriteNotificationPolicy.message(for: .serviceProvider(name: row.companyName))
                        )
                    }
                    applyServer(row, to: cached)
                }
            } else {
                modelContext.insert(CachedServiceProvider(
                    id: row.id,
                    homeId: row.homeId,
                    companyName: row.companyName,
                    serviceType: row.serviceType,
                    accountNumber: row.accountNumber,
                    phone: row.phone,
                    website: row.website,
                    hours: row.hours,
                    notes: row.notes,
                    visibility: row.visibility,
                    syncStatus: .synced,
                    serverUpdatedAt: row.updatedAt
                ))
            }
        }
    }

    private func applyServer(_ row: ServiceProviderDTO, to cached: CachedServiceProvider) {
        cached.companyName = row.companyName
        cached.serviceType = row.serviceType
        cached.accountNumber = row.accountNumber
        cached.phone = row.phone
        cached.website = row.website
        cached.hours = row.hours
        cached.notes = row.notes
        cached.providerVisibility = row.visibility
        cached.serverUpdatedAt = row.updatedAt
        cached.sync = .synced
    }

    private func notifyEditRemoved(provider: CachedServiceProvider, homeId: UUID) {
        if let userId = auth.session?.user.id {
            activityLog.append(
                homeId: homeId,
                actorId: userId,
                entityType: "provider",
                entityId: provider.id,
                action: "conflict_resolved",
                summary: "Contact \(provider.companyName) was deleted; a pending edit was discarded"
            )
        }
        syncEngine.postNotification(
            "\(provider.companyName) was deleted by another member, so your edit was removed."
        )
    }

    // MARK: - Cache helpers

    private func cachedSummaries(homeId: UUID, userRole: HomeRole) -> [ServiceProviderSummary] {
        let homeTarget = homeId
        let providers = (try? modelContext.fetch(FetchDescriptor<CachedServiceProvider>(
            predicate: #Predicate<CachedServiceProvider> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.companyName)]
        ))) ?? []

        return providers.compactMap { provider in
            guard permissions.can(
                .read,
                entity: .serviceProvider(visibility: provider.providerVisibility),
                role: userRole
            ) else { return nil }

            return ServiceProviderSummary(
                id: provider.id,
                homeId: provider.homeId,
                companyName: provider.companyName,
                serviceType: provider.serviceType,
                accountNumber: provider.accountNumber,
                phone: provider.phone,
                website: provider.website,
                hours: provider.hours,
                notes: provider.notes,
                visibility: provider.providerVisibility
            )
        }
    }

    private func cachedProvider(_ providerId: UUID) -> CachedServiceProvider? {
        let target = providerId
        return try? modelContext.fetch(FetchDescriptor<CachedServiceProvider>(
            predicate: #Predicate<CachedServiceProvider> { $0.id == target }
        )).first
    }

    private func pendingDeleteIds() -> Set<UUID> {
        let entity = EntityType.serviceProvider.rawValue
        let deleteOp = OutboxOperation.delete.rawValue
        let entries = (try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>())) ?? []
        return Set(
            entries
                .filter { $0.entityType == entity && $0.operation == deleteOp }
                .map(\.entityId)
        )
    }

    private func removeOutboxEntries(for providerId: UUID) {
        let entity = EntityType.serviceProvider.rawValue
        guard let entries = try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>()) else { return }
        for entry in entries where entry.entityId == providerId && entry.entityType == entity {
            modelContext.delete(entry)
        }
    }
}

enum ProviderError: LocalizedError {
    case notAuthorized
    case notFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "You don't have permission to change contacts for this home."
        case .notFound: "Contact not found."
        }
    }
}

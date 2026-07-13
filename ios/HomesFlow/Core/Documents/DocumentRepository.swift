import Foundation
import SwiftData
import Supabase

// @covers FR-HOME-03, AC-GUEST-01, FR-GUEST-01

@MainActor
final class DocumentRepository: ObservableObject {
    private let modelContext: ModelContext
    private let auth: SupabaseClientProvider
    private let activityLog: ActivityLogService
    private let syncEngine: SyncEngine
    private let storage: DocumentStorageService
    private let permissions = PermissionService()

    init(
        modelContext: ModelContext,
        auth: SupabaseClientProvider,
        activityLog: ActivityLogService,
        syncEngine: SyncEngine,
        storage: DocumentStorageService
    ) {
        self.modelContext = modelContext
        self.auth = auth
        self.activityLog = activityLog
        self.syncEngine = syncEngine
        self.storage = storage
    }

    func fetchDocuments(homeId: UUID, userRole: HomeRole) async throws -> [DocumentSummary] {
        if NetworkMonitor.shared.isConnected {
            try await pullDocuments(homeId: homeId)
        }
        return cachedSummaries(homeId: homeId, userRole: userRole)
    }

    func documentAccessState(documentId: UUID, userRole: HomeRole) -> EntityAccessState {
        guard let document = cachedDocument(documentId) else { return .notFound }
        guard permissions.can(
            .read,
            entity: .document(visibility: document.documentVisibility),
            role: userRole
        ) else {
            return .accessDenied
        }
        return .allowed
    }

    func canManageDocuments(userRole: HomeRole) -> Bool {
        permissions.can(.create, entity: .document(visibility: .manager), role: userRole)
    }

    func signedURL(for documentId: UUID, userRole: HomeRole) async throws -> URL {
        guard let document = cachedDocument(documentId) else { throw DocumentError.notFound }
        guard permissions.can(
            .read,
            entity: .document(visibility: document.documentVisibility),
            role: userRole
        ) else {
            throw DocumentError.notAuthorized
        }
        guard let path = document.storagePath else { throw DocumentError.missingFile }
        return try await storage.signedURL(for: path)
    }

    func createDocument(
        homeId: UUID,
        draft: DocumentDraft,
        fileData: Data,
        fileName: String,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard draft.isValid else { return }
        guard !fileData.isEmpty else { throw DocumentError.missingFile }
        guard NetworkMonitor.shared.isConnected else { throw DocumentError.offlineUpload }
        guard permissions.can(
            .create,
            entity: .document(visibility: draft.visibility),
            role: userRole
        ) else {
            throw DocumentError.notAuthorized
        }

        let document = CachedDocument(
            homeId: homeId,
            title: draft.normalized(draft.title) ?? "",
            category: draft.normalized(draft.category),
            visibility: draft.visibility,
            syncStatus: .pending
        )
        let storagePath = try await storage.upload(
            homeId: homeId,
            documentId: document.id,
            fileName: fileName,
            data: fileData
        )
        document.storagePath = storagePath
        modelContext.insert(document)

        syncEngine.enqueue(
            entityType: .document,
            entityId: document.id,
            operation: .insert,
            payload: ["home_id": homeId.uuidString]
        )
        try modelContext.save()

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "document",
            entityId: document.id,
            action: "created",
            summary: "Added file \(document.title)"
        )

        _ = await syncEngine.run()
    }

    func deleteDocument(
        homeId: UUID,
        documentId: UUID,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard let cached = cachedDocument(documentId) else { throw DocumentError.notFound }
        guard permissions.can(
            .delete,
            entity: .document(visibility: cached.documentVisibility),
            role: userRole
        ) else {
            throw DocumentError.notAuthorized
        }

        let title = cached.title
        let storagePath = cached.storagePath
        let everSynced = cached.serverUpdatedAt != nil

        removeOutboxEntries(for: documentId)
        modelContext.delete(cached)

        if everSynced {
            syncEngine.enqueue(
                entityType: .document,
                entityId: documentId,
                operation: .delete,
                payload: [
                    "home_id": homeId.uuidString,
                    "storage_path": storagePath ?? ""
                ]
            )
        } else if let storagePath {
            try? await storage.delete(storagePath: storagePath)
        }
        try modelContext.save()

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "document",
            entityId: documentId,
            action: "deleted",
            summary: "Deleted file \(title)"
        )

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
        }
    }

    // MARK: - Pull & cache

    private func pullDocuments(homeId: UUID) async throws {
        let rows: [DocumentDTO] = try await auth.client
            .from("documents")
            .select()
            .eq("home_id", value: homeId.uuidString)
            .execute()
            .value

        mergeDocuments(homeId: homeId, rows: rows)
        try modelContext.save()
    }

    private func mergeDocuments(homeId: UUID, rows: [DocumentDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedDocument>(
            predicate: #Predicate<CachedDocument> { $0.homeId == homeTarget }
        ))) ?? []

        let serverIds = Set(rows.map(\.id))
        for local in existing where local.sync == .synced && !serverIds.contains(local.id) {
            modelContext.delete(local)
        }

        for row in rows {
            if let cached = existing.first(where: { $0.id == row.id }) {
                if cached.sync == .pending { continue }
                cached.title = row.title
                cached.category = row.category
                cached.storagePath = row.storagePath
                cached.documentVisibility = row.visibility
                cached.serverUpdatedAt = row.updatedAt
                cached.sync = .synced
            } else {
                modelContext.insert(CachedDocument(
                    id: row.id,
                    homeId: row.homeId,
                    title: row.title,
                    category: row.category,
                    storagePath: row.storagePath,
                    visibility: row.visibility,
                    syncStatus: .synced,
                    serverUpdatedAt: row.updatedAt
                ))
            }
        }
    }

    private func cachedSummaries(homeId: UUID, userRole: HomeRole) -> [DocumentSummary] {
        let homeTarget = homeId
        let documents = (try? modelContext.fetch(FetchDescriptor<CachedDocument>(
            predicate: #Predicate<CachedDocument> { $0.homeId == homeTarget },
            sortBy: [SortDescriptor(\.title)]
        ))) ?? []

        return documents.compactMap { doc in
            guard permissions.can(
                .read,
                entity: .document(visibility: doc.documentVisibility),
                role: userRole
            ) else {
                return nil
            }
            return DocumentSummary(
                id: doc.id,
                homeId: doc.homeId,
                title: doc.title,
                category: doc.category,
                storagePath: doc.storagePath,
                visibility: doc.documentVisibility
            )
        }
    }

    private func cachedDocument(_ id: UUID) -> CachedDocument? {
        let target = id
        return try? modelContext.fetch(FetchDescriptor<CachedDocument>(
            predicate: #Predicate<CachedDocument> { $0.id == target }
        )).first
    }

    private func removeOutboxEntries(for entityId: UUID) {
        let target = entityId
        let entries = (try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>(
            predicate: #Predicate<MutationOutboxEntry> { $0.entityId == target }
        ))) ?? []
        for entry in entries {
            modelContext.delete(entry)
        }
    }
}

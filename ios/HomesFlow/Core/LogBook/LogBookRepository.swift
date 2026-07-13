import Foundation
import SwiftData
import Supabase

// @covers FR-LOG-02, AC-LOG-01, AC-LOG-02, AC-LOG-03, AC-LOG-04, AC-LOG-06

enum LogBookError: LocalizedError {
    case notAuthorized
    case notFound
    case emptyBody
    case editWindowClosed

    var errorDescription: String? {
        switch self {
        case .notAuthorized: "You don't have permission to view the Communications Log."
        case .notFound: "Log entry not found."
        case .emptyBody: "Write something before saving."
        case .editWindowClosed: "This entry can no longer be edited."
        }
    }
}

@MainActor
final class LogBookRepository: ObservableObject {
    private let modelContext: ModelContext
    private let auth: SupabaseClientProvider
    private let syncEngine: SyncEngine
    private let permissions = PermissionService()

    init(
        modelContext: ModelContext,
        auth: SupabaseClientProvider,
        syncEngine: SyncEngine
    ) {
        self.modelContext = modelContext
        self.auth = auth
        self.syncEngine = syncEngine
    }

    func canAccessLogBook(userRole: HomeRole) -> Bool {
        permissions.can(.read, entity: .logBook, role: userRole)
    }

    func fetchEntries(
        homeId: UUID,
        userRole: HomeRole,
        scope: LogBookScopeFilter = .all,
        procedureId: UUID? = nil
    ) async throws -> [LogBookEntrySummary] {
        guard permissions.can(.read, entity: .logBook, role: userRole) else {
            throw LogBookError.notAuthorized
        }

        if NetworkMonitor.shared.isConnected {
            try await pullEntries(homeId: homeId)
        }

        let cached = cachedSummaries(homeId: homeId)
        return LogBookEntryOrganizer.chronological(
            LogBookEntryOrganizer.filtered(cached, scope: scope, procedureId: procedureId)
        )
    }

    func createEntry(
        homeId: UUID,
        procedureId: UUID?,
        procedureTitle: String?,
        body: String,
        userRole: HomeRole
    ) async throws -> LogBookEntrySummary {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard permissions.can(.create, entity: .logBook, role: userRole) else {
            throw LogBookError.notAuthorized
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LogBookError.emptyBody }

        let authorLabel = auth.session?.user.email ?? "You"
        let entry = CachedLogBookEntry(
            homeId: homeId,
            procedureId: procedureId,
            authorId: userId,
            authorLabel: authorLabel,
            body: trimmed,
            createdAt: .now,
            procedureTitle: procedureTitle,
            syncStatus: .pending
        )
        modelContext.insert(entry)

        var payload: [String: String] = ["home_id": homeId.uuidString]
        if let procedureId {
            payload["procedure_id"] = procedureId.uuidString
        }

        syncEngine.enqueue(
            entityType: .logBookEntry,
            entityId: entry.id,
            operation: .insert,
            payload: payload
        )
        try modelContext.save()

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
            try await pullEntries(homeId: homeId)
        }

        return summary(from: entry)
    }

    func updateEntry(
        homeId: UUID,
        entryId: UUID,
        body: String,
        userRole: HomeRole
    ) async throws {
        guard let userId = auth.session?.user.id else { throw AuthError.notSignedIn }
        guard permissions.can(.update, entity: .logBook, role: userRole) else {
            throw LogBookError.notAuthorized
        }

        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LogBookError.emptyBody }

        guard let cached = cachedEntry(entryId) else { throw LogBookError.notFound }
        guard cached.authorId == userId else { throw LogBookError.notAuthorized }
        guard LogBookGraceWindowPolicy.canEdit(
            isAuthor: true,
            receivedAt: cached.receivedAt
        ) else {
            throw LogBookError.editWindowClosed
        }

        cached.body = trimmed
        cached.editedAt = .now
        cached.sync = .pending

        syncEngine.enqueue(
            entityType: .logBookEntry,
            entityId: entryId,
            operation: .update,
            payload: ["home_id": homeId.uuidString]
        )
        try modelContext.save()

        if NetworkMonitor.shared.isConnected {
            _ = await syncEngine.run()
            try await pullEntries(homeId: homeId)
        }
    }

    func pullEntries(homeId: UUID) async throws {
        let rows: [LogBookEntryDTO] = try await auth.client
            .from("log_book_entries")
            .select("*, profiles(display_name, email)")
            .eq("home_id", value: homeId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value

        mergeEntries(homeId: homeId, rows: rows)
        try modelContext.save()
    }

    private func mergeEntries(homeId: UUID, rows: [LogBookEntryDTO]) {
        let homeTarget = homeId
        let existing = (try? modelContext.fetch(FetchDescriptor<CachedLogBookEntry>(
            predicate: #Predicate<CachedLogBookEntry> { $0.homeId == homeTarget }
        ))) ?? []

        let existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let incomingIds = Set(rows.map(\.id))

        for stale in existing where !incomingIds.contains(stale.id) && stale.sync == .synced {
            modelContext.delete(stale)
        }

        for row in rows {
            if let cached = existingById[row.id] {
                applyServer(row, to: cached)
                cached.sync = .synced
                removeOutboxEntries(for: row.id)
            } else {
                modelContext.insert(entry(from: row))
            }
        }
    }

    private func removeOutboxEntries(for entryId: UUID) {
        let entity = EntityType.logBookEntry.rawValue
        let targetId = entryId
        guard let entries = try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>(
            predicate: #Predicate<MutationOutboxEntry> { $0.entityId == targetId }
        )) else { return }
        for entry in entries where entry.entityType == entity {
            modelContext.delete(entry)
        }
    }

    private func applyServer(_ row: LogBookEntryDTO, to cached: CachedLogBookEntry) {
        cached.body = row.body
        cached.procedureId = row.procedureId
        cached.authorId = row.authorId
        cached.authorLabel = row.profiles?.displayName
            ?? row.profiles?.email
            ?? cached.authorLabel
        cached.createdAt = row.createdAt
        cached.receivedAt = row.receivedAt
        cached.editedAt = row.editedAt
        cached.sync = .synced
    }

    private func entry(from row: LogBookEntryDTO) -> CachedLogBookEntry {
        CachedLogBookEntry(
            id: row.id,
            homeId: row.homeId,
            procedureId: row.procedureId,
            authorId: row.authorId,
            authorLabel: row.profiles?.displayName ?? row.profiles?.email ?? "Member",
            body: row.body,
            createdAt: row.createdAt,
            receivedAt: row.receivedAt,
            editedAt: row.editedAt,
            syncStatus: .synced
        )
    }

    private func cachedSummaries(homeId: UUID) -> [LogBookEntrySummary] {
        let homeTarget = homeId
        let entries = (try? modelContext.fetch(FetchDescriptor<CachedLogBookEntry>(
            predicate: #Predicate<CachedLogBookEntry> { $0.homeId == homeTarget }
        ))) ?? []
        return entries.map(summary(from:))
    }

    private func cachedEntry(_ entryId: UUID) -> CachedLogBookEntry? {
        let target = entryId
        return try? modelContext.fetch(FetchDescriptor<CachedLogBookEntry>(
            predicate: #Predicate<CachedLogBookEntry> { $0.id == target }
        )).first
    }

    private func summary(from cached: CachedLogBookEntry) -> LogBookEntrySummary {
        LogBookEntrySummary(
            id: cached.id,
            homeId: cached.homeId,
            procedureId: cached.procedureId,
            authorId: cached.authorId,
            authorLabel: cached.authorLabel,
            body: cached.body,
            createdAt: cached.createdAt,
            receivedAt: cached.receivedAt,
            editedAt: cached.editedAt,
            procedureTitle: cached.procedureTitle
        )
    }

    func attachProcedureTitle(_ title: String, procedureId: UUID) {
        let target = procedureId
        guard let entries = try? modelContext.fetch(FetchDescriptor<CachedLogBookEntry>(
            predicate: #Predicate<CachedLogBookEntry> { $0.procedureId == target }
        )) else { return }
        for entry in entries where entry.procedureTitle == nil {
            entry.procedureTitle = title
        }
        try? modelContext.save()
    }
}

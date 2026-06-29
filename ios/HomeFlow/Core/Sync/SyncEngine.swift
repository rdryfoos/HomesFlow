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

    func run() async {
        await pushOutbox()
        await pullChanges()
    }

    private func pushOutbox() async {
        let descriptor = FetchDescriptor<MutationOutboxEntry>(
            sortBy: [SortDescriptor(\.clientUpdatedAt)]
        )
        guard let entries = try? modelContext.fetch(descriptor) else { return }

        for entry in entries {
            guard entry.entity == .home, entry.op != .delete else {
                modelContext.delete(entry)
                continue
            }

            do {
                switch entry.op {
                case .insert, .update:
                    try await pushHome(entry)
                case .delete:
                    break
                case .none:
                    break
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

    private func pullChanges() async {
        // Phase 0: pull hook — full entity sync in Phase 1+
    }

    private func revertPermissionDenied(entry: MutationOutboxEntry, message: String?) {
        let targetId = entry.entityId
        if let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first {
            home.sync = .synced
        }
        modelContext.delete(entry)
        try? modelContext.save()
        lastNotification = SyncNotification(
            message: message ?? "You no longer have permission for that change. It was reverted."
        )
    }
}

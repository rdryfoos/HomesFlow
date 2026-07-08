import Foundation
import SwiftData

// @covers NFR-SEC-01, FR-AUTH-01

enum LocalDataStore {
    static func purgeAll(modelContext: ModelContext) {
        deleteAll(CachedLogBookEntry.self, in: modelContext)
        deleteAll(CachedActivityLogEntry.self, in: modelContext)
        deleteAll(MutationOutboxEntry.self, in: modelContext)
        deleteAll(CachedProcedureStep.self, in: modelContext)
        deleteAll(CachedProcedure.self, in: modelContext)
        deleteAll(CachedDocument.self, in: modelContext)
        deleteAll(CachedServiceProvider.self, in: modelContext)
        deleteAll(CachedInvite.self, in: modelContext)
        deleteAll(CachedMembership.self, in: modelContext)
        deleteAll(CachedHome.self, in: modelContext)
        try? modelContext.save()
    }

    static func purgeHome(_ homeId: UUID, modelContext: ModelContext) {
        let homeTarget = homeId

        let procedures = (try? modelContext.fetch(FetchDescriptor<CachedProcedure>(
            predicate: #Predicate<CachedProcedure> { $0.homeId == homeTarget }
        ))) ?? []
        for procedure in procedures {
            let procedureTarget = procedure.id
            let steps = (try? modelContext.fetch(FetchDescriptor<CachedProcedureStep>(
                predicate: #Predicate<CachedProcedureStep> { $0.procedureId == procedureTarget }
            ))) ?? []
            steps.forEach { modelContext.delete($0) }
            modelContext.delete(procedure)
        }

        deleteMemberships(homeId: homeTarget, in: modelContext)
        deleteInvites(homeId: homeTarget, in: modelContext)
        deleteProviders(homeId: homeTarget, in: modelContext)
        deleteDocuments(homeId: homeTarget, in: modelContext)
        deleteActivityLog(homeId: homeTarget, in: modelContext)
        deleteLogBookEntries(homeId: homeTarget, in: modelContext)

        if let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == homeTarget }
        )).first {
            modelContext.delete(home)
        }

        removeOutbox(forHomeId: homeTarget, in: modelContext)
        try? modelContext.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in modelContext: ModelContext) {
        guard let rows = try? modelContext.fetch(FetchDescriptor<T>()) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func deleteMemberships(homeId: UUID, in modelContext: ModelContext) {
        let homeTarget = homeId
        guard let rows = try? modelContext.fetch(FetchDescriptor<CachedMembership>(
            predicate: #Predicate<CachedMembership> { $0.homeId == homeTarget }
        )) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func deleteInvites(homeId: UUID, in modelContext: ModelContext) {
        let homeTarget = homeId
        guard let rows = try? modelContext.fetch(FetchDescriptor<CachedInvite>(
            predicate: #Predicate<CachedInvite> { $0.homeId == homeTarget }
        )) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func deleteProviders(homeId: UUID, in modelContext: ModelContext) {
        let homeTarget = homeId
        guard let rows = try? modelContext.fetch(FetchDescriptor<CachedServiceProvider>(
            predicate: #Predicate<CachedServiceProvider> { $0.homeId == homeTarget }
        )) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func deleteDocuments(homeId: UUID, in modelContext: ModelContext) {
        let homeTarget = homeId
        guard let rows = try? modelContext.fetch(FetchDescriptor<CachedDocument>(
            predicate: #Predicate<CachedDocument> { $0.homeId == homeTarget }
        )) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func deleteActivityLog(homeId: UUID, in modelContext: ModelContext) {
        let homeTarget = homeId
        guard let rows = try? modelContext.fetch(FetchDescriptor<CachedActivityLogEntry>(
            predicate: #Predicate<CachedActivityLogEntry> { $0.homeId == homeTarget }
        )) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func deleteLogBookEntries(homeId: UUID, in modelContext: ModelContext) {
        let homeTarget = homeId
        guard let rows = try? modelContext.fetch(FetchDescriptor<CachedLogBookEntry>(
            predicate: #Predicate<CachedLogBookEntry> { $0.homeId == homeTarget }
        )) else { return }
        rows.forEach { modelContext.delete($0) }
    }

    private static func removeOutbox(forHomeId homeId: UUID, in modelContext: ModelContext) {
        guard let entries = try? modelContext.fetch(FetchDescriptor<MutationOutboxEntry>()) else { return }
        let homeTarget = homeId
        for entry in entries {
            if entry.entity == .home, entry.entityId == homeTarget {
                modelContext.delete(entry)
                continue
            }
            if entry.payload["home_id"] == homeTarget.uuidString {
                modelContext.delete(entry)
            }
        }
    }
}

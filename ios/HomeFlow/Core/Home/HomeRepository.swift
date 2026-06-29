import Foundation
import SwiftData
import Supabase

// @covers FR-HOME-01, AC-HOME-01, AC-HOME-02

@MainActor
final class HomeRepository: ObservableObject {
    private let modelContext: ModelContext
    private let auth: SupabaseClientProvider
    private let syncEngine: SyncEngine
    private let activityLog: ActivityLogService
    private let homePhotoService: HomePhotoService

    init(
        modelContext: ModelContext,
        auth: SupabaseClientProvider,
        syncEngine: SyncEngine,
        activityLog: ActivityLogService,
        homePhotoService: HomePhotoService
    ) {
        self.modelContext = modelContext
        self.auth = auth
        self.syncEngine = syncEngine
        self.activityLog = activityLog
        self.homePhotoService = homePhotoService
    }

    func fetchHomes() async throws -> [HomeSummary] {
        if NetworkMonitor.shared.isConnected {
            await syncEngine.run()
        }
        let descriptor = FetchDescriptor<CachedHome>(sortBy: [SortDescriptor(\.name)])
        let cached = try modelContext.fetch(descriptor)
        return cached.map(summary(from:))
    }

    func createHome(name: String, streetAddress: String, photoData: Data? = nil) async throws -> HomeSummary {
        switch HomeValidator.validate(name: name, streetAddress: streetAddress) {
        case .failure(let error):
            throw error
        case .success:
            break
        }

        guard let userId = auth.session?.user.id else {
            throw AuthError.notSignedIn
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = streetAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let homeId = UUID()

        let home = CachedHome(
            id: homeId,
            name: trimmedName,
            streetAddress: trimmedAddress,
            createdBy: userId,
            syncStatus: .pending
        )
        modelContext.insert(home)
        syncEngine.enqueue(entityType: .home, entityId: homeId, operation: .insert)
        try modelContext.save()

        if let photoData {
            try await attachPhoto(homeId: homeId, photoData: photoData, actorId: userId)
        }

        if NetworkMonitor.shared.isConnected {
            await syncEngine.run()
        }

        activityLog.append(
            homeId: homeId,
            actorId: userId,
            entityType: "home",
            entityId: homeId,
            action: "created",
            summary: "Created home \(trimmedName)"
        )

        return summary(from: home)
    }

    /// @covers AC-HOME-03
    func updateHome(
        id: UUID,
        name: String,
        streetAddress: String,
        photoData: Data? = nil
    ) async throws -> HomeSummary {
        switch HomeValidator.validate(name: name, streetAddress: streetAddress) {
        case .failure(let error):
            throw error
        case .success:
            break
        }

        guard let userId = auth.session?.user.id else {
            throw AuthError.notSignedIn
        }

        let targetId = id
        guard let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first else {
            throw HomeEditError.notFound
        }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = streetAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        home.name = trimmedName
        home.streetAddress = trimmedAddress
        home.localUpdatedAt = .now
        home.sync = .pending
        syncEngine.enqueue(entityType: .home, entityId: id, operation: .update)
        try modelContext.save()

        if let photoData {
            try await attachPhoto(homeId: id, photoData: photoData, actorId: userId)
        }

        if NetworkMonitor.shared.isConnected {
            await syncEngine.run()
        }

        activityLog.append(
            homeId: id,
            actorId: userId,
            entityType: "home",
            entityId: id,
            action: "updated",
            summary: "Updated home \(trimmedName)"
        )

        return summary(from: home)
    }

    func signedPhotoURL(for home: HomeSummary) async throws -> URL? {
        guard let path = home.photoURL else { return nil }
        return try await homePhotoService.signedURL(for: path)
    }

    func home(for id: UUID) -> HomeSummary? {
        let targetId = id
        guard let cached = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first else { return nil }
        return summary(from: cached)
    }

    private func attachPhoto(homeId: UUID, photoData: Data, actorId: UUID) async throws {
        let targetId = homeId
        guard let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first else {
            throw HomeEditError.notFound
        }

        let path = try await homePhotoService.uploadPhoto(homeId: homeId, imageData: photoData)
        home.photoURL = path
        home.localUpdatedAt = .now
        home.sync = .pending
        syncEngine.enqueue(entityType: .home, entityId: homeId, operation: .update)
        try modelContext.save()
    }

    private func summary(from cached: CachedHome) -> HomeSummary {
        HomeSummary(
            id: cached.id,
            name: cached.name,
            streetAddress: cached.streetAddress,
            photoURL: cached.photoURL
        )
    }
}

enum AuthError: LocalizedError {
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You must be signed in."
        }
    }
}

enum HomeEditError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound: "Home not found."
        }
    }
}

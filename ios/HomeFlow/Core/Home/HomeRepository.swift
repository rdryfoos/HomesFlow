import Foundation
import SwiftData
import Supabase
import UIKit

// @covers FR-HOME-01, AC-HOME-01, AC-HOME-02, AC-HOME-08

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
        let homes = cached.map(summary(from:))
        homePhotoService.prefetch(storagePaths: homes.compactMap(\.photoURL))
        return homes
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

        try await syncHomeToServer(homeId: homeId, requiredForPhoto: photoData != nil)

        if let photoData {
            try await attachPhoto(homeId: homeId, photoData: photoData, actorId: userId)
            try await syncHomeToServer(homeId: homeId, requiredForPhoto: false)
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

        try await syncHomeToServer(homeId: id, requiredForPhoto: photoData != nil)

        if let photoData {
            try await attachPhoto(homeId: id, photoData: photoData, actorId: userId)
            try await syncHomeToServer(homeId: id, requiredForPhoto: false)
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

    func cachedPhoto(for storagePath: String) -> UIImage? {
        homePhotoService.cachedImage(storagePath: storagePath)
    }

    func loadPhoto(storagePath: String) async throws -> UIImage {
        try await homePhotoService.loadImage(storagePath: storagePath)
    }

    func home(for id: UUID) -> HomeSummary? {
        let targetId = id
        guard let cached = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first else { return nil }
        return summary(from: cached)
    }

    private func syncHomeToServer(homeId: UUID, requiredForPhoto: Bool) async throws {
        // AC-HOME-08: gating rules live in HomePhotoSyncGate (unit tested).
        let decision = try HomePhotoSyncGate.preSync(
            isConnected: NetworkMonitor.shared.isConnected,
            requiredForPhoto: requiredForPhoto
        )
        guard decision == .runSync else { return }

        if let message = await syncEngine.run() {
            throw HomeSyncError.failed(message)
        }

        try HomePhotoSyncGate.postSync(isHomeSynced: syncEngine.isHomeSynced(homeId))
    }

    private func attachPhoto(homeId: UUID, photoData: Data, actorId: UUID) async throws {
        let targetId = homeId
        guard let home = try? modelContext.fetch(FetchDescriptor<CachedHome>(
            predicate: #Predicate<CachedHome> { $0.id == targetId }
        )).first else {
            throw HomeEditError.notFound
        }

        do {
            let path = try await homePhotoService.uploadPhoto(homeId: homeId, imageData: photoData)
            home.photoURL = path
            home.localUpdatedAt = .now
            home.sync = .pending
            syncEngine.enqueue(entityType: .home, entityId: homeId, operation: .update)
            try modelContext.save()
        } catch {
            throw HomeSyncError.photoUploadFailed(error.localizedDescription)
        }
    }

    private func summary(from cached: CachedHome) -> HomeSummary {
        let userId = auth.session?.user.id
        let homeId = cached.id
        let currentUserRole = currentUserRole(for: homeId, createdBy: cached.createdBy, userId: userId)

        return HomeSummary(
            id: cached.id,
            name: cached.name,
            streetAddress: cached.streetAddress,
            photoURL: cached.photoURL,
            isPendingSync: cached.sync == .pending,
            currentUserRole: currentUserRole
        )
    }

    private func currentUserRole(for homeId: UUID, createdBy: UUID, userId: UUID?) -> HomeRole? {
        guard let userId else { return nil }

        let targetHomeId = homeId
        let targetUserId = userId
        if let membership = try? modelContext.fetch(FetchDescriptor<CachedMembership>(
            predicate: #Predicate<CachedMembership> {
                $0.homeId == targetHomeId && $0.userId == targetUserId
            }
        )).first {
            return membership.homeRole
        }

        if createdBy == userId {
            return .owner
        }

        return nil
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

enum HomeSyncError: LocalizedError {
    case offline
    case notSynced
    case failed(String)
    case photoUploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            "You're offline. Connect to the internet before uploading a photo."
        case .notSynced:
            "This home hasn't synced to Supabase yet. Pull to refresh on the dashboard, confirm Supabase is running (`supabase status`), then try again."
        case .failed(let message):
            message
        case .photoUploadFailed(let message):
            "Photo upload failed: \(message)"
        }
    }
}

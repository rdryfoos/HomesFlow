import Foundation

// @covers AC-HOME-08

/// Pure gating rules for syncing a home before photo upload (AC-HOME-08):
/// photo uploads require connectivity and a server-synced home; plain edits
/// may defer sync while offline.
enum HomePhotoSyncGate {
    enum PreSync: Equatable {
        /// Offline with no photo pending — safe to defer sync to a later pass.
        case deferSync
        /// Connected — run the sync engine before continuing.
        case runSync
    }

    static func preSync(isConnected: Bool, requiredForPhoto: Bool) throws -> PreSync {
        guard isConnected else {
            if requiredForPhoto {
                throw HomeSyncError.offline
            }
            return .deferSync
        }
        return .runSync
    }

    static func postSync(isHomeSynced: Bool) throws {
        guard isHomeSynced else {
            throw HomeSyncError.notSynced
        }
    }
}

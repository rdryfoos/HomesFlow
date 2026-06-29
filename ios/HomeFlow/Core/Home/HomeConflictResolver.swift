import Foundation

// @covers AC-HOME-03

enum HomeConflictResolver {
    /// Returns true when server data should overwrite local pending edits.
    static func shouldApplyServer(
        localPending: Bool,
        localUpdatedAt: Date,
        serverUpdatedAt: Date?
    ) -> Bool {
        guard localPending else { return true }
        guard let serverUpdatedAt else { return false }
        return serverUpdatedAt > localUpdatedAt
    }
}

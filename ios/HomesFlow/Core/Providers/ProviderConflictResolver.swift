import Foundation

// @covers AC-HOME-04, AC-HOME-05, AC-SYNC-01

/// What to do with a locally cached provider that no longer exists on the server.
enum ProviderMissingOutcome: Equatable {
    /// Row was created locally and never pushed — keep it for the next push.
    case keepPendingInsert
    /// Row was deleted on the server while a local edit was pending —
    /// delete wins; discard the edit and notify the editor (AC-HOME-05).
    case deleteWinsNotify
    /// Row was deleted on the server and there is no local edit — remove silently.
    case removeSilently
}

enum ProviderConflictResolver {
    /// Server edit vs local state: returns true when the server row should
    /// overwrite the local copy, so edits propagate to permitted users
    /// (AC-HOME-04). Timestamp-wins for pending local edits (AC-SYNC-01).
    static func shouldApplyServer(
        localPending: Bool,
        localUpdatedAt: Date,
        serverUpdatedAt: Date?
    ) -> Bool {
        HomeConflictResolver.shouldApplyServer(
            localPending: localPending,
            localUpdatedAt: localUpdatedAt,
            serverUpdatedAt: serverUpdatedAt
        )
    }

    /// Local row is absent from the server pull. The server delete is by
    /// definition the most recent action we know about, so it wins over any
    /// pending local edit (AC-HOME-05).
    static func resolveMissingFromServer(
        localPending: Bool,
        everSynced: Bool
    ) -> ProviderMissingOutcome {
        if !everSynced { return .keepPendingInsert }
        return localPending ? .deleteWinsNotify : .removeSilently
    }
}

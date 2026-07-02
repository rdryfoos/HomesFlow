import Foundation

// @covers AC-SYNC-03

/// What to do with the local cached row when the server rejects a queued
/// mutation for insufficient permission.
enum PermissionRevertAction: Equatable {
    /// Row only ever existed locally (rejected insert) — remove it entirely.
    case discardLocal
    /// Row exists on the server — keep the server's version and clear the
    /// pending flag so the stale local edit stops re-sending.
    case markSynced
}

enum PermissionRevertPolicy {
    static func action(for op: OutboxOperation?) -> PermissionRevertAction {
        op == .insert ? .discardLocal : .markSynced
    }
}

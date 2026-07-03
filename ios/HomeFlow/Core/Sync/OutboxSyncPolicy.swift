import Foundation

// @covers AC-SYNC-01, AC-HOME-03

/// AC-SYNC-01 / AC-HOME-03: queued local edits must not blindly overwrite a
/// newer server row — pull (or pre-push fetch) first, then push only when
/// the pending edit still wins on timestamp.
enum OutboxSyncPolicy {
    static func shouldPushPendingUpdate(localUpdatedAt: Date, serverUpdatedAt: Date?) -> Bool {
        !OverwriteNotificationPolicy.shouldNotifyLoser(
            localPending: true,
            localUpdatedAt: localUpdatedAt,
            serverUpdatedAt: serverUpdatedAt
        )
    }
}

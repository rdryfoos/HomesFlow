import Foundation

// @covers AC-SYNC-01

/// AC-SYNC-01: when timestamp-wins resolution keeps the server copy over a
/// pending offline edit, the losing user receives an in-app notification.
enum OverwriteNotificationPolicy {

    enum EntityLabel: Equatable, Sendable {
        case home(name: String)
        case procedureStep(title: String)
        case serviceProvider(name: String)
    }

    /// Notify only when the device had a queued offline edit that lost to a
    /// newer server timestamp.
    static func shouldNotifyLoser(
        localPending: Bool,
        localUpdatedAt: Date,
        serverUpdatedAt: Date?
    ) -> Bool {
        guard localPending else { return false }
        return HomeConflictResolver.shouldApplyServer(
            localPending: true,
            localUpdatedAt: localUpdatedAt,
            serverUpdatedAt: serverUpdatedAt
        )
    }

    static func message(for entity: EntityLabel) -> String {
        switch entity {
        case .home(let name):
            "Your offline edit to \(name) was overwritten by a newer update."
        case .procedureStep(let title):
            "Your offline change to \"\(title)\" was overwritten by a newer update."
        case .serviceProvider(let name):
            "Your offline edit to \(name) was overwritten by a newer update."
        }
    }
}

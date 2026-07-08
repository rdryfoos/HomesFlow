import Foundation

// @covers NFR-SEC-01, FR-USER-01

/// Client-side gate: only homes the signed-in user may see on the dashboard.
enum HomeAccessPolicy {
    static func authorizedHomes(
        from homes: [CachedHome],
        memberships: [CachedMembership],
        userId: UUID?,
        serverHomeIds: Set<UUID> = []
    ) -> [CachedHome] {
        guard let userId else { return [] }
        let memberHomeIds = Set(
            memberships
                .filter { $0.userId == userId }
                .map(\.homeId)
        )
        return homes.filter { home in
            memberHomeIds.contains(home.id)
                || serverHomeIds.contains(home.id)
                || (home.createdBy == userId && home.sync == .pending)
        }
    }
}

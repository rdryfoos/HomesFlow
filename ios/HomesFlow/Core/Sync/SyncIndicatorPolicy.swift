import Foundation

// @covers AC-SYNC-04

/// AC-SYNC-04: pending-sync homes are visibly indicated on the dashboard
/// (banner + per-card badge) and the user can pull to refresh while online.
enum SyncIndicatorPolicy {

    /// Dashboard shows one banner when any home hasn't reached the server.
    static func showsPendingBanner(homes: [HomeSummary]) -> Bool {
        homes.contains(where: \.isPendingSync)
    }

    /// Each unsynced home's hero card carries a badge.
    static func showsBadge(for home: HomeSummary) -> Bool {
        home.isPendingSync
    }

    /// VoiceOver users hear the pending state on the hero card (AC-A11Y-02
    /// adjacent: state is announced, not color-only).
    static func accessibilityLabel(for home: HomeSummary) -> String {
        var parts = [home.name, home.locationLabel]
        if home.isPendingSync {
            parts.append("Not synced")
        }
        return parts.joined(separator: ", ")
    }
}

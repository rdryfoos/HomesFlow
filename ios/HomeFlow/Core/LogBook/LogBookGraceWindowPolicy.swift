import Foundation

// @covers AC-LOG-04, FR-LOG-02

enum LogBookGraceWindowPolicy {
    static let graceDuration: TimeInterval = 10 * 60

    /// Whether the author may edit an entry. Unsynced entries (no `receivedAt` yet)
    /// remain editable locally until first server receipt starts the grace window.
    static func canEdit(
        isAuthor: Bool,
        receivedAt: Date?,
        now: Date = .now
    ) -> Bool {
        guard isAuthor else { return false }
        guard let receivedAt else { return true }
        return now <= receivedAt.addingTimeInterval(graceDuration)
    }
}

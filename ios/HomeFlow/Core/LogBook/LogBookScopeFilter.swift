import Foundation

// @covers AC-LOG-05, FR-LOG-02

enum LogBookScopeFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case household = "Household"
    case procedure = "Procedure"

    var id: String { rawValue }

    func matches(procedureId: UUID?) -> Bool {
        switch self {
        case .all:
            return true
        case .household:
            return procedureId == nil
        case .procedure:
            return procedureId != nil
        }
    }
}

enum LogBookEntryOrganizer {
    /// AC-LOG-05 / occurrence-time ordering (newest first for feed display).
    static func chronological(_ entries: [LogBookEntrySummary]) -> [LogBookEntrySummary] {
        entries.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }

    static func filtered(
        _ entries: [LogBookEntrySummary],
        scope: LogBookScopeFilter,
        procedureId: UUID? = nil
    ) -> [LogBookEntrySummary] {
        entries.filter { entry in
            guard scope.matches(procedureId: entry.procedureId) else { return false }
            if let procedureId {
                return entry.procedureId == procedureId
            }
            return true
        }
    }
}

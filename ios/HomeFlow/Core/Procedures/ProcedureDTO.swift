import Foundation

// @covers FR-PROC-01, FR-PROC-02

struct ProcedureDTO: Codable, Sendable {
    let id: UUID
    let homeId: UUID
    let title: String
    let category: String?
    let description: String?
    let status: ProcedureStatus
    let visibility: Visibility
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, category, description, status, visibility
        case homeId = "home_id"
        case updatedAt = "updated_at"
    }
}

struct ProcedureStepDTO: Codable, Sendable {
    let id: UUID
    let procedureId: UUID
    let sortOrder: Int
    let title: String
    let status: StepStatus
    let notes: String?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, status, notes
        case procedureId = "procedure_id"
        case sortOrder = "sort_order"
        case updatedAt = "updated_at"
    }
}

struct ProcedureSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let homeId: UUID
    let title: String
    let category: String?
    let status: ProcedureStatus
    let visibility: Visibility
    let completedSteps: Int
    let totalSteps: Int

    var progressLabel: String {
        guard totalSteps > 0 else { return "No steps" }
        return "\(completedSteps)/\(totalSteps)"
    }
}

struct ProcedureDetail: Identifiable, Sendable {
    let id: UUID
    let homeId: UUID
    let title: String
    let category: String?
    let description: String?
    let status: ProcedureStatus
    let visibility: Visibility
    let steps: [ProcedureStepSummary]
}

struct ProcedureStepSummary: Identifiable, Sendable, Hashable {
    let id: UUID
    let procedureId: UUID
    let sortOrder: Int
    let title: String
    let status: StepStatus
    let notes: String?
}

enum StepMoveDirection: Sendable {
    case up
    case down
}

enum StepStructureAction: String, Sendable {
    case created = "step_created"
    case renamed = "step_renamed"
    case deleted = "step_deleted"
    case reordered = "step_reordered"
}

/// Pure helpers for step structure changes (create, rename, reorder, delete).
/// @covers AC-PROC-05, AC-PROC-06
enum StepStructure {
    /// New steps append at the end of the list.
    static func nextSortOrder(existing: [Int]) -> Int {
        (existing.max() ?? 0) + 1
    }

    /// Returns the neighbor a step swaps sort order with, or nil at a boundary.
    static func swapTarget(
        for stepId: UUID,
        direction: StepMoveDirection,
        in steps: [ProcedureStepSummary]
    ) -> ProcedureStepSummary? {
        let ordered = steps.sorted { $0.sortOrder < $1.sortOrder }
        guard let index = ordered.firstIndex(where: { $0.id == stepId }) else { return nil }
        switch direction {
        case .up:
            return index > 0 ? ordered[index - 1] : nil
        case .down:
            return index < ordered.count - 1 ? ordered[index + 1] : nil
        }
    }

    static func activitySummary(
        action: StepStructureAction,
        stepTitle: String,
        procedureTitle: String
    ) -> String {
        switch action {
        case .created: "Added step \"\(stepTitle)\" to \(procedureTitle)"
        case .renamed: "Renamed step to \"\(stepTitle)\" in \(procedureTitle)"
        case .deleted: "Deleted step \"\(stepTitle)\" from \(procedureTitle)"
        case .reordered: "Moved step \"\(stepTitle)\" in \(procedureTitle)"
        }
    }
}

enum ProcedureAggregator {
    static func completedCount(for steps: [ProcedureStepSummary]) -> Int {
        steps.filter { $0.status == .complete || $0.status == .na }.count
    }

    static func aggregateStatus(for steps: [ProcedureStepSummary]) -> ProcedureStatus {
        guard !steps.isEmpty else { return .notStarted }
        if steps.allSatisfy({ $0.status == .na }) { return .na }
        if steps.allSatisfy({ $0.status == .complete || $0.status == .na }) { return .complete }
        if steps.contains(where: { $0.status == .inProgress }) { return .inProgress }
        if steps.contains(where: { $0.status == .complete || $0.status == .na }) { return .inProgress }
        return .notStarted
    }
}

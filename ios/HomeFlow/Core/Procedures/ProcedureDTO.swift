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

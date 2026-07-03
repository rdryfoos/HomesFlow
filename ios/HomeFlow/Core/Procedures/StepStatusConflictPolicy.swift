import Foundation

// @covers AC-SYNC-05

/// AC-SYNC-05: Complete and N/A are terminal — sync must never silently
/// regress them when a concurrent update would change the step's status.
enum StepStatusConflictPolicy {

    static func isTerminal(_ status: StepStatus) -> Bool {
        status == .complete || status == .na
    }

    /// True when applying `serverStatus` over `localStatus` would change away
    /// from a locally held terminal status.
    static func wouldRegressTerminal(localStatus: StepStatus, serverStatus: StepStatus) -> Bool {
        isTerminal(localStatus) && localStatus != serverStatus
    }

    /// Timestamp-wins merge is allowed only when it would not regress a local
    /// terminal status (AC-SYNC-05 takes precedence over AC-SYNC-01).
    static func shouldApplyServerStep(
        localStatus: StepStatus,
        localPending: Bool,
        localUpdatedAt: Date,
        serverStatus: StepStatus,
        serverUpdatedAt: Date?
    ) -> Bool {
        if wouldRegressTerminal(localStatus: localStatus, serverStatus: serverStatus) {
            return false
        }
        guard localPending else { return true }
        return HomeConflictResolver.shouldApplyServer(
            localPending: true,
            localUpdatedAt: localUpdatedAt,
            serverUpdatedAt: serverUpdatedAt
        )
    }

    static func surfaceMessage(stepTitle: String, keptStatus: StepStatus) -> String {
        "Kept \"\(stepTitle)\" as \(statusLabel(keptStatus)) — another device tried to change its status."
    }

    static func activitySummary(stepTitle: String, keptStatus: StepStatus, rejectedStatus: StepStatus) -> String {
        "Terminal status protected for \"\(stepTitle)\" — kept \(statusLabel(keptStatus)), rejected \(statusLabel(rejectedStatus))"
    }

    static func statusLabel(_ status: StepStatus) -> String {
        switch status {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .complete: "Complete"
        case .na: "N/A"
        }
    }
}

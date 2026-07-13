import Foundation

// @covers AC-SYNC-05, AC-SYNC-06

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

    // MARK: - AC-SYNC-06 — auto-resolve status conflicts

    static func isStatusConflict(localStatus: StepStatus, serverStatus: StepStatus) -> Bool {
        localStatus != serverStatus
    }

    /// Loser notification when timestamp-wins auto-resolves a non-terminal status conflict.
    static func autoResolveLoserMessage(
        stepTitle: String,
        winningStatus: StepStatus,
        losingStatus: StepStatus
    ) -> String {
        "Your change to \"\(stepTitle)\" (\(statusLabel(losingStatus))) was overwritten by \(statusLabel(winningStatus)). See the activity log and re-apply if you still need your update."
    }

    static func autoResolveActivitySummary(
        stepTitle: String,
        procedureTitle: String,
        winningStatus: StepStatus,
        losingStatus: StepStatus
    ) -> String {
        "Status conflict on \"\(stepTitle)\" in \(procedureTitle) — kept \(statusLabel(winningStatus)) over \(statusLabel(losingStatus))"
    }

    static func autoResolveProcedureLoserMessage(
        procedureTitle: String,
        winningStatus: ProcedureStatus,
        losingStatus: ProcedureStatus
    ) -> String {
        "Your change to \"\(procedureTitle)\" (\(procedureStatusLabel(losingStatus))) was overwritten by \(procedureStatusLabel(winningStatus)). See the activity log and re-apply if you still need your update."
    }

    static func procedureStatusLabel(_ status: ProcedureStatus) -> String {
        switch status {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .complete: "Complete"
        case .na: "N/A"
        }
    }
}

import Foundation

// @covers AC-PROC-08

/// AC-PROC-08: step row layout rules — notes under the title, a tappable
/// "Photo attached" indicator when a photo exists, pencil Edit control
/// (permitted users) left of the status ellipsis menu, and tap-to-toggle
/// status behavior.
enum StepRowPresentation {

    /// The photo indicator appears only when the step carries a photo.
    static func showsPhotoIndicator(photoURL: String?) -> Bool {
        photoURL?.isEmpty == false
    }

    /// Notes render below the title only when non-empty.
    static func showsNotes(_ notes: String?) -> Bool {
        guard let notes else { return false }
        return !notes.isEmpty
    }

    /// Pencil Edit and the status menu appear only for permitted users.
    static func showsEditControls(canEdit: Bool) -> Bool {
        canEdit
    }

    /// Terminal statuses (Complete / N/A) render struck through.
    static func isStruckThrough(_ status: StepStatus) -> Bool {
        status == .complete || status == .na
    }

    /// Tap toggles: terminal statuses clear to Not Started; anything else
    /// completes the step.
    static func toggledStatus(from status: StepStatus) -> StepStatus {
        switch status {
        case .complete, .na:
            return .notStarted
        case .notStarted, .inProgress:
            return .complete
        }
    }
}

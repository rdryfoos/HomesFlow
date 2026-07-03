import SwiftUI

// @covers NFR-A11Y-01, AC-A11Y-01, AC-A11Y-02, AC-A11Y-03

/// Shared accessibility rules (NFR-A11Y-01) kept pure so the baseline is unit
/// testable: Dynamic Type scaling for fixed-height heroes, minimum tap
/// targets, Reduce Motion gating, and VoiceOver text for section tabs and
/// step statuses.
enum AccessibilityBaseline {
    /// Apple HIG minimum touch target (44×44 pt).
    static let minimumTapTarget: CGFloat = 44

    /// AC-A11Y-01: fixed-height hero cards grow with the content size
    /// category so the name/address overlay is not clipped at accessibility
    /// text sizes.
    static func scaledHeroHeight(base: CGFloat, for size: DynamicTypeSize) -> CGFloat {
        (base * heroScaleFactor(for: size)).rounded()
    }

    static func heroScaleFactor(for size: DynamicTypeSize) -> CGFloat {
        switch size {
        case .xSmall, .small, .medium, .large:
            return 1.0
        case .xLarge, .xxLarge:
            return 1.1
        case .xxxLarge:
            return 1.2
        case .accessibility1, .accessibility2:
            return 1.4
        case .accessibility3, .accessibility4, .accessibility5:
            return 1.6
        @unknown default:
            return 1.6
        }
    }

    /// AC-A11Y-03: returns nil when Reduce Motion is on, so
    /// `withAnimation(animation(reduceMotion:))` skips the animation.
    static func animation(
        _ base: Animation = .easeInOut(duration: 0.2),
        reduceMotion: Bool
    ) -> Animation? {
        reduceMotion ? nil : base
    }

    /// AC-A11Y-02: VoiceOver hint for a home section tab.
    static func sectionTabHint(_ tabName: String) -> String {
        "Shows \(tabName) for this home"
    }

    /// VoiceOver value announced for a procedure step row.
    static func stepStatusValue(_ status: StepStatus) -> String {
        switch status {
        case .notStarted: "Not started"
        case .inProgress: "In progress"
        case .complete: "Complete"
        case .na: "Not applicable"
        }
    }
}

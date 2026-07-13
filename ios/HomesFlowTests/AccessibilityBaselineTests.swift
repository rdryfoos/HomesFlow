import SwiftUI
import XCTest
@testable import HomesFlow

// @covers NFR-A11Y-01, AC-A11Y-01, AC-A11Y-02, AC-A11Y-03

final class AccessibilityBaselineTests: XCTestCase {

    // MARK: - AC-A11Y-01 — Dynamic Type reflow

    func test_AC_A11Y_01_hero_height_grows_with_text_size() {
        let base: CGFloat = 152
        let standard = AccessibilityBaseline.scaledHeroHeight(base: base, for: .large)
        let big = AccessibilityBaseline.scaledHeroHeight(base: base, for: .xxxLarge)
        let accessibility = AccessibilityBaseline.scaledHeroHeight(base: base, for: .accessibility5)

        XCTAssertEqual(standard, base, "Default text sizes keep the design height")
        XCTAssertGreaterThan(big, standard)
        XCTAssertGreaterThan(accessibility, big)
    }

    func test_AC_A11Y_01_scale_factor_is_monotonic_across_sizes() {
        let ordered: [DynamicTypeSize] = [
            .xSmall, .small, .medium, .large, .xLarge, .xxLarge, .xxxLarge,
            .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5,
        ]
        let factors = ordered.map(AccessibilityBaseline.heroScaleFactor(for:))
        XCTAssertEqual(factors, factors.sorted(), "Larger text must never shrink the hero")
        XCTAssertEqual(factors.first, 1.0)
    }

    // MARK: - AC-A11Y-02 — VoiceOver labels on section tabs

    func test_AC_A11Y_02_every_section_tab_has_meaningful_voiceover_text() {
        for tab in HomeTab.allCases {
            XCTAssertFalse(tab.rawValue.isEmpty, "\(tab) needs a label")
            let hint = AccessibilityBaseline.sectionTabHint(tab.rawValue)
            XCTAssertTrue(hint.contains(tab.rawValue), "Hint should name the section")
        }
    }

    func test_AC_A11Y_02_step_status_values_cover_all_statuses() {
        for status in StepStatus.allCases {
            let value = AccessibilityBaseline.stepStatusValue(status)
            XCTAssertFalse(value.isEmpty, "\(status) needs a VoiceOver value")
        }
        // "N/A" reads poorly in VoiceOver; the spoken form is spelled out.
        XCTAssertEqual(AccessibilityBaseline.stepStatusValue(.na), "Not applicable")
    }

    // MARK: - AC-A11Y-03 — Reduce Motion

    func test_AC_A11Y_03_reduce_motion_disables_animation() {
        XCTAssertNil(AccessibilityBaseline.animation(reduceMotion: true))
        XCTAssertNotNil(AccessibilityBaseline.animation(reduceMotion: false))
    }

    // MARK: - NFR-A11Y-01 — tap targets

    func test_minimum_tap_target_meets_hig() {
        XCTAssertGreaterThanOrEqual(AccessibilityBaseline.minimumTapTarget, 44)
    }
}

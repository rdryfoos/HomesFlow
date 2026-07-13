import XCTest
@testable import HomesFlow

// @covers AC-PROC-08

final class StepRowPresentationTests: XCTestCase {

    // T050d — AC-PROC-08: photo indicator and edit controls on step rows.

    func test_AC_PROC_08_photo_indicator_and_edit_controls() {
        XCTAssertTrue(StepRowPresentation.showsPhotoIndicator(photoURL: "steps/abc.jpg"))
        XCTAssertFalse(StepRowPresentation.showsPhotoIndicator(photoURL: nil))
        XCTAssertFalse(StepRowPresentation.showsPhotoIndicator(photoURL: ""))

        XCTAssertTrue(StepRowPresentation.showsNotes("Turn valve clockwise"))
        XCTAssertFalse(StepRowPresentation.showsNotes(nil))
        XCTAssertFalse(StepRowPresentation.showsNotes(""))

        // Pencil edit + status menu only for users allowed to update the step.
        XCTAssertTrue(StepRowPresentation.showsEditControls(canEdit: true))
        XCTAssertFalse(StepRowPresentation.showsEditControls(canEdit: false))
    }

    func test_AC_PROC_08_terminal_statuses_strike_through() {
        XCTAssertTrue(StepRowPresentation.isStruckThrough(.complete))
        XCTAssertTrue(StepRowPresentation.isStruckThrough(.na))
        XCTAssertFalse(StepRowPresentation.isStruckThrough(.notStarted))
        XCTAssertFalse(StepRowPresentation.isStruckThrough(.inProgress))
    }

    func test_AC_PROC_08_tap_toggle_status_mapping() {
        XCTAssertEqual(StepRowPresentation.toggledStatus(from: .notStarted), .complete)
        XCTAssertEqual(StepRowPresentation.toggledStatus(from: .inProgress), .complete)
        XCTAssertEqual(StepRowPresentation.toggledStatus(from: .complete), .notStarted)
        XCTAssertEqual(StepRowPresentation.toggledStatus(from: .na), .notStarted)
    }
}

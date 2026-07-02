import XCTest

final class HomeFlowUITests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["HomesFlow"].waitForExistence(timeout: 5))
    }
}

import XCTest

final class HomeFlowUITests: XCTestCase {
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["HomeFlow"].waitForExistence(timeout: 5))
    }
}

import XCTest

// UI tests run against a real (or simulator) iOS app via XCUIApplication.
// This is the minimal smoke test: launch the app, see the AINews title.
// Richer flows (tap Learn → Detail, bookmark, force refresh) get layered
// in once the JSON contract is stable on a real device.
final class AINewsWeeklyUITests: XCTestCase {
    func test_appLaunches_withTitle() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars.staticTexts["AINews"].waitForExistence(timeout: 10))
    }
}

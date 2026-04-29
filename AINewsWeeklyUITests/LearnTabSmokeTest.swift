import XCTest

// LearnTabSmokeTest — taps through Digest → Learn tab → Beginner track →
// Setting up Claude Code lesson, captures a screenshot at each. Acts as
// both a smoke test (does the new tab bar wire up the Learn surface
// correctly?) and as scaffolding Weekend 6/7 will reuse for App Store
// screenshots.
//
// Extract the screenshots from the xcresult bundle:
//   xcrun xcresulttool get --legacy --path <result.xcresult> \
//     --format json > attachments.json
final class LearnTabSmokeTest: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_learnTabFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for first launch + curriculum fetch to settle.
        let aiReport = app.staticTexts["AI Report"]
        XCTAssertTrue(aiReport.waitForExistence(timeout: 30),
                      "AI Report (Digest tab) never appeared — Digest fetch failed")
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "01-digest-tab", from: app)

        // Tap Learn tab. SwiftUI TabView's tabItem labels become button labels.
        let learnTab = app.tabBars.buttons["Learn"]
        XCTAssertTrue(learnTab.waitForExistence(timeout: 5))
        learnTab.tap()

        // Wait for Learn hero text to settle.
        let learnHero = app.staticTexts["Learn AI Tools"]
        XCTAssertTrue(learnHero.waitForExistence(timeout: 10),
                      "Learn AI Tools hero never appeared — curriculum fetch failed")
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "02-learn-home", from: app)

        // Tap the Beginner track card.
        let beginnerCard = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Beginner'")).firstMatch
        XCTAssertTrue(beginnerCard.waitForExistence(timeout: 5))
        beginnerCard.tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "03-beginner-track", from: app)

        // Tap into "Setting up Claude Code".
        let lessonRow = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Setting up Claude Code'")).firstMatch
        if lessonRow.waitForExistence(timeout: 5) {
            lessonRow.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(name: "04-lesson-detail", from: app)
        }
    }

    private func attach(name: String, from app: XCUIApplication) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

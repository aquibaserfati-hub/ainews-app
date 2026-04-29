import XCTest

// AppStoreScreenshotTests — drives the app through key states and captures
// XCTAttachment screenshots at each. Run on iPhone 16 Pro Max simulator
// (6.9" — the size Apple wants for new App Store submissions).
//
// To extract the screenshots after running:
//   xcrun xcresulttool get --legacy --path <result.xcresult> \
//     --format json > attachments.json
//   # ...or use the helper script in scripts/extract-screenshots.sh
final class AppStoreScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func test_captureAppStoreScreenshots() throws {
        let app = XCUIApplication()
        app.launch()

        // Wait for the network fetch + decode + render to finish.
        // The Weekly Report hero card has the title "AI Report" in serif.
        let aiReport = app.staticTexts["AI Report"]
        XCTAssertTrue(aiReport.waitForExistence(timeout: 30),
                      "AI Report hero never appeared — backend fetch may have failed")

        // Brief settle so the loading skeleton finishes its transition.
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "01-home-hero", from: app)

        // Scroll down so the Learn section is visible.
        let mainScroll = app.scrollViews.firstMatch
        if mainScroll.exists {
            mainScroll.swipeUp(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "02-learn-section", from: app)

        // Tap into the first Learn item. NavigationLink wraps a Button-style cell;
        // bound by position rather than label since titles vary across digests.
        let firstLearnCard = app.buttons.matching(NSPredicate(format: "label CONTAINS 'min setup' OR label CONTAINS 'Tooling' OR label CONTAINS 'Anthropic' OR label CONTAINS 'OpenAI'")).firstMatch
        if firstLearnCard.exists {
            firstLearnCard.tap()
        } else {
            // Fallback: tap a learn-card-shaped element via coordinate. The
            // first Learn card sits roughly in the middle of the lower half
            // after the swipe.
            let cells = app.buttons.allElementsBoundByIndex
            // Heuristic: the first button after the gear icon (at index 0) is
            // typically the first Learn card.
            if cells.count > 1 {
                cells[1].tap()
            }
        }
        Thread.sleep(forTimeInterval: 1.5)
        attach(name: "03-detail-top", from: app)

        // Scroll to the setup-guide section. The Detail view scrolls the
        // sections; markdown is below pros/cons.
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 0.6)
        app.swipeUp(velocity: .slow)
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "04-detail-setup", from: app)

        // Bookmark this item for the Settings shot.
        let bookmark = app.buttons["Add bookmark"]
        if bookmark.exists {
            bookmark.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }

        // Back to home.
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
            Thread.sleep(forTimeInterval: 1.0)
        }

        // Open Settings via the gear icon.
        let settings = app.buttons["Settings"]
        if settings.exists {
            settings.tap()
            Thread.sleep(forTimeInterval: 1.0)
            attach(name: "05-settings", from: app)
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

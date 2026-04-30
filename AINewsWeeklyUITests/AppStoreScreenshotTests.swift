import XCTest

// AppStoreScreenshotTests — drives the app through key states and captures
// XCTAttachment screenshots at each. Run on iPhone 16 Pro Max simulator
// (6.9" — the size Apple wants for new App Store submissions).
//
// Shot order for v2 (per design doc Weekend 7 — screenshots must show the
// curriculum surface as primary, digest as secondary):
//   01 — Learn tab home (hero + 3 track cards)
//   02 — Beginner track detail (lesson list with progress dots)
//   03 — Lesson detail top (step 1, code block with Copy button visible)
//   04 — Lesson with mid-progress (several steps done, progress bar filled)
//   05 — Digest tab (AI Report hero card — v1's primary screen, now secondary)
//   06 — Settings (bookmarks, force refresh, About)
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

        // Wait for curriculum + digest fetch to settle.
        // Default launch lands on Digest tab — wait for the AI Report hero.
        let aiReport = app.staticTexts["AI Report"]
        XCTAssertTrue(aiReport.waitForExistence(timeout: 30),
                      "AI Report hero never appeared — digest fetch may have failed")
        Thread.sleep(forTimeInterval: 1.5)

        // 1. Switch to the Learn tab first — it's the hero surface for v2.
        let learnTab = app.tabBars.buttons["Learn"]
        XCTAssertTrue(learnTab.waitForExistence(timeout: 5))
        learnTab.tap()

        let learnHero = app.staticTexts["Learn AI Tools"]
        XCTAssertTrue(learnHero.waitForExistence(timeout: 15),
                      "Learn AI Tools hero never appeared — curriculum fetch may have failed")
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "01-learn-home", from: app)

        // 2. Tap into Beginner track.
        let beginnerCard = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Beginner'")
        ).firstMatch
        XCTAssertTrue(beginnerCard.waitForExistence(timeout: 5))
        beginnerCard.tap()
        Thread.sleep(forTimeInterval: 1.0)
        attach(name: "02-beginner-track", from: app)

        // 3. Tap into "Setting up Claude Code".
        let lessonRow = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'Setting up Claude Code'")
        ).firstMatch
        if lessonRow.waitForExistence(timeout: 5) {
            lessonRow.tap()
            Thread.sleep(forTimeInterval: 1.5)
            attach(name: "03-lesson-detail-top", from: app)

            // 4. Mark the first 3 steps done to show filled progress bar
            // and the in-progress state for the screenshot.
            for stepN in 1...3 {
                let markButton = app.buttons["Mark step \(stepN) done"]
                if markButton.waitForExistence(timeout: 3) {
                    markButton.tap()
                    Thread.sleep(forTimeInterval: 0.3)
                }
            }
            attach(name: "04-lesson-mid-progress", from: app)

            // Back to Beginner track, then back to Learn home.
            let backToBeginner = app.navigationBars.buttons.element(boundBy: 0)
            if backToBeginner.exists {
                backToBeginner.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
        }

        let backToLearn = app.navigationBars.buttons.element(boundBy: 0)
        if backToLearn.exists {
            backToLearn.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }

        // 5. Switch to Digest tab for the AI Report screenshot.
        let digestTab = app.tabBars.buttons["Digest"]
        if digestTab.exists {
            digestTab.tap()
            Thread.sleep(forTimeInterval: 1.0)
            attach(name: "05-digest-tab", from: app)
        }

        // 6. Open Settings via the gear icon.
        let settings = app.buttons["Settings"]
        if settings.exists {
            settings.tap()
            Thread.sleep(forTimeInterval: 1.0)
            attach(name: "06-settings", from: app)
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

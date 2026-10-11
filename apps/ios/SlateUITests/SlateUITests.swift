import XCTest

final class SlateUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }
    func testAuthenticationAndProjectCreation() throws {
        guard ProcessInfo.processInfo.environment["SLATE_UI_INTEGRATION"] == "1" else { throw XCTSkip("Set SLATE_UI_INTEGRATION=1 with API running and seeded to test real authenticated workflow.") }
        let app = XCUIApplication(); app.launch()
        if app.tabBars.buttons["Settings"].waitForExistence(timeout: 3) {
            app.tabBars.buttons["Settings"].tap()
            let logout = app.buttons["settings.logout"]; app.swipeUp(); if logout.exists { logout.tap(); app.alerts.buttons["Sign out"].tap() }
        }
        let email = app.textFields["auth.email"]; XCTAssertTrue(email.waitForExistence(timeout: 10)); email.tap(); email.typeText("demo@slate.local")
        let password = app.secureTextFields["auth.password"]; password.tap(); password.typeText("SlateDemo2026!")
        app.buttons["auth.submit"].tap(); XCTAssertTrue(app.tabBars.buttons["Projects"].waitForExistence(timeout: 20))
        app.tabBars.buttons["Projects"].tap(); app.buttons["projects.create"].tap()
        let title = "UI Campaign " + UUID().uuidString.prefix(6)
        app.textFields["project.title"].tap(); app.textFields["project.title"].typeText(title)
        app.textFields["project.deliverable"].tap(); app.textFields["project.deliverable"].typeText("Campaign photographs")
        app.swipeUp(); app.buttons["project.save"].tap()
        XCTAssertTrue(app.navigationBars["Projects"].waitForExistence(timeout: 15))
        app.swipeDown(); XCTAssertTrue(app.staticTexts[String(title)].waitForExistence(timeout: 15))
        app.staticTexts[String(title)].tap(); XCTAssertTrue(app.buttons["project.import"].waitForExistence(timeout: 10))
        app.buttons["project.import"].tap()
        XCTAssertTrue(app.buttons["Photo library"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Files"].exists)
    }
    func testLoginValidation() throws {
        let app = XCUIApplication(); app.launch()
        guard app.buttons["auth.submit"].waitForExistence(timeout: 8) else { throw XCTSkip("An authenticated device already has a session.") }
        app.buttons["auth.submit"].tap()
        XCTAssertTrue(app.staticTexts["Enter a valid email and a password of at least 12 characters."].exists)
    }
}

//
//  AgeGateUITests.swift
//  ChildTimeUITests
//
//  🧒🚫 A child must not open a family as its "parent" (Rani, 2026-10-08).
//  The simulator has no Apple age range to give, so "parent" falls through to
//  the year wheel — which opens on 2016, a child's year.
//
import XCTest

final class AgeGateUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    private func launchPicker() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = "rolepicker"
        app.launchEnvironment["DEMO_LANG"] = "he"
        app.launchEnvironment["DEMO_HASFAMILY"] = "1"
        // A fresh verdict every run (the argument domain wins over the saved one).
        app.launchArguments += ["-ageGate.verdict", ""]
        app.launch()
        return app
    }

    private func tapParent(_ app: XCUIApplication) {
        let parent = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "הוֹרֶה")).firstMatch
        XCTAssertTrue(parent.waitForExistence(timeout: 10))
        parent.tap()
    }

    /// A child who just taps on through the wheel gets the friendly screen.
    func testChildYearLandsOnMinorScreen() {
        let app = launchPicker()
        tapParent(app)
        XCTAssertTrue(app.staticTexts["שְׁאֵלָה קְטַנָּה לִפְנֵי שֶׁמַּתְחִילִים"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.pickerWheels["2016"].exists, "the wheel opens on a child's year")
        app.buttons["הַמְשֵׁךְ"].tap()
        XCTAssertTrue(app.staticTexts["נִרְאֶה שֶׁזֶּה הַמַּכְשִׁיר שֶׁל הַיֶּלֶד 😊"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["🔑 יֵשׁ לִי קוֹד מֵהַהוֹרֶה"].exists)
    }

    /// A grown-up scrolls back to their year and goes on as a parent.
    func testAdultYearGoesOn() {
        let app = launchPicker()
        tapParent(app)
        let wheel = app.pickerWheels.firstMatch
        XCTAssertTrue(wheel.waitForExistence(timeout: 15))
        wheel.adjust(toPickerWheelValue: "1985")
        app.buttons["הַמְשֵׁךְ"].tap()
        XCTAssertFalse(app.staticTexts["נִרְאֶה שֶׁזֶּה הַמַּכְשִׁיר שֶׁל הַיֶּלֶד 😊"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["שְׁאֵלָה קְטַנָּה לִפְנֵי שֶׁמַּתְחִילִים"].exists, "the question closed")
    }
}

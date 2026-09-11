//
//  HeroVideoUITests.swift
//  ChildTimeUITests
//
//  🎬 Drives the kid flow for the website's hero loop, so the video can be
//  re-recorded in any language instead of by hand: home → a question → the
//  right answer → the minutes it earned → opening play time → the clock → home.
//
//  Record the screen while this runs:
//    xcrun simctl io <device> recordVideo --codec h264 /tmp/hero-en.mov &
//    xcodebuild test -scheme ChildTime -destination 'platform=iOS Simulator,id=<device>' \
//      -only-testing:ChildTimeUITests/HeroVideoUITests/testKidFlowForHeroLoop
//    kill -INT %1
//  DEMO_LANG picks the language (defaults to English here).
//
import XCTest

final class HeroVideoUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    @MainActor
    func testKidFlowForHeroLoop() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = "kidflow"
        app.launchEnvironment["DEMO_LANG"] = ProcessInfo.processInfo.environment["HERO_LANG"] ?? "en"
        app.launch()
        wait(2.5)                                   // the home screen settles

        // 1) Open the first world tile ("Tofy Time" — questions picked for the child).
        tapFirst(in: app, ["Tofy Time", "טופי טיים"], fallback: CGVector(dx: 0.25, dy: 0.55))
        wait(3.0)                                   // the question appears

        // 2) Answer. A wrong answer moves the child on to the next question, so
        //    tap the four option slots in turn — one of them is the right answer,
        //    and the loop needs that moment (the green check and the seconds won).
        let slots: [CGVector] = [CGVector(dx: 0.27, dy: 0.56), CGVector(dx: 0.73, dy: 0.56),
                                 CGVector(dx: 0.27, dy: 0.68), CGVector(dx: 0.73, dy: 0.68)]
        for slot in slots {
            app.coordinate(withNormalizedOffset: slot).tap()
            wait(2.0)
        }
        wait(2.0)                                   // the earned-seconds badge

        // 3) Back to the home screen, then open the play time the parents gifted.
        tapFirst(in: app, ["xmark", "✕", "X"], fallback: CGVector(dx: 0.08, dy: 0.07))
        wait(2.0)
        tapFirst(in: app, ["Gift from your parents", "מתנה מההורים", "unlock play time", "לפתוח זמן משחק"],
                 fallback: CGVector(dx: 0.5, dy: 0.78))
        wait(6.0)                                   // "Your time is on its way" → the running clock
    }

    // MARK: helpers

    @MainActor private func tapFirst(in app: XCUIApplication, _ labels: [String], fallback: CGVector) {
        for label in labels {
            let match = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[c] %@ OR identifier CONTAINS[c] %@", label, label))
                .allElementsBoundByIndex.first(where: { $0.isHittable })
            if let match { match.tap(); return }
        }
        app.coordinate(withNormalizedOffset: fallback).tap()
    }

    private func wait(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }
}

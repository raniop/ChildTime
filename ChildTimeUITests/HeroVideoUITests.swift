//
//  HeroVideoUITests.swift
//  ChildTimeUITests
//
//  🎬 Drives the kid flow for the website's hero loop, so the video can be
//  re-recorded in any language instead of by hand.
//
//  Two takes, both recorded in one pass:
//    1. testAnswerCorrectlyForHeroLoop — a math question is read off the screen,
//       solved, and the RIGHT answer is tapped, so the loop can show the green
//       check and the seconds it earned instead of a blind guess.
//    2. testKidFlowForHeroLoop — home → a world → the question → back home →
//       the play time the parents gifted → the running clock.
//
//  Record the screen while they run:
//    xcrun simctl io <device> recordVideo --codec h264 /tmp/hero.mov &
//    xcodebuild test -scheme ChildTime -destination 'platform=iOS Simulator,id=<id>' \
//      -only-testing:ChildTimeUITests/HeroVideoUITests
//    kill -INT %1
//  HERO_LANG picks the language (defaults to Hebrew — the simulator's region is
//  American, so a fresh install would otherwise open in English).
//
import XCTest

final class HeroVideoUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private var lang: String { ProcessInfo.processInfo.environment["HERO_LANG"] ?? "he" }
    private var hebrew: Bool { lang == "he" }

    // MARK: 1) answering correctly

    /// Opens a grade-3 math question, works out the answer from the prompt, and
    /// taps it. A prompt that isn't plain arithmetic (a word problem) is skipped
    /// by relaunching — the next question is a fresh draw.
    @MainActor
    func testAnswerCorrectlyForHeroLoop() throws {
        for _ in 0..<8 {
            let app = XCUIApplication()
            app.launchEnvironment["DEMO_SCREEN"] = "mathgrade"
            app.launchEnvironment["DEMO_WORLD"] = "math"
            app.launchEnvironment["DEMO_GRADE"] = "3"
            app.launchEnvironment["DEMO_LANG"] = lang
            app.launch()
            wait(3.5)                               // the question settles

            let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
            guard let answer = labels.compactMap(Self.solve).first else {
                app.terminate(); wait(0.5); continue        // a word problem — draw again
            }
            // The four options live in the lower half; the same digits can also
            // appear in the counters at the top, so take the lowest match.
            let screen = app.windows.element(boundBy: 0).frame
            let option = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", answer))
                .allElementsBoundByIndex
                .filter { $0.isHittable && $0.frame.midY > screen.height * 0.45 }
                .sorted { $0.frame.midY < $1.frame.midY }
                .first
            guard let option else { app.terminate(); wait(0.5); continue }

            wait(1.5)                               // a beat, so the question is readable
            option.tap()
            wait(6.0)                               // ✅ the check, the seconds, the next question
            return
        }
        XCTFail("No plain-arithmetic question came up in 8 draws")
    }

    /// "20 ÷ 4 = ?" → "5". Returns nil for anything that isn't two whole numbers
    /// and one operator with a whole answer.
    static func solve(_ text: String) -> String? {
        let pattern = #"(\d+)\s*([+\-−×xX*÷:/])\s*(\d+)"#
        guard text.contains("?") || text.contains("=") ,
              let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r1 = Range(m.range(at: 1), in: text),
              let r2 = Range(m.range(at: 2), in: text),
              let r3 = Range(m.range(at: 3), in: text),
              let a = Int(text[r1]), let b = Int(text[r3]) else { return nil }
        switch text[r2] {
        case "+": return String(a + b)
        case "-", "−": return a >= b ? String(a - b) : nil
        case "×", "x", "X", "*": return String(a * b)
        case "÷", ":", "/": return (b != 0 && a % b == 0) ? String(a / b) : nil
        default: return nil
        }
    }

    // MARK: 2) the round trip

    @MainActor
    func testKidFlowForHeroLoop() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = "kidflow"
        app.launchEnvironment["DEMO_LANG"] = lang
        app.launch()
        wait(3.0)                                   // the home screen settles

        // 1) Open the first world tile. The Hebrew label is vocalised
        //    ("טוֹפִי טַיים"), and the Hebrew home is mirrored — an unvocalised
        //    search with a left-to-right fallback used to hit the tile beside it.
        tapFirst(in: app, ["Tofy Time", "טוֹפִי טַיים"],
                 fallback: CGVector(dx: hebrew ? 0.73 : 0.27, dy: 0.55))
        wait(4.0)                                   // the question appears and is readable

        // 2) Back to the home screen, then open the play time the parents gifted.
        tapFirst(in: app, ["xmark", "✕", "X"], fallback: CGVector(dx: 0.08, dy: 0.07))
        wait(2.5)
        tapFirst(in: app, ["Gift from your parents", "מַתָּנָה מֵהַהוֹרִים", "מתנה מההורים"],
                 fallback: CGVector(dx: 0.5, dy: 0.78))
        wait(8.0)                                   // "your time is on its way" → the running clock
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

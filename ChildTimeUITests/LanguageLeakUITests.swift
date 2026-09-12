//
//  LanguageLeakUITests.swift
//  ChildTimeUITests
//
//  🌍 Proof that the app says nothing in Hebrew to a child or parent who chose
//  English or Russian (Rani: "שלא יהיה פתאום משהו בעברית").
//
//  Static checks can only see the strings the code asks for by name. This walks
//  every demo screen in one language and reads what is ACTUALLY on it — labels
//  built at runtime, text from the server, values cached from an earlier run —
//  and fails on any Hebrew letter it finds.
//
//  Run one language at a time:
//    LEAK_LANG=en xcodebuild test -only-testing:ChildTimeUITests/LanguageLeakUITests
//    LEAK_LANG=ru …
//
import XCTest

final class LanguageLeakUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private var lang: String { ProcessInfo.processInfo.environment["LEAK_LANG"] ?? "en" }

    /// Every screen `ChildTimeApp.demoScreen` can open.
    private static let screens = [
        "applock", "askparent", "askworld", "campaignpopup", "campaignpopupkid",
        "childdifficulty", "childjoin", "childscreentime", "childworlds", "choreskid",
        "choresparent", "createchild", "dailychest", "dashboard", "devicecontrols",
        "familychoice", "gate", "giftearly", "giftended", "giftlate", "gradepicker",
        "kidflow", "kidhome", "kidmode", "kidpass", "kidpin", "leaderboard", "levelup",
        "mathgrade", "onboarding", "opening", "openinggift", "packask", "packdetail",
        "packnew", "packoffer", "packowned", "packrequest", "packreveal", "parentassist",
        "parenthelp", "parenthome", "parentsettings", "paywall", "paywallgift", "question",
        "rolepicker", "shop", "starshop", "unlocked", "welcome", "whatsnew", "wheel",
        "worldpass", "worldshelf", "worldunlock",
    ]

    /// Hebrew that is CONTENT, not an untranslated string.
    ///
    /// A Russian-speaking child in an Israeli school learns Hebrew, so the Hebrew
    /// world and the English world's Hebrew glosses are served in Hebrew on
    /// purpose — and every language picker lists "עברית" in its own alphabet.
    private static let allowed = ["עברית", "טופי", "Tofy"]

    private let hebrew = CharacterSet(charactersIn: Unicode.Scalar(0x0590)!...Unicode.Scalar(0x05FF)!)

    @MainActor
    func testNoHebrewLeaksIntoThisLanguage() throws {
        var leaks: [String] = []
        for screen in Self.screens {
            let app = XCUIApplication()
            app.launchEnvironment["DEMO_SCREEN"] = screen
            app.launchEnvironment["DEMO_LANG"] = lang
            // The Hebrew world really is taught in Hebrew; keep it out of the sweep
            // by pinning the question screens to a world that is not it.
            app.launchEnvironment["DEMO_WORLD"] = "math"
            app.launchEnvironment["DEMO_GRADE"] = "3"
            app.launch()
            Thread.sleep(forTimeInterval: 3.5)

            for label in visibleText(app) where label.rangeOfCharacter(from: hebrew) != nil {
                if Self.allowed.contains(where: { label.contains($0) }) { continue }
                leaks.append("\(screen): \(label.replacingOccurrences(of: "\n", with: " ⏎ "))")
            }
            app.terminate()
            Thread.sleep(forTimeInterval: 0.3)
        }
        print("LEAKS[\(lang)] \(leaks.count)")
        for l in leaks { print("LEAK \(l)") }
        XCTAssertTrue(leaks.isEmpty, "עברית דלפה ל-\(lang): \(leaks.prefix(10).joined(separator: " | "))")
    }

    /// Each element is re-queried one at a time — reading a whole
    /// `allElementsBoundByIndex` array while a screen animates throws.
    @MainActor
    private func visibleText(_ app: XCUIApplication) -> [String] {
        var out: [String] = []
        for query in [app.staticTexts, app.buttons, app.navigationBars, app.switches, app.textFields] {
            for i in 0..<query.count {
                let e = query.element(boundBy: i)
                guard e.exists else { continue }
                if !e.label.isEmpty { out.append(e.label) }
                if let v = e.value as? String, !v.isEmpty { out.append(v) }
            }
        }
        return out
    }
}

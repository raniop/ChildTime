//
//  EnglishAuditUITests.swift
//  ChildTimeUITests
//
//  🇺🇸 "No American child ever sees Hebrew" (Rani). Opens every DEMO_SCREEN in
//  English, scrolls through it, and fails on any Hebrew character in the
//  accessibility tree — every label, value and button a user can see.
//
//  Run:
//    xcodebuild test -scheme ChildTime \
//      -destination 'platform=iOS Simulator,name=iPhone 17' \
//      -only-testing:ChildTimeUITests/EnglishAuditUITests
//
//  Every hit is also printed as "HEBREW-AUDIT|<screen>|<text>" so the log can be
//  grepped for the full list in one pass.
//
import XCTest

final class EnglishAuditUITests: XCTestCase {

    /// Every DEMO_SCREEN in ChildTimeApp, plus the question screen of each world.
    static let screens = [
        "splash", "welcome", "rolepicker", "onboarding", "childjoin", "familychoice", "applock", "createchild",
        "dashboard", "parenthome", "parentsettings", "childdifficulty", "childscreentime", "childworlds", "devicecontrols",
        "choresparent", "choreskid", "activation", "giftearly", "giftlate", "giftended", "paywall", "paywallgift",
        "kidhome", "kidflow", "kidmode", "kidpass", "kidpin", "gate", "joinguard", "gradepicker",
        "question", "wheel", "dailychest", "levelup", "worldunlock", "unlocked", "opening", "openinggift",
        "starshop", "shop", "leaderboard", "livegame", "gameinvite", "friendtest",
        "packdetail", "packreveal", "packnew", "packask", "packoffer", "packrequest", "packowned",
        "worldpass", "worldshelf", "campaignpopup", "campaignpopupkid", "askworld", "askparent",
        "parentassist", "parenthelp", "whatsnew",
    ]
    static let worlds = [
        "math", "english", "logic", "science", "history", "geography", "money", "reading",
        "soccer", "dinosaurs", "space", "animals", "sea", "gifted", "food", "music", "body", "vehicles", "flags",
    ]

    /// Text that is Hebrew on purpose in English: the language picker names the
    /// language in its own script so a Hebrew reader can find it.
    static let allowed = ["עברית", "שָׁפָה"]

    private static let hebrew = try! NSRegularExpression(pattern: "[\\u0590-\\u05FF\\uFB1D-\\uFB4F]")

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func testEveryScreenIsEnglish() throws {
        var hits: [String] = []
        for screen in Self.screens {
            hits += audit(screen: screen, env: [:])
        }
        for world in Self.worlds {
            for grade in ["0", "2", "5", "8"] {
                hits += audit(screen: "mathgrade", env: ["DEMO_WORLD": world, "DEMO_GRADE": grade], label: "\(world)@\(grade)")
            }
        }
        if !hits.isEmpty {
            XCTFail("Hebrew visible in English (\(hits.count)):\n" + hits.joined(separator: "\n"))
        }
    }

    @MainActor
    private func audit(screen: String, env: [String: String], label: String? = nil) -> [String] {
        let name = label ?? screen
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = screen
        app.launchEnvironment["DEMO_LANG"] = "en"
        app.launchEnvironment["DEMO_RESET"] = "1"
        for (k, v) in env { app.launchEnvironment[k] = v }
        app.launch()
        Thread.sleep(forTimeInterval: 4)

        var found = Set<String>()
        for pass in 0..<4 {
            for line in app.debugDescription.split(separator: "\n") {
                // The root element's label is the home-screen name, which is טופי on
                // purpose for an English device set to the Israel region (en-IL).
                if line.contains("Application, ") { continue }
                var text = String(line)
                for word in Self.allowed { text = text.replacingOccurrences(of: word, with: "") }
                if Self.hebrew.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                    found.insert(String(line).trimmingCharacters(in: .whitespaces))
                }
            }
            if pass < 3 { app.swipeUp(); Thread.sleep(forTimeInterval: 0.8) }
        }
        app.terminate()
        let hits = found.sorted().map { "HEBREW-AUDIT|\(name)|\($0)" }
        hits.forEach { print($0) }
        return hits
    }
}

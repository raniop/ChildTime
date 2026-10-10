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
//  The language is the `lang` default below. Neither `HERO_LANG=ar xcodebuild …`
//  nor `xcodebuild … TEST_RUNNER_HERO_LANG=ar` reaches the runner — the shell's
//  environment is not forwarded, and `test-without-building` applies no build
//  settings at all, so the TEST_RUNNER_ prefix has nothing to act on either.
//  Both fail silently and record Hebrew. Edit the default, rebuild for testing,
//  record, and put it back to "he".
//
import XCTest

final class HeroVideoUITests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = true }

    private var lang: String { ProcessInfo.processInfo.environment["HERO_LANG"] ?? "he" }
    private var hebrew: Bool { lang == "he" }

    /// Which worlds the smart feed may draw from while recording. ✍️ עברית is
    /// served in Hebrew to Russian and Arabic speakers on purpose — those
    /// children learn Hebrew at school — but a Hebrew question in the middle of
    /// an Arabic promo makes the app look like it was never translated. Arabic
    /// leads with 🎊 الأعياد, the world that ships with the language.
    private var demoTopics: String? {
        switch lang {
        case "ar": return "holidays,science,geography,math,logic,english"
        case "ru": return "science,geography,math,logic,english,reading"
        default:   return nil
        }
    }

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
            // appear in the counters at the top, so only the lower part counts.
            let screen = app.windows.element(boundBy: 0).frame
            let option = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", answer))
                .allElementsBoundByIndex
                // The answer tiles start at ~44% of the height on a Pro Max, and each
                // carries a small number badge (1–4). With a 45% cut the top-row tile
                // was dropped and the "4" badge — sitting on tile "1" — was tapped:
                // a red wrong answer in the Arabic take. The tile's number is set far
                // larger than its badge, so the tallest match is the tile.
                // (2026.10.8: the answers moved up — the top row now starts at ~22% —
                // and with the old 35% cut the top-row tile was dropped again, so the
                // badge carrying the same digit was tapped: a red answer in Russian.)
                .filter { $0.isHittable && $0.frame.midY > screen.height * 0.20 }
                .sorted { $0.frame.height > $1.frame.height }
                .first
            guard let option else { app.terminate(); wait(0.5); continue }

            wait(1.5)                               // a beat, so the question is readable
            option.tap()
            wait(6.0)                               // ✅ the check, the seconds, the next question
            return
        }
        XCTFail("No plain-arithmetic question came up in 8 draws")
    }

    /// "20 ÷ 4 = ?" → "5", "8 × 3 + 14 = ?" → "38". Whole numbers and + − × ÷
    /// only, × and ÷ before + and −; nil for a word problem, a fraction, or an
    /// answer that isn't a whole number. (Taking just the first "8 × 3" once
    /// tapped 24 — a red wrong answer in the Russian take.)
    static func solve(_ text: String) -> String? {
        guard let eq = text.firstIndex(of: "=") else { return nil }
        let expr = text[..<eq].trimmingCharacters(in: .whitespaces)
        var nums: [Int] = [], ops: [Character] = [], digits = ""
        for ch in expr {
            if ch.isWholeNumber, let d = ch.wholeNumberValue { digits.append(String(d)); continue }
            if !digits.isEmpty { nums.append(Int(digits)!); digits = "" }
            switch ch {
            case " ", "\u{00A0}", "\u{200E}", "\u{200F}", "\u{2066}", "\u{2067}", "\u{2068}", "\u{2069}": continue  // RTL marks
            case "+": ops.append("+")
            case "-", "−": ops.append("-")
            case "×", "x", "X", "*": ops.append("*")
            case "÷", ":", "/": ops.append("/")
            default: return nil                       // a letter: a word problem
            }
        }
        if !digits.isEmpty { nums.append(Int(digits)!) }
        guard nums.count >= 2, ops.count == nums.count - 1 else { return nil }
        // × and ÷ first, left to right…
        var terms = [nums[0]], signs: [Character] = []
        for (i, op) in ops.enumerated() {
            let n = nums[i + 1]
            switch op {
            case "*": terms[terms.count - 1] *= n
            case "/":
                guard n != 0, terms[terms.count - 1] % n == 0 else { return nil }
                terms[terms.count - 1] /= n
            default: terms.append(n); signs.append(op)
            }
        }
        // …then + and −.
        var total = terms[0]
        for (i, s) in signs.enumerated() { total += s == "+" ? terms[i + 1] : -terms[i + 1] }
        return total >= 0 ? String(total) : nil
    }

    // MARK: 2) the round trip

    @MainActor
    func testKidFlowForHeroLoop() throws {
        // A throwaway launch first: the take is recorded on a FRESH install (the
        // recording script uninstalls the app — a play window left open by the
        // previous take, or its lease, made the next gift refuse to open), and a
        // cold first launch lands on the splash while the demo data is seeded.
        let warmUp = XCUIApplication()
        warmUp.launchEnvironment["DEMO_SCREEN"] = "kidhome"
        warmUp.launchEnvironment["DEMO_LANG"] = lang
        warmUp.launchEnvironment["DEMO_GIFT_MINUTES"] = "10"
        warmUp.launch()
        wait(6.0)
        warmUp.terminate()
        wait(1.0)

        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = "kidflow"
        app.launchEnvironment["DEMO_LANG"] = lang
        if let demoTopics { app.launchEnvironment["DEMO_TOPICS"] = demoTopics }
        // 💝 Seed the gift pocket explicitly. It used to be whatever the last run
        // left behind: one take opened on a 10-minute gift, the next had none,
        // the tap fell through to the coordinate under it and the recording ended
        // on the Tofy+ paywall instead of the running clock.
        app.launchEnvironment["DEMO_GIFT_MINUTES"] = "10"
        app.launch()
        wait(3.5)                                   // the home screen settles

        // 1) Open the first world tile. The Hebrew label is vocalised
        //    ("טוֹפִי טַיים"), and the Hebrew home is mirrored — an unvocalised
        //    search with a left-to-right fallback used to hit the tile beside it.
        tapFirst(in: app, ["Tofy Time", "טוֹפִי טַיים"],
                 fallback: CGVector(dx: hebrew ? 0.73 : 0.27, dy: 0.55))
        wait(4.0)                                   // the question appears and is readable

        // 2) Back to the home screen, then open the play time the parents gifted.
        // (The ✕ carries a spoken label now, and sits on the leading side — the
        // right in Hebrew and Arabic.)
        tapFirst(in: app, ["סגור", "סגרי", "Close", "Закрыть", "إغلاق", "xmark"],
                 fallback: CGVector(dx: hebrew || lang == "ar" ? 0.92 : 0.08, dy: 0.07))
        wait(2.5)
        // The home's bottom bar (2026.10.8): ONE tap on "💝 10 דק׳ · מתנה · פתחו!"
        // opens the gift — the old two-step ("the gift lands in the bank", then
        // "unlock N minutes") is gone, and a second tap here would now land on
        // "stop and save the time" and end the clock the take is meant to show.
        let giftLabels = ["מתנה · פתחו", "Gift · open", "Подарок · открой", "هدية · افتحوها"]
        tapFirst(in: app, giftLabels + ["💝"],
                 fallback: CGVector(dx: hebrew || lang == "ar" ? 0.80 : 0.20, dy: 0.93))
        wait(3.5)
        // Still on the home screen ("one moment, I'll check your gift — try again")?
        // Then do what the child would: tap it once more.
        let stillThere = giftLabels.contains { label in
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS[cd] %@", label))
                .allElementsBoundByIndex.contains { $0.isHittable }
        }
        if stillThere { tapFirst(in: app, giftLabels, fallback: CGVector(dx: 0.5, dy: 0.5)); wait(3.5) }
        wait(9.0)                                   // "your time is on its way" → the running clock
    }

    // MARK: 3) everything else worth showing

    /// The rest of the app in one pass — the lucky wheel (spun), the daily chest
    /// (opened), the character shop, the friends leaderboard, a level-up and the
    /// chores board. Each is its own launch, so one recording carries every beat
    /// the hero loop might want.
    @MainActor
    func testShowcaseForHeroLoop() throws {
        let beats: [(screen: String, taps: Int, at: CGVector, settle: TimeInterval)] = [
            ("wheel",       1, CGVector(dx: 0.50, dy: 0.44), 7.5),   // the wheel itself spins on a tap
            ("dailychest",  6, CGVector(dx: 0.50, dy: 0.45), 6.0),   // "tap again and again to open"
            ("starshop",    0, .zero, 4.5),
            ("shop",        0, .zero, 5.0),
            ("leaderboard", 0, .zero, 5.0),
            ("levelup",     0, .zero, 4.0),
            ("choreskid",   0, .zero, 5.0),
        ]
        for beat in beats {
            let app = XCUIApplication()
            app.launchEnvironment["DEMO_SCREEN"] = beat.screen
            app.launchEnvironment["DEMO_LANG"] = lang
            app.launch()
            wait(3.0)                                   // the screen settles before anything is touched
            for _ in 0..<beat.taps {
                app.coordinate(withNormalizedOffset: beat.at).tap()
                wait(0.35)
            }
            wait(beat.settle)
            app.terminate()
            wait(0.6)
        }
    }

    // MARK: helpers

    @MainActor private func tapFirst(in app: XCUIApplication, _ labels: [String], fallback: CGVector) {
        for label in labels {
            let match = app.descendants(matching: .any)
                // [cd] — diacritic-insensitive: the app's Hebrew is vocalised
                // ("מַתָּנָה מֵהַהוֹרִים"), and matching that by hand-typed niqqud is a
                // coin flip. Without it the gift banner was never found and the
                // fallback tap opened whatever tile sat under those coordinates.
                .matching(NSPredicate(format: "label CONTAINS[cd] %@ OR identifier CONTAINS[cd] %@", label, label))
                .allElementsBoundByIndex.first(where: { $0.isHittable })
            if let match { match.tap(); return }
        }
        app.coordinate(withNormalizedOffset: fallback).tap()
    }

    private func wait(_ seconds: TimeInterval) { Thread.sleep(forTimeInterval: seconds) }
}

// MARK: - regression: answering must move on to a DIFFERENT question
//
// A wrong answer used to be able to come back as the very next question (the
// re-ask queue popped the item that had just been pushed), so from the child's
// side a wrong answer looked like it did nothing. This drives nine real answers
// and fails if any question is shown twice in a row.
extension HeroVideoUITests {
    @MainActor
    func testWrongAnswerAdvances() throws {
        let app = XCUIApplication()
        app.launchEnvironment["DEMO_SCREEN"] = "mathgrade"
        app.launchEnvironment["DEMO_WORLD"] = "math"
        app.launchEnvironment["DEMO_GRADE"] = "3"
        app.launchEnvironment["DEMO_LANG"] = lang
        app.launch()
        Thread.sleep(forTimeInterval: 4.0)

        let screen = app.windows.element(boundBy: 0).frame

        /// Every element is re-queried one at a time. Reading a whole
        /// `allElementsBoundByIndex` array mid-animation throws "no matches found
        /// for element at index N" — the question swap is exactly such a moment.
        func labels(_ query: XCUIElementQuery, in band: ClosedRange<CGFloat>) -> [(String, CGFloat)] {
            var out: [(String, CGFloat)] = []
            for i in 0..<query.count {
                let e = query.element(boundBy: i)
                guard e.exists else { continue }
                let y = e.frame.midY
                guard band.contains(y / screen.height) else { continue }
                if !e.label.isEmpty { out.append((e.label, y)) }
            }
            return out
        }
        // Every prompt carries the "?" of "3 × 8 + 13 = ?" or of a word problem.
        func promptNow() -> String {
            labels(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "?")), in: 0.20...0.48)
                .map(\.0).max(by: { $0.count < $1.count }) ?? ""
        }

        var seen: [String] = []
        var repeats: [String] = []
        for round in 0..<9 {
            var prompt = ""
            for _ in 0..<20 { prompt = promptNow(); if !prompt.isEmpty { break }; Thread.sleep(forTimeInterval: 0.5) }
            guard !prompt.isEmpty else { print("ROUND \(round): לא נמצאה שאלה"); break }
            // 💫 a bonus question is MEANT to stay put on a wrong answer.
            let bonus = !labels(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "💫")), in: 0...1).isEmpty
            if prompt == seen.last, !bonus { repeats.append("\(round): \(prompt)") }
            seen.append(prompt)

            // ONLY the four answer tiles: their label starts with the value
            // ("44, 1") and they carry no identifier. Anything else in that band
            // is a tool button — the 🚩 flag one really does file a report and
            // email the team, so the filter here is a safety rule, not a detail.
            var picked = false
            let buttons = app.buttons
            for i in 0..<buttons.count {
                let b = buttons.element(boundBy: i)
                guard b.exists, b.identifier.isEmpty, b.isHittable else { continue }
                let y = b.frame.midY / screen.height
                guard y > 0.45, y < 0.80, b.label.first?.isNumber == true else { continue }
                b.tap(); picked = true; break
            }
            guard picked else { print("ROUND \(round): אין אפשרויות"); break }
            Thread.sleep(forTimeInterval: 2.8)
        }
        print("PROMPTS SEEN: \(seen)")
        print("REPEATS: \(repeats)")
        XCTAssertTrue(repeats.isEmpty, "אותה שאלה הוצגה שוב מיד אחרי תשובה: \(repeats)")
        XCTAssertGreaterThanOrEqual(seen.count, 7, "לא נאספו מספיק שאלות")
    }
}

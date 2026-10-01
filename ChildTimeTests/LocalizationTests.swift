import XCTest
@testable import ChildTime

/// 🌍 The language switch: Hebrew must come back byte-for-byte as written, and
/// English must switch at runtime without touching the device language.
final class LocalizationTests: XCTestCase {
    override func tearDown() { LanguageStore.shared.setForTesting(.he); super.tearDown() }

    func testHebrewReturnsTheOriginalText() {
        LanguageStore.shared.setForTesting(.he)
        XCTAssertEqual(tr("שָׁלוֹם"), "שָׁלוֹם")
        XCTAssertEqual(tr("יֵשׁ לְךָ \(5) דַּקּוֹת"), "יֵשׁ לְךָ 5 דַּקּוֹת")
        XCTAssertEqual(tr("מִשְׁפָּט שֶׁאֵין לוֹ תַּרְגּוּם"), "מִשְׁפָּט שֶׁאֵין לוֹ תַּרְגּוּם")
    }

    func testEnglishSwitchesInstantly() {
        LanguageStore.shared.setForTesting(.en)
        XCTAssertEqual(tr("שָׁלוֹם"), "Hello")
        XCTAssertEqual(tr("יֵשׁ לְךָ \(5) דַּקּוֹת"), "You have 5 minutes")
        let name = "Dana"
        XCTAssertEqual(tr("שָׁלוֹם, \(name)"), "Hi, Dana")
        LanguageStore.shared.setForTesting(.he)
        XCTAssertEqual(tr("שָׁלוֹם"), "שָׁלוֹם", "switching back must be instant too")
    }

    /// Interpolated strings must not pick up invisible isolate marks in Hebrew —
    /// the read-aloud script compares byte-for-byte.
    func testHebrewInterpolationIsByteIdentical() {
        LanguageStore.shared.setForTesting(.he)
        let word = "רִאשׁוֹנָה"
        XCTAssertEqual(tr("תְּשׁוּבָה \(word)"), "תְּשׁוּבָה רִאשׁוֹנָה")
        let math = "\u{2066}3 + 4\u{2069}"
        XCTAssertEqual(tr("תַּרְגִּיל \(math)"), "תַּרְגִּיל \u{2066}3 + 4\u{2069}", "the app's own math isolates stay")
    }

    /// A brand-new install follows the iPhone; an Israeli English iPhone and every
    /// install from before languages stay Hebrew.
    func testFirstLaunchLanguage() {
        let fresh = UserDefaults(suiteName: "test.firstLaunch.\(UUID().uuidString)")!
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["en-US"], defaults: fresh), .en)
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["en-GB"], defaults: fresh), .en)
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["en-IL", "he-IL"], defaults: fresh), .he)
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["he-IL"], defaults: fresh), .he)
        // A Russian-speaking phone opens in Russian wherever it is — including in
        // Israel, where the family's child still goes to an Israeli school. That is
        // the opposite of the English rule one line above, and deliberately so.
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["ru-IL"], defaults: fresh), .ru)
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["ru-RU"], defaults: fresh), .ru)
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["ar-SA"], defaults: fresh), .ar)
        let existing = UserDefaults(suiteName: "test.firstLaunch.\(UUID().uuidString)")!
        existing.set(true, forKey: "onboardingCompleted")
        XCTAssertEqual(LanguageStore.firstLaunchLanguage(preferred: ["en-US"], defaults: existing), .he, "an existing family never flips to English")
    }

    /// …and a line with no left-to-right words of its own is not forced
    /// left-to-right: the sentence wrapper exists to stop a digit joining the
    /// Hebrew side, and there is nothing here for it to settle.
    func testMissingTranslationFallsBackToHebrew() {
        LanguageStore.shared.setForTesting(.en)
        XCTAssertEqual(tr("מִשְׁפָּט שֶׁאֵין לוֹ תַּרְגּוּם"), "\u{2067}מִשְׁפָּט שֶׁאֵין לוֹ תַּרְגּוּם\u{2069}")
    }

    /// A Hebrew name inside a translated piece inside another translated string
    /// (PackDetailView's "✓ Unlocked for דנה · 30 days left") — one flat
    /// right-to-left isolate around the name, no nested Foundation isolates.
    func testHebrewNameInNestedEnglishIsIsolatedOnce() {
        LanguageStore.shared.setForTesting(.en)
        let name = "דָּנָה כֹּהֵן"
        let part = tr("\(name)\(tr(" · עוֹד \(30) יוֹם"))")
        XCTAssertEqual(tr("✓ פָּתוּחַ לְ\(part)"),
                       "\u{2066}✓ Unlocked for \u{2067}דָּנָה כֹּהֵן\u{2069} · 30 days left\u{2069}",
                       "one isolate around the name, and ONE sentence wrapper — not a wrapper per nesting level")
    }

    /// The app's own math isolates are U+2066 too — the same scalar as the sentence
    /// wrapper a nested piece leaves behind. Flattening must tell them apart by
    /// what they hold and leave the math alone.
    ///
    /// This key has no English translation, so it falls back to Hebrew: the Hebrew
    /// becomes one right-to-left run, the math isolate survives untouched, and no
    /// sentence wrapper is added because there is no left-to-right word to settle.
    func testMathIsolatesSurviveBesideAHebrewName() {
        LanguageStore.shared.setForTesting(.en)
        let name = "דָּנָה"
        let math = "\u{2066}3 + 4\u{2069}"
        XCTAssertEqual(tr("\(name) פָּתְרָה \(math)"),
                       "\u{2067}דָּנָה פָּתְרָה\u{2069} \u{2066}3 + 4\u{2069}")
    }
}

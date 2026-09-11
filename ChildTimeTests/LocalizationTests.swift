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
        XCTAssertEqual(tr("✓ פָּתוּחַ לְ\(part)"), "✓ Unlocked for \u{2067}דָּנָה כֹּהֵן\u{2069} · 30 days left")
    }
}

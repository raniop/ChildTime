import Foundation
import SwiftUI

// 🎚️ How hard a mini-game is for THIS child (Rani, 2026-10-04, after playing
// the twelve games himself: "יש משחקים שהם לא מותאמים גיל והם קלים מדיי, למשל
// לרשום את המילה בעברית לכיתה ו … גם צריך לראות בדיוק מה מתאים לאיזה כיתה").
//
// Two things live here:
//
//   1️⃣ `MiniGameBand` — the five rungs every game scales on, so "ה׳–ו׳" means
//      the same thing in the word search as it does in the balance.
//   2️⃣ `MiniGameGradeFit` — the game × grade table: the band a game is worth
//      offering in at all. A board that is trivially easy for a grade is not
//      "a quick win", it is a child learning that Tofy is for little kids —
//      so it simply does not appear in that grade's chooser.
//
// 🗣️ The one rule that shapes everything below: **a mother tongue and a
// foreign language are not the same subject.** Hebrew is what an Israeli child
// already speaks — by ה׳ a Hebrew board must be genuinely demanding. English
// starts in ג׳ as a foreign language, so its curve stays gentle all the way up
// (Rani: "תפזורת באנגלית זה בסדר גם לכיתה ו, אבל בעברית זה קל מידי"). A Russian
// or Arabic speaker gets the same split: their own language scales like Hebrew,
// English stays English.

// MARK: - 🎚️ The five rungs

enum MiniGameBand: Int, Comparable, CaseIterable {
    case preReader = 0   // גן — not a reader yet
    case lower = 1       // א׳–ב׳
    case middle = 2      // ג׳–ד׳
    case upper = 3       // ה׳–ו׳
    case top = 4         // ז׳–ח׳

    static func < (a: MiniGameBand, b: MiniGameBand) -> Bool { a.rawValue < b.rawValue }

    static func of(_ grade: Int) -> MiniGameBand {
        switch grade {
        case ..<1:  return .preReader
        case 1, 2:  return .lower
        case 3, 4:  return .middle
        case 5, 6:  return .upper
        default:    return .top
        }
    }

    /// Parent-facing, no niqqud — this label only ever reaches the fit report.
    var hebrewName: String {
        switch self {
        case .preReader: return "גן"
        case .lower:     return "א׳–ב׳"
        case .middle:    return "ג׳–ד׳"
        case .upper:     return "ה׳–ו׳"
        case .top:       return "ז׳–ח׳"
        }
    }
}

extension SpellScript {
    /// Is this a language the child reads at SCHOOL level — their own tongue,
    /// or the one their school teaches them to write in? That is the side that
    /// has to scale hard.
    ///
    /// 🇷🇺 🇦🇪 A Russian- or Arabic-speaking child in Israel goes to an Israeli
    /// school and learns Hebrew spelling there, so Hebrew counts for them too
    /// (the same reasoning that keeps the Hebrew world visible for them in
    /// `ContentAvailability`). English never does — for all three it is the
    /// foreign language that starts in ג׳.
    var isMotherTongue: Bool {
        let language = LanguageStore.shared.current
        switch self {
        case .hebrew:   return language.isIsraeli
        case .english:  return language == .en
        case .cyrillic: return language == .ru
        case .arabic:   return language == .ar
        }
    }

    /// A foreign language the child is only learning to read (English for an
    /// Israeli child). Its boards stay approachable at every grade.
    var isSecondLanguage: Bool { !isMotherTongue }
}

// MARK: - 🧩 The game × grade table

/// The grade band each game is worth offering in. Below the floor the mechanic
/// is beyond the child; above the ceiling the board is a gift, not a game.
enum MiniGameGradeFit {

    /// Is this game worth putting in front of this child at all?
    /// `script` is the board's alphabet where a game has one (🧩 🔤).
    static func offered(_ kind: MiniGameKind, grade: Int, script: SpellScript? = nil,
                        topic: Topic? = nil) -> Bool {
        let band = MiniGameBand.of(grade)
        // 👶 גן is a pre-reader: every one of the twelve shows words, numbers or
        // labels. The runner's picture questions are that child's game.
        guard band > .preReader else { return false }
        switch kind {
        case .word:
            // 🧩 Letter-by-letter spelling. In the mother tongue it stays real
            // work to ח׳ (the ladder grows with the child). In a second
            // language it starts in ג׳, when English starts at school, and
            // stops after ו׳ — a ז׳ child ordering the letters of "apple" is
            // not a game. The word search still is.
            guard let script, script.isSecondLanguage else { return true }
            return grade >= 3 && band <= .upper
        case .wordSearch:
            // 🔤 The grid, the diagonals and the backwards words keep this one
            // alive to ח׳ in both languages — Rani played the English board at
            // ו׳ and called it right. In a second language it still waits for
            // ג׳, when that language starts at school.
            guard let script, script.isSecondLanguage else { return true }
            return grade >= 3
        case .game2048:
            // 🔢 Doubling to 2048 and planning a board: from ג׳.
            return band >= .middle
        case .vault:
            // 🔐 Earning clues and reasoning a code out of them: from ב׳. In
            // א׳–ב׳ a clue names a digit outright ("הַסִּפְרָה הָרִאשׁוֹנָה הִיא 3"),
            // so the work is holding three facts at once; א׳ is still a year
            // too early for that.
            return grade >= 2
        case .pattern:
            // 🧠 In the number worlds the sequences climb to cubes and
            // Fibonacci. In the language worlds it is an alphabet step — real
            // work to ה׳, a freebie after it.
            if topic == .english || topic == .hebrew { return grade <= 5 }
            return true
        case .pairs, .balloon, .crush, .lightning, .sort, .grocery, .balance:
            return true
        }
    }

    /// Every grade this game is offered in (1…8) — the fit report's row.
    static func grades(_ kind: MiniGameKind, script: SpellScript? = nil, topic: Topic? = nil) -> [Int] {
        (1...8).filter { offered(kind, grade: $0, script: script, topic: topic) }
    }
}

// MARK: - 🔤 The Hebrew word ladder

/// One rung of a spelling ladder: the picture that is the only clue, the word
/// as its tiles spell it (no niqqud — a shuffled tile cannot carry one), and
/// the band it belongs to.
struct LadderWord {
    let band: MiniGameBand
    let emoji: String
    let word: String
}

/// 🇮🇱 Hebrew spelling, rung by rung. The mother tongue, so it climbs steeply:
///
///   א׳–ב׳  2–4 letters, the first words a child writes (כלב, בית, שמש).
///   ג׳–ד׳  5–6 letters with the traps of those years (מחברת, עיפרון, מטרייה).
///   ה׳–ו׳  6–8 letters, multi-syllable, מילים לועזיות, ו/י אם קריאה
///          (לווייתן, מיקרופון, גלגיליות) — never כלב / בית / ספר again.
///   ז׳–ח׳  7–9 letters a teenager still has to stop and think about
///          (מיקרוסקופ, תיאטרון, אורנגאוטן, סוכרייה).
///
/// Every word here is picture-clear: the emoji alone has to name it, because
/// in "בְּנוּ אֶת הַמִּלָּה" the picture is the whole clue.
enum HebrewLadder {
    static let general: [LadderWord] = [
        // א׳–ב׳
        LadderWord(band: .lower, emoji: "🐶", word: "כלב"),
        LadderWord(band: .lower, emoji: "🐱", word: "חתול"),
        LadderWord(band: .lower, emoji: "🏠", word: "בית"),
        LadderWord(band: .lower, emoji: "📖", word: "ספר"),
        LadderWord(band: .lower, emoji: "🌳", word: "עץ"),
        LadderWord(band: .lower, emoji: "☀️", word: "שמש"),
        LadderWord(band: .lower, emoji: "🌸", word: "פרח"),
        LadderWord(band: .lower, emoji: "🍎", word: "תפוח"),
        LadderWord(band: .lower, emoji: "⚽", word: "כדור"),
        LadderWord(band: .lower, emoji: "💧", word: "מים"),
        LadderWord(band: .lower, emoji: "🍞", word: "לחם"),
        LadderWord(band: .lower, emoji: "🥛", word: "חלב"),
        LadderWord(band: .lower, emoji: "🐟", word: "דג"),
        LadderWord(band: .lower, emoji: "🐴", word: "סוס"),
        LadderWord(band: .lower, emoji: "🐄", word: "פרה"),
        LadderWord(band: .lower, emoji: "🥚", word: "ביצה"),
        LadderWord(band: .lower, emoji: "🌙", word: "ירח"),
        LadderWord(band: .lower, emoji: "⭐", word: "כוכב"),
        LadderWord(band: .lower, emoji: "☁️", word: "ענן"),
        LadderWord(band: .lower, emoji: "❄️", word: "שלג"),
        LadderWord(band: .lower, emoji: "🥕", word: "גזר"),
        LadderWord(band: .lower, emoji: "👟", word: "נעל"),
        LadderWord(band: .lower, emoji: "🚪", word: "דלת"),
        LadderWord(band: .lower, emoji: "🎩", word: "כובע"),
        LadderWord(band: .lower, emoji: "🍌", word: "בננה"),
        LadderWord(band: .lower, emoji: "🍃", word: "עלה"),
        // ג׳–ד׳
        LadderWord(band: .middle, emoji: "📒", word: "מחברת"),
        LadderWord(band: .middle, emoji: "✏️", word: "עיפרון"),
        LadderWord(band: .middle, emoji: "🚗", word: "מכונית"),
        LadderWord(band: .middle, emoji: "☂️", word: "מטרייה"),
        LadderWord(band: .middle, emoji: "🐸", word: "צפרדע"),
        LadderWord(band: .middle, emoji: "🐓", word: "תרנגול"),
        LadderWord(band: .middle, emoji: "🥾", word: "מגפיים"),
        LadderWord(band: .middle, emoji: "🧦", word: "גרביים"),
        LadderWord(band: .middle, emoji: "👕", word: "חולצה"),
        LadderWord(band: .middle, emoji: "🧳", word: "מזוודה"),
        LadderWord(band: .middle, emoji: "📷", word: "מצלמה"),
        LadderWord(band: .middle, emoji: "🪥", word: "מברשת"),
        LadderWord(band: .middle, emoji: "🚿", word: "מקלחת"),
        LadderWord(band: .middle, emoji: "🛁", word: "אמבטיה"),
        LadderWord(band: .middle, emoji: "💡", word: "מנורה"),
        LadderWord(band: .middle, emoji: "🍉", word: "אבטיח"),
        LadderWord(band: .middle, emoji: "🍑", word: "אפרסק"),
        LadderWord(band: .middle, emoji: "🍄", word: "פטרייה"),
        LadderWord(band: .middle, emoji: "🍦", word: "גלידה"),
        LadderWord(band: .middle, emoji: "🍪", word: "עוגייה"),
        LadderWord(band: .middle, emoji: "🍫", word: "שוקולד"),
        LadderWord(band: .middle, emoji: "⛲", word: "מזרקה"),
        LadderWord(band: .middle, emoji: "🚦", word: "רמזור"),
        LadderWord(band: .middle, emoji: "🚢", word: "אונייה"),
        LadderWord(band: .middle, emoji: "🍒", word: "דובדבן"),
        LadderWord(band: .middle, emoji: "🥒", word: "מלפפון"),
        LadderWord(band: .middle, emoji: "🐙", word: "תמנון"),
        LadderWord(band: .middle, emoji: "🐬", word: "דולפין"),
        LadderWord(band: .middle, emoji: "🦉", word: "ינשוף"),
        LadderWord(band: .middle, emoji: "🦘", word: "קנגורו"),
        LadderWord(band: .middle, emoji: "🐌", word: "חילזון"),
        LadderWord(band: .middle, emoji: "🦗", word: "חרגול"),
        LadderWord(band: .middle, emoji: "🐝", word: "כוורת"),
        LadderWord(band: .middle, emoji: "🍓", word: "תותים"),
        // ה׳–ו׳
        LadderWord(band: .upper, emoji: "✂️", word: "מספריים"),
        LadderWord(band: .upper, emoji: "🚲", word: "אופניים"),
        LadderWord(band: .upper, emoji: "👖", word: "מכנסיים"),
        LadderWord(band: .upper, emoji: "👓", word: "משקפיים"),
        LadderWord(band: .upper, emoji: "🚌", word: "אוטובוס"),
        LadderWord(band: .upper, emoji: "🍅", word: "עגבנייה"),
        LadderWord(band: .upper, emoji: "🔭", word: "טלסקופ"),
        LadderWord(band: .upper, emoji: "🚑", word: "אמבולנס"),
        LadderWord(band: .upper, emoji: "🎹", word: "פסנתר"),
        LadderWord(band: .upper, emoji: "🎺", word: "חצוצרה"),
        LadderWord(band: .upper, emoji: "🎷", word: "סקסופון"),
        LadderWord(band: .upper, emoji: "🎤", word: "מיקרופון"),
        LadderWord(band: .upper, emoji: "📺", word: "טלוויזיה"),
        LadderWord(band: .upper, emoji: "🎧", word: "אוזניות"),
        LadderWord(band: .upper, emoji: "🧮", word: "מחשבון"),
        LadderWord(band: .upper, emoji: "🚜", word: "טרקטור"),
        LadderWord(band: .upper, emoji: "🗼", word: "מגדלור"),
        LadderWord(band: .upper, emoji: "🎡", word: "קרוסלה"),
        LadderWord(band: .upper, emoji: "🛼", word: "גלגיליות"),
        LadderWord(band: .upper, emoji: "🎿", word: "מגלשיים"),
        LadderWord(band: .upper, emoji: "🐳", word: "לווייתן"),
        LadderWord(band: .upper, emoji: "🐧", word: "פינגווין"),
        LadderWord(band: .upper, emoji: "🦩", word: "פלמינגו"),
        LadderWord(band: .upper, emoji: "🐵", word: "שימפנזה"),
        LadderWord(band: .upper, emoji: "🎻", word: "תזמורת"),
        LadderWord(band: .upper, emoji: "🥦", word: "ברוקולי"),
        LadderWord(band: .upper, emoji: "🍔", word: "המבורגר"),
        LadderWord(band: .upper, emoji: "🥐", word: "קרואסון"),
        LadderWord(band: .upper, emoji: "🍩", word: "סופגנייה"),
        LadderWord(band: .upper, emoji: "🥞", word: "פנקייק"),
        LadderWord(band: .upper, emoji: "🌻", word: "חמניות"),
        LadderWord(band: .upper, emoji: "🫖", word: "קומקום"),
        LadderWord(band: .upper, emoji: "🪸", word: "אלמוגים"),
        LadderWord(band: .upper, emoji: "☄️", word: "מטאוריט"),
        LadderWord(band: .upper, emoji: "🌌", word: "גלקסיה"),
        LadderWord(band: .upper, emoji: "🛰️", word: "לוויין"),
        LadderWord(band: .upper, emoji: "🪗", word: "אקורדיון"),
        // ז׳–ח׳
        LadderWord(band: .top, emoji: "🔬", word: "מיקרוסקופ"),
        LadderWord(band: .top, emoji: "👨‍🚀", word: "אסטרונאוט"),
        LadderWord(band: .top, emoji: "🚁", word: "הליקופטר"),
        LadderWord(band: .top, emoji: "🐠", word: "אקווריום"),
        LadderWord(band: .top, emoji: "🩺", word: "סטטוסקופ"),
        LadderWord(band: .top, emoji: "🎶", word: "קסילופון"),
        LadderWord(band: .top, emoji: "🛹", word: "סקייטבורד"),
        LadderWord(band: .top, emoji: "🦛", word: "היפופוטם"),
        LadderWord(band: .top, emoji: "🐊", word: "קרוקודיל"),
        LadderWord(band: .top, emoji: "🌊", word: "אוקיינוס"),
        LadderWord(band: .top, emoji: "🚋", word: "חשמלית"),
        LadderWord(band: .top, emoji: "🦎", word: "סלמנדרה"),
        LadderWord(band: .top, emoji: "🦕", word: "דינוזאור"),
        LadderWord(band: .top, emoji: "🥑", word: "אבוקדו"),
        LadderWord(band: .top, emoji: "🩰", word: "בלרינה"),
        LadderWord(band: .top, emoji: "🎆", word: "זיקוקים"),
        LadderWord(band: .top, emoji: "🦧", word: "אורנגאוטן"),
        LadderWord(band: .top, emoji: "🛴", word: "קורקינט"),
        LadderWord(band: .top, emoji: "🌺", word: "אורכידאה"),
        LadderWord(band: .top, emoji: "🎭", word: "תיאטרון"),
        LadderWord(band: .top, emoji: "🍬", word: "סוכרייה"),
        LadderWord(band: .top, emoji: "🧁", word: "קאפקייק"),
        LadderWord(band: .top, emoji: "🥤", word: "מילקשייק"),
        LadderWord(band: .top, emoji: "🍋", word: "לימונדה"),
        LadderWord(band: .top, emoji: "🥜", word: "בוטנים"),
        LadderWord(band: .top, emoji: "🐯", word: "טיגריס"),
        LadderWord(band: .top, emoji: "🪂", word: "מצנחים"),
    ]

    static let soccer: [LadderWord] = [
        LadderWord(band: .lower, emoji: "⚽", word: "כדור"),
        LadderWord(band: .lower, emoji: "🥅", word: "שער"),
        LadderWord(band: .lower, emoji: "👟", word: "נעל"),
        LadderWord(band: .lower, emoji: "🚩", word: "דגל"),
        LadderWord(band: .lower, emoji: "🏆", word: "גביע"),
        LadderWord(band: .middle, emoji: "📣", word: "אוהדים"),
        LadderWord(band: .middle, emoji: "👥", word: "קבוצה"),
        LadderWord(band: .middle, emoji: "🦵", word: "בעיטה"),
        LadderWord(band: .middle, emoji: "🟨", word: "כרטיס"),
        LadderWord(band: .middle, emoji: "⏱️", word: "מחצית"),
        LadderWord(band: .middle, emoji: "🧤", word: "כפפות"),
        LadderWord(band: .upper, emoji: "🏟️", word: "אצטדיון"),
        LadderWord(band: .upper, emoji: "🏅", word: "אליפות"),
        LadderWord(band: .upper, emoji: "🌍", word: "מונדיאל"),
        LadderWord(band: .upper, emoji: "🥈", word: "מדליה"),
        LadderWord(band: .upper, emoji: "🥇", word: "תחרות"),
        LadderWord(band: .top, emoji: "🧑‍⚖️", word: "שופטים"),
        LadderWord(band: .top, emoji: "🏃", word: "ספורטאי"),
    ]

    static let sea: [LadderWord] = [
        LadderWord(band: .lower, emoji: "🐟", word: "דג"),
        LadderWord(band: .lower, emoji: "🌊", word: "ים"),
        LadderWord(band: .lower, emoji: "🦀", word: "סרטן"),
        LadderWord(band: .lower, emoji: "🦈", word: "כריש"),
        LadderWord(band: .lower, emoji: "🐚", word: "צדף"),
        LadderWord(band: .middle, emoji: "🐙", word: "תמנון"),
        LadderWord(band: .middle, emoji: "🐬", word: "דולפין"),
        LadderWord(band: .middle, emoji: "🪼", word: "מדוזה"),
        LadderWord(band: .middle, emoji: "🦑", word: "דיונון"),
        LadderWord(band: .middle, emoji: "🦭", word: "כלבים"),
        LadderWord(band: .upper, emoji: "🐳", word: "לווייתן"),
        LadderWord(band: .upper, emoji: "🪸", word: "אלמוגים"),
        LadderWord(band: .upper, emoji: "🐧", word: "פינגווין"),
        LadderWord(band: .upper, emoji: "⛵", word: "מפרשית"),
        LadderWord(band: .upper, emoji: "🤿", word: "צוללן"),
        LadderWord(band: .top, emoji: "🌊", word: "אוקיינוס"),
        LadderWord(band: .top, emoji: "🐠", word: "אקווריום"),
        LadderWord(band: .top, emoji: "🐊", word: "קרוקודיל"),
        LadderWord(band: .top, emoji: "🦛", word: "היפופוטם"),
    ]

    static let space: [LadderWord] = [
        LadderWord(band: .lower, emoji: "☀️", word: "שמש"),
        LadderWord(band: .lower, emoji: "🌙", word: "ירח"),
        LadderWord(band: .lower, emoji: "⭐", word: "כוכב"),
        LadderWord(band: .lower, emoji: "🚀", word: "חללית"),
        LadderWord(band: .lower, emoji: "👽", word: "חייזר"),
        LadderWord(band: .middle, emoji: "🔴", word: "מאדים"),
        LadderWord(band: .middle, emoji: "🪐", word: "שבתאי"),
        LadderWord(band: .middle, emoji: "🛰️", word: "לוויין"),
        LadderWord(band: .middle, emoji: "☄️", word: "מטאור"),
        LadderWord(band: .middle, emoji: "🔵", word: "נפטון"),
        LadderWord(band: .upper, emoji: "🔭", word: "טלסקופ"),
        LadderWord(band: .upper, emoji: "🌌", word: "גלקסיה"),
        LadderWord(band: .upper, emoji: "☄️", word: "מטאוריט"),
        LadderWord(band: .upper, emoji: "🟢", word: "אורנוס"),
        LadderWord(band: .top, emoji: "👨‍🚀", word: "אסטרונאוט"),
        LadderWord(band: .top, emoji: "🔭", word: "טלסקופים"),
        LadderWord(band: .top, emoji: "☄️", word: "מטאוריטים"),
    ]

    static let animals: [LadderWord] = [
        LadderWord(band: .lower, emoji: "🐶", word: "כלב"),
        LadderWord(band: .lower, emoji: "🐱", word: "חתול"),
        LadderWord(band: .lower, emoji: "🐴", word: "סוס"),
        LadderWord(band: .lower, emoji: "🐘", word: "פיל"),
        LadderWord(band: .lower, emoji: "🦁", word: "אריה"),
        LadderWord(band: .lower, emoji: "🐒", word: "קוף"),
        LadderWord(band: .lower, emoji: "🐄", word: "פרה"),
        LadderWord(band: .middle, emoji: "🐸", word: "צפרדע"),
        LadderWord(band: .middle, emoji: "🐓", word: "תרנגול"),
        LadderWord(band: .middle, emoji: "🦉", word: "ינשוף"),
        LadderWord(band: .middle, emoji: "🦘", word: "קנגורו"),
        LadderWord(band: .middle, emoji: "🐌", word: "חילזון"),
        LadderWord(band: .middle, emoji: "🦗", word: "חרגול"),
        LadderWord(band: .middle, emoji: "🐬", word: "דולפין"),
        LadderWord(band: .upper, emoji: "🐧", word: "פינגווין"),
        LadderWord(band: .upper, emoji: "🦩", word: "פלמינגו"),
        LadderWord(band: .upper, emoji: "🐵", word: "שימפנזה"),
        LadderWord(band: .upper, emoji: "🐳", word: "לווייתן"),
        LadderWord(band: .upper, emoji: "🦇", word: "עטלפים"),
        LadderWord(band: .top, emoji: "🦛", word: "היפופוטם"),
        LadderWord(band: .top, emoji: "🐊", word: "קרוקודיל"),
        LadderWord(band: .top, emoji: "🦧", word: "אורנגאוטן"),
        LadderWord(band: .top, emoji: "🦎", word: "סלמנדרה"),
        LadderWord(band: .top, emoji: "🐯", word: "טיגריס"),
    ]

    static let dinosaurs: [LadderWord] = [
        LadderWord(band: .lower, emoji: "🦴", word: "עצם"),
        LadderWord(band: .lower, emoji: "🥚", word: "ביצה"),
        LadderWord(band: .lower, emoji: "🦷", word: "שן"),
        LadderWord(band: .lower, emoji: "🍃", word: "עלה"),
        LadderWord(band: .lower, emoji: "🪨", word: "סלע"),
        LadderWord(band: .middle, emoji: "🦎", word: "זוחלים"),
        LadderWord(band: .middle, emoji: "🌿", word: "צמחים"),
        LadderWord(band: .middle, emoji: "🧊", word: "קרחון"),
        LadderWord(band: .middle, emoji: "🦌", word: "קרניים"),
        LadderWord(band: .upper, emoji: "🦕", word: "דינוזאור"),
        LadderWord(band: .upper, emoji: "🦴", word: "מאובנים"),
        LadderWord(band: .upper, emoji: "🐊", word: "תנינים"),
        LadderWord(band: .top, emoji: "🦖", word: "סטגוזאור"),
        LadderWord(band: .top, emoji: "🦕", word: "טריצרטופס"),
    ]

    static let flags: [LadderWord] = [
        LadderWord(band: .lower, emoji: "🚩", word: "דגל"),
        LadderWord(band: .lower, emoji: "🗺️", word: "מפה"),
        LadderWord(band: .lower, emoji: "🏙️", word: "עיר"),
        LadderWord(band: .lower, emoji: "🏝️", word: "אי"),
        LadderWord(band: .lower, emoji: "✈️", word: "מטוס"),
        LadderWord(band: .middle, emoji: "🚢", word: "אונייה"),
        LadderWord(band: .middle, emoji: "🏳️", word: "מדינה"),
        LadderWord(band: .middle, emoji: "🧳", word: "מזוודה"),
        LadderWord(band: .middle, emoji: "🌐", word: "גלובוס"),
        LadderWord(band: .upper, emoji: "🌏", word: "יבשות"),
        LadderWord(band: .upper, emoji: "🚌", word: "אוטובוס"),
        LadderWord(band: .upper, emoji: "🗼", word: "מגדלור"),
        LadderWord(band: .upper, emoji: "🏜️", word: "מדבריות"),
        LadderWord(band: .top, emoji: "🌊", word: "אוקיינוס"),
        LadderWord(band: .top, emoji: "🏛️", word: "אקרופוליס"),
    ]

    static func themed(_ topic: Topic?) -> [LadderWord]? {
        switch topic {
        case .soccer?:    return soccer
        case .sea?:       return sea
        case .space?:     return space
        case .animals?:   return animals
        case .dinosaurs?: return dinosaurs
        case .flags?:     return flags
        default:          return nil
        }
    }

    /// The words for one board. The rung the child is on first, the rung below
    /// it only as filler — so a ה׳ child never meets כלב, and a ז׳ child never
    /// meets מחברת. `maxLetters` is what the screen can actually hold (a word
    /// search's grid, a row of spelling slots).
    static func words(topic: Topic?, grade: Int, maxLetters: Int, minimum: Int) -> [SpellWord] {
        let band = MiniGameBand.of(grade)
        let source = (themed(topic) ?? general)
        func pick(_ list: [LadderWord], _ b: MiniGameBand) -> [SpellWord] {
            list.filter { $0.band == b && $0.word.count <= maxLetters }
                .shuffled()
                .map { SpellWord(emoji: $0.emoji, word: $0.word) }
        }
        var out = pick(source, band)
        // Not enough on the rung itself? Top up from the general ladder at the
        // SAME rung before ever stepping down a band.
        if out.count < minimum, themed(topic) != nil {
            out += pick(general, band).filter { w in !out.contains(where: { $0.word == w.word }) }
        }
        if out.count < minimum, let below = MiniGameBand(rawValue: band.rawValue - 1), below > .preReader {
            let filler = pick(source, below) + pick(general, below)
            out += filler.filter { w in !out.contains(where: { $0.word == w.word }) }
        }
        return out
    }
}

/// 🇺🇸 English spelling. A foreign language that starts in ג׳, so the curve is
/// deliberately flat: ג׳–ד׳ the first three- and four-letter words, ה׳ and up
/// the everyday vocabulary of a school textbook. Nothing here gets "harder for
/// ח׳" — Rani played the ו׳ board and said the level is right, and a ח׳ child
/// learning a second language is not a ח׳ child writing Hebrew.
enum EnglishLadder {
    static let firstWords: [LadderWord] = [
        LadderWord(band: .middle, emoji: "🐱", word: "cat"),
        LadderWord(band: .middle, emoji: "🐶", word: "dog"),
        LadderWord(band: .middle, emoji: "☀️", word: "sun"),
        LadderWord(band: .middle, emoji: "🎩", word: "hat"),
        LadderWord(band: .middle, emoji: "🛏️", word: "bed"),
        LadderWord(band: .middle, emoji: "🚌", word: "bus"),
        LadderWord(band: .middle, emoji: "🥚", word: "egg"),
        LadderWord(band: .middle, emoji: "🦊", word: "fox"),
        LadderWord(band: .middle, emoji: "📦", word: "box"),
        LadderWord(band: .middle, emoji: "🐟", word: "fish"),
        LadderWord(band: .middle, emoji: "⭐", word: "star"),
        LadderWord(band: .middle, emoji: "🌳", word: "tree"),
        LadderWord(band: .middle, emoji: "🐦", word: "bird"),
        LadderWord(band: .middle, emoji: "✋", word: "hand"),
        LadderWord(band: .middle, emoji: "🧢", word: "cap"),
        LadderWord(band: .middle, emoji: "🗝️", word: "key"),
    ]

    static let everyday: [LadderWord] = [
        LadderWord(band: .upper, emoji: "🍎", word: "apple"),
        LadderWord(band: .upper, emoji: "🏠", word: "house"),
        LadderWord(band: .upper, emoji: "🪑", word: "chair"),
        LadderWord(band: .upper, emoji: "🚆", word: "train"),
        LadderWord(band: .upper, emoji: "💧", word: "water"),
        LadderWord(band: .upper, emoji: "🍞", word: "bread"),
        LadderWord(band: .upper, emoji: "🕐", word: "clock"),
        LadderWord(band: .upper, emoji: "🐍", word: "snake"),
        LadderWord(band: .upper, emoji: "🐯", word: "tiger"),
        LadderWord(band: .upper, emoji: "🍕", word: "pizza"),
        LadderWord(band: .upper, emoji: "🌸", word: "flower"),
        LadderWord(band: .upper, emoji: "🦓", word: "zebra"),
        LadderWord(band: .upper, emoji: "🪟", word: "window"),
        LadderWord(band: .upper, emoji: "🍌", word: "banana"),
        LadderWord(band: .upper, emoji: "🧑‍🏫", word: "teacher"),
        LadderWord(band: .upper, emoji: "🐒", word: "monkey"),
        LadderWord(band: .upper, emoji: "🐰", word: "rabbit"),
        LadderWord(band: .upper, emoji: "🧺", word: "basket"),
        LadderWord(band: .upper, emoji: "✏️", word: "pencil"),
        LadderWord(band: .upper, emoji: "🏔️", word: "mountain"),
        LadderWord(band: .upper, emoji: "🦋", word: "butterfly"),
        LadderWord(band: .upper, emoji: "🚲", word: "bicycle"),
    ]

    /// 🇬🇧 And for a child whose OWN language is English — a family in the US,
    /// not an Israeli child in an English lesson — the same two rungs are far
    /// too kind by ה׳. These are the rungs that ladder is missing: the mirror
    /// of the Hebrew ones, picture-clear and genuinely long.
    static let nativeUpper: [LadderWord] = [
        LadderWord(band: .upper, emoji: "✂️", word: "scissors"),
        LadderWord(band: .upper, emoji: "🚲", word: "bicycle"),
        LadderWord(band: .upper, emoji: "👖", word: "trousers"),
        LadderWord(band: .upper, emoji: "👓", word: "glasses"),
        LadderWord(band: .upper, emoji: "🍅", word: "tomato"),
        LadderWord(band: .upper, emoji: "🔭", word: "telescope"),
        LadderWord(band: .upper, emoji: "🚑", word: "ambulance"),
        LadderWord(band: .upper, emoji: "🎹", word: "piano"),
        LadderWord(band: .upper, emoji: "🎺", word: "trumpet"),
        LadderWord(band: .upper, emoji: "🎧", word: "headphones"),
        LadderWord(band: .upper, emoji: "🚜", word: "tractor"),
        LadderWord(band: .upper, emoji: "🗼", word: "lighthouse"),
        LadderWord(band: .upper, emoji: "🎡", word: "carousel"),
        LadderWord(band: .upper, emoji: "🐳", word: "whale"),
        LadderWord(band: .upper, emoji: "🐧", word: "penguin"),
        LadderWord(band: .upper, emoji: "🦩", word: "flamingo"),
        LadderWord(band: .upper, emoji: "🎻", word: "orchestra"),
        LadderWord(band: .upper, emoji: "🥦", word: "broccoli"),
        LadderWord(band: .upper, emoji: "🍔", word: "hamburger"),
        LadderWord(band: .upper, emoji: "🥐", word: "croissant"),
        LadderWord(band: .upper, emoji: "🍩", word: "doughnut"),
        LadderWord(band: .upper, emoji: "🥞", word: "pancake"),
        LadderWord(band: .upper, emoji: "🌻", word: "sunflower"),
        LadderWord(band: .upper, emoji: "🫖", word: "kettle"),
        LadderWord(band: .upper, emoji: "🪸", word: "coral"),
        LadderWord(band: .upper, emoji: "🌌", word: "galaxy"),
        LadderWord(band: .upper, emoji: "🛰️", word: "satellite"),
        LadderWord(band: .upper, emoji: "🪗", word: "accordion"),
        LadderWord(band: .upper, emoji: "🎷", word: "saxophone"),
        LadderWord(band: .upper, emoji: "🍍", word: "pineapple"),
    ]

    static let nativeTop: [LadderWord] = [
        LadderWord(band: .top, emoji: "🔬", word: "microscope"),
        LadderWord(band: .top, emoji: "👨‍🚀", word: "astronaut"),
        LadderWord(band: .top, emoji: "🚁", word: "helicopter"),
        LadderWord(band: .top, emoji: "🐠", word: "aquarium"),
        LadderWord(band: .top, emoji: "🩺", word: "stethoscope"),
        LadderWord(band: .top, emoji: "🛹", word: "skateboard"),
        LadderWord(band: .top, emoji: "🐊", word: "crocodile"),
        LadderWord(band: .top, emoji: "🦧", word: "orangutan"),
        LadderWord(band: .top, emoji: "🦎", word: "salamander"),
        LadderWord(band: .top, emoji: "🦕", word: "dinosaur"),
        LadderWord(band: .top, emoji: "🥑", word: "avocado"),
        LadderWord(band: .top, emoji: "🩰", word: "ballerina"),
        LadderWord(band: .top, emoji: "🎆", word: "fireworks"),
        LadderWord(band: .top, emoji: "🛴", word: "scooter"),
        LadderWord(band: .top, emoji: "🌺", word: "orchid"),
        LadderWord(band: .top, emoji: "🎭", word: "theatre"),
        LadderWord(band: .top, emoji: "🍬", word: "lollipop"),
        LadderWord(band: .top, emoji: "🧁", word: "cupcake"),
        LadderWord(band: .top, emoji: "🥤", word: "milkshake"),
        LadderWord(band: .top, emoji: "🍋", word: "lemonade"),
        LadderWord(band: .top, emoji: "🥜", word: "peanuts"),
        LadderWord(band: .top, emoji: "☂️", word: "umbrella"),
        LadderWord(band: .top, emoji: "🧮", word: "calculator"),
        LadderWord(band: .top, emoji: "🎤", word: "microphone"),
        LadderWord(band: .top, emoji: "📺", word: "television"),
        LadderWord(band: .top, emoji: "🦋", word: "butterfly"),
        LadderWord(band: .top, emoji: "🐛", word: "caterpillar"),
        LadderWord(band: .top, emoji: "🌊", word: "waterfall"),
        LadderWord(band: .top, emoji: "🧳", word: "suitcase"),
        LadderWord(band: .top, emoji: "🥁", word: "percussion"),
    ]

    /// ג׳–ד׳ the first words; ה׳ and up the everyday list — and for a child
    /// learning English as a SECOND language that is the whole ladder, two
    /// rungs, on purpose (Rani: the ו׳ English board is already right). Where
    /// English is the child's own language it gets the full four rungs.
    static func words(grade: Int, maxLetters: Int, minimum: Int,
                      motherTongue: Bool = false) -> [SpellWord] {
        let band = MiniGameBand.of(grade)
        var rungs: [[LadderWord]]
        if motherTongue {
            switch band {
            case .preReader, .lower: rungs = [firstWords, everyday]
            case .middle:            rungs = [everyday, firstWords]
            case .upper:             rungs = [nativeUpper, everyday]
            case .top:               rungs = [nativeTop, nativeUpper]
            }
        } else {
            rungs = grade <= 4 ? [firstWords, everyday] : [everyday, firstWords]
        }
        var out: [SpellWord] = []
        for rung in rungs {
            let fresh = rung.filter { $0.word.count <= maxLetters }
                .shuffled().map { SpellWord(emoji: $0.emoji, word: $0.word) }
            out += fresh.filter { w in !out.contains(where: { $0.word == w.word }) }
            if out.count >= minimum { break }
        }
        return out
    }
}

// MARK: - 🔤 The word search's shape

/// How big the grid is, and which directions a word may hide in. Both grow
/// with the grade — but the mother-tongue board grows much faster, because
/// that is the language the child already reads fluently.
enum WordSearchShape {
    /// 6×6 for a first grader; up to 9×9 (10×10 on an iPad) for a ח׳ child
    /// reading their own language. A second-language board stays small.
    static func size(grade: Int, script: SpellScript, roomy: Bool) -> Int {
        let band = MiniGameBand.of(grade)
        if script.isSecondLanguage {
            // 🇺🇸 Gentle to the top: 6, then 7 from ה׳ (8 where there is room).
            let compact = band >= .upper ? 7 : 6
            return roomy ? compact + 1 : compact
        }
        switch band {
        case .preReader, .lower: return roomy ? 7 : 6
        case .middle:            return roomy ? 8 : 7
        case .upper:             return roomy ? 10 : 8
        case .top:               return roomy ? 10 : 9
        }
    }

    /// Diagonals: from ג׳ in the mother tongue, only from ה׳ in a second
    /// language (there the reading itself is still the work).
    static func diagonals(grade: Int, script: SpellScript) -> Bool {
        let band = MiniGameBand.of(grade)
        return script.isMotherTongue ? band >= .middle : band >= .upper
    }

    /// Words hidden back-to-front — ה׳ and up, and only in the mother tongue.
    /// A child still learning to read English left-to-right is not helped by
    /// a word spelled the other way.
    static func backwards(grade: Int, script: SpellScript) -> Bool {
        script.isMotherTongue && MiniGameBand.of(grade) >= .upper
    }
}

// MARK: - 🎯 How close the wrong answers sit

enum MiniGameDistractors {
    /// From ה׳ a wrong answer should be a near miss, not an obvious throwaway:
    /// the distractor that looks most like the real answer.
    static func pick(answer: String, from distractors: [String], grade: Int) -> String? {
        guard !distractors.isEmpty else { return nil }
        guard MiniGameBand.of(grade) >= .upper else { return distractors.randomElement() }
        let target = Question.stripNiqqud(answer)
        return distractors.min { a, b in
            closeness(target, Question.stripNiqqud(a)) < closeness(target, Question.stripNiqqud(b))
        }
    }

    /// Bigger = more alike. A shared opening, a shared ending and a similar
    /// length are what make two answers hard to tell apart on a card.
    private static func closeness(_ a: String, _ b: String) -> Int {
        if a == b { return -1 }
        let x = Array(a), y = Array(b)
        var head = 0
        while head < min(x.count, y.count), x[head] == y[head] { head += 1 }
        var tail = 0
        while tail < min(x.count, y.count) - head, x[x.count - 1 - tail] == y[y.count - 1 - tail] { tail += 1 }
        return head * 3 + tail * 2 - abs(x.count - y.count)
    }

    /// How far a wrong number may sit from the right one. A ח׳ child should
    /// have to actually compute; an off-by-ten slip is the interesting error.
    static func numericOffsets(answer: Int, grade: Int) -> [Int] {
        switch MiniGameBand.of(grade) {
        case .preReader, .lower:
            return [-2, -1, 1, 2]
        case .middle:
            var o = [-2, -1, 1, 2]
            if abs(answer) >= 20 { o += [-10, 10] }
            return o
        case .upper:
            // Near misses only, plus the classic place-value slip.
            var o = [-1, 1, -2, 2]
            if abs(answer) >= 20 { o += [-9, 9, 10, -10] }
            return o
        case .top:
            var o = [-1, 1, -2, 2]
            if abs(answer) >= 20 { o += [-9, 9, 11, -11] }
            // A sign error is the mistake worth catching once negatives are in.
            if answer != 0 { o.append(-2 * answer) }
            return o
        }
    }
}

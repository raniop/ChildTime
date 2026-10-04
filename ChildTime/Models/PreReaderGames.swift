import Foundation
import SwiftUI

// 👶 גן — mini-games for a child who cannot read a single word (Rani, after
// reading reports/games/grade-fit.md: "פצצה, צריך לעשות משחקים שהם מתאימים
// גם לגן!").
//
// The twelve games were all built around words, numerals and written labels,
// so גן was offered none of them. What follows is the other half of the
// problem: five of the twelve DO have a mechanic that survives with no text
// at all — pop, sort, match, continue, collect — and this file is the content
// that feeds them when the child is a pre-reader.
//
// Three rules shape every board here:
//
//   1️⃣ **Nothing readable on screen.** Pictures, colours and shapes only;
//      a quantity is shown as that many objects, never as a numeral.
//   2️⃣ **The instruction is spoken.** It cannot be printed, so it is read
//      aloud through `SpeechReader` when the round opens, and again whenever
//      the child taps the 🔊 on the round's cue card (`PreReaderCueCard`) —
//      a pre-reader can't re-read a reminder.
//   3️⃣ **Short, big and never on the clock.** Four to six items a round,
//      touch targets a size up, and no timer: a גן round cannot be lost.
//
// A miss is a soft sound and a wobble. No "טעית", no "נכשלת" — for a
// pre-reader, not even a gentle word: sound and movement say it better.

// MARK: - 👂 The cue: pictures on screen, a sentence in the ear

/// What a גן round shows instead of a written instruction: the rule as
/// PICTURES, plus the sentence read aloud. `spoken` is never drawn on screen.
struct PreReaderCue: Equatable {
    /// The rule as pictures — one object, a colour swatch, or a row of objects
    /// that shows a quantity. Empty when the board itself IS the rule (🧠 🧺).
    var icons: [String] = []
    /// Kid-facing Hebrew WITH niqqud. Spoken only.
    var spoken: String
}

// MARK: - 🎨 The pools

/// A picture and the name that is read aloud for it. The name never reaches
/// the screen — it only ever goes to the speech synthesizer.
struct PreReaderPic: Hashable {
    let emoji: String
    /// Definite singular: "הַכֶּלֶב", so "פּוֹצְצוּ אֶת כָּל הַבַּלּוֹנִים עִם הַכֶּלֶב".
    let the: String
}

enum PreReaderGames {

    /// Is this child a pre-reader? (גן and below — `effectiveGrade <= 0`.)
    static func isPreReader(_ grade: Int) -> Bool { MiniGameBand.of(grade) == .preReader }

    /// 👶 **The** question every גן game asks, and the only place it is
    /// answered: is the child in front of us a pre-reader?
    ///
    /// All five screens read this one property rather than each deriving it,
    /// so a גן round can never half-appear — and in particular nothing asks
    /// `MiniGameLevel.grade(for:)`, which floors at 1 and would answer "א׳"
    /// for a child who cannot read a word.
    static var activeChildIsPreReader: Bool {
        isPreReader(ProfileStore.shared.active?.effectiveGrade ?? 1)
    }

    /// Items a round holds — six, not ten, and the balloon round stops at six
    /// good pops rather than on a clock.
    static let roundItems = 6
    /// 🔗 four pairs, not five: eight tiles is already a full screen at this age.
    static let pairCount = 4
    /// 🧠 four sequences, 🧱 five collections — a round of about a minute.
    static let patternCount = 4
    static let countingHits = 5

    static var animals: [PreReaderPic] { [
        PreReaderPic(emoji: "🐶", the: tr("הַכֶּלֶב")), PreReaderPic(emoji: "🐱", the: tr("הֶחָתוּל")),
        PreReaderPic(emoji: "🐰", the: tr("הָאַרְנָב")), PreReaderPic(emoji: "🐸", the: tr("הַצְּפַרְדֵּעַ")),
        PreReaderPic(emoji: "🐮", the: tr("הַפָּרָה")), PreReaderPic(emoji: "🐷", the: tr("הַחֲזִיר")),
        PreReaderPic(emoji: "🦁", the: tr("הָאַרְיֵה")), PreReaderPic(emoji: "🐘", the: tr("הַפִּיל")),
        PreReaderPic(emoji: "🐧", the: tr("הַפִּינְגְּוִין")), PreReaderPic(emoji: "🦊", the: tr("הַשּׁוּעָל")),
        PreReaderPic(emoji: "🐵", the: tr("הַקּוֹף")), PreReaderPic(emoji: "🐯", the: tr("הַנָּמֵר")),
        PreReaderPic(emoji: "🐻", the: tr("הַדֹּב")), PreReaderPic(emoji: "🐴", the: tr("הַסּוּס")),
        PreReaderPic(emoji: "🐔", the: tr("הַתַּרְנְגֹלֶת")), PreReaderPic(emoji: "🐟", the: tr("הַדָּג"))
    ] }

    static var things: [PreReaderPic] { [
        PreReaderPic(emoji: "🍎", the: tr("הַתַּפּוּחַ")), PreReaderPic(emoji: "🍌", the: tr("הַבַּנָּנָה")),
        PreReaderPic(emoji: "🚗", the: tr("הַמְּכוֹנִית")), PreReaderPic(emoji: "⚽", the: tr("הַכַּדּוּר")),
        PreReaderPic(emoji: "🌸", the: tr("הַפֶּרַח")), PreReaderPic(emoji: "⭐", the: tr("הַכּוֹכָב")),
        PreReaderPic(emoji: "🍪", the: tr("הָעוּגִיָּה")), PreReaderPic(emoji: "🚂", the: tr("הָרַכֶּבֶת")),
        PreReaderPic(emoji: "👟", the: tr("הַנַּעַל")), PreReaderPic(emoji: "🧢", the: tr("הַכּוֹבַע")),
        PreReaderPic(emoji: "🔑", the: tr("הַמַּפְתֵּחַ")), PreReaderPic(emoji: "🍉", the: tr("הָאֲבַטִּיחַ")),
        PreReaderPic(emoji: "🥕", the: tr("הַגֶּזֶר")), PreReaderPic(emoji: "🏠", the: tr("הַבַּיִת")),
        PreReaderPic(emoji: "🌳", the: tr("הָעֵץ")), PreReaderPic(emoji: "☂️", the: tr("הַמִּטְרִיָּה"))
    ] }

    /// A colour: the swatch that shows it, the balloon's own fill, and the
    /// plural adjective the sentence uses ("פּוֹצְצוּ אֶת הַבַּלּוֹנִים הָאֲדֻמִּים").
    struct Hue: Hashable {
        let swatch: String
        let hex: String
        let plural: String
    }

    static var hues: [Hue] { [
        Hue(swatch: "🔴", hex: "FF4D4D", plural: tr("הָאֲדֻמִּים")),
        Hue(swatch: "🟢", hex: "2ECC71", plural: tr("הַיְּרֻקִּים")),
        Hue(swatch: "🔵", hex: "3B9BE8", plural: tr("הַכְּחֻלִּים")),
        Hue(swatch: "🟡", hex: "FFD23F", plural: tr("הַצְּהֻבִּים")),
        Hue(swatch: "🟣", hex: "9B5DE5", plural: tr("הַסְּגֻלִּים")),
        Hue(swatch: "🟠", hex: "FF9F1C", plural: tr("הַכְּתֻמִּים"))
    ] }

    /// Something a pre-reader can count: the object, and its plural name.
    /// All masculine, so "שְׁלוֹשָׁה תַּפּוּחִים" is never "שלוש תפוחים".
    static var countables: [(emoji: String, plural: String)] { [
        ("🍎", tr("תַּפּוּחִים")), ("⭐", tr("כּוֹכָבִים")), ("🐟", tr("דָּגִים")),
        ("⚽", tr("כַּדּוּרִים")), ("🌸", tr("פְּרָחִים")), ("🦋", tr("פַּרְפָּרִים")),
        ("🍋", tr("לִימוֹנִים"))
    ] }

    /// 2…6 as a masculine Hebrew word, because the synthesizer reads a bare
    /// digit in the feminine ("שָׁלוֹשׁ תַּפּוּחִים").
    static func countWord(_ n: Int) -> String {
        switch n {
        case ...1: return tr("אֶחָד")
        case 2:    return tr("שְׁנֵי")
        case 3:    return tr("שְׁלוֹשָׁה")
        case 4:    return tr("אַרְבָּעָה")
        case 5:    return tr("חֲמִשָּׁה")
        default:   return tr("שִׁשָּׁה")
        }
    }

    /// "שְׁלוֹשָׁה תַּפּוּחִים" — a quantity as words, for the ear only.
    /// ⚠️ Two and up only. Hebrew counts ONE the other way round — the noun
    /// comes first and in the singular, "פַּרְפָּר אֶחָד" — so every caller
    /// keeps its quantities at two or more rather than letting this produce
    /// "אֶחָד פַּרְפָּרִים".
    static func countPhrase(_ n: Int, _ plural: String) -> String {
        countWord(max(2, n)) + " " + plural
    }

    // MARK: - 🎈 Balloons

    /// 🎈 Three text-free rounds, all the same shape — a picture rule in the
    /// gold cue card, pictures riding the balloons:
    ///
    ///   🐶      one object  — pop every balloon with the dog on it
    ///   🔴      one colour  — pop every red balloon (the balloon IS the answer)
    ///   🍎🍎🍎  a quantity  — pop the balloon carrying exactly three apples
    static func balloons() -> (set: BalloonSet, cue: PreReaderCue) {
        switch Int.random(in: 0...2) {
        case 0:  return balloonColour()
        case 1:  return balloonCount()
        default: return balloonPicture()
        }
    }

    private static func balloonPicture() -> (set: BalloonSet, cue: PreReaderCue) {
        let pool = (Bool.random() ? animals : things).shuffled()
        let target = pool[0]
        let others = pool.dropFirst().prefix(6)
        return (BalloonSet(prompt: "", topic: .logic,
                           targets: [BalloonItem(emoji: target.emoji, label: "", correct: true)],
                           others: others.map { BalloonItem(emoji: $0.emoji, label: "", correct: false) }),
                PreReaderCue(icons: [target.emoji],
                             spoken: tr("פּוֹצְצוּ אֶת כָּל הַבַּלּוֹנִים עִם \(target.the)!")))
    }

    private static func balloonColour() -> (set: BalloonSet, cue: PreReaderCue) {
        let pool = hues.shuffled()
        let target = pool[0]
        let others = pool.dropFirst().prefix(4)
        return (BalloonSet(prompt: "", topic: .logic,
                           targets: [BalloonItem(emoji: "", label: "", correct: true, colorHex: target.hex)],
                           others: others.map { BalloonItem(emoji: "", label: "", correct: false, colorHex: $0.hex) }),
                PreReaderCue(icons: [target.swatch],
                             spoken: tr("פּוֹצְצוּ אֶת כָּל הַבַּלּוֹנִים \(target.plural)!")))
    }

    private static func balloonCount() -> (set: BalloonSet, cue: PreReaderCue) {
        let item = countables.randomElement()!
        let n = Int.random(in: 2...4)
        func balloon(_ k: Int, correct: Bool) -> BalloonItem {
            BalloonItem(emoji: String(repeating: item.emoji, count: k), label: "", correct: correct)
        }
        let others = (1...5).filter { $0 != n }.map { balloon($0, correct: false) }
        return (BalloonSet(prompt: "", topic: .math, targets: [balloon(n, correct: true)], others: others),
                PreReaderCue(icons: Array(repeating: item.emoji, count: n),
                             spoken: tr("פּוֹצְצוּ אֶת הַבַּלּוֹן שֶׁיֵּשׁ עָלָיו \(countPhrase(n, item.plural))!")))
    }

    // MARK: - 🧺 Baskets

    /// 🧺 Two baskets, each wearing pictures instead of a label, and six
    /// pictures to drop in. The baskets themselves are the rule on screen; the
    /// sentence that names it is read aloud.
    static func baskets() -> (set: SortSet, cue: PreReaderCue) {
        func set(_ a: String, _ b: String, _ left: [String], _ right: [String],
                 _ topic: Topic, _ spoken: String) -> (SortSet, PreReaderCue) {
            let items = left.map { SortItem(emoji: $0, label: "", basket: 0) }
                      + right.map { SortItem(emoji: $0, label: "", basket: 1) }
            return (SortSet(baskets: [SortBasket(emoji: a, label: ""), SortBasket(emoji: b, label: "")],
                            items: items, topic: topic),
                    PreReaderCue(spoken: spoken))
        }
        switch Int.random(in: 0...3) {
        case 0:
            return set("🐶🐱", "🍎🍌",
                       ["🐰", "🐸", "🦁", "🐘", "🐧", "🐴"],
                       ["🍉", "🥕", "🍪", "🍇", "🍞", "🧀"], .logic,
                       tr("שִׂימוּ אֶת הַחַיּוֹת בַּסַּל שֶׁיֵּשׁ עָלָיו כֶּלֶב וְחָתוּל, וְאֶת הָאֹכֶל בַּסַּל שֶׁיֵּשׁ עָלָיו תַּפּוּחַ וּבַנָּנָה."))
        case 1:
            return set("🐘", "🐭",
                       ["🐋", "🚌", "🏠", "🌳", "🚂", "🦒"],
                       ["🐜", "🐞", "🔑", "🍓", "🪙", "🦷"], .logic,
                       tr("שִׂימוּ כָּל דָּבָר גָּדוֹל בַּסַּל שֶׁל הַפִּיל, וְכָל דָּבָר קָטָן בַּסַּל שֶׁל הָעַכְבָּר."))
        case 2:
            return set("🌊", "🌳",
                       ["🐟", "🐙", "🐬", "🦈", "🐳", "🦀"],
                       ["🦁", "🐘", "🐶", "🐴", "🐓", "🦒"], .logic,
                       tr("שִׂימוּ אֶת מִי שֶׁחַי בַּמַּיִם בַּסַּל שֶׁל הַגַּלִּים, וְאֶת מִי שֶׁחַי בַּיַּבָּשָׁה בַּסַּל שֶׁל הָעֵץ."))
        default:
            return set("🔴", "🔵",
                       ["🍎", "🍓", "🌹", "🚒", "🟥", "❤️"],
                       ["🫐", "🔵", "🟦", "💙", "🌊", "🐳"], .logic,
                       tr("שִׂימוּ כָּל דָּבָר אָדֹם בַּסַּל הָאָדֹם, וְכָל דָּבָר כָּחֹל בַּסַּל הַכָּחֹל."))
        }
    }

    /// Six items, three from each basket, shuffled.
    static func basketRound(_ set: SortSet) -> [SortItem] {
        var out: [SortItem] = []
        var byBasket = Dictionary(grouping: set.items.shuffled(), by: \.basket)
        while out.count < roundItems {
            var added = false
            for b in set.baskets.indices where out.count < roundItems {
                if var list = byBasket[b], !list.isEmpty {
                    out.append(list.removeLast())
                    byBasket[b] = list
                    added = true
                }
            }
            if !added { break }
        }
        return out.shuffled()
    }

    // MARK: - 🔗 Pairs

    /// 🔗 Picture pairs a five-year-old can reason about: what goes with what.
    /// Nothing to read, and nothing to know — only to think.
    private static let goesTogether: [(String, String)] = [
        ("🐟", "🌊"), ("🚗", "🛣️"), ("🍌", "🐵"), ("🦴", "🐶"), ("🥕", "🐰"),
        ("🧦", "🦶"), ("☂️", "🌧️"), ("🪥", "🦷"), ("🔑", "🚪"), ("🐝", "🌸"),
        ("🥛", "🐄"), ("⚽", "🥅"), ("✏️", "📒"), ("🍼", "👶"), ("🐛", "🦋"),
        ("🥚", "🐣"), ("🌱", "🌳"), ("🐑", "🧶"), ("🧊", "❄️"), ("🍯", "🐻"),
        ("🌙", "⭐"), ("☀️", "🕶️"), ("🐦", "🪶"), ("🌾", "🍞")
    ]

    static func pairs(count: Int = pairCount) -> (pairs: [MatchPair], cue: PreReaderCue) {
        let picked = goesTogether.shuffled().prefix(count)
        return (picked.map { MatchPair(left: $0.0, right: $0.1) },
                PreReaderCue(spoken: tr("חַבְּרוּ כָּל תְּמוּנָה לַתְּמוּנָה שֶׁהוֹלֶכֶת אִתָּהּ!")))
    }

    // MARK: - 🧠 The pattern

    /// 🧠 A repeating row of pictures, colours or shapes, with the last one
    /// missing. `PatternGen.picture` already builds exactly this for the
    /// pre-reader band — here it is, with a pre-reader's own picture sets.
    static var patternSets: [[String]] { [
        ["🔴", "🔵", "🟡", "🟢"],
        ["⭐", "❤️", "🔺", "🟦"],
        ["🐶", "🐱", "🐰", "🦁"],
        ["🍎", "🍌", "🍇", "🍉"],
        ["🚗", "🚂", "✈️", "🚲"],
        ["🌸", "🌳", "🍄", "🌻"]
    ] }

    static var patternCue: PreReaderCue {
        PreReaderCue(spoken: tr("מָה מַמְשִׁיךְ אֶת הַסִּדְרָה? בַּחֲרוּ אֶת הַתְּמוּנָה הַבָּאָה!"))
    }

    // MARK: - 🧱 Collecting

    /// 🧱 "מְפַצְּחִים" turned into pure counting for גן — and only counting.
    ///
    /// Rani, twice, on the version where the child combined cards to reach a
    /// target: "זה לא מובן." He was right, and the reason is not presentation:
    /// adding 3 + 1 to make four is a FIRST-GRADE skill. A five-year-old
    /// counts to five; they do not compose two groups. So the גן round is a
    /// single choice — "tap the card that has exactly four flowers" — and the
    /// combining board stays exactly as it is from א׳ upward.
    struct Collect {
        /// The object the basket and every card are drawn from.
        let emoji: String
        /// How many the basket wants — and exactly one card carries.
        let target: Int
        /// The counts on the six cards, target included, already shuffled.
        let cards: [Int]
        let cue: PreReaderCue
    }

    /// Counts a גן child can take in at a glance.
    static let countingCards = 6
    /// What a card may hold.
    private static let countRange = 1...5
    /// What the goal may ask for. It starts at TWO, and not because one is too
    /// easy: Hebrew counts one the other way round — "פַּרְפָּר אֶחָד", noun
    /// first — so `countPhrase` would have produced "אֶחָד פַּרְפָּרִים". Two to
    /// five is the range worth counting anyway, and a card holding one is
    /// still a fine distractor, because a card carries no words at all.
    private static let targetRange = 2...5

    static func collecting() -> Collect {
        let item = countables.randomElement()!
        let target = Int.random(in: targetRange)
        // Five more cards, every one of them a DIFFERENT count from the target,
        // so there is never a second right answer. Each of the four remaining
        // counts appears once before any repeats — three cards of five flowers
        // on one board made it look like the game had only two answers.
        let others = countRange.filter { $0 != target }.shuffled()
        var cards = [target] + others
        while cards.count < countingCards {
            cards.append(others.randomElement() ?? 1)
        }
        return Collect(emoji: item.emoji, target: target, cards: cards.shuffled(),
                       cue: PreReaderCue(icons: Array(repeating: item.emoji, count: target),
                                         spoken: tr("בַּחֲרוּ אֶת הַכַּרְטִיס שֶׁיֵּשׁ בּוֹ בְּדִיּוּק \(countPhrase(target, item.plural))!")))
    }

    // MARK: - 🧰 Shared chrome copy (spoken only)

    static var startCue: String { tr("בּוֹאוּ נְשַׂחֵק!") }
    static var wellDone: String { tr("כָּל הַכָּבוֹד! אַלּוּפִים!") }
    /// A gentle nudge, for the ear only — never printed, and never a failure.
    static var almost: String { tr("כִּמְעַט! נְנַסֶּה שׁוּב.") }
}

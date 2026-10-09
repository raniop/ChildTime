import Foundation

/// Picture-based questions for early readers (גן, `effectiveGrade < 1`). The
/// on-screen content is VISUAL — objects to count, emoji choices, a letter —
/// and the instruction is read aloud (`Question.spoken`), so a child who can't
/// read yet plays by listening + looking. Used by `QuestionRunnerView` and the
/// boss battle whenever the active child is a pre-reader.
///
/// Every world used to serve the same "where's the dog?" and math only counted
/// to five — a גן חובה girl finished it fast and called every world the same
/// (Ben David, 2026-10-09). Now math adds and subtracts with pictures, Hebrew
/// teaches the letters, and each theme world asks about its own pictures.
enum PreReaderContent {

    static func generate(topic: Topic) -> Question {
        switch topic {
        case .math:
            return mathRound()
        case .hebrew where LanguageStore.shared.current == .he:
            return lettersRound()
        default:
            // A theme world asks about ITS pictures most of the time; the
            // animals / shapes / colours rounds keep some variety.
            if let pool = themedPool(for: topic), Double.random(in: 0...1) < 0.75 {
                return findOne(in: pool, topic: topic)
            }
            return [findAnimal, findShape, findColor].randomElement()!()
        }
    }

    // MARK: - 🔢 Math: count, add, take away, compare, find the digit

    private static func mathRound() -> Question {
        switch Int.random(in: 0..<9) {
        case 0...2: return counting()
        case 3, 4:  return pictureAdd()
        case 5, 6:  return pictureTakeAway()
        case 7:     return whereMore()
        default:    return digitByEar()
        }
    }

    private static var countables: [(emoji: String, plural: String)] { [
        ("🍎", tr("תַּפּוּחִים")), ("⭐", tr("כּוֹכָבִים")), ("🐟", tr("דָּגִים")), ("🌸", tr("פְּרָחִים")),
        ("🎈", tr("בַּלּוֹנִים")), ("🍌", tr("בָּנָנוֹת")), ("🐝", tr("דְּבוֹרִים")), ("⚽", tr("כַּדּוּרִים")),
        ("🚗", tr("מְכוֹנִיּוֹת")), ("🦋", tr("פַּרְפָּרִים")), ("🍪", tr("עוּגִיּוֹת")), ("🐱", tr("חֲתוּלִים"))
    ] }

    private static func row(_ emoji: String, _ n: Int) -> String {
        Array(repeating: emoji, count: n).joined(separator: " ")
    }

    /// Four numbers around `answer`, never below 0 — the right one included.
    private static func numberOptions(_ answer: Int, range: ClosedRange<Int>) -> (options: [String], correct: Int) {
        var nums: Set<Int> = [answer]
        while nums.count < 4 { nums.insert(Int.random(in: range)) }
        let options = nums.shuffled().map(String.init)
        return (options, options.firstIndex(of: String(answer)) ?? 0)
    }

    private static func counting() -> Question {
        let item = countables.randomElement()!
        let n = Int.random(in: 1...8)
        let o = numberOptions(n, range: max(1, n - 3)...(n + 3))
        return Question(topic: .math, prompt: row(item.emoji, n), options: o.options,
                        correctIndex: o.correct, spoken: tr("כַּמָּה \(item.plural)?"))
    }

    /// 🍎🍎 ➕ 🍎 — "how many altogether?" (totals up to 7, still countable).
    private static func pictureAdd() -> Question {
        let item = countables.randomElement()!
        let a = Int.random(in: 1...4)
        let b = Int.random(in: 1...min(4, 7 - a))
        let o = numberOptions(a + b, range: max(1, a + b - 3)...(a + b + 3))
        var q = Question(topic: .math, prompt: "\(row(item.emoji, a))  ➕  \(row(item.emoji, b))", options: o.options,
                         correctIndex: o.correct, spoken: tr("כַּמָּה \(item.plural) יֵשׁ בְּיַחַד?"))
        q.skill = "addSub"
        return q
    }

    /// 🍎🍎🍎 ➖ 🍎 — "how many are left?"
    private static func pictureTakeAway() -> Question {
        let item = countables.randomElement()!
        let total = Int.random(in: 3...7)
        let take = Int.random(in: 1...(total - 1))
        let left = total - take
        let o = numberOptions(left, range: 0...(left + 3))
        var q = Question(topic: .math, prompt: "\(row(item.emoji, total))  ➖  \(row(item.emoji, take))", options: o.options,
                         correctIndex: o.correct, spoken: tr("כַּמָּה \(item.plural) נִשְׁאֲרוּ?"))
        q.skill = "addSub"
        return q
    }

    /// Four groups — "where are there MORE apples?"
    private static func whereMore() -> Question {
        let item = countables.randomElement()!
        let sizes = Array((1...6).shuffled().prefix(4))
        let options = sizes.map { row(item.emoji, $0) }
        let correct = sizes.firstIndex(of: sizes.max()!) ?? 0
        var q = Question(topic: .math, prompt: "⚖️", options: options,
                         correctIndex: correct, spoken: tr("אֵיפֹה יֵשׁ יוֹתֵר \(item.plural)?"))
        q.skill = "compare"
        return q
    }

    /// "Where is the number three?" — the digits 1–10, heard not read.
    private static var numberWords: [String] { [
        tr("אַחַת"), tr("שְׁתַּיִם"), tr("שָׁלוֹשׁ"), tr("אַרְבַּע"), tr("חָמֵשׁ"),
        tr("שֵׁשׁ"), tr("שֶׁבַע"), tr("שְׁמוֹנֶה"), tr("תֵּשַׁע"), tr("עֶשֶׂר")
    ] }

    private static func digitByEar() -> Question {
        let n = Int.random(in: 1...10)
        let o = numberOptions(n, range: 1...10)
        return Question(topic: .math, prompt: "👂", options: o.options,
                        correctIndex: o.correct, spoken: tr("אֵיפֹה הַמִּסְפָּר \(numberWords[n - 1])?"))
    }

    // MARK: - 🔤 Hebrew letters: first letter, the picture for a letter, a letter by ear

    private struct LetterWord { let emoji: String; let word: String; var clearPicture = true }
    private struct Letter { let glyph: String; let name: String; let words: [LetterWord] }

    /// Every word starts with its letter's own sound and has a picture a child
    /// names the same way. `clearPicture: false` = fine to hear, too ambiguous
    /// to pick out of pictures (🚗 is also "אוֹטוֹ").
    private static let letters: [Letter] = [
        Letter(glyph: "א", name: "אָלֶף", words: [.init(emoji: "🍉", word: "אֲבַטִּיחַ"), .init(emoji: "🦁", word: "אַרְיֵה"), .init(emoji: "🍍", word: "אֲנָנָס")]),
        Letter(glyph: "ב", name: "בֵּית", words: [.init(emoji: "🎈", word: "בַּלּוֹן"), .init(emoji: "🍌", word: "בָּנָנָה"), .init(emoji: "🏠", word: "בַּיִת")]),
        Letter(glyph: "ג", name: "גִּימֶל", words: [.init(emoji: "🐪", word: "גָּמָל"), .init(emoji: "🧀", word: "גְּבִינָה"), .init(emoji: "🎸", word: "גִּיטָרָה")]),
        Letter(glyph: "ד", name: "דָּלֶת", words: [.init(emoji: "🐟", word: "דָּג"), .init(emoji: "🐻", word: "דּוֹב"), .init(emoji: "🐝", word: "דְּבוֹרָה")]),
        Letter(glyph: "ה", name: "הֵא", words: [.init(emoji: "⛰️", word: "הַר"), .init(emoji: "🦛", word: "הִיפּוֹפּוֹטָם")]),
        Letter(glyph: "ו", name: "וָו", words: [.init(emoji: "🌹", word: "וֶרֶד")]),
        Letter(glyph: "ז", name: "זַיִן", words: [.init(emoji: "🦓", word: "זֶבְּרָה"), .init(emoji: "🫒", word: "זַיִת")]),
        Letter(glyph: "ח", name: "חֵית", words: [.init(emoji: "🐱", word: "חָתוּל"), .init(emoji: "🥛", word: "חָלָב"), .init(emoji: "🧵", word: "חוּט")]),
        Letter(glyph: "ט", name: "טֵית", words: [.init(emoji: "🦚", word: "טַוָּס"), .init(emoji: "🚜", word: "טְרַקְטוֹר")]),
        Letter(glyph: "י", name: "יוּד", words: [.init(emoji: "🌙", word: "יָרֵחַ"), .init(emoji: "🧒", word: "יֶלֶד", clearPicture: false)]),
        Letter(glyph: "כ", name: "כַּף", words: [.init(emoji: "⚽", word: "כַּדּוּר"), .init(emoji: "🐶", word: "כֶּלֶב"), .init(emoji: "⭐", word: "כּוֹכָב")]),
        Letter(glyph: "ל", name: "לָמֶד", words: [.init(emoji: "🍋", word: "לִימוֹן"), .init(emoji: "❤️", word: "לֵב")]),
        Letter(glyph: "מ", name: "מֵם", words: [.init(emoji: "🚗", word: "מְכוֹנִית", clearPicture: false), .init(emoji: "🔑", word: "מַפְתֵּחַ")]),
        Letter(glyph: "נ", name: "נוּן", words: [.init(emoji: "🐯", word: "נָמֵר"), .init(emoji: "🕯️", word: "נֵר"), .init(emoji: "🐜", word: "נְמָלָה")]),
        Letter(glyph: "ס", name: "סָמֶךְ", words: [.init(emoji: "🐴", word: "סוּס"), .init(emoji: "📚", word: "סֵפֶר")]),
        Letter(glyph: "ע", name: "עַיִן", words: [.init(emoji: "🎂", word: "עוּגָה"), .init(emoji: "🌳", word: "עֵץ"), .init(emoji: "🐭", word: "עַכְבָּר")]),
        Letter(glyph: "פ", name: "פֵּא", words: [.init(emoji: "🐘", word: "פִּיל"), .init(emoji: "🌸", word: "פֶּרַח")]),
        Letter(glyph: "צ", name: "צָדִי", words: [.init(emoji: "🐢", word: "צָב"), .init(emoji: "🐸", word: "צְפַרְדֵּעַ"), .init(emoji: "🐦", word: "צִפּוֹר")]),
        Letter(glyph: "ק", name: "קוֹף", words: [.init(emoji: "🐒", word: "קוֹף"), .init(emoji: "🦔", word: "קִיפּוֹד")]),
        Letter(glyph: "ר", name: "רֵישׁ", words: [.init(emoji: "🤖", word: "רוֹבּוֹט"), .init(emoji: "🚂", word: "רַכֶּבֶת")]),
        Letter(glyph: "ש", name: "שִׁין", words: [.init(emoji: "☀️", word: "שֶׁמֶשׁ"), .init(emoji: "🕐", word: "שָׁעוֹן"), .init(emoji: "🦊", word: "שׁוּעָל")]),
        Letter(glyph: "ת", name: "תָּו", words: [.init(emoji: "🍎", word: "תַּפּוּחַ"), .init(emoji: "👶", word: "תִּינוֹק")]),
    ]

    /// Letters a child can't tell apart by SOUND never stand side by side as
    /// options — "בְּאֵיזוֹ אוֹת מַתְחִילָה עוּגָה?" can't offer both א and ע.
    private static let soundAlike: [Set<String>] = [["א", "ע"], ["ט", "ת"], ["כ", "ק", "ח"], ["ס", "ש"], ["ב", "ו"]]
    private static func clash(_ a: String, _ b: String) -> Bool {
        a == b || soundAlike.contains { $0.contains(a) && $0.contains(b) }
    }

    /// The target plus three letters that can't be confused with it — or each other.
    private static func distinctLetters(around target: Letter) -> [Letter] {
        var picked = [target]
        for l in letters.shuffled() where picked.count < 4 {
            if !picked.contains(where: { clash($0.glyph, l.glyph) }) { picked.append(l) }
        }
        return picked
    }

    /// Internal (not private) so tests reach it without switching the app language.
    static func lettersRound() -> Question {
        switch Int.random(in: 0..<3) {
        case 0:  return firstLetter()
        case 1:  return pictureForLetter()
        default: return letterByEar()
        }
    }

    /// 🍉 — "which letter does אֲבַטִּיחַ start with?" → א
    private static func firstLetter() -> Question {
        let target = letters.randomElement()!
        let word = target.words.randomElement()!
        let options = distinctLetters(around: target).map(\.glyph).shuffled()
        var q = Question(topic: .hebrew, prompt: word.emoji, options: options,
                         correctIndex: options.firstIndex(of: target.glyph) ?? 0,
                         spoken: tr("בְּאֵיזוֹ אוֹת מַתְחִילָה הַמִּלָּה \(word.word)?"))
        q.skill = "letters"
        return q
    }

    /// ב — "which picture starts with the letter בֵּית?" → 🎈
    private static func pictureForLetter() -> Question {
        let target = letters.filter { $0.words.contains(where: \.clearPicture) }.randomElement()!
        let right = target.words.filter(\.clearPicture).randomElement()!
        let others = distinctLetters(around: target).dropFirst().compactMap { $0.words.filter(\.clearPicture).randomElement() }
        let options = ([right.emoji] + others.map(\.emoji)).shuffled()
        var q = Question(topic: .hebrew, prompt: target.glyph, options: options,
                         correctIndex: options.firstIndex(of: right.emoji) ?? 0,
                         spoken: tr("אֵיזוֹ תְּמוּנָה מַתְחִילָה בָּאוֹת \(target.name)?"))
        q.skill = "letters"
        return q
    }

    /// 👂 — "where is the letter גִּימֶל?" → ג
    private static func letterByEar() -> Question {
        let target = letters.randomElement()!
        let options = distinctLetters(around: target).map(\.glyph).shuffled()
        var q = Question(topic: .hebrew, prompt: "👂", options: options,
                         correctIndex: options.firstIndex(of: target.glyph) ?? 0,
                         spoken: tr("אֵיפֹה הָאוֹת \(target.name)?"))
        q.skill = "letters"
        return q
    }

    // MARK: - Find the picture: hear "where's the dog?" → tap the matching emoji.

    private static var animals: [(emoji: String, name: String)] { [
        ("🐶", tr("הַכֶּלֶב")), ("🐱", tr("הֶחָתוּל")), ("🐰", tr("הָאַרְנָב")), ("🐸", tr("הַצְּפַרְדֵּעַ")),
        ("🐮", tr("הַפָּרָה")), ("🐷", tr("הַחֲזִיר")), ("🦁", tr("הָאַרְיֵה")), ("🐘", tr("הַפִּיל")),
        ("🐧", tr("הַפִּינְגְּוִין")), ("🦊", tr("הַשּׁוּעָל")), ("🐵", tr("הַקּוֹף")), ("🐯", tr("הַנָּמֵר"))
    ] }
    private static var shapes: [(emoji: String, name: String)] { [
        ("🔴", tr("הָעִגּוּל")), ("🔺", tr("הַמְּשׁוּלָּשׁ")), ("🟦", tr("הָרִבּוּעַ")),
        ("⭐", tr("הַכּוֹכָב")), ("❤️", tr("הַלֵּב"))
    ] }
    private static var colors: [(emoji: String, name: String)] { [
        ("🔴", tr("הָאָדוֹם")), ("🟢", tr("הַיָּרוֹק")), ("🔵", tr("הַכָּחוֹל")),
        ("🟡", tr("הַצָּהוֹב")), ("🟣", tr("הַסָּגוֹל")), ("🟠", tr("הַכָּתוֹם"))
    ] }

    /// Each theme world's own pictures — so the sea asks about the octopus and
    /// the space world about the moon, not everyone about the dog.
    private static func themedPool(for topic: Topic) -> [(emoji: String, name: String)]? {
        switch topic {
        case .animals:
            return animals
        case .sea:
            return [("🐙", tr("הַתַּמְנוּן")), ("🐬", tr("הַדּוֹלְפִין")), ("🦈", tr("הַכָּרִישׁ")), ("🐢", tr("הַצָּב")),
                    ("🦀", tr("הַסַּרְטָן")), ("🐳", tr("הַלִּוְיָתָן")), ("🐠", tr("הַדָּג")), ("🐚", tr("הַצֶּדֶף"))]
        case .space:
            return [("🚀", tr("הַחֲלָלִית")), ("🌙", tr("הַיָּרֵחַ")), ("☀️", tr("הַשֶּׁמֶשׁ")), ("⭐", tr("הַכּוֹכָב")),
                    ("🌍", tr("כַּדּוּר הָאָרֶץ")), ("👨‍🚀", tr("הָאַסְטְרוֹנָאוּט"))]
        case .vehicles:
            return [("🚗", tr("הַמְּכוֹנִית")), ("🚌", tr("הָאוֹטוֹבּוּס")), ("🚂", tr("הָרַכֶּבֶת")), ("✈️", tr("הַמָּטוֹס")),
                    ("🚲", tr("הָאוֹפַנַּיִם")), ("🚁", tr("הַמַּסּוֹק")), ("🚒", tr("הַכַּבָּאִית")), ("🚢", tr("הָאֳנִיָּה"))]
        case .food:
            return [("🍎", tr("הַתַּפּוּחַ")), ("🍌", tr("הַבָּנָנָה")), ("🍕", tr("הַפִּיצָה")), ("🥕", tr("הַגֶּזֶר")),
                    ("🍞", tr("הַלֶּחֶם")), ("🧀", tr("הַגְּבִינָה")), ("🍉", tr("הָאֲבַטִּיחַ")), ("🍓", tr("הַתּוּת")), ("🥚", tr("הַבֵּיצָה"))]
        case .music:
            return [("🥁", tr("הַתֹּף")), ("🎸", tr("הַגִּיטָרָה")), ("🎹", tr("הַפְּסַנְתֵּר")), ("🎺", tr("הַחֲצוֹצְרָה")),
                    ("🎻", tr("הַכִּנּוֹר")), ("🎤", tr("הַמִּיקְרוֹפוֹן"))]
        case .body:
            return [("👁️", tr("הָעַיִן")), ("👂", tr("הָאֹזֶן")), ("👃", tr("הָאַף")), ("👄", tr("הַפֶּה")),
                    ("✋", tr("הַיָּד")), ("🦶", tr("הָרֶגֶל"))]
        case .soccer:
            return [("⚽", tr("הַכַּדּוּר")), ("🥅", tr("הַשַּׁעַר")), ("🏆", tr("הַגָּבִיעַ")), ("👟", tr("הַנַּעַל")),
                    ("🧤", tr("הַכְּפָפָה")), ("🚩", tr("הַדֶּגֶל"))]
        case .science:
            return [("🔬", tr("הַמִּיקְרוֹסְקוֹפּ")), ("🧲", tr("הַמַּגְנֵט")), ("💡", tr("הַנּוּרָה")), ("🌈", tr("הַקֶּשֶׁת")),
                    ("🔥", tr("הָאֵשׁ")), ("💧", tr("הַטִּפָּה")), ("🌡️", tr("הַמַּדְחֹם"))]
        default:
            return nil
        }
    }

    private static func findAnimal() -> Question { findOne(in: animals, topic: .logic) }
    private static func findShape()  -> Question { findOne(in: shapes, topic: .logic) }
    private static func findColor()  -> Question { findOne(in: colors, topic: .logic) }

    private static func findOne(in pool: [(emoji: String, name: String)], topic: Topic) -> Question {
        let picks = Array(pool.shuffled().prefix(4))
        let target = picks.randomElement()!
        let options = picks.map(\.emoji)
        let correct = options.firstIndex(of: target.emoji) ?? 0
        // The instruction is both shown and read aloud (spoken defaults to prompt).
        return Question(topic: topic, prompt: tr("אֵיפֹה \(target.name)?"),
                        options: options, correctIndex: correct)
    }
}

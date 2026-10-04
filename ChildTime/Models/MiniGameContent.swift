import Foundation
import SwiftUI

// 🎮 The content side of the mini-games that break up the question loop (Rani,
// 2026-10-03, after a parent wrote: "my son realized the topics are the same
// thing in a different coat and lost interest after a few minutes"):
//
//   🧱 CrushBoards      — the "מְפַצְּחִים" number blocks.
//   🔗 MatchPairsSource — the "חַבְּרוּ אֶת הַזּוּגוֹת" board.
//   🎈 BalloonSets      — "פּוֹצְצוּ אֶת כָּל …" categories for the balloon game.
//   🧩 WordSets         — picture → letters for "בְּנוּ אֶת הַמִּלָּה", and the
//                         themed words hidden in the "תַּפְזֹרֶת".
//   ⚡ SurpriseRound    — which game, on which theme, the runner launches.
//
// A ⚡ surprise round pays ⭐ and 💎 only. A game opened from a world's chooser
// earns minutes through the runner's own path (MiniGameEarnSession), so the
// parent's rates and daily cap keep meaning what they say.

// MARK: - 🧮 Computed math facts

enum MathFacts {
    struct Fact { let expression: String; let answer: Int }

    /// A grade-appropriate fact, computed (never a word problem — both games
    /// show it in one short line). Grades follow CurriculumMath: א׳ add/sub to
    /// 20, ב׳ to 100 + ×2/5/10, ג׳ the times table, ד׳+ bigger tables and ÷,
    /// ז׳–ח׳ signed numbers.
    static func fact(grade: Int) -> Fact {
        let g = max(1, grade)
        switch g {
        case 1:
            let a = Int.random(in: 1...10), b = Int.random(in: 1...10)
            if Bool.random() { return Fact(expression: "\(a) + \(b)", answer: a + b) }
            return Fact(expression: "\(max(a, b)) − \(min(a, b))", answer: max(a, b) - min(a, b))
        case 2:
            switch Int.random(in: 0...2) {
            case 0:
                let a = Int.random(in: 11...60), b = Int.random(in: 2...30)
                return Fact(expression: "\(a) + \(b)", answer: a + b)
            case 1:
                let a = Int.random(in: 30...99), b = Int.random(in: 2...29)
                return Fact(expression: "\(a) − \(b)", answer: a - b)
            default:
                let a = [2, 5, 10].randomElement()!, b = Int.random(in: 1...10)
                return Fact(expression: "\(b) × \(a)", answer: a * b)
            }
        case 3:
            let a = Int.random(in: 2...10), b = Int.random(in: 2...10)
            if Int.random(in: 0...3) == 0 { return Fact(expression: "\(a * b) ÷ \(a)", answer: b) }
            return Fact(expression: "\(a) × \(b)", answer: a * b)
        case 4:
            switch Int.random(in: 0...2) {
            case 0:
                let a = Int.random(in: 3...12), b = Int.random(in: 3...12)
                return Fact(expression: "\(a) × \(b)", answer: a * b)
            case 1:
                let a = Int.random(in: 12...40), b = Int.random(in: 2...5)
                return Fact(expression: "\(a) × \(b)", answer: a * b)
            default:
                let a = Int.random(in: 3...12), b = Int.random(in: 3...12)
                return Fact(expression: "\(a * b) ÷ \(a)", answer: b)
            }
        case 5:
            switch Int.random(in: 0...2) {
            case 0:
                let a = Int.random(in: 6...12), b = Int.random(in: 6...12)
                return Fact(expression: "\(a) × \(b)", answer: a * b)
            case 1:
                let a = Int.random(in: 2...20), b = Int.random(in: 2...9), c = Int.random(in: 2...9)
                return Fact(expression: "\(a) + \(b) × \(c)", answer: a + b * c)
            default:
                let a = Int.random(in: 6...12), b = Int.random(in: 6...12)
                return Fact(expression: "\(a * b) ÷ \(a)", answer: b)
            }
        case 6:
            // ו׳: order of operations with brackets, three-digit × one-digit,
            // long division — the ה׳ facts are a warm-up by now.
            switch Int.random(in: 0...3) {
            case 0:
                let a = Int.random(in: 2...9), b = Int.random(in: 2...9), c = Int.random(in: 2...12)
                return Fact(expression: "(\(a) + \(b)) × \(c)", answer: (a + b) * c)
            case 1:
                let a = Int.random(in: 11...40), b = Int.random(in: 3...9)
                return Fact(expression: "\(a) × \(b)", answer: a * b)
            case 2:
                let b = Int.random(in: 3...9), q = Int.random(in: 11...40)
                return Fact(expression: "\(b * q) ÷ \(b)", answer: q)
            default:
                let a = Int.random(in: 2...9), b = Int.random(in: 2...9), c = Int.random(in: 2...9)
                return Fact(expression: "\(a) × \(b) − \(c)", answer: a * b - c)
            }
        case 7:
            // ז׳: signed numbers and powers.
            switch Int.random(in: 0...2) {
            case 0:
                let a = Int.random(in: 2...12), b = Int.random(in: 2...15)
                return Fact(expression: "(−\(a)) + \(b)", answer: b - a)
            case 1:
                let a = Int.random(in: 2...12), b = Int.random(in: 2...12)
                return Fact(expression: "(−\(a)) × \(b)", answer: -a * b)
            default:
                let a = Int.random(in: 2...15)
                return Fact(expression: "\(a)²", answer: a * a)
            }
        default:   // ח׳
            // ח׳: roots, cubes, a product of two negatives, powers of two.
            switch Int.random(in: 0...3) {
            case 0:
                let a = Int.random(in: 4...20)
                return Fact(expression: "√\(a * a)", answer: a)
            case 1:
                let a = Int.random(in: 2...8)
                return Fact(expression: "\(a)³", answer: a * a * a)
            case 2:
                let a = Int.random(in: 2...12), b = Int.random(in: 2...12)
                return Fact(expression: "(−\(a)) × (−\(b))", answer: a * b)
            default:
                let a = Int.random(in: 2...9), b = Int.random(in: 2...6)
                return Fact(expression: "\(a)² − \(b)²", answer: a * a - b * b)
            }
        }
    }

    /// "−4" with a real minus sign.
    nonisolated static func show(_ n: Int) -> String { n < 0 ? "−\(abs(n))" : "\(n)" }
}

/// A bank question that works as one short card on its own: no passage, no
/// odd-one-out set, short prompt, short answers, no yes/no answers.
enum ShortQuestions {
    static func isShortAndSelfContained(_ q: Question, maxPrompt: Int, maxAnswer: Int) -> Bool {
        guard q.isSelfContainedPrompt, q.options.count >= 2, q.spoken == nil,
              !QuestionReporter.shared.isHidden(q.prompt) else { return false }
        let plainPrompt = Question.stripNiqqud(q.prompt)
        guard plainPrompt.count <= maxPrompt else { return false }
        guard q.options.allSatisfy({ Question.stripNiqqud($0).count <= maxAnswer }) else { return false }
        let yesNo: Set<String> = ["כן", "לא", "נכון", "לא נכון", "yes", "no", "true", "false",
                                  "да", "нет", "верно", "неверно", "نعم", "لا", "صحيح", "خطأ"]
        if q.options.contains(where: { yesNo.contains(Question.stripNiqqud($0).lowercased()) }) { return false }
        // The "no questions for this topic yet" placeholder answers itself.
        if q.correctAnswer == tr("בְּסֵדֶר") && q.options.contains(tr("הַמְשֵׁךְ")) { return false }
        return true
    }
}

// MARK: - 🔗 Match pairs

struct MatchPair: Hashable {
    let left: String
    let right: String
}

enum MatchPairsSource: Equatable {
    case capitals
    case englishWords
    case math
    case bank(Topic)

    /// The topic the board's answers are recorded under (parent reports).
    var topic: Topic {
        switch self {
        case .capitals:     return .geography
        case .englishWords: return .english
        case .math:         return .math
        case .bank(let t):  return t
        }
    }

    /// Which board fits the world it was opened from.
    static func pick(for topic: Topic?, grade: Int) -> MatchPairsSource {
        switch topic {
        case .math?:                         return .math
        case .english?:                      return .englishWords
        case .flags?, .geography?:           return grade >= 2 ? .capitals : .math
        case .some(let t) where t != .reading && t != .holidays:
            return .bank(t)
        default:
            // Opened without a world (the runner's bonus card in the feed): mix.
            var options: [MatchPairsSource] = [.math]
            if grade >= 2 { options.append(.capitals) }
            if grade >= 1 { options.append(.englishWords) }
            return options.randomElement() ?? .math
        }
    }

    /// Five pairs with five DIFFERENT right-hand items. A bank board that
    /// can't fill up falls back to math, which never runs dry.
    func pairs(count: Int, grade: Int, profile: Profile?) -> (source: MatchPairsSource, pairs: [MatchPair]) {
        switch self {
        case .math:
            return (self, Self.mathPairs(count: count, grade: grade))
        case .capitals:
            return (self, Self.capitalPairs(count: count, grade: grade))
        case .englishWords:
            return (self, Self.englishPairs(count: count, grade: grade))
        case .bank(let t):
            let p = Self.bankPairs(topic: t, count: count, grade: grade, profile: profile)
            if p.count == count { return (self, p) }
            return (.math, Self.mathPairs(count: count, grade: grade))
        }
    }

    static func mathPairs(count: Int, grade: Int) -> [MatchPair] {
        var out: [MatchPair] = []
        var seenAnswers = Set<Int>(), seenExpr = Set<String>()
        var tries = 0
        while out.count < count && tries < 200 {
            tries += 1
            let f = MathFacts.fact(grade: grade)
            guard !seenAnswers.contains(f.answer), !seenExpr.contains(f.expression) else { continue }
            seenAnswers.insert(f.answer); seenExpr.insert(f.expression)
            out.append(MatchPair(left: CurriculumMath.ltr(f.expression), right: CurriculumMath.ltr(MathFacts.show(f.answer))))
        }
        return out
    }

    struct Capital { let flag: String; let country: String; let city: String; let easy: Bool }

    /// Timeless, uncontested capitals. Israel is left out on purpose: the board
    /// ships in Arabic too, and a matching game is no place for that argument.
    static var capitalList: [Capital] { [
        Capital(flag: "🇫🇷", country: tr("צָרְפַת"), city: tr("פָּרִיז"), easy: true),
        Capital(flag: "🇮🇹", country: tr("אִיטַלְיָה"), city: tr("רוֹמָא"), easy: true),
        Capital(flag: "🇬🇧", country: tr("בְּרִיטַנְיָה"), city: tr("לוֹנְדוֹן"), easy: true),
        Capital(flag: "🇯🇵", country: tr("יַפָּן"), city: tr("טוֹקְיוֹ"), easy: true),
        Capital(flag: "🇪🇸", country: tr("סְפָרַד"), city: tr("מַדְרִיד"), easy: true),
        Capital(flag: "🇩🇪", country: tr("גֶּרְמַנְיָה"), city: tr("בֶּרְלִין"), easy: true),
        Capital(flag: "🇺🇸", country: tr("אַרְצוֹת הַבְּרִית"), city: tr("וָשִׁינְגְּטוֹן"), easy: true),
        Capital(flag: "🇬🇷", country: tr("יָוָן"), city: tr("אָתוּנָה"), easy: true),
        Capital(flag: "🇷🇺", country: tr("רוּסְיָה"), city: tr("מוֹסְקְבָה"), easy: true),
        Capital(flag: "🇪🇬", country: tr("מִצְרַיִם"), city: tr("קָהִיר"), easy: true),
        Capital(flag: "🇨🇳", country: tr("סִין"), city: tr("בֵּייגִ'ינְג"), easy: false),
        Capital(flag: "🇨🇦", country: tr("קָנָדָה"), city: tr("אוֹטָוָה"), easy: false),
        Capital(flag: "🇦🇺", country: tr("אוֹסְטְרַלְיָה"), city: tr("קַנְבֶּרָה"), easy: false),
        Capital(flag: "🇧🇷", country: tr("בְּרָזִיל"), city: tr("בְּרָזִילְיָה"), easy: false),
        Capital(flag: "🇦🇷", country: tr("אַרְגֶּנְטִינָה"), city: tr("בּוּאֶנוֹס אַיְירֶס"), easy: false),
        Capital(flag: "🇵🇹", country: tr("פּוֹרְטוּגָל"), city: tr("לִיסַבּוֹן"), easy: false),
        Capital(flag: "🇳🇱", country: tr("הוֹלַנְד"), city: tr("אַמְסְטֶרְדָּם"), easy: false),
        Capital(flag: "🇹🇷", country: tr("טוּרְקִיָּה"), city: tr("אַנְקָרָה"), easy: false),
        Capital(flag: "🇰🇷", country: tr("דְּרוֹם קוֹרֵאָה"), city: tr("סֵאוּל"), easy: false),
        Capital(flag: "🇮🇳", country: tr("הֹדּוּ"), city: tr("נְיוּ דֶּלְהִי"), easy: false),
        Capital(flag: "🇸🇪", country: tr("שְׁוֶדְיָה"), city: tr("שְׁטוֹקְהוֹלְם"), easy: false),
        Capital(flag: "🇦🇹", country: tr("אוֹסְטְרִיָּה"), city: tr("וִינָה"), easy: false),
        Capital(flag: "🇹🇭", country: tr("תָּאִילַנְד"), city: tr("בַּנְגְקוֹק"), easy: false),
        Capital(flag: "🇳🇴", country: tr("נוֹרְבֶגְיָה"), city: tr("אוֹסְלוֹ"), easy: false),
    ] }

    static func capitalPairs(count: Int, grade: Int) -> [MatchPair] {
        let all = capitalList
        let easy = all.filter(\.easy), hard = all.filter { !$0.easy }
        let chosen: [Capital]
        switch grade {
        case ...3: chosen = Array(easy.shuffled().prefix(count))
        case 4:    chosen = Array(easy.shuffled().prefix(3)) + Array(hard.shuffled().prefix(count - 3))
        default:   chosen = Array(easy.shuffled().prefix(1)) + Array(hard.shuffled().prefix(count - 1))
        }
        return chosen.map { MatchPair(left: "\($0.flag) \($0.country)", right: $0.city) }
    }

    private struct Word { let emoji: String; let label: String; let english: String }

    private static var basicWords: [Word] { [
        Word(emoji: "🐶", label: tr("כֶּלֶב"), english: "dog"),
        Word(emoji: "🐱", label: tr("חָתוּל"), english: "cat"),
        Word(emoji: "☀️", label: tr("שֶׁמֶשׁ"), english: "sun"),
        Word(emoji: "🍎", label: tr("תַּפּוּחַ"), english: "apple"),
        Word(emoji: "⚽", label: tr("כַּדּוּר"), english: "ball"),
        Word(emoji: "🐟", label: tr("דָּג"), english: "fish"),
        Word(emoji: "📖", label: tr("סֵפֶר"), english: "book"),
        Word(emoji: "🚗", label: tr("מְכוֹנִית"), english: "car"),
        Word(emoji: "🏠", label: tr("בַּיִת"), english: "house"),
        Word(emoji: "🌳", label: tr("עֵץ"), english: "tree"),
        Word(emoji: "🥛", label: tr("חָלָב"), english: "milk"),
        Word(emoji: "🐦", label: tr("צִפּוֹר"), english: "bird"),
        Word(emoji: "⭐", label: tr("כּוֹכָב"), english: "star"),
        Word(emoji: "🌙", label: tr("יָרֵחַ"), english: "moon"),
        Word(emoji: "🌸", label: tr("פֶּרַח"), english: "flower"),
        Word(emoji: "🐮", label: tr("פָּרָה"), english: "cow"),
        Word(emoji: "🦁", label: tr("אַרְיֵה"), english: "lion"),
        Word(emoji: "🍞", label: tr("לֶחֶם"), english: "bread"),
        Word(emoji: "💧", label: tr("מַיִם"), english: "water"),
    ] }

    /// ז׳–ח׳: words a seventh grader meets in the textbook, not words that
    /// are hard to spell. The English ladder rises by vocabulary only.
    private static var laterWords: [Word] { [
        Word(emoji: "🌦️", label: tr("מַזָּג אֲוִיר"), english: "weather"),
        Word(emoji: "📚", label: tr("סִפְרִיָּה"), english: "library"),
        Word(emoji: "🍳", label: tr("אֲרוּחַת בֹּקֶר"), english: "breakfast"),
        Word(emoji: "🌍", label: tr("עוֹלָם"), english: "world"),
        Word(emoji: "🚑", label: tr("אַמְבּוּלַנְס"), english: "ambulance"),
        Word(emoji: "🏥", label: tr("בֵּית חוֹלִים"), english: "hospital"),
        Word(emoji: "🧪", label: tr("נִסּוּי"), english: "experiment"),
        Word(emoji: "🗺️", label: tr("מַסָּע"), english: "journey"),
        Word(emoji: "🌉", label: tr("גֶּשֶׁר"), english: "bridge"),
        Word(emoji: "🏖️", label: tr("חוֹף"), english: "beach"),
        Word(emoji: "🎒", label: tr("שִׁעוּרֵי בַּיִת"), english: "homework"),
        Word(emoji: "🌡️", label: tr("טֶמְפֶּרָטוּרָה"), english: "temperature"),
        Word(emoji: "🦷", label: tr("רוֹפֵא שִׁנַּיִם"), english: "dentist"),
        Word(emoji: "🎟️", label: tr("כַּרְטִיס"), english: "ticket"),
    ] }

    private static var advancedWords: [Word] { [
        Word(emoji: "🏫", label: tr("בֵּית סֵפֶר"), english: "school"),
        Word(emoji: "🤝", label: tr("חָבֵר"), english: "friend"),
        Word(emoji: "👨‍👩‍👧", label: tr("מִשְׁפָּחָה"), english: "family"),
        Word(emoji: "🍳", label: tr("מִטְבָּח"), english: "kitchen"),
        Word(emoji: "🪟", label: tr("חַלּוֹן"), english: "window"),
        Word(emoji: "🌧️", label: tr("גֶּשֶׁם"), english: "rain"),
        Word(emoji: "🐴", label: tr("סוּס"), english: "horse"),
        Word(emoji: "🪑", label: tr("כִּסֵּא"), english: "chair"),
        Word(emoji: "✈️", label: tr("מָטוֹס"), english: "airplane"),
        Word(emoji: "🎂", label: tr("עוּגָה"), english: "cake"),
        Word(emoji: "🐘", label: tr("פִּיל"), english: "elephant"),
        Word(emoji: "🧀", label: tr("גְּבִינָה"), english: "cheese"),
        Word(emoji: "🕐", label: tr("שָׁעוֹן"), english: "clock"),
        Word(emoji: "🏔️", label: tr("הַר"), english: "mountain"),
        Word(emoji: "❄️", label: tr("שֶׁלֶג"), english: "snow"),
        Word(emoji: "👟", label: tr("נַעַל"), english: "shoe"),
        Word(emoji: "🎒", label: tr("תִּיק"), english: "bag"),
    ] }

    /// The child's own-language word ↔ the English word. In English the left
    /// side is the picture alone — an American child matching "dog" to "dog"
    /// would be no game at all.
    static func englishPairs(count: Int, grade: Int) -> [MatchPair] {
        let list: [Word]
        switch MiniGameBand.of(grade) {
        case .preReader, .lower, .middle:
            list = basicWords
        case .upper:
            list = Array(basicWords.shuffled().prefix(2)) + advancedWords
        case .top:
            list = Array(advancedWords.shuffled().prefix(3)) + laterWords
        }
        let pictureOnly = LanguageStore.shared.current == .en
        return list.shuffled().prefix(count).map { w in
            MatchPair(left: pictureOnly ? w.emoji : "\(w.emoji) \(w.label)",
                      right: w.english)
        }
    }

    /// Short prompt ↔ answer pairs from the world's own bank (🦖 🚀 🔬 …) —
    /// only questions that stand without their options, five different answers.
    static func bankPairs(topic: Topic, count: Int, grade: Int, profile: Profile?) -> [MatchPair] {
        let items = GameContent.distinctAnswers(
            GameContent.items(topic: topic, grade: grade, maxPrompt: 60, maxAnswer: 24, standalone: true))
        return items.prefix(count).map { MatchPair(left: $0.prompt, right: $0.answer) }
    }
}


// MARK: - 🎁 Mini-game rewards (⭐ + 💎 only — never minutes)

enum MiniGameReward {
    struct Grant { let stars: Int; let diamonds: Int; let full: Bool; var doubled: Bool = false }

    private static func dayKey(_ game: String) -> String {
        "minigame.full.\(game).\(ProfileStore.shared.activeID?.uuidString ?? "none")"
    }

    /// From a world screen: the first finished round of the day pays per
    /// correct answer (capped); replays pay a small practice reward — the boss
    /// battle's rule, so a 60-second loop can't farm the shop.
    ///
    /// ⚡ In a surprise round it always pays the full amount, doubled: the round
    /// only comes after 12–15 real questions (twice a session at most), so it
    /// can't be farmed — the questions are the gate.
    @discardableResult
    static func grant(game: String, correct: Int, starsPer: Int, diamondsPer: Int, cap: Int,
                      surprise: Bool = false) -> Grant {
        let n = max(0, min(correct, cap))
        let grant: Grant
        if surprise {
            let m = SurpriseRound.rewardMultiplier
            grant = Grant(stars: n * starsPer * m, diamonds: n * diamondsPer * m, full: true, doubled: true)
        } else {
            let key = dayKey(game)
            let usedToday = DayGate.usedToday(UserDefaults.standard.object(forKey: key) as? Date)
            if !usedToday && n > 0 {
                grant = Grant(stars: n * starsPer, diamonds: n * diamondsPer, full: true)
                UserDefaults.standard.set(Date(), forKey: key)
            } else {
                grant = Grant(stars: min(n, 5), diamonds: 0, full: false)
            }
        }
        if grant.stars > 0 || grant.diamonds > 0 {
            ProgressStore.shared.applyChestReward(ChestReward(stars: grant.stars, diamonds: grant.diamonds, minutes: 0))
        }
        return grant
    }
}

// MARK: - 🎈 Balloon sets

struct BalloonItem: Hashable {
    let emoji: String
    let label: String
    let correct: Bool
}

/// One balloon round: "פּוֹצְצוּ אֶת כָּל הַחַיּוֹת שֶׁחַיּוֹת בַּיָּם!" and the
/// items that float up — the ones to pop and the ones to let fly.
struct BalloonSet {
    let prompt: String
    let topic: Topic
    let targets: [BalloonItem]
    let others: [BalloonItem]
}

enum BalloonSets {
    /// The set for a world (or a surprise round's theme). Every interest world
    /// has its own; the rest get numbers sized to the child's grade.
    /// Does this world have balloons of its own? (Any other world pops the
    /// answers to its own questions.)
    static func hasCategory(_ topic: Topic, grade: Int) -> Bool {
        switch topic {
        case .sea, .animals, .space, .dinosaurs, .soccer, .english, .science, .math: return true
        case .flags, .geography: return grade >= 2
        default: return false
        }
    }

    /// Every set has two rungs: the picture-level sort for א׳–ד׳, and a real
    /// classification from ה׳ — sea MAMMALS instead of "lives in the sea", gas
    /// giants instead of "is a planet", carnivores instead of "is a dinosaur",
    /// English VERBS instead of English animals. Same game, grown-up rule.
    static func make(for topic: Topic?, grade: Int) -> BalloonSet {
        let hard = MiniGameBand.of(grade) >= .upper
        switch topic {
        case .sea?, .animals?:      return seaAnimals(hard: hard)
        case .flags?, .geography?:  return grade >= 2 ? capitals(grade: grade) : numbers(grade: grade)
        case .space?:               return planets(hard: hard)
        case .dinosaurs?:           return dinosaurs(hard: hard)
        case .soccer?:              return soccer(hard: hard)
        case .english?:             return englishWords(hard: hard)
        case .science?:             return Bool.random() ? planets(hard: hard) : seaAnimals(hard: hard)
        case .math?:                return numbers(grade: grade)
        default:
            var all: [() -> BalloonSet] = [{ numbers(grade: grade) }, { seaAnimals(hard: hard) }, { planets(hard: hard) }]
            if grade >= 2 { all.append { capitals(grade: grade) } }
            return all.randomElement()!()
        }
    }

    /// ה׳+: which of the sea's animals are MAMMALS — a dolphin and a whale
    /// against a shark, an octopus and a turtle. The easy board's rule
    /// ("lives in the sea") a ו׳ child solves without reading.
    static func seaMammals() -> BalloonSet {
        BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל הַיּוֹנְקִים שֶׁחַיִּים בַּיָּם!"),
            topic: .sea,
            targets: [
                BalloonItem(emoji: "🐬", label: tr("דּוֹלְפִין"), correct: true),
                BalloonItem(emoji: "🐳", label: tr("לִוְיָתָן"), correct: true),
                BalloonItem(emoji: "🦭", label: tr("כֶּלֶב יָם"), correct: true),
                BalloonItem(emoji: "🐋", label: tr("אוֹרְקָה"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🦈", label: tr("כָּרִישׁ"), correct: false),
                BalloonItem(emoji: "🐙", label: tr("תְּמָנוּן"), correct: false),
                BalloonItem(emoji: "🪼", label: tr("מֵדוּזָה"), correct: false),
                BalloonItem(emoji: "🦀", label: tr("סַרְטָן"), correct: false),
                BalloonItem(emoji: "🐠", label: tr("דָּג"), correct: false),
                BalloonItem(emoji: "🐢", label: tr("צָב יָם"), correct: false),
                BalloonItem(emoji: "🦑", label: tr("דְּיוֹנוּן"), correct: false),
                BalloonItem(emoji: "⭐", label: tr("כּוֹכַב יָם"), correct: false),
            ])
    }

    static func seaAnimals(hard: Bool = false) -> BalloonSet {
        if hard { return seaMammals() }
        return BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל הַחַיּוֹת שֶׁחַיּוֹת בַּיָּם!"),
            topic: .sea,
            targets: [
                BalloonItem(emoji: "🐙", label: tr("תְּמָנוּן"), correct: true),
                BalloonItem(emoji: "🐬", label: tr("דּוֹלְפִין"), correct: true),
                BalloonItem(emoji: "🦈", label: tr("כָּרִישׁ"), correct: true),
                BalloonItem(emoji: "🐳", label: tr("לִוְיָתָן"), correct: true),
                BalloonItem(emoji: "🦀", label: tr("סַרְטָן"), correct: true),
                BalloonItem(emoji: "🐠", label: tr("דָּג"), correct: true),
                BalloonItem(emoji: "🪼", label: tr("מֵדוּזָה"), correct: true),
                BalloonItem(emoji: "⭐", label: tr("כּוֹכַב יָם"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🦁", label: tr("אַרְיֵה"), correct: false),
                BalloonItem(emoji: "🐘", label: tr("פִּיל"), correct: false),
                BalloonItem(emoji: "🦒", label: tr("גִ'ירָפָה"), correct: false),
                BalloonItem(emoji: "🐄", label: tr("פָּרָה"), correct: false),
                BalloonItem(emoji: "🐎", label: tr("סוּס"), correct: false),
                BalloonItem(emoji: "🐒", label: tr("קוֹף"), correct: false),
                BalloonItem(emoji: "🐇", label: tr("אַרְנָב"), correct: false),
                BalloonItem(emoji: "🐫", label: tr("גָּמָל"), correct: false),
            ])
    }

    /// Even / odd / multiples of n / squares / primes — the rule and the range
    /// both climb. Even-or-odd stops being offered from ה׳: a ו׳ child reads
    /// it off the last digit without thinking.
    static func numbers(grade: Int) -> BalloonSet {
        let g = max(1, grade)
        let band = MiniGameBand.of(g)
        let top: Int
        switch band {
        case .preReader, .lower: top = g <= 1 ? 20 : 100
        case .middle:            top = 200
        case .upper:             top = 500
        case .top:               top = 1000
        }
        enum Rule { case even, odd, multiple(Int), square, prime }
        var rules: [Rule] = []
        if band <= .middle { rules += [.even, .odd] }
        if g >= 3 { rules.append(.multiple([3, 4, 5].randomElement()!)) }
        if g >= 5 { rules += [.multiple([6, 7, 9].randomElement()!), .square] }
        if g >= 6 { rules.append(.multiple([11, 12, 15].randomElement()!)) }
        if g >= 7 { rules.append(.prime) }
        let rule = rules.randomElement() ?? .even
        let prompt: String
        let isTarget: (Int) -> Bool
        switch rule {
        case .even:
            prompt = tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הַזּוּגִיִּים!")
            isTarget = { $0 % 2 == 0 }
        case .odd:
            prompt = tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הָאִי־זוּגִיִּים!")
            isTarget = { $0 % 2 == 1 }
        case .multiple(let n):
            prompt = tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים שֶׁמִּתְחַלְּקִים בְּ־\(n)!")
            isTarget = { $0 % n == 0 }
        case .square:
            prompt = tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הָרִבּוּעִיִּים!")
            let squares = Set((1...40).map { $0 * $0 })
            isTarget = { squares.contains($0) }
        case .prime:
            prompt = tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הָרִאשׁוֹנִיִּים!")
            isTarget = { n in
                guard n > 1 else { return false }
                if n < 4 { return true }
                if n % 2 == 0 { return false }
                var d = 3
                while d * d <= n {
                    if n % d == 0 { return false }
                    d += 2
                }
                return true
            }
        }
        let pool = Array(1...top).shuffled()
        // A sparse rule (squares, primes) needs its targets found across the
        // WHOLE range, not in the first slice of a shuffle.
        let targets = pool.filter(isTarget).prefix(14).map { BalloonItem(emoji: "", label: "\($0)", correct: true) }
        // Near misses: a square's neighbours, a prime's odd neighbours.
        let misses = pool.filter { !isTarget($0) && (isTarget($0 - 1) || isTarget($0 + 1)) }.prefix(7)
        let rest = pool.filter { !isTarget($0) && !misses.contains($0) }.prefix(14 - misses.count)
        let others = (Array(misses) + Array(rest)).map { BalloonItem(emoji: "", label: "\($0)", correct: false) }
        return BalloonSet(prompt: prompt, topic: .math, targets: Array(targets), others: Array(others))
    }

    /// Capitals against big cities that are NOT capitals — each with its flag,
    /// so 🇪🇸 מַדְרִיד and 🇪🇸 בַּרְצֶלוֹנָה make the child think.
    static func capitals(grade: Int) -> BalloonSet {
        // ה׳+: Ottawa, Canberra and Ankara join the board — the easy half
        // alone (Paris, Rome, London) is a ג׳ round.
        let list = MiniGameBand.of(grade) >= .upper
            ? MatchPairsSource.capitalList
            : MatchPairsSource.capitalList.filter(\.easy)
        let caps = list.map { BalloonItem(emoji: $0.flag, label: $0.city, correct: true) }
        return BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל עָרֵי הַבִּירָה!"),
            topic: .geography,
            targets: caps,
            others: [
                BalloonItem(emoji: "🇪🇸", label: tr("בַּרְצֶלוֹנָה"), correct: false),
                BalloonItem(emoji: "🇮🇹", label: tr("מִילָאנוֹ"), correct: false),
                BalloonItem(emoji: "🇬🇧", label: tr("מַנְצֶ'סְטֶר"), correct: false),
                BalloonItem(emoji: "🇯🇵", label: tr("אוֹסָקָה"), correct: false),
                BalloonItem(emoji: "🇩🇪", label: tr("מִינְכֶן"), correct: false),
                BalloonItem(emoji: "🇺🇸", label: tr("נְיוּ יוֹרְק"), correct: false),
                BalloonItem(emoji: "🇦🇺", label: tr("סִידְנִי"), correct: false),
                BalloonItem(emoji: "🇹🇷", label: tr("אִיסְטַנְבּוּל"), correct: false),
                BalloonItem(emoji: "🇧🇷", label: tr("רִיוֹ דֶה זָ'נֵירוֹ"), correct: false),
            ])
    }

    /// ה׳+: the gas giants against the rocky planets — the easy board only
    /// asks "is it a planet at all".
    static func gasGiants() -> BalloonSet {
        BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל כּוֹכְבֵי הַלֶּכֶת הַגָּזִיִּים!"),
            topic: .space,
            targets: [
                BalloonItem(emoji: "🟠", label: tr("צֶדֶק"), correct: true),
                BalloonItem(emoji: "🪐", label: tr("שַׁבְּתַאי"), correct: true),
                BalloonItem(emoji: "🟢", label: tr("אוּרָנוּס"), correct: true),
                BalloonItem(emoji: "🔵", label: tr("נֶפְּטוּן"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🟤", label: tr("כּוֹכָב חַמָּה"), correct: false),
                BalloonItem(emoji: "🟡", label: tr("נֹגַהּ"), correct: false),
                BalloonItem(emoji: "🌍", label: tr("כַּדּוּר הָאָרֶץ"), correct: false),
                BalloonItem(emoji: "🔴", label: tr("מַאְדִּים"), correct: false),
                BalloonItem(emoji: "🌙", label: tr("הַיָּרֵחַ"), correct: false),
                BalloonItem(emoji: "☄️", label: tr("שָׁבִיט"), correct: false),
                BalloonItem(emoji: "🪨", label: tr("אַסְטֶרוֹאִיד"), correct: false),
            ])
    }

    static func planets(hard: Bool = false) -> BalloonSet {
        if hard { return gasGiants() }
        return BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל כּוֹכְבֵי הַלֶּכֶת!"),
            topic: .space,
            targets: [
                BalloonItem(emoji: "🌍", label: tr("כַּדּוּר הָאָרֶץ"), correct: true),
                BalloonItem(emoji: "🔴", label: tr("מַאְדִּים"), correct: true),
                BalloonItem(emoji: "🪐", label: tr("שַׁבְּתַאי"), correct: true),
                BalloonItem(emoji: "🟠", label: tr("צֶדֶק"), correct: true),
                BalloonItem(emoji: "🔵", label: tr("נֶפְּטוּן"), correct: true),
                BalloonItem(emoji: "🟡", label: tr("נֹגַהּ"), correct: true),
                BalloonItem(emoji: "🟤", label: tr("כּוֹכָב חַמָּה"), correct: true),
                BalloonItem(emoji: "🟢", label: tr("אוּרָנוּס"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "☀️", label: tr("הַשֶּׁמֶשׁ"), correct: false),
                BalloonItem(emoji: "🌙", label: tr("הַיָּרֵחַ"), correct: false),
                BalloonItem(emoji: "☄️", label: tr("שָׁבִיט"), correct: false),
                BalloonItem(emoji: "🌌", label: tr("גָּלַקְסְיָה"), correct: false),
                BalloonItem(emoji: "🛰️", label: tr("לַוְיָן"), correct: false),
                BalloonItem(emoji: "🕳️", label: tr("חוֹר שָׁחֹר"), correct: false),
                BalloonItem(emoji: "🪨", label: tr("אַסְטֶרוֹאִיד"), correct: false),
            ])
    }

    /// Real dinosaurs against animals kids often mistake for them (a mammoth, a
    /// crocodile). Flying and swimming reptiles are left out on purpose — they
    /// weren't dinosaurs, and a balloon is no place for that fine print.
    /// ה׳+: which of them ATE MEAT. "Is it a dinosaur" is a ב׳ question.
    static func dinosaurCarnivores() -> BalloonSet {
        BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל הַדִּינוֹזָאוּרִים שֶׁאָכְלוּ בָּשָׂר!"),
            topic: .dinosaurs,
            targets: [
                BalloonItem(emoji: "🦖", label: tr("טִירָנוֹזָאוּרוּס"), correct: true),
                BalloonItem(emoji: "🦖", label: tr("וֶלוֹצִירַפְּטוֹר"), correct: true),
                BalloonItem(emoji: "🦖", label: tr("סְפִּינוֹזָאוּרוּס"), correct: true),
                BalloonItem(emoji: "🦖", label: tr("אַלוֹזָאוּרוּס"), correct: true),
                BalloonItem(emoji: "🦖", label: tr("דִּילוֹפוֹזָאוּרוּס"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🦴", label: tr("טְרִיצֶרָטוֹפְּס"), correct: false),
                BalloonItem(emoji: "🦴", label: tr("סְטֶגוֹזָאוּרוּס"), correct: false),
                BalloonItem(emoji: "🦕", label: tr("בְּרָכִיוֹזָאוּרוּס"), correct: false),
                BalloonItem(emoji: "🦕", label: tr("דִּיפְּלוֹדוֹקוּס"), correct: false),
                BalloonItem(emoji: "🦴", label: tr("אַנְקִילוֹזָאוּרוּס"), correct: false),
                BalloonItem(emoji: "🦕", label: tr("פָּרָזָאוּרוֹלוֹפוּס"), correct: false),
            ])
    }

    static func dinosaurs(hard: Bool = false) -> BalloonSet {
        if hard { return dinosaurCarnivores() }
        return BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל הַדִּינוֹזָאוּרִים!"),
            topic: .dinosaurs,
            targets: [
                BalloonItem(emoji: "🦖", label: tr("טִירָנוֹזָאוּרוּס"), correct: true),
                BalloonItem(emoji: "🦕", label: tr("בְּרָכִיוֹזָאוּרוּס"), correct: true),
                BalloonItem(emoji: "🦕", label: tr("דִּיפְּלוֹדוֹקוּס"), correct: true),
                BalloonItem(emoji: "🦖", label: tr("וֶלוֹצִירַפְּטוֹר"), correct: true),
                BalloonItem(emoji: "🦴", label: tr("טְרִיצֶרָטוֹפְּס"), correct: true),
                BalloonItem(emoji: "🦴", label: tr("סְטֶגוֹזָאוּרוּס"), correct: true),
                BalloonItem(emoji: "🦴", label: tr("אַנְקִילוֹזָאוּרוּס"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🐊", label: tr("תַּנִּין"), correct: false),
                BalloonItem(emoji: "🦣", label: tr("מָמוּתָה"), correct: false),
                BalloonItem(emoji: "🦎", label: tr("לְטָאָה"), correct: false),
                BalloonItem(emoji: "🐢", label: tr("צָב"), correct: false),
                BalloonItem(emoji: "🦏", label: tr("קַרְנַף"), correct: false),
                BalloonItem(emoji: "🐍", label: tr("נָחָשׁ"), correct: false),
                BalloonItem(emoji: "🐘", label: tr("פִּיל"), correct: false),
            ])
    }

    /// Soccer things against other sports. (Club rosters change every
    /// transfer window — a balloon must still be true next year.)
    /// ה׳+: the defensive roles against the attacking ones — real football
    /// knowledge, instead of "is a ball part of football".
    static func soccerRoles() -> BalloonSet {
        BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל תַּפְקִידֵי הַהֲגָנָה!"),
            topic: .soccer,
            targets: [
                BalloonItem(emoji: "🧤", label: tr("שׁוֹעֵר"), correct: true),
                BalloonItem(emoji: "🛡️", label: tr("בַּלָּם"), correct: true),
                BalloonItem(emoji: "🛡️", label: tr("מֵגֵן"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🎯", label: tr("חָלוּץ"), correct: false),
                BalloonItem(emoji: "🎯", label: tr("כַּנְפָן"), correct: false),
                BalloonItem(emoji: "🔄", label: tr("קַשָּׁר"), correct: false),
                BalloonItem(emoji: "🧑‍🏫", label: tr("מְאַמֵּן"), correct: false),
                BalloonItem(emoji: "🧑‍⚖️", label: tr("שׁוֹפֵט"), correct: false),
                BalloonItem(emoji: "📣", label: tr("אוֹהֵד"), correct: false),
            ])
    }

    static func soccer(hard: Bool = false) -> BalloonSet {
        if hard { return soccerRoles() }
        return BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל מַה שֶּׁשַּׁיָּךְ לְכַדּוּרֶגֶל!"),
            topic: .soccer,
            targets: [
                BalloonItem(emoji: "⚽", label: tr("כַּדּוּר"), correct: true),
                BalloonItem(emoji: "🥅", label: tr("שַׁעַר"), correct: true),
                BalloonItem(emoji: "🧤", label: tr("שׁוֹעֵר"), correct: true),
                BalloonItem(emoji: "🟨", label: tr("כַּרְטִיס צָהֹב"), correct: true),
                BalloonItem(emoji: "🟥", label: tr("כַּרְטִיס אָדֹם"), correct: true),
                BalloonItem(emoji: "🚩", label: tr("נִבְדָּל"), correct: true),
                BalloonItem(emoji: "🎯", label: tr("פֶּנְדֵּל"), correct: true),
                BalloonItem(emoji: "🏳️", label: tr("קֶרֶן"), correct: true),
            ],
            others: [
                BalloonItem(emoji: "🏀", label: tr("כַּדּוּרְסַל"), correct: false),
                BalloonItem(emoji: "🎾", label: tr("טֶנִיס"), correct: false),
                BalloonItem(emoji: "🏓", label: tr("פִּינְג פּוֹנְג"), correct: false),
                BalloonItem(emoji: "⛳", label: tr("גּוֹלְף"), correct: false),
                BalloonItem(emoji: "🥊", label: tr("אִגְרוּף"), correct: false),
                BalloonItem(emoji: "🛹", label: tr("סְקֵייטְבּוֹרְד"), correct: false),
                BalloonItem(emoji: "🏸", label: tr("בַּדְמִינְטוֹן"), correct: false),
            ])
    }

    /// English words against other English words — no pictures: the child has
    /// to read the word. ג׳–ד׳ sort animals from everything else; ה׳ and up
    /// sort VERBS from nouns, which is what the English lesson is about by
    /// then. The words themselves stay everyday words — English is a second
    /// language here and its ladder is meant to stay gentle.
    static func englishWords(hard: Bool = false) -> BalloonSet {
        if hard {
            return BalloonSet(
                prompt: tr("פּוֹצְצוּ אֶת כָּל הַפְּעָלִים בְּאַנְגְּלִית!"),
                topic: .english,
                targets: ["run", "eat", "jump", "write", "sing", "read", "swim", "drink", "sleep", "think"]
                    .map { BalloonItem(emoji: "", label: $0, correct: true) },
                others: ["table", "water", "school", "friend", "window", "garden", "bread", "river", "chair", "flower"]
                    .map { BalloonItem(emoji: "", label: $0, correct: false) })
        }
        return BalloonSet(
            prompt: tr("פּוֹצְצוּ אֶת כָּל הַחַיּוֹת בְּאַנְגְּלִית!"),
            topic: .english,
            targets: ["dog", "cat", "horse", "lion", "fish", "bird", "cow", "monkey", "duck"]
                .map { BalloonItem(emoji: "", label: $0, correct: true) },
            others: ["apple", "car", "book", "tree", "house", "chair", "milk", "bread", "shoe"]
                .map { BalloonItem(emoji: "", label: $0, correct: false) })
    }
}

// MARK: - 🧩 Build-the-word sets

/// One word to build: the picture, and the word's letters in order.
struct SpellWord: Hashable {
    let emoji: String
    let word: String
}

enum SpellScript {
    case hebrew, english
    /// A world's own answers in the child's language (🇷🇺 / 🇸🇦 banks).
    case cyrillic, arabic
    /// Hebrew and Arabic fill their slots right-to-left, English and Russian
    /// left-to-right — whatever the app's own language is.
    var direction: LayoutDirection { self == .hebrew || self == .arabic ? .rightToLeft : .leftToRight }
    var topic: Topic { self == .hebrew ? .hebrew : .english }
    /// Latin and Cyrillic are shown in capitals.
    var uppercased: Bool { self == .english || self == .cyrillic }
    /// The letters an extra tile / the word search's filler come from.
    var alphabet: [Character] {
        switch self {
        case .english:  return Array("ABCDEFGHIKLMNOPRSTUWY")
        case .hebrew:   return Array("אבגדהוזחטיכלמנסעפצקרשת")
        case .cyrillic: return Array("АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЫЭЮЯ")
        case .arabic:   return Array("ابتثجحخدذرزسشصضطظعغفقكلمنهوي")
        }
    }
    /// A word as its tiles show it.
    func display(_ word: String) -> String { uppercased ? word.uppercased() : word }
}

/// Short concrete nouns with an unambiguous picture — the picture is the only
/// clue (writing the word next to it would give the spelling away). Hebrew is
/// spelled without niqqud, final letters included.
enum WordSets {
    static let wordCount = 5

    /// Which script a board spells in: the English world spells English, the
    /// Hebrew world Hebrew; a surprise round spells English for an English
    /// speaker or from ג׳ (when English starts at school), Hebrew before that.
    static func script(for topic: Topic?, grade: Int) -> SpellScript {
        switch topic {
        case .english?: return .english
        case .hebrew?:  return .hebrew
        default:
            if LanguageStore.shared.current == .en { return .english }
            if LanguageStore.shared.current == .he && grade < 3 { return .hebrew }
            return .english
        }
    }

    /// Can this child be handed a spelling board themed on an interest world?
    /// An English or Hebrew speaker always (their own letters); a Russian or
    /// Arabic speaker from ג׳, when English starts at school — never a script
    /// the child hasn't met yet.
    /// A world with its own picture list (the rest spell their own answers).
    static func hasThemedList(_ topic: Topic?, grade: Int) -> Bool {
        switch topic {
        case .english?, .hebrew?: return true
        case .soccer?, .sea?, .space?, .animals?, .dinosaurs?, .flags?: return spellingAvailable(grade: grade)
        default: return false
        }
    }

    static func spellingAvailable(grade: Int) -> Bool {
        switch LanguageStore.shared.current {
        case .en, .he: return true
        default:       return grade >= 3
        }
    }

    /// 🧩 The five words one spelling board shows. `maxLetters` is what a row
    /// of slots can hold before the tiles shrink out of reach.
    static func words(for topic: Topic?, script: SpellScript, grade: Int, maxLetters: Int = 8) -> [SpellWord] {
        Array(list(for: topic, script: script, grade: grade, maxLetters: maxLetters).prefix(wordCount))
    }

    /// The child's own rung of the ladder, already shuffled (the word search
    /// takes whatever fits its grid).
    ///
    /// 🇮🇱 Hebrew climbs steeply — it is the mother tongue, and by ה׳ a board of
    /// כלב / בית / ספר is an insult. 🇺🇸 English climbs gently — it starts in ג׳
    /// as a foreign language and the ו׳ level is already right.
    static func list(for topic: Topic?, script: SpellScript, grade: Int, maxLetters: Int = 8) -> [SpellWord] {
        switch script {
        case .hebrew:
            return HebrewLadder.words(topic: topic, grade: grade, maxLetters: maxLetters, minimum: wordCount)
        // Picture lists exist in English and Hebrew only; the other scripts
        // spell a world's own answers (GameContent.words).
        case .english, .cyrillic, .arabic:
            return english(topic, grade: grade, maxLetters: maxLetters)
        }
    }

    /// 🇺🇸 A themed world keeps its own short picture words; everything else
    /// comes off English's two gentle rungs (see `EnglishLadder`).
    private static func english(_ topic: Topic?, grade: Int, maxLetters: Int) -> [SpellWord] {
        func w(_ e: String, _ s: String) -> SpellWord { SpellWord(emoji: e, word: s) }
        let themed: [SpellWord]
        switch topic {
        case .soccer?:    themed = [w("⚽", "ball"), w("🥅", "goal"), w("👟", "shoe"), w("🚩", "flag"), w("🏆", "cup"), w("🧤", "glove")]
        case .sea?:       themed = [w("🐟", "fish"), w("🦀", "crab"), w("🦈", "shark"), w("🐳", "whale"), w("🐚", "shell"), w("🐙", "octopus")]
        case .space?:     themed = [w("☀️", "sun"), w("🌙", "moon"), w("⭐", "star"), w("🚀", "rocket"), w("🪐", "planet"), w("👽", "alien")]
        case .animals?:   themed = [w("🐶", "dog"), w("🐱", "cat"), w("🐄", "cow"), w("🦁", "lion"), w("🐴", "horse"), w("🦆", "duck"), w("🐸", "frog")]
        case .dinosaurs?: themed = [w("🦴", "bone"), w("🥚", "egg"), w("🦷", "tooth"), w("🍃", "leaf"), w("🪨", "rock"), w("🌋", "volcano")]
        case .flags?:     themed = [w("🚩", "flag"), w("🗺️", "map"), w("🏙️", "city"), w("🚢", "ship"), w("✈️", "plane"), w("🏝️", "island")]
        default:          themed = []
        }
        // 🇬🇧 An American child's English is a mother tongue and gets the full
        // ladder; an Israeli child's English is a second language and gets the
        // gentle one.
        let ladder = EnglishLadder.words(grade: grade, maxLetters: maxLetters, minimum: wordCount,
                                         motherTongue: SpellScript.english.isMotherTongue)
        guard !themed.isEmpty else { return ladder }
        var out = themed.filter { $0.word.count <= maxLetters }.shuffled()
        if out.count < wordCount {
            out += ladder.filter { l in !out.contains(where: { $0.word == l.word }) }
        }
        return out
    }
}

// MARK: - 🔤 Word search

struct GridCell: Hashable {
    let r: Int
    let c: Int
}

struct HiddenWord: Identifiable {
    var id: String { word }
    let word: String
    let emoji: String
    /// Cells in reading order (logical columns: 0 is where a line STARTS —
    /// the right edge for Hebrew, the left edge for English).
    let cells: [GridCell]
}

struct WordSearchBoard {
    let size: Int
    /// `letters[r][c]`, logical columns.
    let letters: [[Character]]
    let words: [HiddenWord]
    let script: SpellScript
    /// Words may run diagonally — the finger has to snap the same way the
    /// board was built, so the rule travels WITH the board.
    let diagonals: Bool
    /// Words may run back-to-front (ה׳ and up, mother tongue only).
    let backwards: Bool
}

enum WordSearch {
    static let wordCount = 5

    /// 5 themed words hidden in the grid, the rest filled with random letters.
    /// How large the grid is, whether words run diagonally and whether they
    /// run backwards all come from `WordSearchShape` — and all three climb
    /// much faster in the child's own language than in a foreign one.
    /// English is shown in capitals; Hebrew without niqqud, final letters as
    /// written.
    static func make(topic: Topic?, script: SpellScript, grade: Int, size: Int) -> WordSearchBoard {
        let themed = WordSets.list(for: topic, script: script, grade: grade, maxLetters: size)
        let general = WordSets.list(for: nil, script: script, grade: grade, maxLetters: size)
        var candidates = themed
        candidates += general.filter { g in !candidates.contains(where: { $0.word == g.word }) }
        return place(candidates.filter { (2...size).contains($0.word.count) },
                     script: script, grade: grade, size: size)
    }

    /// 🧺 The world's own short answers (capitals, animals, planets…) hidden in
    /// the grid — for a world without a themed picture list.
    static func make(words: [SpellWord], script: SpellScript, grade: Int, size: Int) -> WordSearchBoard {
        place(words.filter { (2...size).contains($0.word.count) }.shuffled(), script: script, grade: grade, size: size)
    }

    private static func place(_ candidates: [SpellWord], script: SpellScript, grade: Int, size: Int) -> WordSearchBoard {
        let diagonals = WordSearchShape.diagonals(grade: grade, script: script)
        let backwards = WordSearchShape.backwards(grade: grade, script: script)
        var directions: [(Int, Int)] = [(0, 1), (1, 0)]
        if diagonals { directions.append((1, 1)) }
        if backwards {
            directions += [(0, -1), (-1, 0)]
            if diagonals { directions += [(1, -1), (-1, 1)] }
        }
        var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
        var placed: [HiddenWord] = []
        var used = Set<String>()
        // The longest words first: they need the emptiest grid.
        for cand in candidates.sorted(by: { $0.word.count > $1.word.count }) where placed.count < wordCount {
            let word = script.display(cand.word)
            guard used.insert(word).inserted else { continue }
            let letters = Array(word)
            let span = letters.count - 1
            var done = false
            for _ in 0..<200 where !done {
                let (dr, dc) = directions.randomElement()!
                // The first cell has to leave room for the whole word — in
                // front of it, or behind it when the word runs backwards.
                let rLo = dr < 0 ? span : 0, rHi = dr > 0 ? size - 1 - span : size - 1
                let cLo = dc < 0 ? span : 0, cHi = dc > 0 ? size - 1 - span : size - 1
                guard rLo <= rHi, cLo <= cHi else { continue }
                let r0 = Int.random(in: rLo...rHi), c0 = Int.random(in: cLo...cHi)
                let cells = letters.indices.map { GridCell(r: r0 + dr * $0, c: c0 + dc * $0) }
                let fits = zip(cells, letters).allSatisfy { cell, ch in
                    grid[cell.r][cell.c] == " " || grid[cell.r][cell.c] == ch
                }
                guard fits else { continue }
                for (cell, ch) in zip(cells, letters) { grid[cell.r][cell.c] = ch }
                placed.append(HiddenWord(word: word, emoji: cand.emoji, cells: cells))
                done = true
            }
        }
        let alphabet = script == .english ? Array("ABCDEFGHIJKLMNOPRSTUWY") : script.alphabet
        for r in 0..<size {
            for c in 0..<size where grid[r][c] == " " {
                grid[r][c] = alphabet.randomElement()!
            }
        }
        return WordSearchBoard(size: size, letters: grid, words: placed.shuffled(),
                               script: script, diagonals: diagonals, backwards: backwards)
    }
}

// MARK: - 🧱 Number crush

enum CrushMode { case sum, product, fraction, decimal }

/// The rules of one "מְפַצְּחִים" round: what the blocks may carry and the
/// target they must reach. Values are whole units — integers, twelfths for
/// fractions, tenths for decimals — so the arithmetic is always exact.
struct CrushRules {
    let mode: CrushMode
    let target: Int
    let values: [Int]

    func display(_ v: Int) -> String {
        switch mode {
        case .sum, .product: return MathFacts.show(v)
        case .fraction:
            switch v {
            case 2: return "⅙"
            case 3: return "¼"
            case 4: return "⅓"
            case 6: return "½"
            case 8: return "⅔"
            case 9: return "¾"
            case 10: return "⅚"
            default: return "\(v)/12"
            }
        case .decimal: return "0.\(v)"
        }
    }

    var targetText: String {
        switch mode {
        case .sum, .product: return "\(target)"
        case .fraction, .decimal: return "1"
        }
    }

    /// The selection's running total (sum, or product for ×).
    func total(_ picked: [Int]) -> Int {
        mode == .product ? picked.reduce(1, *) : picked.reduce(0, +)
    }

    /// Still on the way to the target? A signed round (ז׳–ח׳) can overshoot
    /// and come back, so there the running total is never "too far".
    func canStillReach(_ picked: [Int]) -> Bool {
        let t = total(picked)
        if mode == .product { return t != 0 && abs(t) <= abs(target) && target % t == 0 }
        // A signed board can overshoot and come back, so "too far" is not a
        // number here — but the selection still lets go after three blocks,
        // because every solvable combination on the board is two or three.
        if signed { return picked.count <= 3 }
        return t <= target
    }

    /// Are there negative blocks on this board?
    var signed: Bool { values.contains { $0 < 0 } }

    func hits(_ picked: [Int]) -> Bool { picked.count >= 2 && total(picked) == target }

    /// "3 + 4 = 7" / "3 × 4 = 12" / "8 + (−5) = 3" — what the child has
    /// picked so far.
    func expression(_ picked: [Int]) -> String {
        let op = mode == .product ? " × " : " + "
        return picked.map { v -> String in
            let shown = display(v)
            return v < 0 && picked.count > 1 ? "(\(shown))" : shown
        }.joined(separator: op)
    }

    var symbol: String { mode == .product ? "×" : "+" }

    /// A value that pairs with `v` to hit the target, if there is one.
    func complement(of v: Int) -> Int? {
        let c: Int
        if mode == .product {
            guard v > 0, target % v == 0 else { return nil }
            c = target / v
        } else {
            c = target - v
        }
        return values.contains(c) ? c : nil
    }
}

enum CrushBoards {
    /// One rung per grade, following CurriculumMath:
    ///   א׳  sums to 10          ב׳  sums to 10–20
    ///   ג׳  sums to 20–30 and the small times table
    ///   ד׳  sums to 40–60 and products to 72
    ///   ה׳  fractions and decimals to 1, or round sums to 100
    ///   ו׳  products to 144 and sums of multiples of 25 to 200
    ///   ז׳  signed blocks summing to a signed target
    ///   ח׳  signed products, and sums to 1000 in hundreds and halves
    static func rules(grade: Int, topic: Topic?) -> CrushRules {
        let productChance = topic == .math ? 0.5 : 0.3
        switch max(1, grade) {
        case 1:
            return CrushRules(mode: .sum, target: 10, values: Array(1...9))
        case 2:
            let t = [10, 12, 15, 20].randomElement()!
            return CrushRules(mode: .sum, target: t, values: Array(1...(t - 1)).filter { $0 <= 15 })
        case 3:
            if Double.random(in: 0...1) < productChance {
                let t = [12, 18, 20, 24, 30].randomElement()!
                return CrushRules(mode: .product, target: t,
                                  values: [2, 3, 4, 5, 6, 9, 10].filter { t % $0 == 0 && $0 < t })
            }
            let t = [20, 25, 30].randomElement()!
            return CrushRules(mode: .sum, target: t, values: Array(2...min(15, t - 2)))
        case 4:
            if Double.random(in: 0...1) < productChance {
                let t = [36, 40, 48, 54, 60, 72].randomElement()!
                return CrushRules(mode: .product, target: t,
                                  values: [2, 3, 4, 5, 6, 8, 9, 10, 12].filter { t % $0 == 0 && $0 < t })
            }
            let t = [40, 50, 60].randomElement()!
            return CrushRules(mode: .sum, target: t, values: Array(3...min(29, t - 3)))
        case 5:
            switch Int.random(in: 0...2) {
            case 0:  return CrushRules(mode: .fraction, target: 12, values: [2, 3, 4, 6, 8, 9, 10])
            case 1:  return CrushRules(mode: .decimal, target: 10, values: Array(1...9))
            default: return CrushRules(mode: .sum, target: 100,
                                       values: stride(from: 5, through: 95, by: 5).map { $0 })
            }
        case 6:
            switch Int.random(in: 0...2) {
            case 0:
                let t = [84, 96, 108, 120, 144].randomElement()!
                return CrushRules(mode: .product, target: t,
                                  values: [2, 3, 4, 6, 7, 8, 9, 12].filter { t % $0 == 0 && $0 < t })
            case 1:  return CrushRules(mode: .fraction, target: 12, values: [2, 3, 4, 6, 8, 9, 10])
            default:
                let t = [150, 175, 200].randomElement()!
                return CrushRules(mode: .sum, target: t,
                                  values: stride(from: 25, through: 125, by: 25).map { $0 }
                                        + stride(from: 10, through: 50, by: 10).map { $0 })
            }
        case 7:
            // ז׳: negative blocks on the board, and a target that can be below
            // zero — reaching it means adding a loss, not only a gain.
            switch Int.random(in: 0...1) {
            case 0:
                let t = [-10, -6, -4, 4, 6, 10].randomElement()!
                return CrushRules(mode: .sum, target: t,
                                  values: Array(-12...(-1)) + Array(1...12))
            default:
                let t = [60, 72, 84, 90, 96].randomElement()!
                return CrushRules(mode: .product, target: t,
                                  values: [2, 3, 4, 5, 6, 7, 8, 9, 10, 12].filter { t % $0 == 0 && $0 < t })
            }
        default:   // ח׳
            switch Int.random(in: 0...2) {
            case 0:
                let t = [-24, -18, 18, 24, 36].randomElement()!
                return CrushRules(mode: .sum, target: t,
                                  values: Array(-20...(-2)) + Array(2...20))
            case 1:
                let t = [120, 144, 168, 180, 240].randomElement()!
                return CrushRules(mode: .product, target: t,
                                  values: [2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15].filter { t % $0 == 0 && $0 < t })
            default:
                return CrushRules(mode: .sum, target: 1000,
                                  values: stride(from: 50, through: 500, by: 50).map { $0 })
            }
        }
    }

    /// A product round's blocks are all divisors of the target, so ANY block
    /// keeps the selection reachable — the board would never need a second
    /// look. Mixing in a few non-divisors makes it a puzzle.
    static func randomValue(_ rules: CrushRules) -> Int {
        if rules.mode == .product, Int.random(in: 0...3) == 0 {
            return [7, 11, 14, 15, 16, 17].filter { rules.target % $0 != 0 }.randomElement() ?? rules.values.randomElement()!
        }
        return rules.values.randomElement()!
    }

    /// Is there at least one pair or triple on the board that hits the target?
    static func isSolvable(_ board: [Int], rules: CrushRules) -> Bool {
        let n = board.count
        for i in 0..<n {
            for j in (i + 1)..<n {
                if rules.hits([board[i], board[j]]) { return true }
                for k in (j + 1)..<n where rules.hits([board[i], board[j], board[k]]) { return true }
            }
        }
        return false
    }
}

// MARK: - ⚡ True / false statements

/// One card of "נָכוֹן אוֹ לֹא נָכוֹן?": an optional question line, the claim
/// in big letters, and whether it is true.
struct LightningStatement: Equatable {
    let prompt: String?
    let claim: String
    let isTrue: Bool
    let topic: Topic
}

enum LightningStatements {
    /// Half of the cards are true. Math is computed (a fact with its real
    /// result, or one a little off); everything else is a short bank question
    /// with its real answer or one of its distractors.
    static func make(topic: Topic?, grade: Int, profile: Profile?, seen: inout Set<String>) -> LightningStatement {
        let mathShare: Double
        switch topic {
        case .math?: mathShare = 1
        case nil:    mathShare = 0.5
        default:     mathShare = 0.2
        }
        if Double.random(in: 0..<1) >= mathShare,
           let s = fromBank(topic: topic, grade: grade, profile: profile, seen: &seen) {
            return s
        }
        return math(grade: grade, seen: &seen)
    }

    static func math(grade: Int, seen: inout Set<String>) -> LightningStatement {
        var fact = MathFacts.fact(grade: grade)
        var tries = 0
        while seen.contains(fact.expression), tries < 20 {
            fact = MathFacts.fact(grade: grade)
            tries += 1
        }
        seen.insert(fact.expression)
        let isTrue = Bool.random()
        var shown = fact.answer
        if !isTrue {
            var offsets = MiniGameDistractors.numericOffsets(answer: fact.answer, grade: grade)
            if grade < 7 { offsets = offsets.filter { fact.answer + $0 >= 0 } }
            offsets = offsets.filter { $0 != 0 }
            shown = fact.answer + (offsets.randomElement() ?? 1)
        }
        return LightningStatement(prompt: nil,
                                  claim: CurriculumMath.ltr("\(fact.expression) = \(MathFacts.show(shown))"),
                                  isTrue: shown == fact.answer, topic: .math)
    }

    private static func fromBank(topic: Topic?, grade: Int, profile: Profile?, seen: inout Set<String>) -> LightningStatement? {
        let pool: [Topic]
        if let topic, topic != .math, topic != .reading {
            pool = [topic]
        } else {
            pool = Array(profile?.playableTopics ?? Set(Topic.core))
                .filter { $0 != .math && $0 != .reading && ContentAvailability.hasContent($0) }
        }
        guard !pool.isEmpty else { return nil }
        // The same short items the chooser counted when it offered the game.
        for _ in 0..<4 {
            guard let t = pool.randomElement() else { return nil }
            let items = GameContent.items(topic: t, grade: grade, maxPrompt: 70, maxAnswer: 28)
            guard let q = items.first(where: { !seen.contains($0.prompt) }) else { continue }
            seen.insert(q.prompt)
            if Bool.random() || q.distractors.isEmpty {
                return LightningStatement(prompt: q.prompt, claim: q.answer, isTrue: true, topic: t)
            }
            // ה׳+ gets the near miss, not the throwaway.
            let wrong = MiniGameDistractors.pick(answer: q.answer, from: q.distractors, grade: grade)
                ?? q.distractors[0]
            return LightningStatement(prompt: q.prompt, claim: wrong, isTrue: false, topic: t)
        }
        return nil
    }
}

// MARK: - ⚡ Surprise round

/// What the runner launches: a game, themed on a world kids love.
struct SurprisePlan: Identifiable {
    let id = UUID()
    let topic: Topic
    let game: MiniGameKind
}

/// ⚡ "סִבּוּב הַפְתָּעָה" — after every 12–15 regular questions (twice a
/// session at most) the runner stops for one quick arcade game — 🔗 🎈 🧩 🧱 🔤
/// ⚡ 🧺 🧠, and 🔢 🔐 ⚖️ / 🛒 where numbers / money are on the menu — themed
/// on ⚽ 🌍 🚀 🐾 🦖 🌊, paying ⭐ and 💎 twice over
/// and never a minute.
enum SurpriseRound {
    static let maxPerSession = 2
    static let rewardMultiplier = 2
    /// Regular questions between rounds.
    static func nextGap() -> Int { Int.random(in: 12...15) }

    /// The "things kids love" worlds. Most are paid packs — the round is a free
    /// taste of them for every child, without unlocking the pack itself.
    static let interestTopics: [Topic] = [.soccer, .flags, .space, .animals, .dinosaurs, .sea]

    private static var suffix: String { ProfileStore.shared.activeID?.uuidString ?? "none" }

    /// Worlds that can serve a fair round to this child right now: content in
    /// the app's language, and enough of it near the child's grade (flags start
    /// at ג׳ — a first grader gets the others).
    static func eligibleTopics(grade: Int) -> [Topic] {
        let withContent = interestTopics.filter { topic in
            guard ContentAvailability.hasContent(topic) else { return false }
            return nearGrade(topic: topic, grade: grade).count >= 8
        }
        // Prefer packs the founder has launched (in Release `visiblePacks` is the
        // live list); with fewer than two of those, use every world with content
        // so the round still rotates.
        let visible = Set(PackStore.shared.visiblePacks.map(\.topic))
        let live = withContent.filter { $0.pack == nil || visible.contains($0) }
        return live.count >= 2 ? live : withContent
    }

    private static func nearGrade(topic: Topic, grade: Int) -> [BankQuestion] {
        let reach = grade > 6 ? 2 : 1
        return (QuestionBanks.bank(for: topic) ?? []).filter { item in
            let r = item.grades
            let d = r.contains(grade) ? 0 : min(abs(r.lowerBound - grade), abs(r.upperBound - grade))
            return d <= reach
        }
    }

    /// Weighted by what the child shows they like — answers given in the world,
    /// its learned affinity, the interests a parent picked — and never the same
    /// world twice in a row.
    static func pickTopic(grade: Int, profile: Profile?) -> Topic? {
        var pool = eligibleTopics(grade: grade)
        let lastKey = "surprise.lastTopic." + suffix
        if pool.count > 1, let last = UserDefaults.standard.string(forKey: lastKey).flatMap(Topic.init(rawValue:)) {
            pool.removeAll { $0 == last }
        }
        guard !pool.isEmpty else { return nil }
        let interests = Set(profile?.interests ?? [])
        func liked(_ t: Topic) -> Bool {
            switch t {
            case .soccer:        return interests.contains("sports")
            case .flags:         return interests.contains("flags") || interests.contains("geography")
            case .space:         return interests.contains("space")
            case .animals, .sea: return interests.contains("animals")
            case .dinosaurs:     return interests.contains("animals") || interests.contains("science")
            default:             return false
            }
        }
        let progress = ProgressStore.shared
        let weights = pool.map { t -> Double in
            let answered = Double(min(progress.topicAnswered[t.rawValue] ?? 0, 60)) / 60
            return 1 + progress.affinity(for: t) * 1.5 + answered + (liked(t) ? 1.5 : 0)
        }
        var roll = Double.random(in: 0..<max(weights.reduce(0, +), 0.0001))
        for (t, w) in zip(pool, weights) {
            if roll < w { return t }
            roll -= w
        }
        return pool.last
    }

    /// The games that can be themed on `topic` for this grade, in the session
    /// it interrupts (`context` = the world being played, nil in the feed):
    /// 🎈 always (each interest world has its own balloons); 🧩 🔤 when the
    /// child can spell in the board's script; 🔗 ⚡ when the world's bank has
    /// enough SHORT question/answer pairs (or capitals for 🌍); 🧱 only where
    /// numbers are already on the menu — the math world and the mixed feed.
    static func games(for topic: Topic, grade: Int, context: Topic? = nil) -> [MiniGameKind] {
        var out: [MiniGameKind] = [.balloon]
        if WordSets.spellingAvailable(grade: grade) { out += [.word, .wordSearch] }
        let short = nearGrade(topic: topic, grade: grade).filter { q in
            let p = Question.stripNiqqud(q.prompt)
            return p.count <= 60 && !p.contains("לא שיך") && !p.contains("לא שייך")
                && Question.stripNiqqud(q.correctAnswer).count <= 24
                && q.distractors.allSatisfy { Question.stripNiqqud($0).count <= 24 }
        }
        if (topic == .flags && grade >= 2) || short.count >= 12 { out.append(.pairs) }
        if short.count >= 12 { out.append(.lightning) }
        if context == nil || context == .math { out.append(.crush) }
        // 🧺 every theme world has baskets of its own; 🧠 patterns are drawn in
        // the theme's own pictures.
        if SortSets.make(topic: topic, grade: grade) != nil { out.append(.sort) }
        out.append(.pattern)
        // 🔢 🔐 ⚖️ — numbers and logic: only where those are already on the menu.
        if context == nil || [.math, .logic, .gifted].contains(context!) {
            out += [.game2048, .balance]
            if short.count >= 6 || context == .math { out.append(.vault) }
        }
        // 🛒 the shop belongs to the money world.
        if context == .money { out.append(.grocery) }
        // In the English / Hebrew world, the spelling games come first.
        if context == .english || context == .hebrew {
            let spelling = out.filter { $0 == .word || $0 == .wordSearch }
            if !spelling.isEmpty { out += spelling }
        }
        // 🎚️ And nothing that is a freebie at this grade (see MiniGameGradeFit)
        // — a surprise round the child wins without thinking is a worse
        // interruption than no surprise round.
        let script = WordSets.script(for: topic, grade: grade)
        out = out.filter {
            MiniGameGradeFit.offered($0, grade: grade,
                                     script: ($0 == .word || $0 == .wordSearch) ? script : nil,
                                     topic: context ?? topic)
        }
        return out
    }

    /// The next round for this child, or nil when nothing fits.
    static func plan(grade: Int, profile: Profile?, context: Topic? = nil) -> SurprisePlan? {
        guard let topic = pickTopic(grade: grade, profile: profile) else { return nil }
        var games = games(for: topic, grade: grade, context: context)
        let gameKey = "surprise.lastGame." + suffix
        if games.count > 1, let last = UserDefaults.standard.string(forKey: gameKey).flatMap(MiniGameKind.init(rawValue:)) {
            games.removeAll { $0 == last }
        }
        guard let game = games.randomElement() else { return nil }
        UserDefaults.standard.set(topic.rawValue, forKey: "surprise.lastTopic." + suffix)
        UserDefaults.standard.set(game.rawValue, forKey: gameKey)
        return SurprisePlan(topic: topic, game: game)
    }

    /// "⚽ כַּדּוּרֶגֶל" — the theme line on the interstitial.
    static func themeName(_ topic: Topic) -> String {
        switch topic {
        case .soccer:    return tr("כַּדּוּרֶגֶל")
        case .flags:     return tr("דְּגָלִים וּבִירוֹת")
        case .space:     return tr("חָלָל")
        case .animals:   return tr("חַיּוֹת")
        case .dinosaurs: return tr("דִּינוֹזָאוּרִים")
        case .sea:       return tr("הַיָּם")
        default:         return topic.displayName
        }
    }
}

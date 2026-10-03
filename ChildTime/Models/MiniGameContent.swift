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
// Nothing here grants screen-time minutes: the parent's daily cap has to keep
// meaning what it says, so every extra here pays ⭐ and 💎 only.

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
        case 5, 6:
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
        default:   // ז׳–ח׳
            if Bool.random() {
                let a = -Int.random(in: 2...12), b = Int.random(in: 2...15)
                return Fact(expression: "(−\(abs(a))) + \(b)", answer: a + b)
            }
            let a = Int.random(in: 2...12)
            return Fact(expression: "\(a)²", answer: a * a)
        }
    }

    /// "−4" with a real minus sign.
    static func show(_ n: Int) -> String { n < 0 ? "−\(abs(n))" : "\(n)" }
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
        let list = grade <= 3 ? basicWords : (Array(basicWords.shuffled().prefix(2)) + advancedWords)
        let pictureOnly = LanguageStore.shared.current == .en
        return list.shuffled().prefix(count).map { w in
            MatchPair(left: pictureOnly ? w.emoji : "\(w.emoji) \(w.label)",
                      right: w.english)
        }
    }

    /// Short prompt ↔ answer pairs from the world's own bank (🦖 🚀 🔬 …).
    static func bankPairs(topic: Topic, count: Int, grade: Int, profile: Profile?) -> [MatchPair] {
        var out: [MatchPair] = []
        var seenLeft = Set<String>(), seenRight = Set<String>()
        let base = profile?.difficulty(for: topic) ?? .easy
        var tries = 0
        while out.count < count && tries < 60 {
            tries += 1
            let q = QuestionGenerator.generate(topic: topic, difficulty: base, grade: grade)
            guard ShortQuestions.isShortAndSelfContained(q, maxPrompt: 60, maxAnswer: 24),
                  !seenLeft.contains(q.prompt), !seenRight.contains(q.correctAnswer) else { continue }
            seenLeft.insert(q.prompt); seenRight.insert(q.correctAnswer)
            out.append(MatchPair(left: q.prompt, right: q.correctAnswer))
        }
        return out
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
    static func make(for topic: Topic?, grade: Int) -> BalloonSet {
        switch topic {
        case .sea?, .animals?:      return seaAnimals()
        case .flags?, .geography?:  return grade >= 2 ? capitals() : numbers(grade: grade)
        case .space?:               return planets()
        case .dinosaurs?:           return dinosaurs()
        case .soccer?:              return soccer()
        case .english?:             return englishAnimals()
        case .science?:             return Bool.random() ? planets() : seaAnimals()
        case .math?:                return numbers(grade: grade)
        default:
            var all: [() -> BalloonSet] = [{ numbers(grade: grade) }, { seaAnimals() }, { planets() }]
            if grade >= 2 { all.append { capitals() } }
            return all.randomElement()!()
        }
    }

    static func seaAnimals() -> BalloonSet {
        BalloonSet(
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

    /// Even (or odd, or multiples of n) — sized to what the grade knows.
    static func numbers(grade: Int) -> BalloonSet {
        let g = max(1, grade)
        let top = g <= 1 ? 20 : (g == 2 ? 100 : 200)
        enum Rule { case even, odd, multiple(Int) }
        var rules: [Rule] = [.even, .odd]
        if g >= 3 { rules += [.multiple([3, 4, 5].randomElement()!)] }
        if g >= 5 { rules += [.multiple([6, 7, 9].randomElement()!)] }
        let rule = rules.randomElement()!
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
        }
        let pool = Array(1...top).shuffled()
        let targets = pool.filter(isTarget).prefix(14).map { BalloonItem(emoji: "", label: "\($0)", correct: true) }
        let others = pool.filter { !isTarget($0) }.prefix(14).map { BalloonItem(emoji: "", label: "\($0)", correct: false) }
        return BalloonSet(prompt: prompt, topic: .math, targets: Array(targets), others: Array(others))
    }

    /// Capitals against big cities that are NOT capitals — each with its flag,
    /// so 🇪🇸 מַדְרִיד and 🇪🇸 בַּרְצֶלוֹנָה make the child think.
    static func capitals() -> BalloonSet {
        let caps = MatchPairsSource.capitalList.filter(\.easy)
            .map { BalloonItem(emoji: $0.flag, label: $0.city, correct: true) }
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

    static func planets() -> BalloonSet {
        BalloonSet(
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
    static func dinosaurs() -> BalloonSet {
        BalloonSet(
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
    static func soccer() -> BalloonSet {
        BalloonSet(
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

    /// English animal words against other English words — no pictures: the
    /// child has to read the word.
    static func englishAnimals() -> BalloonSet {
        BalloonSet(
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
    /// Hebrew fills its slots right-to-left, English left-to-right — whatever
    /// the app's own language is.
    var direction: LayoutDirection { self == .hebrew ? .rightToLeft : .leftToRight }
    var topic: Topic { self == .hebrew ? .hebrew : .english }
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
    static func spellingAvailable(grade: Int) -> Bool {
        switch LanguageStore.shared.current {
        case .en, .he: return true
        default:       return grade >= 3
        }
    }

    static func words(for topic: Topic?, script: SpellScript, grade: Int) -> [SpellWord] {
        Array(list(for: topic, script: script, grade: grade).shuffled().prefix(wordCount))
    }

    /// The whole themed list (the word search picks what fits its grid).
    static func list(for topic: Topic?, script: SpellScript, grade: Int) -> [SpellWord] {
        switch script {
        case .english: return english(topic, grade: grade)
        case .hebrew:  return hebrew(topic)
        }
    }

    private static func english(_ topic: Topic?, grade: Int) -> [SpellWord] {
        func w(_ e: String, _ s: String) -> SpellWord { SpellWord(emoji: e, word: s) }
        switch topic {
        case .soccer?:    return [w("⚽", "ball"), w("🥅", "goal"), w("👟", "shoe"), w("🚩", "flag"), w("🏆", "cup"), w("🧤", "glove")]
        case .sea?:       return [w("🐟", "fish"), w("🦀", "crab"), w("🦈", "shark"), w("🐳", "whale"), w("🐚", "shell"), w("🐙", "octopus")]
        case .space?:     return [w("☀️", "sun"), w("🌙", "moon"), w("⭐", "star"), w("🚀", "rocket"), w("🪐", "planet"), w("👽", "alien")]
        case .animals?:   return [w("🐶", "dog"), w("🐱", "cat"), w("🐄", "cow"), w("🦁", "lion"), w("🐴", "horse"), w("🦆", "duck"), w("🐸", "frog")]
        case .dinosaurs?: return [w("🦴", "bone"), w("🥚", "egg"), w("🦷", "tooth"), w("🍃", "leaf"), w("🪨", "rock"), w("🌋", "volcano")]
        case .flags?:     return [w("🚩", "flag"), w("🗺️", "map"), w("🏙️", "city"), w("🚢", "ship"), w("✈️", "plane"), w("🏝️", "island")]
        default:
            if grade <= 3 {
                return [w("🐱", "cat"), w("🐶", "dog"), w("☀️", "sun"), w("🎩", "hat"), w("🛏️", "bed"), w("🚌", "bus"),
                        w("🥚", "egg"), w("🦊", "fox"), w("📦", "box"), w("🐟", "fish"), w("⭐", "star"), w("🌳", "tree")]
            }
            return [w("🍎", "apple"), w("🏠", "house"), w("🪑", "chair"), w("🚆", "train"), w("💧", "water"), w("🍞", "bread"),
                    w("🕐", "clock"), w("🐍", "snake"), w("🐯", "tiger"), w("🍕", "pizza"), w("🌸", "flower"), w("🦓", "zebra")]
        }
    }

    private static func hebrew(_ topic: Topic?) -> [SpellWord] {
        func w(_ e: String, _ s: String) -> SpellWord { SpellWord(emoji: e, word: s) }
        switch topic {
        case .soccer?:    return [w("⚽", "כדור"), w("🥅", "שער"), w("👟", "נעל"), w("🚩", "דגל"), w("🏆", "גביע")]
        case .sea?:       return [w("🐟", "דג"), w("🌊", "ים"), w("🦀", "סרטן"), w("🦈", "כריש"), w("🐚", "צדף"), w("🐙", "תמנון")]
        case .space?:     return [w("☀️", "שמש"), w("🌙", "ירח"), w("⭐", "כוכב"), w("🚀", "חללית"), w("👽", "חייזר")]
        case .animals?:   return [w("🐶", "כלב"), w("🐱", "חתול"), w("🐴", "סוס"), w("🐘", "פיל"), w("🦁", "אריה"), w("🐒", "קוף"), w("🐄", "פרה")]
        case .dinosaurs?: return [w("🦴", "עצם"), w("🥚", "ביצה"), w("🦷", "שן"), w("🍃", "עלה"), w("🪨", "סלע"), w("🦖", "דינוזאור")]
        case .flags?:     return [w("🚩", "דגל"), w("🗺️", "מפה"), w("🏙️", "עיר"), w("🚢", "אונייה"), w("✈️", "מטוס"), w("🏝️", "אי")]
        default:
            return [w("🐶", "כלב"), w("🐱", "חתול"), w("🏠", "בית"), w("📖", "ספר"), w("🌳", "עץ"), w("☀️", "שמש"),
                    w("🌸", "פרח"), w("🍎", "תפוח"), w("⚽", "כדור"), w("💧", "מים"), w("🍞", "לחם"), w("🥛", "חלב")]
        }
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
}

enum WordSearch {
    static let wordCount = 5

    /// 5 themed words hidden across, down (and diagonally from ד׳), the rest
    /// filled with random letters. English is shown in capitals; Hebrew
    /// without niqqud, final letters as written.
    static func make(topic: Topic?, script: SpellScript, grade: Int, size: Int) -> WordSearchBoard {
        var directions = [(0, 1), (1, 0)]
        if grade >= 4 { directions.append((1, 1)) }
        let themed = WordSets.list(for: topic, script: script, grade: grade).shuffled()
        let general = WordSets.list(for: nil, script: script, grade: grade).shuffled()
        let candidates = (themed + general).filter { (2...size).contains($0.word.count) }

        var grid = Array(repeating: Array(repeating: Character(" "), count: size), count: size)
        var placed: [HiddenWord] = []
        var used = Set<String>()
        for cand in candidates where placed.count < wordCount {
            let word = script == .english ? cand.word.uppercased() : cand.word
            guard used.insert(word).inserted else { continue }
            let letters = Array(word)
            var done = false
            for _ in 0..<120 where !done {
                let (dr, dc) = directions.randomElement()!
                let maxR = size - 1 - dr * (letters.count - 1)
                let maxC = size - 1 - dc * (letters.count - 1)
                guard maxR >= 0, maxC >= 0 else { continue }
                let r0 = Int.random(in: 0...maxR), c0 = Int.random(in: 0...maxC)
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
        let alphabet = Array(script == .english ? "ABCDEFGHIJKLMNOPRSTUWY" : "אבגדהוזחטיכלמנסעפצקרשת")
        for r in 0..<size {
            for c in 0..<size where grid[r][c] == " " {
                grid[r][c] = alphabet.randomElement()!
            }
        }
        return WordSearchBoard(size: size, letters: grid, words: placed, script: script)
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
        case .sum, .product: return "\(v)"
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

    /// Still on the way to the target?
    func canStillReach(_ picked: [Int]) -> Bool {
        let t = total(picked)
        if mode == .product { return t <= target && target % t == 0 }
        return t <= target
    }

    func hits(_ picked: [Int]) -> Bool { picked.count >= 2 && total(picked) == target }

    /// "3 + 4 = 7" / "3 × 4 = 12" — what the child has picked so far.
    func expression(_ picked: [Int]) -> String {
        let op = mode == .product ? " × " : " + "
        return picked.map(display).joined(separator: op)
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
    /// Ranges by grade: א׳ sums to 10, ב׳ sums to 10–20, ג׳–ד׳ sums to 20–50 or
    /// products (more often in the math world), ה׳+ fractions and decimals to 1.
    static func rules(grade: Int, topic: Topic?) -> CrushRules {
        switch max(1, grade) {
        case 1:
            return CrushRules(mode: .sum, target: 10, values: Array(1...9))
        case 2:
            let t = [10, 12, 15, 20].randomElement()!
            return CrushRules(mode: .sum, target: t, values: Array(1...(t - 1)).filter { $0 <= 15 })
        case 3, 4:
            let productChance = topic == .math ? 0.5 : 0.3
            if Double.random(in: 0...1) < productChance {
                let t = [12, 18, 20, 24, 30, 36, 40].randomElement()!
                return CrushRules(mode: .product, target: t,
                                  values: [2, 3, 4, 5, 6, 8, 9, 10, 12].filter { t % $0 == 0 && $0 < t })
            }
            let t = [20, 30, 40, 50].randomElement()!
            return CrushRules(mode: .sum, target: t, values: Array(2...min(25, t - 2)))
        case 5, 6:
            if Bool.random() {
                return CrushRules(mode: .fraction, target: 12, values: [2, 3, 4, 6, 8, 9, 10])
            }
            return CrushRules(mode: .decimal, target: 10, values: Array(1...9))
        default:
            switch Int.random(in: 0...2) {
            case 0:  return CrushRules(mode: .fraction, target: 12, values: [2, 3, 4, 6, 8, 9, 10])
            case 1:  return CrushRules(mode: .decimal, target: 10, values: Array(1...9))
            default:
                let t = 100
                return CrushRules(mode: .sum, target: t, values: stride(from: 5, through: 95, by: 5).map { $0 })
            }
        }
    }

    /// A product round's blocks are all divisors of the target, so ANY block
    /// keeps the selection reachable — the board would never need a second
    /// look. Mixing in a few non-divisors makes it a puzzle.
    static func randomValue(_ rules: CrushRules) -> Int {
        if rules.mode == .product, Int.random(in: 0...3) == 0 {
            return [7, 11, 14, 15, 16].filter { rules.target % $0 != 0 }.randomElement() ?? rules.values.randomElement()!
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
            var offsets = [-2, -1, 1, 2]
            if abs(fact.answer) >= 20 { offsets += [-10, 10] }
            if grade < 7 { offsets = offsets.filter { fact.answer + $0 >= 0 } }
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
        for _ in 0..<30 {
            guard let t = pool.randomElement() else { return nil }
            let base = profile?.difficulty(for: t) ?? .easy
            let q = QuestionGenerator.generate(topic: t, difficulty: base, grade: grade)
            guard ShortQuestions.isShortAndSelfContained(q, maxPrompt: 70, maxAnswer: 28),
                  !seen.contains(q.prompt) else { continue }
            seen.insert(q.prompt)
            let wrongs = q.options.filter { $0 != q.correctAnswer }
            if Bool.random() || wrongs.isEmpty {
                return LightningStatement(prompt: q.prompt, claim: q.correctAnswer, isTrue: true, topic: t)
            }
            return LightningStatement(prompt: q.prompt, claim: wrongs.randomElement()!, isTrue: false, topic: t)
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
/// session at most) the runner stops for one quick arcade game out of the six
/// — 🔗 🎈 🧩 🧱 🔤 ⚡ — themed on ⚽ 🌍 🚀 🐾 🦖 🌊, paying ⭐ and 💎 twice over
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
        // In the English / Hebrew world, the spelling games come first.
        if context == .english || context == .hebrew {
            let spelling = out.filter { $0 == .word || $0 == .wordSearch }
            if !spelling.isEmpty { out += spelling }
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

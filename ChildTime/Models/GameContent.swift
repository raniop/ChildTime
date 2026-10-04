import Foundation
import SwiftUI

// 🎮 Where a world's games get their content — and which games a world can
// really carry (Rani, 2026-10-03: "show every game that can sensibly be built
// from that world's content — and ONLY those").
//
// A game appears in a world's chooser only when the world's own bank, at the
// child's grade and in the child's language, can fill a whole natural round
// for it. Nothing here is a hand-picked per-world list: each game states what
// it needs (short question/answer pairs, single-word answers, numbers…) and
// `WorldGameFit` counts what the bank actually holds.

// MARK: - One item

/// One short multiple-choice item a game builds a round from — a bank
/// question, or a computed math fact dressed as one.
struct GameItem: Hashable {
    let prompt: String
    let answer: String
    let distractors: [String]
    let topic: Topic

    /// Answer + distractors, shuffled.
    var shuffledOptions: [String] { ([answer] + distractors).shuffled() }
}

/// A word a spelling game can use: the clue (a picture or a question) and the
/// word itself, letters only.
struct GameWord: Hashable {
    let clue: String
    let word: String
    let script: SpellScript
    let topic: Topic
    /// The clue is a picture (an emoji), not a question line.
    var isPicture: Bool { clue.count <= 2 && !clue.unicodeScalars.contains { CharacterSet.letters.contains($0) } }
}

// MARK: - The pools

enum GameContent {
    /// The bank behind a world's games. Reading has no short questions of its
    /// own (every one needs its passage), so its games use the bank of the
    /// language the child reads in: Hebrew in Hebrew, English in English.
    static func sourceTopic(_ topic: Topic?) -> Topic? {
        guard let topic else { return nil }
        guard topic == .reading else { return topic }
        switch LanguageStore.shared.current {
        case .he: return .hebrew
        case .en: return .english
        default:  return nil
        }
    }

    private static let yesNo: Set<String> = ["כן", "לא", "נכון", "לא נכון", "yes", "no", "true", "false",
                                             "да", "нет", "верно", "неверно", "نعم", "لا", "صحيح", "خطأ"]

    /// Prompts that only make sense next to their options ("מִי מֵהַבָּאִים…?",
    /// "which of these…") — fine where the game shows the options (balloons,
    /// the vault's key card), not where only the answer travels (pairs, words).
    static func refersToOptions(_ prompt: String) -> Bool {
        let p = Question.stripNiqqud(prompt).lowercased()
        let markers = ["הבאים", "מבין", "מהם", "מי מהן", "איזה מה", "איזו מה", "לא שיך", "לא שייך",
                       "following", "of these", "which one", "из этих", "из перечисленных", "кто из", "что из",
                       "التالي", "التالية", "أي من", "أيّ من"]
        return markers.contains { p.contains($0) }
    }

    /// The grade window of a world's bank, the adaptive tier first.
    static func pool(topic: Topic, grade: Int) -> [BankQuestion] {
        guard topic != .math, topic != .reading else { return [] }
        let pool = gradePool(topic: topic, grade: grade).shuffled()
        let tier = MiniGameLevel.difficulty(for: topic)
        return pool.filter { $0.difficulty == tier } + pool.filter { $0.difficulty != tier }
    }

    /// The grade window, kept for a minute: the chooser asks a dozen questions
    /// of the same bank when it opens, and each would rebuild it.
    private static var poolCache: [String: (at: Date, items: [BankQuestion])] = [:]
    private static func gradePool(topic: Topic, grade: Int) -> [BankQuestion] {
        let key = "\(topic.rawValue)|\(grade)|\(LanguageStore.shared.current.rawValue)"
        if let hit = poolCache[key], Date().timeIntervalSince(hit.at) < 60 { return hit.items }
        let items = QuestionGenerator.effectivePool(topic: topic, grade: grade)
        poolCache[key] = (Date(), items)
        return items
    }

    /// Short, self-contained items: a prompt that fits a card, answers that fit
    /// a tile, no yes/no answers, nothing a parent removed.
    static func items(topic: Topic, grade: Int, maxPrompt: Int = 60, maxAnswer: Int = 24,
                      standalone: Bool = false) -> [GameItem] {
        var seen = Set<String>()
        var out: [GameItem] = []
        for q in pool(topic: topic, grade: grade) {
            let p = Question.stripNiqqud(q.prompt)
            guard p.count <= maxPrompt, q.distractors.count >= 2,
                  !p.contains("לא שיך"), !p.contains("לא שייך"),
                  !QuestionReporter.shared.isHidden(q.prompt) else { continue }
            let options = [q.correctAnswer] + q.distractors
            guard options.allSatisfy({ Question.stripNiqqud($0).count <= maxAnswer }),
                  !options.contains(where: { yesNo.contains(Question.stripNiqqud($0).lowercased()) }) else { continue }
            if standalone && refersToOptions(q.prompt) { continue }
            guard seen.insert(q.prompt + "|" + q.correctAnswer).inserted else { continue }
            out.append(GameItem(prompt: q.prompt, answer: q.correctAnswer, distractors: Array(q.distractors.prefix(3)), topic: topic))
        }
        return out
    }

    /// The same items with DIFFERENT answers — a pairs board can't hold two
    /// cards that both say "פָּרִיז".
    static func distinctAnswers(_ items: [GameItem]) -> [GameItem] {
        var seen = Set<String>()
        return items.filter { seen.insert(Question.stripNiqqud($0.answer)).inserted }
    }

    // MARK: Words

    /// A single word of 2–8 letters in one script (niqqud / harakat dropped),
    /// or nil — "בייג'ינג", "New York" and "7" are not spellable.
    static func spellable(_ raw: String) -> (word: String, script: SpellScript)? {
        let stripped = Question.stripNiqqud(raw).unicodeScalars.filter {
            !(0x064B...0x065F).contains(Int($0.value)) && $0.value != 0x0670 && $0.value != 0x0640
        }
        let s = String(String.UnicodeScalarView(stripped)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...8).contains(s.count) else { return nil }
        var script: SpellScript?
        for u in s.unicodeScalars {
            let sc: SpellScript
            switch u.value {
            case 0x05D0...0x05EA:                    sc = .hebrew
            case 0x41...0x5A, 0x61...0x7A:           sc = .english
            case 0x0410...0x044F, 0x0401, 0x0451:    sc = .cyrillic
            case 0x0621...0x064A:                    sc = .arabic
            default:                                 return nil
            }
            if script == nil { script = sc } else if script != sc { return nil }
        }
        guard let script else { return nil }
        return (s, script)
    }

    /// The world's single-word answers, each with its question as the clue —
    /// in the script most of them share (one board never mixes alphabets).
    static func words(topic: Topic, grade: Int, maxLetters: Int = 8) -> [GameWord] {
        var byScript: [SpellScript: [GameWord]] = [:]
        var seen = Set<String>()
        for item in items(topic: topic, grade: grade, maxPrompt: 70, maxAnswer: 12, standalone: true) {
            guard let w = spellable(item.answer), w.word.count <= maxLetters,
                  seen.insert(w.word.lowercased()).inserted else { continue }
            byScript[w.script, default: []].append(GameWord(clue: item.prompt, word: w.word, script: w.script, topic: topic))
        }
        return byScript.values.max { $0.count < $1.count } ?? []
    }

    // MARK: Numbers

    nonisolated static func number(_ s: String) -> Int? {
        let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "−", with: "-")
        return Int(t)
    }

    /// Items whose answer AND options are whole numbers ("8", "11").
    static func numericItems(topic: Topic, grade: Int) -> [GameItem] {
        items(topic: topic, grade: grade, maxPrompt: 70, maxAnswer: 6, standalone: true).filter { item in
            guard let a = number(item.answer), (0...10_000).contains(a) else { return false }
            return item.distractors.allSatisfy { number($0) != nil }
        }
    }

    /// A computed fact as a card: "7 × 8 = ?" and four nearby numbers.
    static func mathItem(grade: Int) -> GameItem {
        let f = MathFacts.fact(grade: grade)
        var options: Set<Int> = [f.answer]
        var tries = 0
        while options.count < 4 && tries < 60 {
            tries += 1
            let d = Int.random(in: 1...max(3, abs(f.answer) / 4 + 2))
            let c = Bool.random() ? f.answer + d : f.answer - d
            if grade >= 7 || c >= 0 { options.insert(c) }
        }
        return GameItem(prompt: MiniGameText.ltr(f.expression + " = ?"),
                        answer: MathFacts.show(f.answer),
                        distractors: options.subtracting([f.answer]).map(MathFacts.show),
                        topic: .math)
    }

    /// The next card for a world: its bank, or computed math where the world
    /// is math (or has run dry).
    static func card(topic: Topic?, grade: Int, avoiding seen: inout Set<String>) -> GameItem {
        if let t = sourceTopic(topic), t != .math {
            let pool = items(topic: t, grade: grade, maxPrompt: 80, maxAnswer: 24)
            if let fresh = pool.first(where: { !seen.contains($0.prompt) }) ?? pool.randomElement() {
                seen.insert(fresh.prompt)
                return fresh
            }
        }
        return mathItem(grade: MiniGameLevel.grade(for: .math))
    }
}

// MARK: - Adaptive level

/// The adaptive engine's view, for a game: the level the child is really
/// playing at in a topic, around the parent's base.
enum MiniGameLevel {
    /// The child's grade, one step up or down when the adaptive level has
    /// clearly moved away from the parent's base for this topic.
    static func grade(for topic: Topic?) -> Int {
        let base = max(1, ProfileStore.shared.active?.effectiveGrade ?? 2)
        guard let topic, let p = ProfileStore.shared.active else { return base }
        let anchor = p.difficulty(for: topic)
        let delta = ProgressStore.shared.adaptiveLevel(for: topic, base: anchor) - AdaptiveDifficultyEngine.level(for: anchor)
        if delta >= 0.6 { return min(8, base + 1) }
        if delta <= -0.6 { return max(1, base - 1) }
        return base
    }

    /// The bank tier to prefer — the runner's own 70/20/10 sampling.
    static func difficulty(for topic: Topic) -> Difficulty {
        let anchor = ProfileStore.shared.active?.difficulty(for: topic) ?? .easy
        let level = ProgressStore.shared.adaptiveLevel(for: topic, base: anchor)
        return AdaptiveDifficultyEngine.sampledDifficulty(forLevel: level, base: anchor)
    }
}

// MARK: - Which games fit a world

/// The games a world can carry for this child, best fit first. A game is in
/// only when the world's content suits its mechanic AND there is enough of it
/// at the child's grade, in the child's language, for a full round.
enum WorldGameFit {
    static func games(for world: World, grade: Int) -> [MiniGameKind] {
        games(topic: world.isBonusWorld ? nil : world.topic, grade: grade)
    }

    static func games(topic: Topic?, grade: Int) -> [MiniGameKind] {
        guard MiniGameKind.availableForActiveChild else { return [] }
        // 👶 גן plays the same five games in every world, because its boards
        // are not dealt from the world's bank at all — they come from
        // `PreReaderGames` (pictures, colours, shapes, quantities). So the
        // bank counts below would only ever say "no" to a child who in fact
        // has five playable games.
        guard !PreReaderGames.isPreReader(grade) else { return MiniGameGradeFit.preReaderRoster }
        // 💫 The arena mixes every topic: the three games that mix too.
        guard let topic else {
            return [.lightning, .pairs, .balloon].filter {
                MiniGameGradeFit.offered($0, grade: grade, topic: nil)
            }
        }
        let probe = Probe(topic: topic, grade: grade)
        return order(for: topic).filter { probe.fits($0) }
    }

    /// Best fit first: the mechanic the world is really about leads.
    static func order(for topic: Topic) -> [MiniGameKind] {
        switch topic {
        case .math:
            return [.crush, .balance, .game2048, .vault, .lightning, .pairs, .pattern, .sort, .balloon, .grocery]
        case .english, .hebrew, .reading:
            return [.word, .wordSearch, .sort, .pairs, .balloon, .lightning, .grocery, .pattern, .vault]
        case .money:
            return [.grocery, .lightning, .sort, .balance, .crush, .pairs, .balloon, .vault]
        case .logic, .gifted:
            return [.pattern, .vault, .balance, .game2048, .crush, .lightning, .pairs, .sort, .balloon]
        default:
            return [.sort, .pairs, .balloon, .lightning, .word, .wordSearch, .vault, .balance]
        }
    }

    /// Counts what one world's bank holds — computed once per chooser.
    struct Probe {
        let topic: Topic
        let source: Topic?
        let grade: Int
        let numericWorld: Bool

        init(topic: Topic, grade: Int) {
            self.topic = topic
            self.grade = grade
            self.source = GameContent.sourceTopic(topic)
            self.numericWorld = [.math, .money, .logic, .gifted].contains(topic)
        }

        private func count(maxPrompt: Int, maxAnswer: Int, standalone: Bool, distinct: Bool = false) -> Int {
            guard let source, source != .math else { return 0 }
            let items = GameContent.items(topic: source, grade: grade, maxPrompt: maxPrompt,
                                          maxAnswer: maxAnswer, standalone: standalone)
            return distinct ? GameContent.distinctAnswers(items).count : items.count
        }

        /// The alphabet a spelling game would use for this world — the grade
        /// table needs it, because a mother-tongue board and a foreign-language
        /// board are not the same game.
        var spellScript: SpellScript {
            let world = source ?? topic
            // A world with a picture list spells in the app's own script; one
            // without spells its OWN answers, whatever alphabet those are in.
            if let source, source != .math, !WordSets.hasThemedList(world, grade: grade),
               let first = GameContent.words(topic: source, grade: grade).first {
                return first.script
            }
            return WordSets.script(for: world, grade: grade)
        }

        func fits(_ kind: MiniGameKind) -> Bool {
            // 🎚️ First: is this game worth this child's time at this grade?
            // 🛒 The grocery's shopping list is words only in a reading world,
            // so there too the grade table needs the board's alphabet.
            let script: SpellScript? = switch kind {
            case .word, .wordSearch: spellScript
            case .grocery:           topic == .english ? .english : (topic == .hebrew ? .hebrew : nil)
            default:                 nil
            }
            guard MiniGameGradeFit.offered(kind, grade: grade, script: script,
                                           topic: source ?? topic) else { return false }
            switch kind {
            case .lightning:
                return topic == .math || count(maxPrompt: 70, maxAnswer: 28, standalone: false) >= 12
            case .pairs:
                if topic == .math || topic == .english { return true }
                if (topic == .flags || topic == .geography) && grade >= 2 { return true }
                return count(maxPrompt: 60, maxAnswer: 24, standalone: true, distinct: true) >= 8
            case .balloon:
                if BalloonSets.hasCategory(topic, grade: grade) { return true }
                return count(maxPrompt: 70, maxAnswer: 16, standalone: false) >= 8
            case .sort:
                if SortSets.make(topic: source ?? topic, grade: grade) != nil { return true }
                return count(maxPrompt: 45, maxAnswer: 18, standalone: true) >= 10
            case .vault:
                if numericWorld { return true }
                return count(maxPrompt: 80, maxAnswer: 24, standalone: false) >= 6
            case .word:
                if WordSets.hasThemedList(source ?? topic, grade: grade) { return true }
                guard let source, source != .math else { return false }
                return GameContent.words(topic: source, grade: grade).count >= 6
            case .wordSearch:
                if WordSets.hasThemedList(source ?? topic, grade: grade) { return true }
                guard let source, source != .math else { return false }
                return GameContent.words(topic: source, grade: grade, maxLetters: 6).count >= 5
            case .crush:
                return numericWorld
            case .game2048:
                return [.math, .logic, .gifted].contains(topic)
            case .balance:
                if numericWorld { return true }
                // Comparisons ("how many legs…") — the beam says "more" or "less".
                guard let source else { return false }
                return GameContent.numericItems(topic: source, grade: grade).count >= 8
            case .pattern:
                return [.math, .logic, .gifted].contains(topic) || source == .english || source == .hebrew
            case .grocery:
                return [.math, .money].contains(topic) || source == .english || source == .hebrew
            }
        }
    }
}

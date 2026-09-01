import Foundation

struct QuestionGenerator {

    /// `grade` (Profile.effectiveGrade) aligns content to משרד החינוך: math
    /// routes to the curriculum engine, banks prefer grade-tagged items. nil →
    /// legacy behavior (e.g. the live quiz, where players span families).
    static func generate(topic: Topic, difficulty: Difficulty, grade: Int? = nil) -> Question {
        switch topic {
        case .math:
            if let grade, grade >= 1 {
                return CurriculumMath.generate(grade: grade, difficulty: difficulty)
            }
            return makeMath(difficulty: difficulty)
        case .reading:
            return ReadingContent.singleQuestion(target: difficulty, grade: grade)
        case .english, .hebrew, .logic, .science, .history, .geography, .money:
            return makeFromBank(topic: topic, difficulty: difficulty, grade: grade)
        }
    }

    /// 💫 A BONUS question — served only when the rare bonus event fires. Pulls
    /// from the dedicated really-hard pool (BonusQuestionBank); math is generated
    /// as a two-step expression. Falls back to a regular hard question if the
    /// pool for this topic is exhausted this session.
    static func generateBonus(topic: Topic, grade: Int? = nil) -> Question {
        if topic == .math { return makeBonusMath(grade: grade) }
        var pool = BonusQuestionBank.pool(for: topic)
        // 💫 Bonus stays HARD but age-fair: with the whole bank grade-tagged,
        // filter to the child's window (nearest items when the window is thin).
        if let g = grade {
            let inWindow = pool.filter { $0.grades.contains(g) }
            // Threshold 8 (not 3): a 3-item pool is smaller than QuestionMemory's
            // recency window, which killed the anti-repeat — the same three
            // bonus questions returned every session. Top up with the nearest
            // windows instead. shuffled() first so equal-distance ties don't
            // always pick the same declaration-order items.
            if inWindow.count >= 5 {
                pool = inWindow
            } else {
                // Pools are small (~10) — take the nearest-window items so a
                // 1st-grader doesn't get a ה'-ו' bonus. min() keeps it a real
                // filter instead of "prefix(12) of 10" = the whole pool.
                pool = Array(pool.shuffled().sorted {
                    let d0 = $0.grades.contains(g) ? 0 : min(abs($0.grades.lowerBound - g), abs($0.grades.upperBound - g))
                    let d1 = $1.grades.contains(g) ? 0 : min(abs($1.grades.lowerBound - g), abs($1.grades.upperBound - g))
                    return d0 < d1
                }.prefix(min(6, pool.count)))
            }
        }
        guard let item = QuestionMemory.shared.pickFresh(pool, for: topic, target: .hard) else {
            // Keep the grade — this fallback used to hand a 1st-grader an
            // untargeted hard question (e.g. a ד'-ו' reading passage).
            return generate(topic: topic, difficulty: .hard, grade: grade)
        }
        let allOptions = ([item.correctAnswer] + item.distractors).shuffled()
        return Question(
            topic: topic,
            prompt: item.prompt,
            options: allOptions,
            correctIndex: allOptions.firstIndex(of: item.correctAnswer) ?? 0
        )
    }

    /// Bonus math: a TWO-step expression (e.g. "7 × 6 + 13 = ?") — a real jump
    /// over the regular hard tier, matching the "really really hard" bonus pool.
    private static func makeBonusMath(grade: Int? = nil) -> Question {
        // Young kids get a REAL but fair jump: one grade up at hard, instead of
        // the universal two-step "7×6+13" they haven't learned yet.
        if let g = grade, g <= 2 {
            return CurriculumMath.generate(grade: min(6, g + 1), difficulty: .hard)
        }
        let a = Int.random(in: 3...12)
        let b = Int.random(in: 3...12)
        let prompt: String
        let answer: Int
        switch Int.random(in: 0...3) {
        case 0:
            let c = Int.random(in: 5...30)
            prompt = "\(a) × \(b) + \(c) = ?"
            answer = a * b + c
        case 1:
            let c = Int.random(in: 1..<(a * b))
            prompt = "\(a) × \(b) − \(c) = ?"
            answer = a * b - c
        case 2:
            let x = Int.random(in: 120...480), y = Int.random(in: 120...480)
            prompt = "\(x) + \(y) = ?"
            answer = x + y
        default:
            let x = Int.random(in: 250...900), y = Int.random(in: 100..<250)
            prompt = "\(x) − \(y) = ?"
            answer = x - y
        }
        return makeNumericQuestion(prompt: prompt, answer: answer, topic: .math)
    }

    // MARK: - Math (combines addition/subtraction and multiplication/division)

    private static func makeMath(difficulty: Difficulty) -> Question {
        // Easy: only +/− . Medium: 60% +/− , 40% ×/÷ . Hard: 50/50.
        let useMulDiv: Bool
        switch difficulty {
        case .easy:   useMulDiv = false
        case .medium: useMulDiv = Double.random(in: 0...1) < 0.4
        case .hard:   useMulDiv = Bool.random()
        }
        return useMulDiv
            ? makeMulDiv(difficulty: difficulty)
            : makeAddSub(difficulty: difficulty)
    }

    private static func makeAddSub(difficulty: Difficulty) -> Question {
        let max: Int
        switch difficulty {
        case .easy: max = 10
        case .medium: max = 20
        case .hard: max = 100
        }
        let isAdd = Bool.random()
        let a = Int.random(in: 1...max)
        let b = Int.random(in: 1...max)
        let prompt: String
        let answer: Int
        if isAdd {
            prompt = "\(a) + \(b) = ?"
            answer = a + b
        } else {
            let big = Swift.max(a, b)
            let small = Swift.min(a, b)
            prompt = "\(big) − \(small) = ?"
            answer = big - small
        }
        return makeNumericQuestion(prompt: prompt, answer: answer, topic: .math)
    }

    private static func makeMulDiv(difficulty: Difficulty) -> Question {
        let factorMax: Int
        switch difficulty {
        case .easy: factorMax = 5
        case .medium: factorMax = 10
        case .hard: factorMax = 12
        }
        let isMul = Bool.random()
        let a = Int.random(in: 1...factorMax)
        let b = Int.random(in: 1...factorMax)
        let prompt: String
        let answer: Int
        if isMul {
            prompt = "\(a) × \(b) = ?"
            answer = a * b
        } else {
            let product = a * b
            prompt = "\(product) ÷ \(a) = ?"
            answer = b
        }
        return makeNumericQuestion(prompt: prompt, answer: answer, topic: .math)
    }

    private static func makeNumericQuestion(prompt: String, answer: Int, topic: Topic) -> Question {
        var options: Set<Int> = [answer]
        while options.count < 4 {
            let delta = Int.random(in: 1...Swift.max(3, answer / 2 + 2))
            let candidate = Bool.random() ? answer + delta : answer - delta
            if candidate >= 0 { options.insert(candidate) }
        }
        let shuffled = options.shuffled()
        let correctIndex = shuffled.firstIndex(of: answer) ?? 0
        return Question(
            topic: topic,
            prompt: prompt,
            options: shuffled.map { String($0) },
            correctIndex: correctIndex
        )
    }

    // MARK: - Bank-based questions

    private static func makeFromBank(topic: Topic, difficulty: Difficulty, grade: Int? = nil) -> Question {
        var bank = QuestionBanks.bank(for: topic) ?? []
        if let g = grade {
            // 🎓 Curriculum window (the whole bank is now grade-tagged): serve
            // ONLY items whose window contains this grade. When the pool is
            // sparse or absent (English before ג׳, geography in גן — deliberate
            // curriculum gaps), borrow the CLOSEST-grade items instead of the
            // whole range, so a kindergartner gets the easiest material rather
            // than world capitals.
            func windowDistance(_ item: BankQuestion) -> Int {
                let r = item.grades
                if r.contains(g) { return 0 }
                return min(abs(r.lowerBound - g), abs(r.upperBound - g))
            }
            let tagged = bank.filter { $0.grades.contains(g) }
            if tagged.count >= 5 {
                bank = tagged
            } else {
                // shuffled() first: equal-distance ties otherwise resolve by
                // declaration order and the same 20 items get served forever.
                let nearest = bank.shuffled().sorted { windowDistance($0) < windowDistance($1) }
                bank = Array(nearest.prefix(20))
            }
        }
        guard let item = QuestionMemory.shared.pickFresh(bank, for: topic, target: difficulty) else {
            return Question(
                topic: topic,
                prompt: "אוֹפְּס... אֵין שְׁאֵלוֹת לַנּוֹשֵׂא הַזֶּה עֲדַיִן",
                options: ["בְּסֵדֶר", "הַמְשֵׁךְ", "תּוֹדָה", "חֲזוֹר"],
                correctIndex: 0
            )
        }
        let allOptions = ([item.correctAnswer] + item.distractors).shuffled()
        let correctIndex = allOptions.firstIndex(of: item.correctAnswer) ?? 0
        return Question(
            topic: topic,
            prompt: item.prompt,
            options: allOptions,
            correctIndex: correctIndex
        )
    }
}

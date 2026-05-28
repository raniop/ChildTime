import Foundation

struct QuestionGenerator {

    /// Dynamically derives difficulty from rolling accuracy.
    static func adaptiveDifficulty(base: Difficulty, accuracy: Double) -> Difficulty {
        let levels: [Difficulty] = [.easy, .medium, .hard]
        guard let idx = levels.firstIndex(of: base) else { return base }
        var target = idx
        if accuracy < 0.5 { target = max(0, idx - 1) }
        else if accuracy > 0.85 { target = min(levels.count - 1, idx + 1) }
        return levels[target]
    }

    static func generate(topic: Topic, difficulty: Difficulty) -> Question {
        switch topic {
        case .math:
            return makeMath(difficulty: difficulty)
        case .english, .logic, .science, .history, .geography:
            return makeFromBank(topic: topic, difficulty: difficulty)
        }
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

    private static func makeFromBank(topic: Topic, difficulty: Difficulty) -> Question {
        let bank = QuestionBanks.bank(for: topic) ?? []
        guard let item = bank.randomElement() else {
            return Question(
                topic: topic,
                prompt: "אופס... אין שאלות לנושא הזה עדיין",
                options: ["בסדר", "המשך", "תודה", "חזור"],
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

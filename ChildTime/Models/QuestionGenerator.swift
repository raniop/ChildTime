import Foundation

struct QuestionGenerator {

    /// Dynamically derives difficulty from rolling accuracy.
    /// - accuracy < 0.5 → drop one notch
    /// - accuracy > 0.85 → bump one notch
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
        case .addSub:
            return makeAddSub(difficulty: difficulty)
        case .mulDiv:
            return makeMulDiv(difficulty: difficulty)
        case .hebrewSpelling:
            return makeSpelling(difficulty: difficulty)
        }
    }

    // MARK: - Math

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
        return makeNumericQuestion(prompt: prompt, answer: answer, topic: .addSub)
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
        return makeNumericQuestion(prompt: prompt, answer: answer, topic: .mulDiv)
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

    // MARK: - Hebrew spelling

    private static func makeSpelling(difficulty: Difficulty) -> Question {
        let wordPool: [String]
        switch difficulty {
        case .easy: wordPool = HebrewWords.grade1
        case .medium: wordPool = HebrewWords.grade1 + HebrewWords.grade2
        case .hard: wordPool = HebrewWords.grade2
        }
        let word = wordPool.randomElement() ?? "ילד"
        let chars = Array(word)
        let hideIndex = Int.random(in: 0..<chars.count)
        let hidden = chars[hideIndex]

        let normalized: Character
        if let regular = HebrewWords.finalLetters.first(where: { $0.value == hidden })?.key {
            normalized = regular
        } else {
            normalized = hidden
        }

        var displayChars = chars
        displayChars[hideIndex] = "_"
        let displayed = String(displayChars)
        let prompt = "איזו אות חסרה?\n\(displayed)"

        var optionSet: Set<Character> = [normalized]
        let alphabet = HebrewWords.alphabet
        while optionSet.count < 4 {
            if let pick = alphabet.randomElement() {
                optionSet.insert(pick)
            }
        }
        let options = optionSet.shuffled().map { String($0) }
        let correctIndex = options.firstIndex(of: String(normalized)) ?? 0
        return Question(
            topic: .hebrewSpelling,
            prompt: prompt,
            options: options,
            correctIndex: correctIndex
        )
    }
}

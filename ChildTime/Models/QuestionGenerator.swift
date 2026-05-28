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
        let pool: [HebrewWord]
        switch difficulty {
        case .easy:   pool = HebrewWords.grade1
        case .medium: pool = HebrewWords.grade1 + HebrewWords.grade2
        case .hard:   pool = HebrewWords.grade2
        }

        let word = pool.randomElement() ?? HebrewWord(text: "ילד", emoji: "👦")

        // Pick a hide position that yields good distractors.
        // We try every position (shuffled) and accept the first one that
        // produces at least 3 letters that DON'T form another valid word.
        let positions = Array(0..<word.text.count).shuffled()
        for hideIndex in positions {
            if let question = makeSpellingQuestion(word: word, hideIndex: hideIndex, strictDistractors: true) {
                return question
            }
        }
        // Fallback: at least one position must work loosely (emoji disambiguates).
        return makeSpellingQuestion(word: word, hideIndex: positions[0], strictDistractors: false)!
    }

    /// Builds a spelling question for `word` with the letter at `hideIndex` hidden.
    /// If `strictDistractors` is true, distractor letters must NOT form another
    /// valid Hebrew word from our dictionary. Returns nil if it can't find enough.
    private static func makeSpellingQuestion(
        word: HebrewWord,
        hideIndex: Int,
        strictDistractors: Bool
    ) -> Question? {
        let chars = Array(word.text)
        guard hideIndex >= 0 && hideIndex < chars.count else { return nil }
        let hidden = chars[hideIndex]

        // Normalize: if hidden is a final letter (ך, ם, ן, ף, ץ), the correct option
        // displayed to the kid is the regular form (כ, מ, נ, פ, צ).
        let normalized: Character
        if let regular = HebrewWords.finalLetters.first(where: { $0.value == hidden })?.key {
            normalized = regular
        } else {
            normalized = hidden
        }

        // Build the set of letters that would NOT form another valid word at hideIndex.
        let isLastIndex = (hideIndex == chars.count - 1)
        var safeDistractors: [Character] = []
        for letter in HebrewWords.alphabet where letter != normalized {
            // When position is at end of word, also test the final form (if applicable).
            let testLetter: Character
            if isLastIndex, let finalForm = HebrewWords.finalLetters[letter] {
                testLetter = finalForm
            } else {
                testLetter = letter
            }
            var test = chars
            test[hideIndex] = testLetter
            let testWord = String(test)
            let normalizedTest = HebrewWords.normalizeFinals(testWord)
            let conflicts = HebrewWords.dictionary.contains(testWord)
                || HebrewWords.dictionary.contains(normalizedTest)
            if !conflicts {
                safeDistractors.append(letter)
            }
        }

        if strictDistractors && safeDistractors.count < 3 {
            return nil
        }

        // Pick 3 distractors (from safe pool if strict, else from any non-correct letter).
        let pool = strictDistractors
            ? safeDistractors
            : HebrewWords.alphabet.filter { $0 != normalized }
        let chosenDistractors = Array(pool.shuffled().prefix(3))

        let options = ([normalized] + chosenDistractors).shuffled().map { String($0) }
        let correctIndex = options.firstIndex(of: String(normalized)) ?? 0

        var displayChars = chars
        displayChars[hideIndex] = "_"
        let displayed = String(displayChars)
        let prompt = "\(word.emoji)\nאיזו אות חסרה?\n\(displayed)"

        return Question(
            topic: .hebrewSpelling,
            prompt: prompt,
            options: options,
            correctIndex: correctIndex
        )
    }
}

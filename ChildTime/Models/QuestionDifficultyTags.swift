import Foundation

/// Difficulty rating for each hand-curated bank question, keyed by the same
/// `"<prompt>|<correctAnswer>"` key the anti-repeat memory uses.
///
/// Stored as a side table (rather than baked into each `BankQuestion` literal)
/// so the ~900 curated questions don't have to be rewritten, and so re-grading
/// is a single-file change. Anything not in the map falls back to `.medium`,
/// so partial coverage is always safe.
enum QuestionDifficultyTags {

    /// Look up a question's difficulty by its prompt + correct answer.
    static func difficulty(prompt: String, correctAnswer: String) -> Difficulty {
        map["\(prompt)|\(correctAnswer)"] ?? .medium
    }

    /// `"<prompt>|<correctAnswer>"` → difficulty. Combined from the per-file
    /// grading passes (see QuestionDifficultyTags_*.swift). Later files win on
    /// the rare cross-file duplicate key.
    static let map: [String: Difficulty] = {
        var m = QDTBase.all
        m.merge(QDTExpanded.all)  { _, new in new }
        m.merge(QDTWorkflow.all)  { _, new in new }
        m.merge(QDTWorkflow2.all) { _, new in new }
        return m
    }()
}

extension BankQuestion {
    /// The graded difficulty of this bank question (falls back to `.medium`).
    var difficulty: Difficulty {
        QuestionDifficultyTags.difficulty(prompt: prompt, correctAnswer: correctAnswer)
    }
}

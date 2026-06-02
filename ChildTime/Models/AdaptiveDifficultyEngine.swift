import Foundation

/// Keeps each child in their personal "optimal learning zone" — challenging
/// enough to grow, easy enough to stay motivated (target ≈ 80% success).
///
/// The engine tracks a CONTINUOUS difficulty level per topic (0 = easy,
/// 1 = medium, 2 = hard). It nudges that level a little after every answer
/// using multiple signals (correctness, speed, hint use, abandonment), so a
/// single great answer never jumps a level — it takes a sustained run of
/// strong answers to rise, and the level eases back quickly the moment a child
/// starts to struggle (relief before frustration).
///
/// The parent's chosen base difficulty (`Profile.difficulty(for:)`) is the
/// ANCHOR: the adaptive level only floats within ±1 level around it, so the
/// parent's intent is always respected.
///
/// This type is intentionally pure (no I/O) so it's easy to reason about and
/// test. `ProgressStore` owns the persisted level and feeds the signals in.
enum AdaptiveDifficultyEngine {

    // MARK: - Level ⇆ Difficulty

    /// Continuous level for a discrete difficulty. easy→0, medium→1, hard→2.
    static func level(for difficulty: Difficulty) -> Double {
        switch difficulty {
        case .easy:   return 0
        case .medium: return 1
        case .hard:   return 2
        }
    }

    /// The discrete difficulty a continuous level maps to (rounded, clamped).
    static func difficulty(forLevel level: Double) -> Difficulty {
        switch Int(level.rounded()) {
        case ..<1: return .easy
        case 1:    return .medium
        default:   return .hard
        }
    }

    // MARK: - Per-answer signals

    struct Signals {
        var correct: Bool
        /// Answered faster than the child's own rolling average for the topic.
        var fast: Bool
        /// The child leaned on a hint for this question.
        var hintUsed: Bool
        /// The child gave up on the question (swapped it out).
        var abandoned: Bool
    }

    // Step sizes. Rising is slow (it takes a sustained run of strong answers to
    // move up a whole level); easing down is a bit faster, so a struggling child
    // gets relief before frustration sets in. Tuned so ~6 fast-correct answers
    // raise a level and ~3 misses ease it back — gradual, never jumpy.
    private static let riseStrong = 0.17   // correct, fast, no hint → mastery
    private static let riseSolid  = 0.09   // correct, normal pace, no hint
    private static let riseShaky  = 0.03   // correct but needed a hint
    private static let easeMiss   = 0.34   // wrong answer
    private static let easeGiveUp = 0.45   // abandoned the question

    /// Updates the continuous level after one answer. Clamps to the parent's
    /// chosen base ±1 (so the parent's setting stays the anchor) and to the
    /// absolute easy…hard range.
    static func updatedLevel(current: Double, base: Difficulty, signals: Signals) -> Double {
        let delta: Double
        if signals.abandoned {
            delta = -easeGiveUp
        } else if !signals.correct {
            delta = -easeMiss
        } else if signals.hintUsed {
            delta = riseShaky
        } else if signals.fast {
            delta = riseStrong
        } else {
            delta = riseSolid
        }

        let baseLevel = level(for: base)
        var next = current + delta
        // Float only within ±1 of the parent's anchor…
        next = min(baseLevel + 1, max(baseLevel - 1, next))
        // …and never outside the real easy…hard scale.
        return min(2, max(0, next))
    }

    // MARK: - Question selection mix

    /// Picks the difficulty tier for the NEXT question around the child's
    /// current level. Mostly serves at-level questions, sprinkles a few that are
    /// a touch harder (to stretch) and a few easier (to reinforce / rebuild
    /// confidence). Default mix ≈ 70% at-level · 20% harder · 10% easier; when
    /// the child is below their anchor (struggling) it leans gentler.
    static func sampledDifficulty(forLevel level: Double, base: Difficulty) -> Difficulty {
        let center = Int(level.rounded())
        let struggling = level < self.level(for: base)   // engine eased below the anchor

        // roll: harder / at-level / easier
        let harderChance = struggling ? 0.10 : 0.20
        let easierChance = struggling ? 0.30 : 0.10
        let r = Double.random(in: 0..<1)
        let offset: Int
        if r < harderChance { offset = 1 }
        else if r < harderChance + easierChance { offset = -1 }
        else { offset = 0 }

        return difficulty(forLevel: Double(min(2, max(0, center + offset))))
    }
}

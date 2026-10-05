package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Difficulty
import kotlin.math.floor
import kotlin.random.Random

/** Swift's `.rounded()` — half AWAY from zero (Kotlin's round() is half-even). */
internal fun swiftRound(x: Double): Double = if (x >= 0) floor(x + 0.5) else -floor(-x + 0.5)

/**
 * AdaptiveDifficultyEngine.swift — keeps each child in the ~80% success zone.
 * A CONTINUOUS level per topic (0 easy · 1 medium · 2 hard) that rises slowly
 * on strong answers and eases faster on struggle, floating only within the
 * parent's base ±1. Pure — the persisted level lives in the progress snapshot
 * (`topicAdaptiveLevel`), owned by the progress core.
 */
object AdaptiveDifficultyEngine {
    fun level(d: Difficulty): Double = when (d) {
        Difficulty.EASY -> 0.0
        Difficulty.MEDIUM -> 1.0
        Difficulty.HARD -> 2.0
    }

    fun difficulty(level: Double): Difficulty {
        val n = swiftRound(level).toInt()
        return when {
            n < 1 -> Difficulty.EASY
            n == 1 -> Difficulty.MEDIUM
            else -> Difficulty.HARD
        }
    }

    data class Signals(
        val correct: Boolean,
        /** Faster than the child's own rolling average for the topic. */
        val fast: Boolean,
        val hintUsed: Boolean,
        /** Gave up on the question (swapped it out). */
        val abandoned: Boolean,
    )

    // Step sizes — exact iOS constants (~6 fast-correct answers raise a level,
    // ~3 misses ease it back).
    const val RISE_STRONG = 0.17   // correct, fast, no hint
    const val RISE_SOLID = 0.09    // correct, normal pace, no hint
    const val RISE_SHAKY = 0.03    // correct but needed a hint
    const val EASE_MISS = 0.34     // wrong answer
    const val EASE_GIVE_UP = 0.45  // abandoned

    fun updatedLevel(current: Double, base: Difficulty, signals: Signals): Double {
        val delta = when {
            signals.abandoned -> -EASE_GIVE_UP
            !signals.correct -> -EASE_MISS
            signals.hintUsed -> RISE_SHAKY
            signals.fast -> RISE_STRONG
            else -> RISE_SOLID
        }
        val baseLevel = level(base)
        var next = current + delta
        next = minOf(baseLevel + 1, maxOf(baseLevel - 1, next))   // the parent's anchor ±1
        return minOf(2.0, maxOf(0.0, next))                       // the real easy…hard scale
    }

    /**
     * The tier for the NEXT question around the current level: ≈70% at-level ·
     * 20% harder · 10% easier; below the anchor (struggling) 10% harder · 30% easier.
     */
    fun sampledDifficulty(level: Double, base: Difficulty, rng: Random = Random.Default): Difficulty {
        val center = swiftRound(level).toInt()
        val struggling = level < level(base)
        val harderChance = if (struggling) 0.10 else 0.20
        val easierChance = if (struggling) 0.30 else 0.10
        val r = rng.nextDouble()
        val offset = when {
            r < harderChance -> 1
            r < harderChance + easierChance -> -1
            else -> 0
        }
        return difficulty(minOf(2, maxOf(0, center + offset)).toDouble())
    }

    /** The level "band" the runner celebrates/softens on (only a real band change). */
    fun band(level: Double): Int = swiftRound(level).toInt()
}

/** EventEngine.swift — when the special events fire during a session. */
object EventEngine {
    /** 🌀 Mystery Portal — ~10%, never on Q1/Q2 or the last question. */
    fun shouldFireMysteryPortal(questionIndex: Int, totalQuestions: Int, rng: Random = Random.Default): Boolean {
        if (questionIndex < 2 || questionIndex >= totalQuestions - 1) return false
        return rng.nextDouble() < 0.10
    }

    /** ⭐ Super Question — golden frame, ×3 reward, ~7%. */
    fun shouldFireSuperQuestion(questionIndex: Int, totalQuestions: Int, rng: Random = Random.Default): Boolean {
        if (questionIndex < 1 || questionIndex >= totalQuestions) return false
        return rng.nextDouble() < 0.07
    }

    /** 💫 Bonus Question — the rarest (~6%): pays ~2 regular batches. */
    fun shouldFireBonusQuestion(questionIndex: Int, totalQuestions: Int, rng: Random = Random.Default): Boolean {
        if (questionIndex < 2 || questionIndex >= totalQuestions - 1) return false
        return rng.nextDouble() < 0.06
    }

    /** Big combo celebration at exactly 3, 5 and 10 in a row. */
    fun shouldFireComboEvent(streak: Int): Boolean = streak == 3 || streak == 5 || streak == 10
}

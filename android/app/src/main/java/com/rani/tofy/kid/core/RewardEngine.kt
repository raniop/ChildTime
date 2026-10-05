package com.rani.tofy.kid.core

import java.time.DayOfWeek
import java.time.ZoneId
import kotlin.random.Random

/*
 * Reward rules — ports of ChildTime/Models/RewardEngine.swift,
 * AdaptiveDifficultyEngine.swift, GameEvent.swift and the LearningLevel /
 * Difficulty enums. Pure functions, no state.
 *
 * PUBLIC API
 *   Difficulty / LearningLevel           — raw values identical to iOS ("easy", "beginner"…)
 *   RewardEngine.starsForCorrect / diamondsForCorrect / pointsForCorrect /
 *     comboMultiplier / level(forXP) / levelThresholds / levelUpDiamonds /
 *     levelTier / diamondPrice / chestContents / endOfSessionChestKind
 *   ChestKind, ChestReward
 *   AdaptiveDifficultyEngine.updatedLevel / sampledDifficulty / level / difficultyForLevel
 *   GameEvent.current(now, zone) + diamondMultiplier(topic)
 * Topics are plain iOS `Topic.rawValue` strings ("math", "hebrew", …).
 */

enum class Difficulty(val raw: String) {
    EASY("easy"), MEDIUM("medium"), HARD("hard");
    companion object { fun of(raw: String?): Difficulty? = entries.firstOrNull { it.raw == raw } }
}

/** ChildRecord.swift LearningLevel. */
enum class LearningLevel(val raw: String, val seedDifficulty: Difficulty, val affinityBoost: Double) {
    BEGINNER("beginner", Difficulty.EASY, 0.10),
    DEVELOPING("developing", Difficulty.EASY, 0.15),
    PROFICIENT("proficient", Difficulty.MEDIUM, 0.20),
    ADVANCED("advanced", Difficulty.HARD, 0.25);
    companion object { fun of(raw: String?): LearningLevel? = entries.firstOrNull { it.raw == raw } }
}

enum class ChestKind(val raw: String, val emoji: String) {
    WOOD("wood", "📦"), GOLD("gold", "🎁"), MAGIC("magic", "🪄"), LEGENDARY("legendary", "🌌")
}

data class ChestReward(val stars: Int, val diamonds: Int, val minutes: Int, val cosmeticID: String? = null)

object RewardEngine {
    const val starMultiplier = 3
    /** 💫 Minutes a correct BONUS QUESTION pays (via grantBonusMinutes). */
    const val bonusQuestionMinutes = 7
    const val xpPerQuestion = 1
    const val xpPerCorrect = 2
    const val answersPerReward = 10
    const val minutesPerReward = 4
    const val pointsPerCorrect = 10
    const val diamondPriceDivisor = 5

    fun comboMultiplier(streak: Int): Int = when {
        streak < 3 -> 1
        streak < 5 -> 2
        streak < 10 -> 3
        streak < 15 -> 4
        else -> 5
    }

    fun starsForCorrect(combo: Int, isSuperQuestion: Boolean, isMysteryPortal: Boolean, isBonusQuestion: Boolean = false): Int = when {
        isBonusQuestion -> 5 * starMultiplier
        isMysteryPortal -> 3 * starMultiplier
        isSuperQuestion -> 5 * starMultiplier
        else -> comboMultiplier(combo) * starMultiplier
    }

    fun diamondsForCorrect(combo: Int, isSuperQuestion: Boolean, isMysteryPortal: Boolean, isBonusQuestion: Boolean = false): Int = when {
        isBonusQuestion -> 5
        isMysteryPortal -> 3
        isSuperQuestion -> 5
        combo < 5 -> 1
        combo < 10 -> 2
        else -> 3
    }

    fun diamondPrice(forStarPrice: Int): Int =
        if (forStarPrice <= 0) 0 else maxOf(1, (forStarPrice.toDouble() / diamondPriceDivisor).roundHalfAwayFromZero())

    fun bonusMinutesForStreak(streak: Int): Int = when {
        streak < 3 -> 0
        streak < 5 -> 1
        streak < 10 -> 2
        else -> 3
    }

    fun pointsForCorrect(
        combo: Int, isSuperQuestion: Boolean, isMysteryPortal: Boolean,
        difficulty: Difficulty, isBonusQuestion: Boolean = false,
    ): Int {
        var base = pointsPerCorrect
        base += when (if (isBonusQuestion) Difficulty.HARD else difficulty) {
            Difficulty.EASY -> 0
            Difficulty.MEDIUM -> 5
            Difficulty.HARD -> 10
        }
        if (combo >= 10) base += 10 else if (combo >= 5) base += 5 else if (combo >= 3) base += 2
        if (isBonusQuestion) base *= 5
        if (isSuperQuestion) base *= 5
        if (isMysteryPortal) base *= 3
        return base
    }

    /** 30 levels: the original eleven, then +500 XP per level. */
    val levelThresholds: List<Int> = listOf(0, 10, 25, 50, 100, 200, 350, 550, 800, 1100, 1500) + (1..19).map { 1500 + it * 500 }

    fun levelUpDiamonds(level: Int): Int = maxOf(10, 10 * level)
    fun levelTier(level: Int): Int = if (level >= 20) 3 else if (level >= 10) 2 else if (level >= 5) 1 else 0

    fun level(forXP: Int): Int {
        var lvl = 1
        levelThresholds.forEachIndexed { i, t -> if (forXP >= t) lvl = i + 1 }
        return lvl
    }

    fun xpForCurrentLevel(xp: Int): Int = levelThresholds.getOrElse(level(xp) - 1) { 0 }
    fun xpForNextLevel(xp: Int): Int = levelThresholds.getOrElse(level(xp)) { levelThresholds.last() + 500 }

    fun chestContents(kind: ChestKind): ChestReward = when (kind) {
        ChestKind.WOOD -> ChestReward(2 * starMultiplier, 2, 1)
        ChestKind.GOLD -> ChestReward(3 * starMultiplier, 3, 3)
        ChestKind.MAGIC -> ChestReward(10 * starMultiplier, 8, 5)
        ChestKind.LEGENDARY -> ChestReward(50 * starMultiplier, 35, 15, "legendary_aura")
    }

    /** Perfect session: 50% gold; otherwise 15% gold. */
    fun endOfSessionChestKind(correctInSession: Int, total: Int, random: Random = Random.Default): ChestKind {
        if (correctInSession == total && random.nextDouble() < 0.5) return ChestKind.GOLD
        return if (random.nextDouble() < 0.15) ChestKind.GOLD else ChestKind.WOOD
    }
}

/** Swift's `.rounded()` — schoolbook rounding, half away from zero (Kotlin's roundToInt rounds -0.5 up). */
internal fun Double.roundHalfAwayFromZero(): Int = if (this >= 0) kotlin.math.floor(this + 0.5).toInt() else -kotlin.math.floor(-this + 0.5).toInt()

/** AdaptiveDifficultyEngine.swift — continuous level 0 (easy) … 2 (hard), anchored ±1 around the parent's base. */
object AdaptiveDifficultyEngine {
    data class Signals(val correct: Boolean, val fast: Boolean, val hintUsed: Boolean, val abandoned: Boolean)

    private const val riseStrong = 0.17
    private const val riseSolid = 0.09
    private const val riseShaky = 0.03
    private const val easeMiss = 0.34
    private const val easeGiveUp = 0.45

    fun level(d: Difficulty): Double = when (d) { Difficulty.EASY -> 0.0; Difficulty.MEDIUM -> 1.0; Difficulty.HARD -> 2.0 }

    fun difficultyForLevel(level: Double): Difficulty {
        val r = level.roundHalfAwayFromZero()
        return when { r < 1 -> Difficulty.EASY; r == 1 -> Difficulty.MEDIUM; else -> Difficulty.HARD }
    }

    fun updatedLevel(current: Double, base: Difficulty, signals: Signals): Double {
        val delta = when {
            signals.abandoned -> -easeGiveUp
            !signals.correct -> -easeMiss
            signals.hintUsed -> riseShaky
            signals.fast -> riseStrong
            else -> riseSolid
        }
        val b = level(base)
        var next = current + delta
        next = minOf(b + 1, maxOf(b - 1, next))
        return minOf(2.0, maxOf(0.0, next))
    }

    /** ≈70% at-level · 20% harder · 10% easier (gentler when below the anchor). */
    fun sampledDifficulty(level: Double, base: Difficulty, random: Random = Random.Default): Difficulty {
        val center = level.roundHalfAwayFromZero()
        val struggling = level < level(base)
        val harder = if (struggling) 0.10 else 0.20
        val easier = if (struggling) 0.30 else 0.10
        val r = random.nextDouble()
        val offset = if (r < harder) 1 else if (r < harder + easier) -1 else 0
        return difficultyForLevel(minOf(2, maxOf(0, center + offset)).toDouble())
    }
}

/** GameEvent.swift — a pure function of the calendar date, so every device agrees. */
sealed class GameEvent {
    data object DoubleDiamonds : GameEvent()
    data class FeaturedTopic(val topic: String) : GameEvent()

    fun diamondMultiplier(topic: String): Int = when (this) {
        DoubleDiamonds -> 2
        is FeaturedTopic -> if (this.topic == topic) 2 else 1
    }

    companion object {
        private val pool = listOf("english", "hebrew", "logic", "science", "history", "geography", "money", "reading")

        fun current(nowApple: Double, zone: ZoneId): GameEvent {
            val d = DayMath.localDate(nowApple, zone)
            if (d.dayOfWeek == DayOfWeek.FRIDAY || d.dayOfWeek == DayOfWeek.SATURDAY) return DoubleDiamonds
            return FeaturedTopic(pool[d.dayOfYear % pool.size])
        }
    }
}

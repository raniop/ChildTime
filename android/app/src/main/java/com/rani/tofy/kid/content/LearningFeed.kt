package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Topic
import kotlin.math.exp
import kotlin.random.Random

/**
 * The per-topic learning signals the progress snapshot carries
 * (ProgressSnapshot: topicAccuracy, topicAnswered, topicAffinity, topicExposure,
 * topicAbandon, topicResponseMs), keyed by Topic.raw.
 */
data class LearningSignals(
    val topicAccuracy: Map<String, Double> = emptyMap(),
    val topicAnswered: Map<String, Int> = emptyMap(),
    val topicAffinity: Map<String, Double> = emptyMap(),
    val topicExposure: Map<String, Int> = emptyMap(),
    val topicAbandon: Map<String, Int> = emptyMap(),
    val topicResponseMs: Map<String, Double> = emptyMap(),
)

/**
 * LearningProfile.swift — a read-only projection of what the system learned
 * about one child; shared by the Smart Feed and the parent views so both use
 * one definition of favorite / strong / weak.
 */
class LearningProfile(signals: LearningSignals, val enabledTopics: Set<Topic>) {
    private val accuracy = HashMap<Topic, Double>()
    private val answered = HashMap<Topic, Int>()
    private val affinity = HashMap<Topic, Double>()
    private val exposure = HashMap<Topic, Int>()
    private val abandon = HashMap<Topic, Int>()
    private val responseMs = HashMap<Topic, Double>()

    init {
        // init(snapshot:) / ProgressStore defaults: accuracy 0.7, affinity seeded
        // 0.6 for an enabled topic and 0.4 otherwise.
        for (t in Topic.entries) {
            accuracy[t] = signals.topicAccuracy[t.raw] ?: 0.7
            answered[t] = signals.topicAnswered[t.raw] ?: 0
            affinity[t] = signals.topicAffinity[t.raw] ?: (if (enabledTopics.contains(t)) 0.6 else 0.4)
            exposure[t] = signals.topicExposure[t.raw] ?: 0
            abandon[t] = signals.topicAbandon[t.raw] ?: 0
            signals.topicResponseMs[t.raw]?.let { responseMs[t] = it }
        }
    }

    fun affinity(t: Topic) = affinity[t] ?: 0.5
    fun exposure(t: Topic) = exposure[t] ?: 0
    fun abandonCount(t: Topic) = abandon[t] ?: 0
    fun successRate(t: Topic) = accuracy[t] ?: 0.0
    fun avgResponseMs(t: Topic): Double? = responseMs[t]

    /** Average success over topics actually met; a neutral 0.7 before any history. */
    val overallAccuracy: Double
        get() {
            val met = Topic.entries.filter { (answered[it] ?: 0) > 0 }
            if (met.isEmpty()) return 0.7
            return met.sumOf { successRate(it) } / met.size
        }

    private fun isConfident(t: Topic) = (answered[t] ?: 0) >= CONFIDENT_SAMPLE_COUNT

    private fun byDesc(f: (Topic) -> Double) = compareByDescending<Topic> { f(it) }.thenBy { it.raw }
    private fun byAsc(f: (Topic) -> Double) = compareBy<Topic> { f(it) }.thenBy { it.raw }

    val favorites: List<Topic> get() = enabledTopics.filter { exposure(it) > 0 }.sortedWith(byDesc(::affinity))
    val strong: List<Topic> get() = Topic.entries.filter { isConfident(it) && successRate(it) >= 0.8 }.sortedWith(byDesc(::successRate))
    val weak: List<Topic> get() = Topic.entries.filter { isConfident(it) && successRate(it) < 0.5 }.sortedWith(byAsc(::successRate))
    val unexplored: List<Topic> get() = enabledTopics.filter { exposure(it) < CONFIDENT_SAMPLE_COUNT }.sortedWith(byAsc { exposure(it).toDouble() })
    val abandoned: List<Topic> get() = Topic.entries.filter { abandonCount(it) > 0 }.sortedWith(byDesc { abandonCount(it).toDouble() })
    val discovering: List<Topic>
        get() = enabledTopics.filter { exposure(it) in 1 until 8 && affinity(it) >= 0.65 }.sortedWith(byDesc(::affinity))

    companion object {
        /** Answers needed before a topic's accuracy label is trusted. */
        const val CONFIDENT_SAMPLE_COUNT = 4
    }
}

/**
 * LearningFeedEngine.swift — the Smart Feed's topic picker: exploit what the
 * child loves (softmax over affinity) and explore barely-met topics
 * (inverse exposure), never more than twice in a row. Pure.
 */
class LearningFeedEngine(val profile: LearningProfile) {
    private val exploitTemperature = 0.5

    /** Strictly the parent's enabled set (falls back to the core topics). */
    private val universe: List<Topic>
        get() = profile.enabledTopics.toList().sortedBy { it.ordinal }.ifEmpty { Topic.core }

    fun nextTopic(history: List<Topic>, index: Int, rng: Random = Random.Default): Topic {
        val pool = universe
        if (pool.size <= 1) return pool.firstOrNull() ?: Topic.MATH
        val candidates = antiRepeatFiltered(pool, history)
        return if (isExploreSlot(index)) exploreTopic(candidates, rng) else exploitTopic(candidates, rng)
    }

    fun plan(length: Int, rng: Random = Random.Default): List<Topic> {
        val history = mutableListOf<Topic>()
        repeat(maxOf(0, length)) { history.add(nextTopic(history, it, rng)) }
        return history
    }

    /** Base 20% explore; thriving → 30%, struggling → 10%. */
    val exploreRatio: Double
        get() {
            val acc = profile.overallAccuracy
            return when { acc > 0.85 -> 0.30; acc < 0.50 -> 0.10; else -> 0.20 }
        }

    private fun isExploreSlot(index: Int): Boolean {
        val cadence = maxOf(2, swiftRound(1.0 / exploreRatio).toInt())
        return (index + 1) % cadence == 0
    }

    private fun exploitTopic(candidates: List<Topic>, rng: Random): Topic {
        val met = candidates.filter { profile.exposure(it) > 0 }
        val pool = met.ifEmpty { candidates }
        val weights = pool.map { exp(profile.affinity(it) / exploitTemperature) }
        return weightedPick(pool, weights, rng) ?: pool.randomOrNull(rng) ?: candidates[0]
    }

    private fun exploreTopic(candidates: List<Topic>, rng: Random): Topic {
        val maxExposure = candidates.maxOfOrNull { profile.exposure(it) } ?: 0
        val weights = candidates.map { (maxExposure - profile.exposure(it)).toDouble() + 1.0 }
        return weightedPick(candidates, weights, rng) ?: candidates.randomOrNull(rng) ?: candidates[0]
    }

    /** Drops a topic that already ran twice in a row (unless nothing else is left). */
    private fun antiRepeatFiltered(pool: List<Topic>, history: List<Topic>): List<Topic> {
        if (history.size < 2) return pool
        val last = history[history.size - 1]
        if (last != history[history.size - 2]) return pool
        return pool.filter { it != last }.ifEmpty { pool }
    }

    private fun weightedPick(items: List<Topic>, weights: List<Double>, rng: Random): Topic? {
        if (items.size != weights.size || items.isEmpty()) return null
        val total = weights.sum()
        if (total <= 0) return items.random(rng)
        var roll = rng.nextDouble() * total
        for ((item, w) in items.zip(weights)) {
            roll -= w
            if (roll < 0) return item
        }
        return items.last()
    }
}

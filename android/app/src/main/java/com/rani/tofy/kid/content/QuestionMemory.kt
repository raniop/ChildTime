package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.serialization.encodeToString
import kotlin.random.Random

/**
 * QuestionMemory (QuestionBanks.swift) — per-profile anti-repeat memory.
 *
 * • Cross-session: each topic remembers the last ~85% of its pool
 *   ("prompt|answer" keys), so a child cycles through most of a bank before
 *   anything returns. Persisted under "questionMemory.<profileId>" as the same
 *   {topic: [key]} JSON iOS stores.
 * • In-session: nothing is served twice in one session (the runner's deliberate
 *   re-ask of a wrong answer goes through [allowReask]).
 *
 * Also owns the 📖 reading-passage recency (ReadingContent.recentIDs/markUsed),
 * which iOS keeps per profile too ("reading.recentPassageIDs.<profileId>").
 */
class QuestionMemory(private val prefs: ContentPrefs, val profileId: String?) {
    private val storageKey = "questionMemory.${profileId ?: "default"}"
    private val readingKey = "reading.recentPassageIDs" + (profileId?.let { ".$it" } ?: "")

    private var recent: MutableMap<String, MutableList<String>> = mutableMapOf()
    private var loaded = false
    private val sessionServed = HashSet<String>()

    @Synchronized fun beginSession() = sessionServed.clear()
    @Synchronized fun markServedThisSession(key: String) { sessionServed.add(key) }
    @Synchronized fun wasServedThisSession(key: String) = sessionServed.contains(key)
    /** Allow a wrong question to come back (the runner re-asks it). */
    @Synchronized fun allowReask(key: String) { sessionServed.remove(key) }

    /**
     * Difficulty-aware pick: the target tier first, then its neighbours, then
     * anything — a thin tier never starves the child. The recency window is
     * sized by the WHOLE topic pool, not the tier slice.
     */
    @Synchronized
    fun pickFresh(pool: List<BankQuestion>, topic: Topic, target: Difficulty, rng: Random): BankQuestion? {
        val order = when (target) {
            Difficulty.EASY -> listOf(Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD)
            Difficulty.MEDIUM -> listOf(Difficulty.MEDIUM, Difficulty.EASY, Difficulty.HARD)
            Difficulty.HARD -> listOf(Difficulty.HARD, Difficulty.MEDIUM, Difficulty.EASY)
        }
        val fullWindow = windowFor(pool.size)
        for (tier in order) {
            val slice = pool.filter { it.difficulty == tier }
            // Strict (no session repeats) so an exhausted tier yields to the next.
            pickFresh(slice, topic, rng, allowSessionRepeat = false, windowOverride = fullWindow)?.let { return it }
        }
        // Every tier was fully served this session — allow a lenient repeat.
        return pickFresh(pool, topic, rng, windowOverride = fullWindow)
    }

    /**
     * A random item not served recently. Fallback chain: fresh → not yet this
     * session → (if allowed) anything.
     */
    @Synchronized
    fun pickFresh(
        pool: List<BankQuestion>, topic: Topic, rng: Random,
        allowSessionRepeat: Boolean = true, windowOverride: Int? = null,
    ): BankQuestion? {
        ensureLoaded()
        if (pool.isEmpty()) return null
        val windowSize = windowOverride ?: windowFor(pool.size)
        val recentList = recent[topic.raw] ?: emptyList<String>()
        val recentSet = recentList.toHashSet()
        val fresh = pool.filter { it.key !in recentSet && it.key !in sessionServed }
        val notInSession = pool.filter { it.key !in sessionServed }
        val candidates = when {
            fresh.isNotEmpty() -> fresh
            notInSession.isNotEmpty() -> notInSession
            allowSessionRepeat -> pool
            else -> return null   // the tier picker tries another tier instead of repeating
        }
        val chosen = candidates.random(rng)
        remember(chosen.key, topic, windowSize)
        sessionServed.add(chosen.key)
        return chosen
    }

    /** Wipe this profile's memory (remote reset). */
    @Synchronized
    fun clear() {
        recent = mutableMapOf()
        loaded = true
        prefs.putString(storageKey, null)
    }

    /** The persisted recency list for a topic (tests / diagnostics). */
    @Synchronized
    fun recentKeys(topic: Topic): List<String> { ensureLoaded(); return recent[topic.raw]?.toList() ?: emptyList() }

    private fun remember(key: String, topic: Topic, windowSize: Int) {
        val list = recent.getOrPut(topic.raw) { mutableListOf() }
        list.add(key)
        if (list.size > windowSize) repeat(list.size - windowSize) { list.removeAt(0) }
        save()
    }

    private fun ensureLoaded() {
        if (loaded) return
        loaded = true
        recent = runCatching {
            prefs.getString(storageKey)?.let { contentJson.decodeFromString<Map<String, List<String>>>(it) }
        }.getOrNull()
            ?.filterKeys { Topic.of(it) != null }
            ?.mapValues { it.value.toMutableList() }?.toMutableMap()
            ?: mutableMapOf()
    }

    private fun save() {
        prefs.putString(storageKey, contentJson.encodeToString(recent.mapValues { it.value.toList() }))
    }

    // MARK: - 📖 Reading passages (ReadingContent anti-repeat, ~60% of the universe)

    @Synchronized
    fun readingRecentIDs(): List<String> =
        runCatching { prefs.getString(readingKey)?.let { contentJson.decodeFromString<List<String>>(it) } }.getOrNull() ?: emptyList()

    /** Cap at ~60% of the CURRENT universe (min 1, never all − so one fresh passage always exists). */
    @Synchronized
    fun markPassageUsed(id: String, universeCount: Int) {
        val ids = readingRecentIDs().filter { it != id }.toMutableList()
        ids.add(id)
        val cap = maxOf(1, minOf((universeCount * 6) / 10, universeCount - 1))
        if (ids.size > cap) repeat(ids.size - cap) { ids.removeAt(0) }
        prefs.putString(readingKey, contentJson.encodeToString(ids.toList()))
    }

    companion object {
        /** 85% of the pool, at least 5. */
        fun windowFor(poolSize: Int) = maxOf(5, (poolSize * 85) / 100)
    }
}

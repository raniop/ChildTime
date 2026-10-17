package com.rani.tofy.kid.content

import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.serialization.encodeToString
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlin.random.Random

/**
 * Where [QuestionMemory] shares what was asked with the child's other devices
 * (QuestionMemorySync.swift). The Firestore one is [QuestionMemorySync]; tests
 * and the first run have none.
 */
interface QuestionMemoryCloud {
    /** Fetch what the child's other devices asked; `merge` gets topic → fingerprint → time. */
    fun pull(child: String, merge: (Map<String, Map<String, Double>>) -> Unit)
    /** Queue one asked question; sent with the others a few seconds later. */
    fun push(child: String, topic: String, fingerprint: String, at: Double)
    /** How much of a world's pool this child has been asked — sent with the next batch. */
    fun coverage(child: String, topic: String, seen: Int, pool: Int, at: Double)
}

/**
 * QuestionMemory (QuestionBanks.swift) — per-profile anti-repeat memory.
 *
 * Rani, 2026-10-17: "שאלות שנשאלו לא יחזרו".
 * • Cross-session: per topic, fingerprint → when it was last asked (seconds
 *   since 1970). An UNSEEN question always comes first; only when the whole
 *   pool has been asked does the one asked longest ago come back. Persisted
 *   under "questionMemory2.<profileId>" as the same {topic: {fp: time}} JSON
 *   iOS stores, and shared with the child's other devices ([QuestionMemoryCloud]).
 * • In-session: nothing is served twice in one session (the runner's deliberate
 *   re-ask of a wrong answer goes through [allowReask]).
 *
 * Also owns the 📖 reading-passage recency (ReadingContent.recentIDs/markUsed),
 * which iOS keeps per profile too ("reading.recentPassageIDs.<profileId>").
 */
class QuestionMemory(
    private val prefs: ContentPrefs,
    val profileId: String?,
    private val cloud: QuestionMemoryCloud? = null,
    private val clock: () -> Double = { System.currentTimeMillis() / 1000.0 },
) {
    private val storageKey = "questionMemory2.${profileId ?: "default"}"
    /** The old memory: a recent list per topic, oldest first. Migrated once. */
    private val legacyKey = "questionMemory.${profileId ?: "default"}"
    private val readingKey = "reading.recentPassageIDs" + (profileId?.let { ".$it" } ?: "")

    /** topic → fingerprint → when it was last asked. */
    private var seen: MutableMap<String, MutableMap<String, Double>> = mutableMapOf()
    private var loaded = false
    private val sessionServed = HashSet<String>()

    @Synchronized fun beginSession() {
        sessionServed.clear()
        pull()
    }
    @Synchronized fun markServedThisSession(key: String) { sessionServed.add(key) }
    @Synchronized fun wasServedThisSession(key: String) = sessionServed.contains(key)
    /** Allow a wrong question to come back (the runner re-asks it). */
    @Synchronized fun allowReask(key: String) { sessionServed.remove(key) }

    /** Fetch what the child's other devices asked (on a session start and a child switch). */
    fun pull() {
        val child = profileId ?: return
        cloud?.pull(child) { remote -> merge(remote) }
    }

    /**
     * Difficulty-aware pick: an UNSEEN question first — at `target`, then its
     * neighbours — and only when the whole world has been asked, the one asked
     * longest ago.
     */
    @Synchronized
    fun pickFresh(pool: List<BankQuestion>, topic: Topic, target: Difficulty, rng: Random): BankQuestion? {
        val order = when (target) {
            Difficulty.EASY -> listOf(Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD)
            Difficulty.MEDIUM -> listOf(Difficulty.MEDIUM, Difficulty.EASY, Difficulty.HARD)
            Difficulty.HARD -> listOf(Difficulty.HARD, Difficulty.MEDIUM, Difficulty.EASY)
        }
        ensureLoaded()
        for (tier in order) {
            pickUnseen(pool.filter { it.difficulty == tier }, topic, rng)?.let { report(pool, topic); return it }
        }
        return pickFresh(pool, topic, rng)
    }

    /**
     * An unseen question from `pool` if there is one, otherwise the one asked
     * longest ago (still never one already shown this session, unless the
     * whole pool was). Ties go at random.
     */
    @Synchronized
    fun pickFresh(pool: List<BankQuestion>, topic: Topic, rng: Random): BankQuestion? {
        ensureLoaded()
        if (pool.isEmpty()) return null
        val chosen = pickUnseen(pool, topic, rng) ?: run {
            val memory = seen[topic.raw] ?: emptyMap<String, Double>()
            val notInSession = pool.filter { it.key !in sessionServed }
            val candidates = notInSession.ifEmpty { pool }
            val oldest = candidates.minOf { memory[fingerprint(it.key)] ?: 0.0 }
            candidates.filter { (memory[fingerprint(it.key)] ?: 0.0) == oldest }.random(rng).also { remember(it, topic) }
        }
        report(pool, topic)
        return chosen
    }

    private fun pickUnseen(pool: List<BankQuestion>, topic: Topic, rng: Random): BankQuestion? {
        val memory = seen[topic.raw] ?: emptyMap<String, Double>()
        val unseen = pool.filter { it.key !in sessionServed && fingerprint(it.key) !in memory }
        if (unseen.isEmpty()) return null
        return unseen.random(rng).also { remember(it, topic) }
    }

    /** How many of `pool` this child has already been asked — for the "running out of questions" alert. */
    @Synchronized
    fun seenCount(pool: List<BankQuestion>, topic: Topic): Int {
        ensureLoaded()
        val memory = seen[topic.raw] ?: return 0
        return pool.count { fingerprint(it.key) in memory }
    }

    /** When this question was last asked (seconds since 1970), or null — tests / diagnostics. */
    @Synchronized
    fun askedAt(q: BankQuestion, topic: Topic): Double? { ensureLoaded(); return seen[topic.raw]?.get(fingerprint(q.key)) }

    /** 📊 How much of this world the child has used up — the founder dashboard warns before a child runs out. */
    private fun report(pool: List<BankQuestion>, topic: Topic) {
        val child = profileId ?: return
        if (pool.isEmpty() || cloud == null) return
        cloud.coverage(child, topic.raw, seenCount(pool, topic), pool.size, clock())
    }

    /** Wipe this profile's memory (remote reset). */
    @Synchronized
    fun clear() {
        seen = mutableMapOf()
        loaded = true
        prefs.putString(storageKey, null)
        prefs.putString(legacyKey, null)
    }

    private fun remember(q: BankQuestion, topic: Topic) {
        sessionServed.add(q.key)
        val fp = fingerprint(q.key)
        val now = clock()
        val memory = seen.getOrPut(topic.raw) { mutableMapOf() }
        memory[fp] = now
        trim(memory)
        save()
        profileId?.let { cloud?.push(it, topic.raw, fp, now) }
    }

    /** A world never holds more than [MAX_PER_TOPIC] remembered questions — the oldest go. */
    private fun trim(memory: MutableMap<String, Double>) {
        if (memory.size <= MAX_PER_TOPIC) return
        memory.entries.sortedBy { it.value }.take(memory.size - MAX_PER_TOPIC).map { it.key }.forEach { memory.remove(it) }
    }

    /** Folds in what the child's other devices asked: the later time wins. */
    @Synchronized
    fun merge(remote: Map<String, Map<String, Double>>) {
        ensureLoaded()
        var changed = false
        for ((topic, entries) in remote) {
            val memory = seen.getOrPut(topic) { mutableMapOf() }
            for ((fp, at) in entries) if (at > (memory[fp] ?: 0.0)) { memory[fp] = at; changed = true }
            trim(memory)
        }
        if (changed) save()
    }

    // MARK: - Persistence (per profile)

    private fun ensureLoaded() {
        if (loaded) return
        loaded = true
        val stored = runCatching {
            prefs.getString(storageKey)?.let { contentJson.decodeFromString<Map<String, Map<String, Double>>>(it) }
        }.getOrNull()
        if (stored != null) {
            seen = stored.mapValues { it.value.toMutableMap() }.toMutableMap()
            return
        }
        seen = mutableMapOf()
        // The old memory (a list of recent prompts per topic, oldest first)
        // becomes timestamps in the same order, so nothing seen is forgotten.
        val old = runCatching {
            prefs.getString(legacyKey)?.let { contentJson.decodeFromString<Map<String, List<String>>>(it) }
        }.getOrNull() ?: return
        val now = clock()
        for ((topic, list) in old) {
            seen[topic] = list.mapIndexed { i, key -> fingerprint(key) to now - (list.size - i) }.toMap().toMutableMap()
        }
        save()
    }

    private fun save() {
        prefs.putString(storageKey, contentJson.encodeToString<Map<String, Map<String, Double>>>(seen))
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
        /** A world never holds more than this many remembered questions. */
        const val MAX_PER_TOPIC = 4000

        /** Every pick looks at the whole pool — hash each question once per launch. */
        private val fingerprints = ConcurrentHashMap<String, String>()

        /**
         * The first 12 hex digits of SHA-256 over the UTF-8 of "prompt|answer" —
         * short enough to keep thousands per child, and the same on iOS.
         */
        fun fingerprint(key: String): String = fingerprints.getOrPut(key) {
            MessageDigest.getInstance("SHA-256").digest(key.toByteArray(Charsets.UTF_8))
                .take(6).joinToString("") { "%02x".format(it.toInt() and 0xff) }
        }
    }
}

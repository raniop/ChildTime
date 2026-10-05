package com.rani.tofy.kid.content

import android.content.Context
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import java.io.File

/**
 * ☁️ RemoteQuestionBank.swift — approved questions that live in Firestore and
 * reach children without an app release. Built-ins stay the offline seed; this
 * only ever ADDS on top (QuestionBanks.assemble).
 *
 * One small read per sync: `questionBankIndex/current.topics` holds a version per
 * topic, and `questionBanks/{topic}` is fetched only when its version moved.
 * Cached to `remoteQuestionBank.json` so it works fully offline after one sync.
 */
object RemoteQuestionBank {
    @Serializable
    private data class Cache(
        val versions: MutableMap<String, Int> = mutableMapOf(),
        val items: MutableMap<String, List<BankItem>> = mutableMapOf(),
    )

    private val lock = Any()
    private var cache = Cache()
    private var syncing = false
    private var lastSyncAt: Long? = null
    private var file: File? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    /** 10-minute quiet period after a sync that actually reached the server. */
    const val THROTTLE_MS = 10 * 60 * 1000L

    fun init(context: Context) {
        val f = File(context.applicationContext.filesDir, "remoteQuestionBank.json")
        file = f
        runCatching {
            if (f.exists()) {
                val decoded = contentJson.decodeFromString<Cache>(f.readText())
                synchronized(lock) { cache = decoded }
                ContentCache.invalidate()
            }
        }
    }

    // MARK: - Wire format (RemoteQuestionBank.Item)

    /**
     * Item.init?(_ d:) — a row of `questionBanks/{topic}.items`. Nil when a
     * required field is missing or the item isn't approved (drafts wait in the
     * admin). Numbers may arrive as Long or Double.
     */
    fun itemFrom(d: Map<String, Any?>, topic: String): BankItem? {
        val id = d["id"] as? String ?: return null
        val prompt = d["prompt"] as? String ?: return null
        val answer = d["correctAnswer"] as? String ?: return null
        val distractors = (d["distractors"] as? List<*>)?.let { l -> l.map { it as? String ?: return null } } ?: return null
        val lo = (d["gradeLo"] as? Number)?.toInt() ?: return null
        val hi = (d["gradeHi"] as? Number)?.toInt() ?: return null
        if (((d["status"] as? String) ?: "approved") != "approved") return null
        return BankItem(id = id, prompt = prompt, correctAnswer = answer, distractors = distractors,
            tier = d["tier"] as? String, gradeLo = lo, gradeHi = hi, lang = d["lang"] as? String,
            topic = topic, skill = d["skill"] as? String)
    }

    /**
     * Item.isPlayable — the server validates on import, but a malformed item
     * must never become a question with its answer among the wrong options.
     */
    fun isPlayable(i: BankItem): Boolean {
        val p = i.prompt.trim()
        val a = i.correctAnswer.trim()
        val ds = i.distractors.map { it.trim() }
        return p.isNotEmpty() && a.isNotEmpty() &&
            ds.size >= 3 && !ds.contains(a) && ds.toSet().size == ds.size &&
            i.gradeLo in 0..8 && i.gradeHi in 0..8 && i.gradeLo <= i.gradeHi
    }

    /** Item.bankQuestion — first 3 distractors; a missing tier falls back like BankQuestion.difficulty. */
    fun toBankQuestion(i: BankItem): BankQuestion = BankQuestion(
        prompt = i.prompt, correctAnswer = i.correctAnswer, distractors = i.distractors.take(3),
        difficulty = Difficulty.of(i.tier) ?: ContentAssets.tierIndex()["${i.prompt}|${i.correctAnswer}"] ?: Difficulty.MEDIUM,
        gradeLo = i.gradeLo, gradeHi = i.gradeHi, skill = i.skill,
    )

    /** Approved, playable cloud questions for a topic in one language (nil lang = Hebrew). */
    fun questions(topic: Topic, lang: AppLanguage): List<BankQuestion> {
        val items = synchronized(lock) { cache.items[topic.raw] ?: emptyList() }
        return items.filter { isPlayable(it) && (it.lang ?: AppLanguage.HE.code) == lang.code }.map(::toBankQuestion)
    }

    /** How many cloud items each topic holds — diagnostics. */
    val countsByTopic: Map<String, Int> get() = synchronized(lock) { cache.items.mapValues { it.value.size } }

    /** Test seam: replace the cache without Firestore. */
    fun replaceForTest(items: Map<String, List<BankItem>>) {
        synchronized(lock) { cache = Cache(items = items.toMutableMap()) }
        ContentCache.invalidate()
    }

    // MARK: - Sync

    /** Pull any topic whose version moved. Throttled; safe on every foreground. */
    fun syncIfNeeded(force: Boolean = false) {
        synchronized(lock) {
            val recent = lastSyncAt?.let { System.currentTimeMillis() - it < THROTTLE_MS } ?: false
            if (syncing || (!force && recent)) return
            syncing = true
        }
        scope.launch { sync() }
    }

    private suspend fun sync() {
        var reached = false
        try {
            val db = FirebaseFirestore.getInstance()
            val index = runCatching { db.collection("questionBankIndex").document("current").get().await() }.getOrNull() ?: return
            @Suppress("UNCHECKED_CAST")
            val topics = index.get("topics") as? Map<String, Any?> ?: return
            reached = true
            var changed = false
            for ((raw, value) in topics) {
                val version = (value as? Number)?.toInt() ?: 0
                val have = synchronized(lock) { cache.versions[raw] ?: 0 }
                if (version <= have) continue
                val doc = runCatching { db.collection("questionBanks").document(raw).get().await() }.getOrNull() ?: continue
                val rows = doc.get("items") as? List<*> ?: continue
                @Suppress("UNCHECKED_CAST")
                val items = rows.mapNotNull { (it as? Map<String, Any?>)?.let { m -> itemFrom(m, raw) } }
                synchronized(lock) {
                    cache.items[raw] = items
                    cache.versions[raw] = version
                }
                changed = true
            }
            // New cloud questions must reach the child without a relaunch.
            if (changed) { ContentCache.invalidate(); saveToDisk() }
        } finally {
            // Only a sync that reached the server starts the quiet period — a denied
            // read before sign-in must retry as soon as the device signs in.
            synchronized(lock) { syncing = false; if (reached) lastSyncAt = System.currentTimeMillis() }
        }
    }

    private fun saveToDisk() {
        val f = file ?: return
        val snapshot = synchronized(lock) { Cache(cache.versions.toMutableMap(), cache.items.toMutableMap()) }
        runCatching {
            val tmp = File(f.parentFile, f.name + ".tmp")
            tmp.writeText(contentJson.encodeToString(snapshot))
            tmp.renameTo(f)
        }
    }
}

package com.rani.tofy.data

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/**
 * ❌ One wrong pick: q = the question as the child heard/saw it, a = what they
 * chose, c = the right answer (all without niqqud), at = unix seconds.
 */
@Serializable
data class Mistake(val q: String, val a: String, val c: String, val at: Double)

/*
 * ❌ Which questions the child got wrong — not only how many (Sasha,
 * 2026-10-24: "יש רק כמות פעמים שהיא טועה, אבל אנחנו לא יודעים מה צריך לתרגל
 * איתה"). The twin of iOS Models/MistakeLog.swift, same data:
 *
 *   children/{id}/memory/mistakes   m: { <topic>: [ { q, a, c, at }, … ] }  — newest last, ≤ 30 per topic
 *
 * The child's device records (the first wrong try of a question only) and
 * pushes the whole topic list; the parent's phone fetches it and merges in
 * whatever it recorded itself (a child playing in Kid Mode on it). A local
 * copy lives in SharedPreferences under "mistakes.<childId>". Family-only,
 * like every other progress record (children/{id}/{sub=**}).
 */
object MistakeLog {
    const val PER_TOPIC = 30
    private val json = Json { ignoreUnknownKeys = true }
    private var app: Context? = null

    fun init(context: Context) { app = context.applicationContext }

    // ── pure (MistakeLogTest) ────────────────────────────────────────────────

    /** "spoken · prompt" — both when they differ, niqqud stripped (iOS MistakeLog.record). */
    fun questionText(spoken: String?, prompt: String): String =
        strip(listOfNotNull(spoken, prompt).filter { it.isNotEmpty() }.distinct().joinToString(" · "))

    fun strip(s: String): String = s.filterNot { it.code in 0x0591..0x05C7 }

    /** One more miss at the end (newest last), the oldest dropped past [PER_TOPIC]. */
    fun appended(list: List<Mistake>, m: Mistake): List<Mistake> = (list + m).takeLast(PER_TOPIC)

    /** The parent's view: both copies, no duplicates, newest first, ≤ [PER_TOPIC] per topic. */
    fun merged(local: Map<String, List<Mistake>>, cloud: Map<String, List<Mistake>>): Map<String, List<Mistake>> =
        (local.keys + cloud.keys).associateWith { t ->
            ((local[t] ?: emptyList()) + (cloud[t] ?: emptyList())).distinct().sortedByDescending { it.at }.take(PER_TOPIC)
        }

    /** The Firestore `m` map → per-topic lists (rows missing q/a/c are skipped). */
    fun fromFirestore(m: Any?): Map<String, List<Mistake>> {
        val map = m as? Map<*, *> ?: return emptyMap()
        return map.entries.mapNotNull { (k, v) ->
            val topic = k as? String ?: return@mapNotNull null
            val rows = (v as? List<*>)?.mapNotNull { r ->
                val d = r as? Map<*, *> ?: return@mapNotNull null
                val q = d["q"] as? String ?: return@mapNotNull null
                val a = d["a"] as? String ?: return@mapNotNull null
                val c = d["c"] as? String ?: return@mapNotNull null
                Mistake(q, a, c, (d["at"] as? Number)?.toDouble() ?: 0.0)
            } ?: return@mapNotNull null
            topic to rows
        }.toMap()
    }

    fun rows(list: List<Mistake>): List<Map<String, Any>> = list.map { mapOf("q" to it.q, "a" to it.a, "c" to it.c, "at" to it.at) }

    fun encode(v: Map<String, List<Mistake>>): String = json.encodeToString(v)
    fun decode(s: String?): Map<String, List<Mistake>> =
        s?.let { runCatching { json.decodeFromString<Map<String, List<Mistake>>>(it) }.getOrNull() } ?: emptyMap()

    // ── child device ─────────────────────────────────────────────────────────

    /** One wrong pick of [topic] by [childID]: kept here, and the topic's whole list sent to the family. */
    fun record(childID: String, topic: String, question: String, chosen: String, correct: String) {
        val m = Mistake(question, strip(chosen), strip(correct), nowSecs())
        val all = load(childID).toMutableMap()
        val list = appended(all[topic] ?: emptyList(), m)
        all[topic] = list
        save(childID, all)
        if (FirebaseAuth.getInstance().currentUser == null) return
        // Field-by-field merge keeps the other topics; a second device of the same
        // child overwrites this topic with its own list — fine for "the latest misses".
        runCatching { doc(childID).set(mapOf("m" to mapOf(topic to rows(list))), SetOptions.merge()) }
    }

    // ── parent device ────────────────────────────────────────────────────────

    /** The child's recent misses per topic, newest first: the cloud copy plus this device's own. */
    suspend fun fetch(childID: String): Map<String, List<Mistake>> {
        val cloud = runCatching { fromFirestore(doc(childID).get().await().get("m")) }.getOrDefault(emptyMap())
        return merged(load(childID), cloud)
    }

    private fun doc(childID: String) =
        FirebaseFirestore.getInstance().collection("children").document(childID).collection("memory").document("mistakes")

    private fun prefs() = app?.getSharedPreferences("tofy", Context.MODE_PRIVATE)
    private fun load(childID: String) = decode(prefs()?.getString("mistakes.$childID", null))
    private fun save(childID: String, v: Map<String, List<Mistake>>) {
        prefs()?.edit()?.putString("mistakes.$childID", encode(v))?.apply()
    }
}

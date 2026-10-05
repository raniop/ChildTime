package com.rani.tofy.kid.ui.play

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

/**
 * The recording half of LearningHistoryStore.swift: per-child daily learning
 * aggregates kept locally and mirrored (merge) to
 * `children/{childID}/dailyStats/{yyyy-MM-dd}` — the parent's report reads
 * these (accuracy per topic / skill, learning time, sessions, voluntary answers).
 * Field names = DailyStat's Swift property names; `perSkill` omitted when nil.
 */
@Serializable
data class SkillDay(var answered: Int = 0, var correct: Int = 0)

@Serializable
data class TopicDay(var answered: Int = 0, var correct: Int = 0, var responseMsTotal: Double = 0.0, var perSkill: MutableMap<String, SkillDay>? = null)

@Serializable
data class DailyStat(
    var date: String,
    var questionsAnswered: Int = 0,
    var correct: Int = 0,
    var wrong: Int = 0,
    var minutesEarned: Int = 0,
    var minutesUsed: Int = 0,
    var longestStreak: Int = 0,
    var learningSeconds: Int = 0,
    var sessions: Int = 0,
    var earnSessions: Int = 0,
    var freeSessions: Int = 0,
    var voluntaryAnswers: Int = 0,
    var perTopic: MutableMap<String, TopicDay> = mutableMapOf(),
) {
    fun toFirestore(): Map<String, Any> = mapOf(
        "date" to date, "questionsAnswered" to questionsAnswered, "correct" to correct, "wrong" to wrong,
        "minutesEarned" to minutesEarned, "minutesUsed" to minutesUsed, "longestStreak" to longestStreak,
        "learningSeconds" to learningSeconds, "sessions" to sessions, "earnSessions" to earnSessions,
        "freeSessions" to freeSessions, "voluntaryAnswers" to voluntaryAnswers,
        "perTopic" to perTopic.mapValues { (_, t) ->
            buildMap<String, Any> {
                put("answered", t.answered); put("correct", t.correct); put("responseMsTotal", t.responseMsTotal)
                t.perSkill?.let { m -> put("perSkill", m.mapValues { (_, s) -> mapOf("answered" to s.answered, "correct" to s.correct) }) }
            }
        },
    )
}

object LearningHistoryRecorder {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true; explicitNulls = false }
    private const val RETENTION_DAYS = 120
    private var app: Context? = null

    fun init(context: Context) { app = context.applicationContext }

    private fun prefs() = app?.getSharedPreferences("tofy.kid.history", Context.MODE_PRIVATE)
    private fun key(childID: String) = "learningHistory.$childID"
    private fun dayKey(): String = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)

    private fun load(childID: String): MutableMap<String, DailyStat> =
        prefs()?.getString(key(childID), null)?.let { runCatching { json.decodeFromString<MutableMap<String, DailyStat>>(it) }.getOrNull() }
            ?: mutableMapOf()

    private fun mutateToday(childID: String, transform: (DailyStat) -> Unit) {
        val days = load(childID)
        val k = dayKey()
        val stat = days[k] ?: DailyStat(k)
        transform(stat)
        days[k] = stat
        val kept = if (days.size > RETENTION_DAYS) days.keys.sorted().takeLast(RETENTION_DAYS).associateWith { days[it]!! } else days
        prefs()?.edit()?.putString(key(childID), json.encodeToString(kept.toMutableMap()))?.apply()
        if (FirebaseAuth.getInstance().currentUser == null) return
        FirebaseFirestore.getInstance().collection("children").document(childID)
            .collection("dailyStats").document(stat.date).set(stat.toFirestore(), SetOptions.merge())
    }

    /** Every runner session is an Earn-to-Unlock one (see RunnerController). */
    fun recordSessionStart(childID: String, earn: Boolean = true) = mutateToday(childID) {
        it.sessions += 1
        if (earn) it.earnSessions += 1 else it.freeSessions += 1
    }

    fun recordAnswer(childID: String, topic: String, correct: Boolean, responseMs: Double, earnedMinutes: Int,
                     streak: Int, voluntary: Boolean = false, skill: String? = null) = mutateToday(childID) { s ->
        s.questionsAnswered += 1
        if (correct) s.correct += 1 else s.wrong += 1
        if (voluntary) s.voluntaryAnswers += 1
        s.minutesEarned += maxOf(0, earnedMinutes)
        s.longestStreak = maxOf(s.longestStreak, streak)
        s.learningSeconds += (responseMs / 1000).roundToInt()
        val t = s.perTopic[topic] ?: TopicDay()
        t.answered += 1
        if (correct) t.correct += 1
        t.responseMsTotal += responseMs
        if (skill != null) {
            val map = t.perSkill ?: mutableMapOf()
            val sk = map[skill] ?: SkillDay()
            sk.answered += 1
            if (correct) sk.correct += 1
            map[skill] = sk
            t.perSkill = map
        }
        s.perTopic[topic] = t
    }
}

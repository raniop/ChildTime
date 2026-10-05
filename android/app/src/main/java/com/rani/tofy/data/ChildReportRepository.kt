package com.rani.tofy.data

import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.tasks.await

/** LearningHistoryStore.swift DailyStat — children/{id}/dailyStats/{YYYY-MM-DD}. */
data class DailyStat(
    val date: String,
    val questionsAnswered: Int,
    val correct: Int,
    val wrong: Int,
    val minutesEarned: Int,
    val minutesUsed: Int,
    val longestStreak: Int,
    val learningSeconds: Int,
    val sessions: Int,
    val earnSessions: Int,
    val freeSessions: Int,
    val voluntaryAnswers: Int,
    val perTopic: Map<String, TopicDay>,
) {
    data class TopicDay(val answered: Int, val correct: Int, val perSkill: Map<String, SkillDay>?)
    data class SkillDay(val answered: Int, val correct: Int)

    companion object {
        fun from(id: String, d: Doc): DailyStat {
            fun i(k: String) = d.int(k) ?: 0
            val topics = d.map("perTopic")?.mapNotNull { (k, v) ->
                @Suppress("UNCHECKED_CAST") val t = v as? Map<String, Any?> ?: return@mapNotNull null
                val skills = t.map("perSkill")?.mapNotNull { (sk, sv) ->
                    @Suppress("UNCHECKED_CAST") val s = sv as? Map<String, Any?> ?: return@mapNotNull null
                    sk to SkillDay(s.int("answered") ?: 0, s.int("correct") ?: 0)
                }?.toMap()
                k to TopicDay(t.int("answered") ?: 0, t.int("correct") ?: 0, skills)
            }?.toMap() ?: emptyMap()
            return DailyStat(
                date = d.str("date") ?: id,
                questionsAnswered = i("questionsAnswered"), correct = i("correct"), wrong = i("wrong"),
                minutesEarned = i("minutesEarned"), minutesUsed = i("minutesUsed"), longestStreak = i("longestStreak"),
                learningSeconds = i("learningSeconds"), sessions = i("sessions"), earnSessions = i("earnSessions"),
                freeSessions = i("freeSessions"), voluntaryAnswers = i("voluntaryAnswers"), perTopic = topics,
            )
        }
    }
}

/** A public leaderboard card (FriendsManager.swift FriendCard) — the fields the parent's list shows. */
data class FriendCardLite(val id: String, val name: String, val character3DID: String?, val stars: Int) {
    /** FriendCard.displayName: first word only — a surname never leaves the family. */
    val displayName: String get() = name.trim().split(Regex("\\s+")).firstOrNull().orEmpty()
}

/**
 * The per-child report's data that FamilyRepository doesn't keep: the daily
 * history (LearningHistoryStore.fetchRemoteHistory — a one-shot read, cached
 * for the session like iOS's local copy), the snapshot fields the report's
 * engines read (topicAdaptiveLevel / topicAffinity / topicExposure), and the
 * child's friends (ChildFriendsView).
 */
object ChildReportRepository {
    private val db get() = FirebaseFirestore.getInstance()

    private val _history = MutableStateFlow<Map<String, List<DailyStat>>>(emptyMap())
    val history: StateFlow<Map<String, List<DailyStat>>> = _history

    /** Pull every dailyStats doc. Returns false on a read error (the cached copy stays). */
    suspend fun refreshHistory(childID: String): Boolean = runCatching {
        val docs = db.collection("children").document(childID).collection("dailyStats").get().await().documents
        val stats = docs.mapNotNull { d -> d.data?.let { DailyStat.from(d.id, it) } }.sortedBy { it.date }
        _history.update { it + (childID to stats) }
        true
    }.getOrDefault(false)

    /** Live raw state/current — the snapshot maps Progress doesn't model. */
    fun stateDoc(childID: String): Flow<Doc> = callbackFlow {
        val reg = db.collection("children").document(childID).collection("state").document("current")
            .addSnapshotListener { s, _ -> trySend(s?.data ?: emptyMap()) }
        awaitClose { reg.remove() }
    }

    /** FriendsManager.friends(ofChild:): my card's friendIDs − hiddenIDs, plus every card that added me. */
    suspend fun friends(childID: String): List<FriendCardLite>? = runCatching {
        val ids = mutableSetOf<String>()
        db.collection("friendCards").document(childID).get().await().data?.let { d ->
            ids += d.strList("friendIDs").orEmpty()
            ids -= d.strList("hiddenIDs").orEmpty().toSet()
        }
        runCatching {
            db.collection("friendCards").whereArrayContains("friendIDs", childID).get().await().documents.forEach { ids += it.id }
        }
        ids -= childID
        ids.mapNotNull { fid ->
            runCatching { db.collection("friendCards").document(fid).get().await().data }.getOrNull()?.let { d ->
                FriendCardLite(fid, d.str("name") ?: "", d.str("character3DID"), d.int("stars") ?: 0)
            }
        }.sortedByDescending { it.stars }
    }.getOrNull()

    /** FriendsManager.removeFriend(_:forChild:) — confirmed, with the membership self-heal. */
    suspend fun removeFriend(childID: String, friendID: String): WriteOutcome {
        val ref = db.collection("friendCards").document(childID)
        val f = mapOf("friendIDs" to FieldValue.arrayRemove(friendID), "hiddenIDs" to FieldValue.arrayUnion(friendID))
        var out = confirmedMerge(ref, f)
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(ref, f) }
        return out
    }

    /** Commands.removeDevice / purgeCaches + the DENIED → reassert → retry rule. */
    suspend fun withRetry(op: suspend () -> WriteOutcome): WriteOutcome {
        var out = op()
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = op() }
        return out
    }
}

package com.rani.tofy.kid.ui.play

import android.content.Context
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.data.Household
import com.rani.tofy.data.nowSecs
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.tasks.await

/** The parent's answer: the option to remove from the child's screen + the one they kept. */
data class HelpReply(val removed: String, val kept: String)

/**
 * The CHILD side of ParentHelpManager (ChildTime/Models/ParentHelp.swift):
 * create `helpRequests/{id}` with the iOS fields, listen for the parent's
 * keptOption/removedOption, expire it when the kid moves on. The parent side
 * (and the push) already exist: data/HelpRepository.kt + the Cloud Function.
 */
object HelpRequestSender {
    /** ParentHelpManager.cooldown — a help request pushes a parent's phone. */
    const val COOLDOWN_SECS = 120.0

    private val db get() = FirebaseFirestore.getInstance()
    private var listener: ListenerRegistration? = null
    private var activeRequestID: String? = null
    private var app: Context? = null

    private val _lastReply = MutableStateFlow<HelpReply?>(null)
    val lastReply: StateFlow<HelpReply?> = _lastReply
    private val _activeQuestion = MutableStateFlow<String?>(null)
    /** The prompt of the open request (a reply for THIS question vs one that arrived late). */
    val activeQuestion: StateFlow<String?> = _activeQuestion
    val hasActiveRequest: Boolean get() = activeRequestID != null

    fun init(context: Context) { app = context.applicationContext }

    private fun prefs() = app?.getSharedPreferences("tofy.kid.help", Context.MODE_PRIVATE)
    private fun lastKey(childID: String) = "parentHelp.lastRequestAt.$childID"

    fun cooldownRemaining(childID: String): Double {
        val last = (prefs()?.getLong(lastKey(childID), 0L) ?: 0L) / 1000.0
        return maxOf(0.0, last + COOLDOWN_SECS - nowSecs())
    }

    // households/{hid} is readable by a joined play device (it's in parentUIDs).
    private var cachedHousehold: Household? = null

    suspend fun household(hid: String): Household? {
        cachedHousehold?.takeIf { it.id == hid }?.let { return it }
        val d = runCatching { db.collection("households").document(hid).get().await().data }.getOrNull() ?: return null
        return Household.from(hid, d).also { cachedHousehold = it }
    }

    /** HouseholdManager.linkedParents — every named parent, sorted by name. */
    fun linkedParents(h: Household?): List<Pair<String, String>> =
        h?.parentNames?.filter { it.value.isNotEmpty() }?.map { it.key to it.value }?.sortedBy { it.second } ?: emptyList()

    /** Create a request; the correct answer lands in a random slot so a parent can't always tap the same button. */
    fun requestHelp(childID: String, childName: String, parentUID: String, householdID: String, topic: String,
                    question: String, correctAnswer: String, distractor: String, gender: String) {
        expireActiveRequest()
        val correctFirst = kotlin.random.Random.nextBoolean()
        val ref = db.collection("helpRequests").document()
        val data = hashMapOf<String, Any>(
            "childID" to childID,
            "childName" to childName,
            "parentUID" to parentUID,
            "householdID" to householdID,
            "topic" to topic,
            "question" to question,
            "optionA" to if (correctFirst) correctAnswer else distractor,
            "optionB" to if (correctFirst) distractor else correctAnswer,
            "correctAnswer" to correctAnswer,
            "fromUID" to (FirebaseAuth.getInstance().currentUser?.uid ?: ""),
            "gender" to gender,
            "status" to "pending",
            "createdAt" to nowSecs(),
        )
        ref.set(data)
        prefs()?.edit()?.putLong(lastKey(childID), System.currentTimeMillis())?.apply()
        activeRequestID = ref.id
        _activeQuestion.value = question
        _lastReply.value = null
        listenForReply(ref.id)
    }

    private fun listenForReply(id: String) {
        listener?.remove()
        listener = db.collection("helpRequests").document(id).addSnapshotListener { snap, _ ->
            val d = snap?.data ?: return@addSnapshotListener
            val kept = d["keptOption"] as? String ?: return@addSnapshotListener
            val removed = d["removedOption"] as? String ?: return@addSnapshotListener
            _lastReply.value = HelpReply(removed, kept)
            stopListening()
        }
    }

    /** The reply was used (or dropped) — clear it so it isn't applied twice. */
    fun consumeReply() { _lastReply.value = null }

    fun stopListening() {
        listener?.remove(); listener = null
        activeRequestID = null
    }

    /** The kid moved on while the request was open: close it so it leaves the parent's banner. */
    fun expireActiveRequest() {
        val id = activeRequestID ?: return
        db.collection("helpRequests").document(id)
            .set(mapOf("status" to "expired", "expiredAt" to nowSecs()), SetOptions.merge())
        stopListening()
        _activeQuestion.value = null
    }
}

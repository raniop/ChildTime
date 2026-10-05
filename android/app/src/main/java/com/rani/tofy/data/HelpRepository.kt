package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** helpRequests/{id} — HelpRequest in ParentHelp.swift (the fields the parent reads). */
data class HelpRequest(
    val id: String,
    val childID: String,
    val childName: String,
    val parentUID: String,
    val householdID: String,
    val topic: String,
    val question: String,
    val optionA: String,
    val optionB: String,
    val correctAnswer: String,
    val fromUID: String,
    val gender: String,
    val createdAt: Double,
) {
    val isGirl: Boolean get() = gender == "girl"

    companion object {
        fun from(id: String, d: Doc): HelpRequest? {
            val q = d.str("question") ?: return null
            val a = d.str("optionA") ?: return null
            val b = d.str("optionB") ?: return null
            return HelpRequest(
                id = id, childID = d.str("childID") ?: "", childName = d.str("childName") ?: tr("הילד"),
                parentUID = d.str("parentUID") ?: "", householdID = d.str("householdID") ?: "",
                topic = d.str("topic") ?: "", question = q, optionA = a, optionB = b,
                correctAnswer = d.str("correctAnswer") ?: "", fromUID = d.str("fromUID") ?: "",
                gender = d.str("gender") ?: "", createdAt = d.secs("createdAt") ?: 0.0,
            )
        }
    }
}

/**
 * ParentHelpManager.swift, parent side: the household's open help requests
 * addressed to me (or to "all" parents), the answer write-back and "לא עכשיו".
 */
object HelpRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val me get() = FirebaseAuth.getInstance().currentUser?.uid ?: ""

    private val _pending = MutableStateFlow<List<HelpRequest>>(emptyList())
    val pending: StateFlow<List<HelpRequest>> = _pending
    /** The request whose answer sheet is open (a banner tap). */
    val prompted = MutableStateFlow<HelpRequest?>(null)

    private var started = false
    private var listening: String? = null
    private var reg: ListenerRegistration? = null

    fun start() {
        if (started) return
        started = true
        scope.launch { FamilyRepository.state.map { it.household?.id }.distinctUntilChanged().collect { bind(it) } }
    }

    private fun bind(hid: String?) {
        if (hid == listening) return
        reg?.remove(); reg = null
        listening = hid
        _pending.value = emptyList()
        hid ?: return
        reg = db.collection("helpRequests").whereEqualTo("householdID", hid).whereEqualTo("status", "pending")
            .addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                val uid = me
                val cutoff = nowSecs() - 2 * 3600   // an old request is stale — the kid moved on
                val mine = snap.documents.mapNotNull { d -> d.data?.let { HelpRequest.from(d.id, it) } }
                    .filter { (it.parentUID == uid || it.parentUID == "all") && it.fromUID != uid && it.createdAt > cutoff }
                    .sortedByDescending { it.createdAt }
                _pending.value = mine
                // The open sheet closes itself once its request is gone.
                prompted.value?.let { p -> if (mine.none { it.id == p.id }) prompted.value = null }
            }
    }

    /** The parent kept `kept`; the other option leaves the child's screen. */
    suspend fun answer(req: HelpRequest, kept: String, removed: String): Boolean {
        if (kept.isEmpty() || removed.isEmpty()) return false
        val ref = db.collection("helpRequests").document(req.id)
        val fields = mapOf(
            "keptOption" to kept, "removedOption" to removed, "status" to "answered",
            "respondedByUID" to me, "respondedAt" to nowSecs(),
        )
        var out = confirmedMerge(ref, fields)
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(ref, fields) }
        if (out == WriteOutcome.DENIED || out == WriteOutcome.ERROR) return false
        _pending.update { l -> l.filterNot { it.id == req.id } }
        return true
    }

    /** "לא עכשיו" — hide the request on every parent device without answering. */
    fun dismiss(req: HelpRequest) {
        _pending.update { l -> l.filterNot { it.id == req.id } }
        if (prompted.value?.id == req.id) prompted.value = null
        scope.launch {
            val ref = db.collection("helpRequests").document(req.id)
            val fields = mapOf("status" to "dismissed", "dismissedAt" to nowSecs())
            if (confirmedMerge(ref, fields) == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); confirmedMerge(ref, fields) }
        }
    }
}

package com.rani.tofy.data

import com.google.android.gms.tasks.Task
import com.google.firebase.firestore.Blob
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
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
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Calendar
import kotlin.coroutines.resume

/**
 * 🧹 households/{hid}/chores/{id} — mirrors `Chore` in ChoreStore.swift. Field
 * names, types and defaults are the iOS ones; the proof photo is the raw JPEG
 * bytes iOS stores as `Data` (a Firestore Blob).
 */
data class Chore(
    val id: String,
    val childID: String,
    val title: String,
    val emoji: String,
    val rewardMinutes: Int,
    val rewardCoins: Int,
    val isDaily: Boolean,
    val timesPerDay: Int,
    val createdAt: Double,
    val markedDoneAt: Double?,
    val chosenReward: String?,
    val lastApprovedAt: Double?,
    val photo: ByteArray?,
    val photoToken: String?,
    val approvedTodayCount: Int,
    val approvedTodayAt: Double?,
    val archived: Boolean,
) {
    val isPendingApproval: Boolean get() = markedDoneAt != null
    /** Approvals that landed TODAY (0 when the counter is from another day). */
    val doneToday: Int get() = if (usedToday(approvedTodayAt)) approvedTodayCount else 0
    val approvedToday: Boolean get() = isDaily && doneToday >= maxOf(1, timesPerDay)
    val isPreset: Boolean get() = id.startsWith("preset-")

    override fun equals(other: Any?) = other is Chore && other.id == id && other.markedDoneAt == markedDoneAt &&
        other.lastApprovedAt == lastApprovedAt && other.archived == archived && other.rewardMinutes == rewardMinutes &&
        other.title == title && other.emoji == emoji && other.timesPerDay == timesPerDay && other.approvedTodayCount == approvedTodayCount &&
        other.photoToken == photoToken && (other.photo?.size ?: 0) == (photo?.size ?: 0)
    override fun hashCode() = id.hashCode()

    companion object {
        fun from(id: String, d: Doc): Chore? {
            val childID = d.str("childID") ?: return null
            val title = d.str("title") ?: return null
            return Chore(
                id = id, childID = childID, title = title,
                emoji = d.str("emoji") ?: "🧹",
                rewardMinutes = d.int("rewardMinutes") ?: 0,
                rewardCoins = d.int("rewardCoins") ?: 0,
                isDaily = d.bool("isDaily") ?: false,
                timesPerDay = d.int("timesPerDay") ?: 1,
                createdAt = d.secs("createdAt") ?: 0.0,
                markedDoneAt = d.secs("markedDoneAt"),
                chosenReward = d.str("chosenReward"),
                lastApprovedAt = d.secs("lastApprovedAt"),
                photo = (d["photoData"] as? Blob)?.toBytes(),
                photoToken = d.str("photoToken"),
                approvedTodayCount = d.int("approvedTodayCount") ?: 0,
                approvedTodayAt = d.secs("approvedTodayAt"),
                archived = d.bool("archived") ?: false,
            )
        }
    }
}

/** DayGate.usedToday(unixSeconds:) — the stamp's day is today (or later). */
fun usedToday(t: Double?): Boolean {
    t ?: return false
    fun startOfDay(ms: Long) = Calendar.getInstance().apply {
        timeInMillis = ms; set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis
    return startOfDay((t * 1000).toLong()) >= startOfDay(System.currentTimeMillis())
}

/** households/{hid}/choreStats/{childID} — the lifetime ledger. */
data class ChoreStats(val minutes: Int = 0, val coins: Int = 0, val paid: Int = 0)

/**
 * ChoreStore.swift, parent side: a live mirror of the household's chores and
 * chore ledger, the built-in catalog, and the parent's writes. Chore docs are
 * separate from the progress snapshot so a kid's "עשיתי" and the parent's
 * approval never race the LWW machinery.
 */
object ChoresRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val _chores = MutableStateFlow<List<Chore>>(emptyList())
    val chores: StateFlow<List<Chore>> = _chores
    private val _stats = MutableStateFlow<Map<String, ChoreStats>>(emptyMap())
    val stats: StateFlow<Map<String, ChoreStats>> = _stats
    /** Approvals awaiting the server transaction — the button shows "מאשר…". */
    private val _approving = MutableStateFlow<Set<String>>(emptySet())
    val approving: StateFlow<Set<String>> = _approving
    /** An approval that could not commit (offline/permission) — the screen says so honestly. */
    val lastActionFailed = MutableStateFlow(false)
    /** The child the chores screen should open on (set by a banner / the child's actions). */
    var focusChildID: String? = null

    private var started = false
    private var listening: String? = null
    private var regs = listOf<ListenerRegistration>()

    /**
     * Idempotent. Like ChoreStore.startIfNeeded's race fix: subscribe to the
     * household id, so the listener attaches the moment the family loads and
     * re-binds if it changes.
     */
    fun start() {
        if (started) return
        started = true
        scope.launch {
            FamilyRepository.state.map { it.household?.id }.distinctUntilChanged().collect { bind(it) }
        }
    }

    private fun bind(hid: String?) {
        if (hid == listening) return
        regs.forEach { it.remove() }; regs = emptyList()
        listening = hid
        _chores.value = emptyList(); _stats.value = emptyMap()
        hid ?: return
        val hh = db.collection("households").document(hid)
        regs = listOf(
            hh.collection("chores").addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                _chores.value = snap.documents.mapNotNull { d -> d.data?.let { Chore.from(d.id, it) } }.sortedBy { it.createdAt }
            },
            hh.collection("choreStats").addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                _stats.value = snap.documents.associate { d ->
                    d.id to ChoreStats(d.getLong("minutesTotal")?.toInt() ?: 0, d.getLong("coinsTotal")?.toInt() ?: 0, d.getLong("coinsPaid")?.toInt() ?: 0)
                }
            },
        )
    }

    // MARK: catalog

    data class Preset(val key: String, val emoji: String, val title: String, val minutes: Int, val timesPerDay: Int)

    /** ChoreStore.catalog — every child gets these automatically (ids `preset-…_{childID}`). */
    val catalog: List<Preset>
        get() = listOf(
            Preset("preset-bed", "🛏", tr("לסדר את המיטה"), 5, 1),
            Preset("preset-clothes", "👕", tr("לשים בגדים בסל הכביסה"), 5, 2),
            Preset("preset-plate", "🍽", tr("לפנות את הצלחת מהשולחן"), 5, 3),
            Preset("preset-shoes", "👟", tr("לסדר את הנעליים בכניסה"), 5, 1),
            Preset("preset-toys", "🧸", tr("לאסוף את הצעצועים"), 10, 1),
            Preset("preset-table", "🍴", tr("לערוך את השולחן לארוחה"), 10, 3),
            Preset("preset-bag", "🎒", tr("להכין את התיק לבית הספר"), 10, 1),
            Preset("preset-plants", "🪴", tr("להשקות את העציצים"), 10, 1),
            Preset("preset-pet", "🐕", tr("להאכיל את חיית המחמד"), 10, 2),
            Preset("preset-trash", "🗑", tr("להוריד את הזבל"), 10, 1),
            Preset("preset-desk", "📚", tr("לסדר את שולחן הכתיבה"), 15, 1),
            Preset("preset-sweep", "🧹", tr("לסדר את החדר"), 20, 1),
            Preset("preset-laundry", "🧺", tr("לעזור בקיפול כביסה"), 20, 1),
            Preset("preset-groceries", "🛒", tr("לעזור בסידור הקניות"), 20, 1),
            Preset("preset-cooking", "🍳", tr("לעזור בהכנת ארוחה"), 20, 1),
            Preset("preset-sibling", "🎲", tr("לשחק עם אח או אחות"), 10, 2),
            Preset("preset-outfit", "👔", tr("לסדר תלבושת לבית הספר"), 5, 1),
            Preset("preset-closet", "🧥", tr("לסדר את הארון"), 15, 1),
            Preset("preset-homework", "📝", tr("להכין שיעורי בית"), 30, 1),
            Preset("preset-reading", "📖", tr("לקרוא ספר"), 60, 1),
            Preset("preset-leaves", "🍂", tr("לאסוף עלים מהגינה"), 30, 1),
        )

    /** ChoreStore.chores(forChild:): the catalog (overridden by same-id docs) + the family's custom chores. */
    fun choresFor(childID: String, all: List<Chore> = _chores.value): List<Chore> {
        val byID = all.filter { it.childID == childID }.associateBy { it.id }.toMutableMap()
        val out = mutableListOf<Chore>()
        for (p in catalog) {
            val docID = "${p.key}_$childID"
            val doc = byID.remove(docID)
            if (doc != null) { if (!doc.archived) out += doc }
            else out += Chore(docID, childID, p.title, p.emoji, p.minutes, 0, true, p.timesPerDay, 0.0,
                null, null, null, null, null, 0, null, false)
        }
        out += byID.values.filter { !it.archived }.sortedBy { it.createdAt }
        return out
    }

    fun hiddenPresets(childID: String, all: List<Chore> = _chores.value) =
        all.filter { it.childID == childID && it.archived && it.isPreset }

    fun pendingApproval(all: List<Chore> = _chores.value) = all.filter { it.isPendingApproval }

    fun totals(childID: String) = _stats.value[childID] ?: ChoreStats()

    /** The chorePhoto Cloud Function URL (what the iOS notification extension fetches). */
    fun photoURL(householdID: String, choreID: String, token: String) =
        "https://us-central1-childtime-86e98.cloudfunctions.net/chorePhoto?hh=${enc(householdID)}&chore=${enc(choreID)}&token=$token"

    private fun enc(s: String) = java.net.URLEncoder.encode(s, "UTF-8")

    // MARK: parent writes

    private fun choreRef(id: String) = listening?.let { db.collection("households").document(it).collection("chores").document(id) }

    /** A confirmed write (same contract as confirmedMerge) that self-heals membership once. */
    private suspend fun confirmed(op: () -> Task<Void>): WriteOutcome {
        suspend fun once(): WriteOutcome = withTimeoutOrNull(3000) {
            suspendCancellableCoroutine { cont ->
                op().addOnCompleteListener { t ->
                    if (!cont.isActive) return@addOnCompleteListener
                    val e = t.exception
                    cont.resume(when {
                        e == null -> WriteOutcome.OK
                        (e as? FirebaseFirestoreException)?.code == FirebaseFirestoreException.Code.PERMISSION_DENIED -> WriteOutcome.DENIED
                        else -> WriteOutcome.ERROR
                    })
                }
            }
        } ?: WriteOutcome.QUEUED
        var out = once()
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = once() }
        return out
    }

    suspend fun addChore(childID: String, title: String, emoji: String, rewardMinutes: Int, timesPerDay: Int): WriteOutcome {
        val hid = listening ?: FamilyRepository.householdID ?: return WriteOutcome.ERROR
        val ref = db.collection("households").document(hid).collection("chores").document()
        val data = mapOf(
            "childID" to childID, "title" to title, "emoji" to emoji,
            "rewardMinutes" to rewardMinutes, "rewardCoins" to 0, "isDaily" to true,
            "timesPerDay" to maxOf(1, timesPerDay), "createdAt" to nowSecs(),
        )
        return confirmed { ref.set(data) }
    }

    suspend fun deleteChore(chore: Chore): WriteOutcome {
        val ref = choreRef(chore.id) ?: return WriteOutcome.ERROR
        return confirmed { ref.delete() }
    }

    /** Retune rewards (or rename a custom chore); for a catalog chore this writes its per-child override doc. */
    suspend fun updateChore(chore: Chore, title: String, emoji: String, rewardMinutes: Int, timesPerDay: Int): WriteOutcome {
        val ref = choreRef(chore.id) ?: return WriteOutcome.ERROR
        val data = mapOf(
            "childID" to chore.childID, "title" to title, "emoji" to emoji,
            "rewardMinutes" to rewardMinutes, "rewardCoins" to 0, "isDaily" to chore.isDaily,
            "timesPerDay" to maxOf(1, timesPerDay),
            "createdAt" to (if (chore.createdAt > 0) chore.createdAt else nowSecs()),
        )
        return confirmed { ref.set(data, SetOptions.merge()) }
    }

    /** Hide a catalog chore for this child; a custom one is deleted outright (deleteChore). */
    suspend fun hideChore(chore: Chore): WriteOutcome {
        val ref = choreRef(chore.id) ?: return WriteOutcome.ERROR
        val data = mapOf(
            "childID" to chore.childID, "title" to chore.title, "emoji" to chore.emoji,
            "rewardMinutes" to chore.rewardMinutes, "rewardCoins" to chore.rewardCoins,
            "isDaily" to chore.isDaily, "timesPerDay" to chore.timesPerDay,
            "createdAt" to (if (chore.createdAt > 0) chore.createdAt else nowSecs()),
            "archived" to true,
            "markedDoneAt" to FieldValue.delete(), "chosenReward" to FieldValue.delete(),
            "photoData" to FieldValue.delete(), "photoToken" to FieldValue.delete(),
        )
        return confirmed { ref.set(data, SetOptions.merge()) }
    }

    suspend fun restoreChore(chore: Chore): WriteOutcome {
        val ref = choreRef(chore.id) ?: return WriteOutcome.ERROR
        return confirmed { ref.update("archived", false) }
    }

    /** "Not quite done yet" — back to the kid's list, no reward, no failure language. */
    suspend fun returnChore(chore: Chore): WriteOutcome {
        val ref = choreRef(chore.id) ?: return WriteOutcome.ERROR
        return confirmed {
            ref.update(mapOf(
                "markedDoneAt" to FieldValue.delete(), "chosenReward" to FieldValue.delete(),
                "photoData" to FieldValue.delete(), "photoToken" to FieldValue.delete(),
                "returnedAt" to nowSecs(),
            ))
        }
    }

    enum class ApprovalResult { WON, ALREADY_RESOLVED, FAILED }

    /** ChoreStore.approve: ignore double taps, retry once after a membership heal, flag a genuine failure. */
    fun approve(chore: Chore) {
        val hid = listening ?: return
        if (chore.id in _approving.value) return
        _approving.update { it + chore.id }
        scope.launch {
            var r = performApproval(hid, chore.id)
            if (r == ApprovalResult.FAILED) {
                FamilyRepository.reassertMembership()
                r = performApproval(hid, chore.id)
            }
            if (r == ApprovalResult.FAILED) lastActionFailed.value = true
            _approving.update { it - chore.id }
        }
    }

    /**
     * ChoreStore.performApproval — ONE transaction claims the chore (only while
     * it's still marked done) and grants the reward, so two approvers can never
     * pay twice and a partial failure never leaves a paid-but-pending chore.
     */
    suspend fun performApproval(householdID: String, choreID: String): ApprovalResult {
        val hh = db.collection("households").document(householdID)
        val choreRef = hh.collection("chores").document(choreID)
        return try {
            val won = db.runTransaction { txn ->
                val d = txn.get(choreRef).data
                if (d == null || d["markedDoneAt"] == null) return@runTransaction false
                val childID = d.str("childID") ?: ""
                val rewardMinutes = d.int("rewardMinutes") ?: 0
                val rewardCoins = d.int("rewardCoins") ?: 0
                val coins = d.str("chosenReward") == "coins" && rewardCoins > 0
                val isDaily = d.bool("isDaily") ?: false
                val now = nowSecs()
                val doneToday = if (usedToday(d.secs("approvedTodayAt"))) d.int("approvedTodayCount") ?: 0 else 0
                val update = mutableMapOf<String, Any>(
                    "markedDoneAt" to FieldValue.delete(), "chosenReward" to FieldValue.delete(),
                    "photoData" to FieldValue.delete(), "photoToken" to FieldValue.delete(),
                    "lastApprovedAt" to now, "approvedTodayCount" to doneToday + 1, "approvedTodayAt" to now,
                )
                if (!isDaily) update["archived"] = true
                txn.update(choreRef, update)
                // Reward inside the same transaction: the ledger, and for minutes the
                // earned-wallet command the kid's device consumes exactly once.
                txn.set(hh.collection("choreStats").document(childID),
                    mapOf((if (coins) "coinsTotal" else "minutesTotal") to FieldValue.increment((if (coins) rewardCoins else rewardMinutes).toLong())),
                    SetOptions.merge())
                if (!coins && rewardMinutes > 0 && childID.isNotEmpty()) {
                    txn.set(db.collection("children").document(childID),
                        mapOf("pendingMinuteAdjustment" to FieldValue.increment(rewardMinutes.toLong())), SetOptions.merge())
                }
                true
            }.await()
            if (won) ApprovalResult.WON else ApprovalResult.ALREADY_RESOLVED
        } catch (e: Exception) {
            ApprovalResult.FAILED
        }
    }
}

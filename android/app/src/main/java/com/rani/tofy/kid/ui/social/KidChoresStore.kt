package com.rani.tofy.kid.ui.social

import android.graphics.Bitmap
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.firebase.firestore.Blob
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.rani.tofy.data.Chore
import com.rani.tofy.data.ChoreStats
import com.rani.tofy.data.ChoresRepository
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.confirmedMerge
import com.rani.tofy.data.nowSecs
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.JoinRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import java.io.ByteArrayOutputStream

/**
 * ChoreStore.swift, KID side. A live mirror of households/{hid}/chores (+ the
 * choreStats ledger) for the BOUND child's household — on a child device the
 * parent-side FamilyRepository never runs, so the household comes from the
 * child doc. The chore model + catalog are the parent's (data/ChoresRepository).
 */
object KidChoresStore {
    private val db get() = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    var chores by mutableStateOf<List<Chore>>(emptyList()); private set
    var stats by mutableStateOf<Map<String, ChoreStats>>(emptyMap()); private set

    private var started = false
    private var listening: String? = null
    private var regs = listOf<ListenerRegistration>()

    /** startIfNeeded: idempotent, and re-binds the moment the child doc (→ household) loads or changes. */
    fun startIfNeeded() {
        if (started) return
        started = true
        scope.launch {
            KidSession.childDoc.map { it?.get("householdID") as? String }.distinctUntilChanged().collect { bind(it?.takeIf { h -> h.isNotEmpty() }) }
        }
    }

    private fun bind(hid: String?) {
        if (hid == listening) return
        regs.forEach { it.remove() }; regs = emptyList()
        listening = hid
        chores = emptyList(); stats = emptyMap()
        hid ?: return
        // Heal membership up front (like iOS): an offline-queued "done" must be made under a valid membership.
        scope.launch { JoinRepository.reassertMembership(hid) }
        val hh = db.collection("households").document(hid)
        regs = listOf(
            hh.collection("chores").addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                chores = snap.documents.mapNotNull { d -> d.data?.let { Chore.from(d.id, it) } }.sortedBy { it.createdAt }
            },
            hh.collection("choreStats").addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                stats = snap.documents.associate { d ->
                    d.id to ChoreStats(d.getLong("minutesTotal")?.toInt() ?: 0, d.getLong("coinsTotal")?.toInt() ?: 0, d.getLong("coinsPaid")?.toInt() ?: 0)
                }
            },
        )
    }

    /** chores(forChild:) — the catalog (overridden per child) + the family's custom chores. */
    fun choresFor(childID: String): List<Chore> = ChoresRepository.choresFor(childID, chores)

    fun totals(childID: String): ChoreStats = stats[childID] ?: ChoreStats()

    enum class SendResult { SENT, QUEUED, NOT_READY, FAILED }

    /**
     * markDone — CONFIRMED (never fire-and-forget): DENIED → re-assert membership
     * and retry once; any other error with a photo (most likely the 1 MB doc cap)
     * → land the done-signal without the photo; no ack in the window → QUEUED
     * (Firestore's durable queue delivers it). The photo is raw JPEG bytes (a
     * Firestore Blob, iOS `Data`); `photoToken` is minted by onChoreWritten.
     */
    suspend fun markDone(chore: Chore, reward: String, photo: ByteArray?): SendResult {
        val hid = listening ?: SocialMe.householdID ?: return SendResult.NOT_READY
        val ref = db.collection("households").document(hid).collection("chores").document(chore.id)
        val base = mutableMapOf<String, Any?>(
            "childID" to chore.childID, "title" to chore.title, "emoji" to chore.emoji,
            "rewardMinutes" to chore.rewardMinutes, "rewardCoins" to chore.rewardCoins,
            "isDaily" to chore.isDaily, "timesPerDay" to chore.timesPerDay,
            "createdAt" to (if (chore.createdAt > 0) chore.createdAt else nowSecs()),
            "markedDoneAt" to nowSecs(), "chosenReward" to reward,
            // Clear a stale photo/token from a previous round by default.
            "photoData" to FieldValue.delete(), "photoToken" to FieldValue.delete(),
        )
        val full = base.toMutableMap()
        if (photo != null && photo.isNotEmpty()) full["photoData"] = Blob.fromBytes(photo)

        suspend fun write(f: Map<String, Any?>): WriteOutcome {
            var o = confirmedMerge(ref, f)
            if (o == WriteOutcome.DENIED) { JoinRepository.reassertMembership(hid); o = confirmedMerge(ref, f) }
            return o
        }
        var out = write(full)
        if (out == WriteOutcome.ERROR && photo != null) out = write(base)
        return when (out) {
            WriteOutcome.OK -> SendResult.SENT
            WriteOutcome.QUEUED -> SendResult.QUEUED
            else -> SendResult.FAILED
        }
    }

    /** compressProof: longest edge ≤ 900 px, JPEG 0.55 — ≈100-200 KB, well inside the 1 MB doc cap. */
    fun compressProof(src: Bitmap): ByteArray? = runCatching {
        val scale = minOf(1f, 900f / maxOf(src.width, src.height).toFloat())
        val bmp = if (scale < 1f) Bitmap.createScaledBitmap(src, (src.width * scale).toInt().coerceAtLeast(1), (src.height * scale).toInt().coerceAtLeast(1), true) else src
        ByteArrayOutputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 55, it); it.toByteArray() }
    }.getOrNull()
}

package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.util.Calendar
import kotlin.coroutines.resume

/** FirestoreWrite.swift: what actually happened to a write. */
enum class WriteOutcome { OK, QUEUED, DENIED, ERROR }

/**
 * One merge-write that reports whether the SERVER accepted it. Offline, the
 * completion never fires (the write sits in the durable queue) — so no ack in
 * 3 s is QUEUED (will deliver), and only a real server error is a failure.
 */
suspend fun confirmedMerge(ref: DocumentReference, fields: Map<String, Any?>, timeoutMs: Long = 3000): WriteOutcome =
    withTimeoutOrNull(timeoutMs) {
        suspendCancellableCoroutine { cont ->
            ref.set(fields, SetOptions.merge()).addOnCompleteListener { t ->
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

/** Live status of one parent command — RemoteCommandStatusView's data. */
data class CommandStatus(
    val childID: String,
    val kind: Kind,
    val stamp: Double,
    val minutes: Int = 0,
    val note: String? = null,
    val targets: List<String> = emptyList(),
    val reachedCloud: Boolean = false,
    val queued: Boolean = false,
    val failed: Boolean = false,
    val noDevice: Boolean = false,
) {
    enum class Kind { GIFT, LOCK, LOCK_AND_REVOKE }
}

/**
 * Parent → child commands, field-for-field the iOS ones (RemoteSyncManager +
 * HouseholdManager.sendDeviceCommand). Every write is confirmed, and a
 * permission-denied self-heals membership once and retries (command-delivery
 * certainty — never fire-and-forget).
 */
object Commands {
    private val db get() = FirebaseFirestore.getInstance()
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val uid get() = FirebaseAuth.getInstance().currentUser?.uid

    private val _status = MutableStateFlow<CommandStatus?>(null)
    val status: StateFlow<CommandStatus?> = _status
    fun clearStatus() { _status.value = null }

    private suspend fun childCommand(childID: String, fields: Map<String, Any?>): WriteOutcome {
        val ref = db.collection("children").document(childID)
        var out = confirmedMerge(ref, fields)
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(ref, fields) }
        return out
    }

    /** Minutes left until midnight — the per-give cap (ProgressStore.minutesUntilMidnight). */
    fun minutesUntilMidnight(): Int {
        val c = Calendar.getInstance()
        val now = c.timeInMillis
        c.add(Calendar.DAY_OF_YEAR, 1); c.set(Calendar.HOUR_OF_DAY, 0); c.set(Calendar.MINUTE, 0); c.set(Calendar.SECOND, 0); c.set(Calendar.MILLISECOND, 0)
        return maxOf(0, ((c.timeInMillis - now) / 60000).toInt())
    }

    /** 💝 Into the child's GIFT pocket; the child opens it when they choose. */
    fun gift(childID: String, wanted: Int, capNote: (Int) -> String?) {
        val allowed = minOf(wanted, minutesUntilMidnight())
        if (allowed <= 0) return
        val stamp = nowSecs()
        _status.value = CommandStatus(childID, CommandStatus.Kind.GIFT, stamp, allowed, if (allowed < wanted) capNote(wanted) else null)
        val fields = mutableMapOf<String, Any?>("pendingGiftAdjustment" to FieldValue.increment(allowed.toLong()), "giftSentAt" to stamp)
        uid?.let { fields["giftCommandBy"] = it }
        scope.launch {
            val out = childCommand(childID, fields)
            mark(stamp, out)
            ActivityStore.record(ActivityStore.Kind.GIFT, childID, allowed, stamp, out)
        }
    }

    /** 🔒 Re-lock now: a stamp on every device row, then settle the lease if the device never answers. */
    fun lock(childID: String, revokeGift: Boolean = false) {
        val stamp = nowSecs()
        _status.value = CommandStatus(childID, if (revokeGift) CommandStatus.Kind.LOCK_AND_REVOKE else CommandStatus.Kind.LOCK, stamp)
        scope.launch {
            if (revokeGift) {
                val f = mutableMapOf<String, Any?>("revokeGiftAt" to stamp, "pendingGiftAdjustment" to 0)
                uid?.let { f["giftCommandBy"] = it }
                val out = childCommand(childID, f)
                if (out == WriteOutcome.DENIED || out == WriteOutcome.ERROR) _status.update { it?.copy(failed = true) }
            }
            val out = deviceCommand(childID, mapOf("remoteLockAt" to stamp), stamp)
            ActivityStore.record(ActivityStore.Kind.LOCK, childID, 0, stamp, out)
            parentRelease(childID)
        }
    }

    /** Short "allow deleting apps" window on the child's device. */
    fun allowAppRemoval(childID: String) = scope.launch { deviceCommand(childID, mapOf("appRemovalUnlockAt" to nowSecs()), null) }

    /** Reset: the child's device does the authoritative wipe. */
    suspend fun resetProgress(childID: String): WriteOutcome {
        val out = childCommand(childID, mapOf("resetRequestedAt" to nowSecs(), "pendingMinuteAdjustment" to 0, "pendingGiftAdjustment" to 0))
        // 👨‍👧 No device of the child's own (she plays in Kid Mode on a parent's
        // phone) → nobody would consume the command until Kid Mode is next
        // opened, and the dashboard kept the old numbers. Consume it here, in ONE
        // transaction: read the command, write the blank at a higher revision and
        // reset epoch, clear the command (RemoteSyncManager.applyPendingReset).
        if (out != WriteOutcome.DENIED && out != WriteOutcome.ERROR && childHasOwnDevice(childID) == false) {
            runCatching { consumeResetHere(childID) }
        }
        return out
    }

    /**
     * Asked of the SERVER (the listener may not have loaded yet, and an empty
     * unloaded list would take the wipe away from a real device). Kid Mode rows
     * are a parent's phone, told apart by the `parent_<install>` row with the
     * same deviceID (HouseholdManager.childHasOwnDevice). null = couldn't ask.
     */
    private suspend fun childHasOwnDevice(childID: String): Boolean? {
        val hid = FamilyRepository.householdID ?: return null
        val docs = runCatching {
            db.collection("childDevices").whereEqualTo("householdID", hid)
                .get(com.google.firebase.firestore.Source.SERVER).await().documents
        }.getOrNull() ?: return null
        // A parent row hides a child row only if it was still alive when the
        // child row appeared (a phone that became the child's own keeps a dead one).
        fun secs(v: Any?) = (v as? Number)?.toDouble() ?: 0.0
        val parentLastSeen = HashMap<String, Double>()
        for (d in docs) {
            val dev = d.get("deviceID") as? String ?: continue
            if (d.get("role") as? String == "parent") parentLastSeen[dev] = maxOf(parentLastSeen[dev] ?: 0.0, secs(d.get("lastSeenAt")))
        }
        return docs.any {
            val dev = it.get("deviceID") as? String ?: ""
            val kidMode = parentLastSeen[dev]?.let { seen -> seen >= secs(it.get("joinedAt")) } ?: false
            it.get("childID") as? String == childID && it.get("role") as? String != "parent" &&
                it.get("removed") as? Boolean != true && !kidMode
        }
    }

    private suspend fun consumeResetHere(childID: String) {
        val childRef = db.collection("children").document(childID)
        val stateRef = childRef.collection("state").document("current")
        db.runTransaction { txn ->
            if (txn.get(childRef).data?.get("resetRequestedAt") == null) return@runTransaction null
            val cloud = txn.get(stateRef).data?.let { com.rani.tofy.kid.core.ProgressSnapshot.fromFirestore(it) }
            // deviceID = the PARENT, not this install: Kid Mode on this same phone
            // uses the install id and would skip the blank as "our own echo".
            val blank = com.rani.tofy.kid.core.ProgressSnapshot(lastModifiedAt = com.rani.tofy.kid.core.AppleTime.now(),
                deviceID = "parent-" + (uid ?: "unknown"))
            blank.revision = (cloud?.revision ?: 0) + 1
            blank.resetEpoch = (cloud?.resetEpoch ?: 0) + 1
            txn.set(stateRef, blank.toFirestore())   // NOT merge
            txn.update(childRef, hashMapOf<String, Any?>("resetRequestedAt" to FieldValue.delete()))
            null
        }.await()
    }

    suspend fun purgeCaches(childID: String): WriteOutcome =
        confirmedMerge(db.collection("children").document(childID).collection("state").document("current"), mapOf("purgeCacheAt" to nowSecs()))

    /** Disconnect a device: the device sees `removed` and resets itself. */
    suspend fun removeDevice(deviceRowID: String): WriteOutcome =
        confirmedMerge(db.collection("childDevices").document(deviceRowID), mapOf("removed" to true))

    private suspend fun deviceCommand(childID: String, fields: Map<String, Any?>, stamp: Double?): WriteOutcome {
        val f = fields.toMutableMap(); uid?.let { f["commandBy"] = it }
        var targets = FamilyRepository.state.value.devicesOf(childID).map { it.id }
        if (targets.isEmpty()) {
            val hid = FamilyRepository.householdID ?: return WriteOutcome.ERROR
            targets = runCatching {
                db.collection("childDevices").whereEqualTo("householdID", hid).whereEqualTo("childID", childID).get().await().documents.map { it.id }
            }.getOrDefault(emptyList())
        }
        if (stamp != null) _status.update { if (it?.stamp == stamp) it.copy(targets = targets, noDevice = targets.isEmpty()) else it }
        if (targets.isEmpty()) return WriteOutcome.ERROR
        var best = WriteOutcome.ERROR
        for (id in targets) {
            var out = confirmedMerge(db.collection("childDevices").document(id), f)
            if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(db.collection("childDevices").document(id), f) }
            if (out.ordinal < best.ordinal) best = out
        }
        if (stamp != null) mark(stamp, best)
        return best
    }

    private fun mark(stamp: Double, out: WriteOutcome) = _status.update {
        if (it?.stamp != stamp) it else when (out) {
            WriteOutcome.OK -> it.copy(reachedCloud = true)
            WriteOutcome.QUEUED -> it.copy(queued = true)
            else -> it.copy(failed = true)
        }
    }

    /**
     * PlayWindowLeaseManager.parentRelease: give the device the first word (15 s) —
     * a live device releases the lease itself as proof it re-locked. Only if it
     * never answers do we settle it here, refunding the unspent seconds to the
     * pocket that funded it, in ONE transaction with the lease going idle.
     */
    private suspend fun parentRelease(childID: String) {
        val wRef = db.collection("children").document(childID).collection("state").document("window")
        val sRef = db.collection("children").document(childID).collection("state").document("current")
        repeat(5) {
            delay(3000)
            val l = runCatching { Lease.from(wRef.get().await().data ?: emptyMap()) }.getOrNull() ?: return
            if (!l.isHeld) return
        }
        val leaseID = runCatching { Lease.from(wRef.get().await().data ?: emptyMap()) }.getOrNull()?.takeIf { it.isHeld }?.leaseID ?: return
        runCatching {
            db.runTransaction { txn ->
                val w = txn.get(wRef).data ?: emptyMap()
                if (w.str("lastReleasedLeaseID") == leaseID || w.str("leaseID") != leaseID) return@runTransaction null
                val held = Lease.from(w)
                val elapsed = held.startedAt?.let { maxOf(0, (nowSecs() - it).toInt()) } ?: 0
                val refund = maxOf(0, held.grantedSeconds - elapsed)
                val s = txn.get(sRef).data ?: emptyMap()
                val upd = mutableMapOf<String, Any?>()
                var eIn = s.int("earnedSecondsIn") ?: 0; val eOut = s.int("earnedSecondsOut") ?: 0
                var gIn = s.int("giftSecondsIn") ?: 0; val gOut = s.int("giftSecondsOut") ?: 0
                if (refund > 0) when (held.kind) {
                    "earned" -> { eIn += refund; upd["earnedSecondsIn"] = eIn
                        upd["minutesUnlockedToday"] = maxOf(0, (s.int("minutesUnlockedToday") ?: 0) - refund / 60) }
                    "gift" -> { gIn += refund; upd["giftSecondsIn"] = gIn }
                }
                upd["pendingMinutes"] = maxOf(0, eIn - eOut) / 60
                upd["parentGiftMinutes"] = maxOf(0, gIn - gOut) / 60
                upd["revision"] = (s.int("revision") ?: 0) + 1
                upd["lastModifiedAt"] = nowAppleSecs()   // state/current Dates are Apple-reference, not unix
                txn.set(sRef, upd, SetOptions.merge())
                txn.set(wRef, mapOf(
                    "state" to "idle",
                    "leaseID" to FieldValue.delete(), "ownerDeviceID" to FieldValue.delete(),
                    "ownerKind" to FieldValue.delete(), "ownerName" to FieldValue.delete(),
                    "grantedSeconds" to FieldValue.delete(), "startedAt" to FieldValue.delete(),
                    "releaseRequestedBy" to FieldValue.delete(), "releaseRequestedAt" to FieldValue.delete(),
                    "lastReleasedLeaseID" to leaseID, "lastReleasedAt" to FieldValue.serverTimestamp(),
                    "refundedSeconds" to (if (held.kind == "grant") 0 else refund),
                ), SetOptions.merge())
                null
            }.await()
        }
    }
}

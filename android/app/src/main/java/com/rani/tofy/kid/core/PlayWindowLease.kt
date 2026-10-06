package com.rani.tofy.kid.core

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  PlayWindowLease — port of ChildTime/Models/PlayWindowLease.swift
 * ════════════════════════════════════════════════════════════════════════════
 *
 * ONE authoritative play window per child, owned by exactly ONE device — an
 * iPad, an iPhone or an Android phone, interchangeably. Doc:
 * children/{childID}/state/window. The wallet debit and the lease write are the
 * SAME transaction (with state/current), so minutes are never spent-but-unclaimed
 * or claimed-but-unspent. `startedAt` is a SERVER timestamp; remaining time is
 * derived from it, never stored.
 *
 * Every transaction does ALL its reads before any write (Firestore rejects a
 * read after a write; iOS learned that the hard way with gifts).
 *
 * PUBLIC API
 *   PlayWindowLease (+ State, Kind)   — parsed doc; isHeld / isMine / isExpired /
 *                                       isHeldElsewhere / remainingSeconds
 *   ClaimedWallet, ClaimOutcome, ClaimPolicy
 *   PlayWindowLeaseManager(db, host, scope)
 *     .lease: StateFlow<PlayWindowLease>          live view of the child's lease
 *     .startIfNeeded(childID) / .stop()
 *     .claim(childID, kind, requestedSeconds, policy)       → ClaimOutcome
 *     .release(childID, leaseID, localRemainingSeconds)     → Boolean (committed)
 *     .requestRelease(childID)                               → Boolean
 *     .transferHere(childID, ownerDeviceRowID, kind, secs)   → ClaimOutcome
 *     .parentRelease(childID, afterGrace)
 *     .reconcileOfflineWindowIfNeeded(childID)
 *   LeaseHost — what the manager needs from the live kid store (KidSession implements it)
 */

data class PlayWindowLease(
    val state: State = State.IDLE,
    val leaseID: String? = null,
    val ownerDeviceID: String? = null,
    val ownerKind: String? = null,
    val ownerName: String? = null,
    val kind: Kind = Kind.EARNED,
    val grantedSeconds: Int = 0,
    /** UNIX seconds, server-stamped. */
    val startedAt: Double? = null,
    val releaseRequestedBy: String? = null,
    val lastReleasedLeaseID: String? = null,
) {
    enum class State(val raw: String) { OPEN("open"), RELEASING("releasing"), IDLE("idle") }
    /** Which pocket funded the window — decides where a refund goes. */
    enum class Kind(val raw: String) {
        EARNED("earned"), GIFT("gift"), GRANT("grant");
        companion object { fun of(raw: String?): Kind? = entries.firstOrNull { it.raw == raw } }
    }

    fun isMine(me: String = KidIdentity.installID): Boolean = ownerDeviceID == me
    val isHeld: Boolean get() = state != State.IDLE && leaseID != null

    fun remainingSeconds(nowUnix: Double = AppleTime.nowUnix()): Int {
        val s = startedAt ?: return 0
        return maxOf(0, grantedSeconds - (nowUnix - s).toInt())
    }

    fun isExpired(nowUnix: Double = AppleTime.nowUnix()): Boolean {
        val s = startedAt
        if (!isHeld || s == null) return true
        return nowUnix - s > (grantedSeconds + EXPIRY_GRACE_SECONDS).toDouble()
    }

    /** Someone ELSE is genuinely playing right now. */
    fun isHeldElsewhere(nowUnix: Double = AppleTime.nowUnix(), me: String = KidIdentity.installID): Boolean =
        isHeld && !isMine(me) && !isExpired(nowUnix)

    companion object {
        const val EXPIRY_GRACE_SECONDS = 120

        fun from(d: Map<String, Any?>): PlayWindowLease = PlayWindowLease(
            state = State.entries.firstOrNull { it.raw == d["state"] as? String } ?: State.IDLE,
            leaseID = d["leaseID"] as? String,
            ownerDeviceID = d["ownerDeviceID"] as? String,
            ownerKind = d["ownerKind"] as? String,
            ownerName = d["ownerName"] as? String,
            kind = Kind.of(d["kind"] as? String) ?: Kind.EARNED,
            grantedSeconds = (d["grantedSeconds"] as? Number)?.toInt() ?: 0,
            startedAt = when (val v = d["startedAt"]) {
                is Timestamp -> v.seconds + v.nanoseconds / 1e9
                is Number -> v.toDouble()
                else -> null
            },
            releaseRequestedBy = d["releaseRequestedBy"] as? String,
            lastReleasedLeaseID = d["lastReleasedLeaseID"] as? String,
        )
    }
}

/**
 * The wallet as a lease transaction left it in the cloud. The caller applies
 * [deltaSeconds] (negative spent, positive refunded) to its own counters and
 * adopts [revision] — see ProgressEngine.applyClaimedWallet.
 */
data class ClaimedWallet(
    val pendingMinutes: Int,
    val parentGiftMinutes: Int,
    val minutesUnlockedToday: Int,
    val secondsCarry: Int,
    val carryIsGift: Boolean = false,
    val revision: Int,
    val basedOnEditSeq: Int = 0,
    val deltaSeconds: Int = 0,
    val deltaIsGift: Boolean = false,
)

sealed class ClaimOutcome {
    data class Granted(val leaseID: String, val seconds: Int, val wallet: ClaimedWallet?) : ClaimOutcome()
    /** Another device holds a live window — offer the transfer. */
    data class HeldElsewhere(val ownerKind: String, val secondsLeft: Int) : ClaimOutcome()
    data object Insufficient : ClaimOutcome()
    /** The transaction could not run (transactions do NOT queue offline). */
    data object Offline : ClaimOutcome()
}

enum class ClaimPolicy {
    /** The child tapping "open my minutes". */
    NORMAL,
    /** A parent's remote grant outranks a sibling device. */
    PARENT_OVERRIDE,
    /** Retro-claim for a window already opened offline — publishes ownership, debits nothing. */
    ADOPT_LOCAL,
}

/** What the lease manager needs from the live kid store. */
interface LeaseHost {
    /** The child this device is currently BEING (null = none). */
    val activeChildID: String?
    fun captureSnapshot(): ProgressSnapshot
    val localEditSeq: Int
    val localRevision: Int
    val minimumUnlockSeconds: Int
    val isUnlocked: Boolean
    val activeLeaseID: String?
    val unlockSecondsRemaining: Int
    val unlockKind: String
    fun adoptLeaseID(id: String)
    fun applyClaimedWallet(w: ClaimedWallet)
    /** OWNER side of a transfer: re-lock, then stop-and-save (which releases the lease). */
    fun stopForPeerRequest()
    /** Doorbell: stamp remoteLockAt on the owner's device row (confirmed write). */
    fun ringOwnerDevice(deviceRowID: String)
    val ownerKind: String
    val ownerName: String
}

class PlayWindowLeaseManager(
    private val db: FirebaseFirestore,
    private val host: LeaseHost,
    private val scope: CoroutineScope,
    private val enabled: () -> Boolean = { true },
) {
    private val _lease = MutableStateFlow(PlayWindowLease())
    val lease: StateFlow<PlayWindowLease> = _lease

    private var listener: ListenerRegistration? = null
    private var listeningChild: String? = null
    private var reconciling = false
    private val me: String get() = KidIdentity.installID

    private fun windowRef(cid: String): DocumentReference =
        db.collection("children").document(cid).collection("state").document("window")
    private fun stateRef(cid: String): DocumentReference =
        db.collection("children").document(cid).collection("state").document("current")

    fun startIfNeeded(childID: String) {
        if (!enabled() || childID == listeningChild) return
        listener?.remove()
        listeningChild = childID
        listener = windowRef(childID).addSnapshotListener { snap, err ->
            if (err != null) return@addSnapshotListener
            val parsed = PlayWindowLease.from(snap?.data ?: emptyMap())
            _lease.value = parsed
            honorReleaseRequestIfNeeded(childID, parsed)
        }
    }

    fun stop() {
        listener?.remove(); listener = null
        listeningChild = null
        _lease.value = PlayWindowLease()
    }

    /** OWNER side: the child's other device asked for the window — let go now. */
    private fun honorReleaseRequestIfNeeded(childID: String, l: PlayWindowLease) {
        if (!l.isMine(me) || l.state != PlayWindowLease.State.RELEASING || l.releaseRequestedBy == me) return
        if (host.isUnlocked) { host.stopForPeerRequest(); return }
        // We hold the lease but are not playing — a path missed the release. Refund 0.
        val lid = l.leaseID ?: return
        if (host.activeChildID == childID) scope.launch { release(childID, lid, 0) }
    }

    /** CLAIMANT side: ask the owner to let go, ring its doorbell, wait for idle, then claim. */
    suspend fun transferHere(childID: String, ownerDeviceRowID: String?, kind: PlayWindowLease.Kind, requestedSeconds: Int): ClaimOutcome {
        if (!requestRelease(childID)) return claim(childID, kind, requestedSeconds)
        ownerDeviceRowID?.let { host.ringOwnerDevice(it) }
        for (i in 0 until 60) {   // wait for the honest confirmation, bounded (30 s)
            delay(500)
            val l = _lease.value
            if (!l.isHeld || l.isMine(me) || l.isExpired()) break
        }
        val l = _lease.value
        if (l.isHeldElsewhere(me = me)) return ClaimOutcome.HeldElsewhere(l.ownerKind ?: "other", l.remainingSeconds())
        return claim(childID, kind, requestedSeconds)
    }

    /**
     * RECONNECT SWEEP: holding the lease but not playing → let go; playing an
     * offline window without a lease → retro-claim one (ADOPT_LOCAL, no debit).
     */
    fun reconcileOfflineWindowIfNeeded(childID: String) {
        if (!enabled()) return
        val l = _lease.value
        if (l.isMine(me) && l.isHeld && !host.isUnlocked) {
            val lid = l.leaseID ?: return
            scope.launch { release(childID, lid, 0) }
            return
        }
        if (!host.isUnlocked || host.activeLeaseID != null) return
        val left = host.unlockSecondsRemaining
        if (left <= 30 || reconciling) return
        val kind = PlayWindowLease.Kind.of(host.unlockKind) ?: PlayWindowLease.Kind.EARNED
        reconciling = true
        scope.launch {
            try {
                val out = claim(childID, kind, left, ClaimPolicy.ADOPT_LOCAL)
                if (out is ClaimOutcome.Granted) host.adoptLeaseID(out.leaseID)
            } finally { reconciling = false }
        }
    }

    // ── CLAIM (open) ────────────────────────────────────────────────────────
    private sealed class ClaimTx {
        data class Ok(val leaseID: String, val seconds: Int, val wallet: ClaimedWallet) : ClaimTx()
        data class Held(val kind: String, val seconds: Int) : ClaimTx()
        data object Insufficient : ClaimTx()
    }

    private fun walletOf(s: ProgressSnapshot, baseSeq: Int, delta: Int, gift: Boolean) = ClaimedWallet(
        pendingMinutes = s.pendingMinutes, parentGiftMinutes = s.parentGiftMinutes ?: 0,
        minutesUnlockedToday = s.minutesUnlockedToday, secondsCarry = s.secondsCarry ?: 0,
        carryIsGift = s.carryIsGift ?: false, revision = s.revision, basedOnEditSeq = baseSeq,
        deltaSeconds = delta, deltaIsGift = gift,
    )

    /**
     * Atomically: verify nobody else holds a live window, settle a dead lease,
     * DEBIT the wallet, write the lease. Open the window only on Granted.
     */
    suspend fun claim(childID: String, kind: PlayWindowLease.Kind, requestedSeconds: Int, policy: ClaimPolicy = ClaimPolicy.NORMAL): ClaimOutcome {
        val candidate = java.util.UUID.randomUUID().toString().uppercase()
        // Captured BEFORE the transaction — the block may re-run.
        val local = host.captureSnapshot()
        val baseSeq = host.localEditSeq
        val minSeconds = host.minimumUnlockSeconds
        val wRef = windowRef(childID); val sRef = stateRef(childID)
        val ownerKind = host.ownerKind; val ownerName = host.ownerName
        val myID = me
        val result = try {
            db.runTransaction { txn ->
                val wData: Map<String, Any?> = txn.get(wRef).data ?: emptyMap()
                val held = PlayWindowLease.from(wData)
                val now = AppleTime.nowUnix()
                // 1. Already ours → same answer, NO second debit.
                if (held.isHeld && held.isMine(myID) && !held.isExpired(now)) {
                    val cur = txn.get(sRef).data?.let { ProgressSnapshot.fromFirestore(it) } ?: ProgressSnapshot.blank()
                    return@runTransaction ClaimTx.Ok(held.leaseID ?: "", held.remainingSeconds(now), walletOf(cur, baseSeq, 0, false))
                }
                // 2. Someone else is genuinely playing → refuse. THE invariant.
                if (held.isHeldElsewhere(now, myID) && (policy == ClaimPolicy.NORMAL || policy == ClaimPolicy.ADOPT_LOCAL)) {
                    return@runTransaction ClaimTx.Held(held.ownerKind ?: "other", held.remainingSeconds(now))
                }
                val cloud = txn.get(sRef).data?.let { ProgressSnapshot.fromFirestore(it) } ?: ProgressSnapshot.blank()
                // 3. Taking over a dead lease → SETTLE it first (raise "in", never lower "out").
                val hid = held.leaseID
                if (held.isHeld && hid != null && held.lastReleasedLeaseID != hid) {
                    val owed = held.remainingSeconds(now)
                    if (owed > 0) when (held.kind) {
                        PlayWindowLease.Kind.EARNED -> {
                            cloud.earnedSecondsIn = (cloud.earnedSecondsIn ?: 0) + owed
                            cloud.minutesUnlockedToday = maxOf(0, cloud.minutesUnlockedToday - owed / 60)
                        }
                        PlayWindowLease.Kind.GIFT -> cloud.giftSecondsIn = (cloud.giftSecondsIn ?: 0) + owed
                        PlayWindowLease.Kind.GRANT -> Unit
                    }
                }
                // 4. Merge our local state up (never lowers the cloud), then debit.
                val merged = ProgressSnapshot.ratchetMerged(local, cloud)
                val grant: Int
                if (policy == ClaimPolicy.ADOPT_LOCAL) {
                    grant = requestedSeconds
                } else when (kind) {
                    PlayWindowLease.Kind.EARNED -> {
                        grant = minOf(requestedSeconds, merged.earnedSecondsAvailable)
                        if (grant < minSeconds) return@runTransaction ClaimTx.Insufficient
                        merged.earnedSecondsOut = (merged.earnedSecondsOut ?: 0) + grant
                        merged.minutesUnlockedToday += grant / 60
                    }
                    PlayWindowLease.Kind.GIFT -> {
                        grant = minOf(requestedSeconds, merged.giftSecondsAvailable)
                        if (grant <= 0) return@runTransaction ClaimTx.Insufficient
                        merged.giftSecondsOut = (merged.giftSecondsOut ?: 0) + grant
                    }
                    PlayWindowLease.Kind.GRANT -> grant = requestedSeconds   // minted, not spent
                }
                merged.syncWalletMirrors()
                merged.revision = maxOf(local.revision, cloud.revision) + 1
                merged.lastModifiedAt = AppleTime.now()
                merged.deviceID = myID
                txn.set(sRef, merged.toFirestore(), SetOptions.merge())
                // 5. The lease — a full set (NOT merge) so a stale releaseRequestedBy can't survive.
                txn.set(wRef, hashMapOf<String, Any?>(
                    "schemaVersion" to 1, "state" to "open",
                    "leaseID" to candidate, "ownerDeviceID" to myID,
                    "ownerKind" to ownerKind, "ownerName" to ownerName,
                    "kind" to kind.raw, "grantedSeconds" to grant,
                    "startedAt" to FieldValue.serverTimestamp(),
                    "lastReleasedLeaseID" to (held.leaseID ?: wData["lastReleasedLeaseID"]),
                ))
                val delta = if (policy == ClaimPolicy.ADOPT_LOCAL || kind == PlayWindowLease.Kind.GRANT) 0 else -grant
                ClaimTx.Ok(candidate, grant, walletOf(merged, baseSeq, delta, kind == PlayWindowLease.Kind.GIFT))
            }.await()
        } catch (e: Exception) {
            return ClaimOutcome.Offline
        }
        return when (result) {
            is ClaimTx.Ok -> ClaimOutcome.Granted(result.leaseID, result.seconds, result.wallet)
            is ClaimTx.Held -> ClaimOutcome.HeldElsewhere(result.kind, result.seconds)
            ClaimTx.Insufficient -> ClaimOutcome.Insufficient
            null -> ClaimOutcome.Offline
        }
    }

    // ── RELEASE (close) ─────────────────────────────────────────────────────
    /**
     * Return the unused remainder (clamped to granted − elapsed by the SERVER
     * start) and clear the lease — idempotent. Adopts the result into the live
     * store only while this device is still being that child, and only on a
     * COMMITTED transaction (adopting an uncommitted revision froze iPads).
     */
    /** [asOfUnix]: measure the leftover at that moment (a window closed by a school time / bedtime). */
    suspend fun release(childID: String, leaseID: String, localRemainingSeconds: Int, asOfUnix: Double? = null): Boolean {
        val wRef = windowRef(childID); val sRef = stateRef(childID)
        // iOS merges its live store in unconditionally; here only when this device
        // IS that child, so a parent-side settle can never fold another child's
        // store into this child's document.
        val isActive = host.activeChildID == childID
        val localRevision = if (isActive) host.localRevision else 0
        val local = if (isActive) host.captureSnapshot() else null
        val baseSeq = if (isActive) host.localEditSeq else 0
        val myID = me
        val wallet = try {
            db.runTransaction { txn ->
                val wData: Map<String, Any?> = txn.get(wRef).data ?: emptyMap()
                if (wData["lastReleasedLeaseID"] as? String == leaseID) return@runTransaction null
                if (wData["leaseID"] as? String != leaseID) return@runTransaction null
                val remote = txn.get(sRef).data?.let { ProgressSnapshot.fromFirestore(it) } ?: ProgressSnapshot.blank()
                val held = PlayWindowLease.from(wData)
                val elapsed = held.startedAt?.let { maxOf(0, ((asOfUnix ?: AppleTime.nowUnix()) - it).toInt()) } ?: 0
                val refund = maxOf(0, minOf(localRemainingSeconds, held.grantedSeconds - elapsed))
                // Merge our local state up, THEN add the refund (by raising "in").
                val cloud = if (local != null) ProgressSnapshot.ratchetMerged(local, remote) else remote.copy()
                if (refund > 0) when (held.kind) {
                    PlayWindowLease.Kind.EARNED -> {
                        cloud.earnedSecondsIn = (cloud.earnedSecondsIn ?: 0) + refund
                        cloud.minutesUnlockedToday = maxOf(0, cloud.minutesUnlockedToday - refund / 60)
                    }
                    PlayWindowLease.Kind.GIFT -> cloud.giftSecondsIn = (cloud.giftSecondsIn ?: 0) + refund
                    PlayWindowLease.Kind.GRANT -> Unit
                }
                cloud.syncWalletMirrors()
                cloud.revision = maxOf(localRevision, cloud.revision) + 1
                cloud.lastModifiedAt = AppleTime.now()
                cloud.deviceID = myID
                txn.set(sRef, cloud.toFirestore(), SetOptions.merge())
                txn.set(wRef, hashMapOf<String, Any?>(
                    "state" to "idle",
                    "leaseID" to FieldValue.delete(), "ownerDeviceID" to FieldValue.delete(),
                    "ownerKind" to FieldValue.delete(), "ownerName" to FieldValue.delete(),
                    "grantedSeconds" to FieldValue.delete(), "startedAt" to FieldValue.delete(),
                    "releaseRequestedBy" to FieldValue.delete(), "releaseRequestedAt" to FieldValue.delete(),
                    "lastReleasedLeaseID" to leaseID,
                    "lastReleasedAt" to FieldValue.serverTimestamp(),
                    "refundedSeconds" to refund,
                ), SetOptions.merge())
                walletOf(cloud, baseSeq, if (held.kind == PlayWindowLease.Kind.GRANT) 0 else refund, held.kind == PlayWindowLease.Kind.GIFT)
            }.await()
        } catch (e: Exception) {
            return false
        }
        if (wallet != null && host.activeChildID == childID) host.applyClaimedWallet(wallet)
        return true
    }

    /**
     * PARENT closes a child's window with no cooperation from the holding device:
     * give the device the first word (15 s), then settle at the server's clock.
     */
    suspend fun parentRelease(childID: String, afterGrace: Boolean = true) {
        if (!enabled()) return
        val ref = windowRef(childID)
        if (afterGrace) {
            repeat(PARENT_RELEASE_GRACE_SECONDS / 3) {
                delay(3000)
                val d = runCatching { ref.get().await().data }.getOrNull() ?: emptyMap()
                if (!PlayWindowLease.from(d).isHeld) return
            }
        }
        val d = runCatching { ref.get().await().data }.getOrNull() ?: emptyMap()
        val l = PlayWindowLease.from(d)
        val lid = l.leaseID
        if (!l.isHeld || lid == null) return
        release(childID, lid, Int.MAX_VALUE)
    }

    /** Mark the lease "releasing"; the owner's release is the proof it closed. */
    suspend fun requestRelease(childID: String): Boolean {
        val wRef = windowRef(childID)
        val myID = me
        return try {
            db.runTransaction { txn ->
                val held = PlayWindowLease.from(txn.get(wRef).data ?: emptyMap())
                if (!held.isHeld || held.isMine(myID)) return@runTransaction false
                txn.set(wRef, hashMapOf<String, Any?>(
                    "state" to "releasing",
                    "releaseRequestedBy" to myID,
                    "releaseRequestedAt" to FieldValue.serverTimestamp(),
                ), SetOptions.merge())
                true
            }.await() == true
        } catch (e: Exception) { false }
    }

    companion object {
        const val PARENT_RELEASE_GRACE_SECONDS = 15
    }
}

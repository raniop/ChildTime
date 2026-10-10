package com.rani.tofy.kid.core

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.provider.Settings
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.rani.tofy.BuildConfig
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.confirmedMerge
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import java.time.ZoneId
import java.util.UUID

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  KidSync — the child device's Firestore side
 *  (ports RemoteSyncManager.swift child paths + HouseholdManager device rows +
 *   LiveEventReporter.swift)
 * ════════════════════════════════════════════════════════════════════════════
 *
 * Owned by [KidSession]; the UI talks to KidSession, not to this class.
 *
 *  • state/current — debounced (3 s, coalesced) ratchet-merge UPLOAD transaction
 *    (skip when the cloud already holds everything; revision = max + 1; the
 *    landed generation is adopted), and a listener that merges remote snapshots
 *    (own echoes skipped by deviceID) and re-uploads when we were ahead.
 *  • children/{id} — listener + the parent COMMANDS, consumed exactly once in
 *    read-all-then-write transactions, field-for-field iOS:
 *      pendingGiftAdjustment  → giftSecondsIn/Out, ack giftAppliedAt = giftSentAt
 *      pendingMinuteAdjustment→ earnedSecondsIn/Out (then pushed immediately)
 *      resetRequestedAt       → local reset + authoritative blank (higher resetEpoch, plain set)
 *      revokeGiftAt           → wipe all parent time, ack revokeGiftAppliedAt, THEN a newer gift
 *    A command is never consumed if the wallet can't be paid (no state doc).
 *  • childDevices/{childID}_{installID} — registration every 15 s (heartbeat),
 *    window state (windowEndsAt/frozenSeconds/windowIsManual), and the device's
 *    own-row watcher: removed → reset, remoteLockAt / remoteUnlockAt(+Minutes,
 *    ≤6 h fresh) applied in STAMP order, appRemovalUnlockAt — each acked with
 *    its `…AppliedAt` (and lost acks healed).
 *  • children/{id}/events — LiveEventReporter rows for the parent's feed/push.
 *
 * Dates: state/current uses Apple-reference seconds (see ProgressSnapshot);
 * every other doc here uses UNIX seconds, exactly like iOS.
 */

/** Stable per-install identity + device labels (ChildDevice.swift DeviceIdentity). */
@SuppressLint("StaticFieldLeak")
object KidIdentity {
    private const val PREFS = "tofy.kid"
    private const val KEY = "kid.installID"
    @Volatile private var cached: String? = null
    private var prefs: SharedPreferences? = null
    private var context: Context? = null
    @Volatile var fcmToken: String? = null

    fun init(ctx: Context) {
        context = ctx.applicationContext
        prefs = ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        ProgressSnapshot.defaultDeviceID = installID
    }

    internal val sharedPrefs: SharedPreferences? get() = prefs

    /** UPPERCASE UUID like iOS's uuidString; survives relaunches, resets on reinstall. */
    val installID: String
        get() = cached ?: synchronized(this) {
            cached ?: (prefs?.getString(KEY, null) ?: UUID.randomUUID().toString().uppercase().also { id ->
                prefs?.edit()?.putString(KEY, id)?.apply()
            }).also { cached = it }
        }

    /**
     * iOS writes "ipad" | "iphone" | "other" and every reader (dashboard labels,
     * Cloud Function push copy) maps anything else to "the other device". An
     * Android phone or tablet is neither an iPad nor an iPhone, so "other" is
     * the one value that reads correctly everywhere.
     */
    const val kind = "other"

    /** The user-visible device name when set, else the model ("Pixel 7"). Latin on purpose, like iOS. */
    val friendlyName: String
        get() {
            val ctx = context
            val named = ctx?.let { runCatching { Settings.Global.getString(it.contentResolver, "device_name") }.getOrNull() }
            return named?.takeIf { it.isNotBlank() } ?: Build.MODEL ?: "Android"
        }

    val systemVersion: String get() = "Android ${Build.VERSION.RELEASE}"
    val appVersion: String get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
}

/** The Android clock: wall clock + elapsedRealtime (monotonic, survives clock changes). */
object AndroidKidClock : KidClock {
    override fun nowUnix(): Double = System.currentTimeMillis() / 1000.0
    override fun uptimeSecs(): Double = SystemClock.elapsedRealtime() / 1000.0
    override val zone: ZoneId get() = ZoneId.systemDefault()
}

class KidSync internal constructor(
    private val session: KidSession,
    private val scope: CoroutineScope,
) {
    private val db: FirebaseFirestore get() = FirebaseFirestore.getInstance()
    private val me: String get() = KidIdentity.installID
    private val uid: String? get() = FirebaseAuth.getInstance().currentUser?.uid

    private var childID: String? = null
    var householdID: String? = null
        private set
    private val regs = mutableListOf<ListenerRegistration>()
    private var ownDeviceReg: ListenerRegistration? = null
    private var uploadJob: Job? = null
    private var heartbeatJob: Job? = null
    private var retries = 0

    private val _childDoc = MutableStateFlow<Map<String, Any?>?>(null)
    /** Live children/{childID} doc (name, gender, dailyCapMinutes, difficultyByTopic, …). */
    val childDoc: StateFlow<Map<String, Any?>?> = _childDoc

    var syncActive: Boolean = false
        private set
    /** Unix seconds of the last successful upload (cloudStateIsFresh). */
    var lastUploadAt: Double? = null
        private set
    var lastError: String? = null
        private set

    private fun childRef(cid: String) = db.collection("children").document(cid)
    private fun stateRef(cid: String) = childRef(cid).collection("state").document("current")
    private fun deviceRef(cid: String) = db.collection("childDevices").document("${cid}_$me")

    // ── lifecycle ───────────────────────────────────────────────────────────
    fun start(cid: String) {
        stop()
        childID = cid
        syncActive = true
        retries = 0
        attachListeners(cid)
        startHeartbeat()
        uploadSoon()
    }

    fun stop() {
        regs.forEach { it.remove() }; regs.clear()
        ownDeviceReg?.remove(); ownDeviceReg = null
        uploadJob?.cancel(); uploadJob = null
        heartbeatJob?.cancel(); heartbeatJob = null
        childID = null
        householdID = null
        _childDoc.value = null
        syncActive = false
    }

    fun pauseHeartbeat() { heartbeatJob?.cancel(); heartbeatJob = null }
    fun startHeartbeat() {
        if (heartbeatJob?.isActive == true) return
        heartbeatJob = scope.launch {
            while (isActive) {
                registerDevice()
                delay(15_000)
            }
        }
    }

    /** Re-attach every listener now (after a join, when earlier ones were refused). */
    fun resubscribe() {
        val cid = childID ?: return
        regs.forEach { it.remove() }; regs.clear()
        retries = 0
        attachListeners(cid)
    }

    private fun attachListeners(cid: String) {
        regs += stateRef(cid).addSnapshotListener { doc, err ->
            if (err != null) { listenerFailed(cid); return@addSnapshotListener }
            val raw = doc?.data ?: return@addSnapshotListener
            if (childID != cid) return@addSnapshotListener
            handleRemoteSnapshot(ProgressSnapshot.fromFirestore(raw))
        }
        regs += childRef(cid).addSnapshotListener { doc, err ->
            if (err != null) { listenerFailed(cid); return@addSnapshotListener }
            if (childID != cid) return@addSnapshotListener
            retries = 0
            val d = doc?.data ?: return@addSnapshotListener
            _childDoc.value = d
            (d["householdID"] as? String)?.let { householdID = it }
            session.onChildDoc(d)
            consumeCommands(cid, d)
        }
    }

    /**
     * A refused listener (permission-denied before this device's uid reached the
     * household) is dead for good — free it and retry with a short backoff.
     */
    private fun listenerFailed(cid: String) {
        regs.forEach { it.remove() }; regs.clear()
        val n = ++retries
        if (n > 8) return
        scope.launch {
            delay(minOf(30, 2 * n) * 1000L)
            if (childID == cid && regs.isEmpty()) attachListeners(cid)
        }
    }

    // ── state/current: upload + merge ───────────────────────────────────────
    /** Debounced upload — coalesced, never restarted, so fast answering can't starve it. */
    fun uploadSoon() {
        if (uploadJob?.isActive == true) return
        uploadJob = scope.launch {
            delay(3000)
            uploadJob = null
            upload()
        }
    }

    /** Ratchet-merge upload transaction — an upload can only raise the cloud, never lower it. */
    suspend fun upload() {
        val cid = childID ?: return
        val e = session.engineFor(cid) ?: return   // the store must hold THIS child's data
        val local = e.capture()
        val seqAtCapture = e.localEditSeq
        val ref = stateRef(cid)
        val myID = me
        // The transaction returns what is now in the cloud. Adopting only its
        // REVISION was a bug: the merge folds the cloud's data (stars, wallet…)
        // into the write, and our listener skips its own echo — so a freshly
        // bound device kept showing zeros while the cloud held the real numbers.
        val landed: ProgressSnapshot? = try {
            db.runTransaction { txn ->
                val cloudRaw = txn.get(ref).data
                if (cloudRaw == null) {
                    txn.set(ref, local.toFirestore(), SetOptions.merge())
                    return@runTransaction local
                }
                val cloud = ProgressSnapshot.fromFirestore(cloudRaw)
                val merged = ProgressSnapshot.ratchetMerged(local, cloud)
                if (ProgressSnapshot.sameProgressData(merged, cloud)) return@runTransaction cloud
                merged.revision = maxOf(local.revision, cloud.revision) + 1
                merged.lastModifiedAt = AppleTime.now()
                merged.deviceID = myID
                txn.set(ref, merged.toFirestore(), SetOptions.merge())
                merged
            }.await()
        } catch (ex: Exception) {
            lastError = ex.message
            return
        }
        lastUploadAt = AppleTime.nowUnix()
        lastError = null
        if (landed != null) session.engineFor(cid)?.let { eng ->
            val editedSince = eng.localEditSeq != seqAtCapture
            // Fold the cloud result in (ratchet = idempotent; local edits made
            // meanwhile survive), then take its generation.
            session.mergeRemote(cid, landed)
            session.adoptUploaded(cid, landed.revision, editedSince)
        }
    }

    private fun handleRemoteSnapshot(snap: ProgressSnapshot) {
        val cid = childID ?: return
        if (snap.deviceID == me) return   // our own echo — never re-apply
        val needsUpload = session.mergeRemote(cid, snap)
        if (needsUpload) scope.launch { upload() }
    }

    // ── parent commands on children/{id} ────────────────────────────────────
    private fun consumeCommands(cid: String, d: Map<String, Any?>) {
        val adj = (d["pendingMinuteAdjustment"] as? Number)?.toInt() ?: 0
        val gift = (d["pendingGiftAdjustment"] as? Number)?.toInt() ?: 0
        val revokePending = d["revokeGiftAt"] != null
        if (adj != 0) applyPendingMinuteGrant(cid)
        if (gift != 0 && !revokePending) applyPendingGift(cid)   // else: applied after the revoke
        if (d["resetRequestedAt"] != null) applyPendingReset(cid)
        if (revokePending) applyPendingGiftRevoke(cid)
    }

    /** Kid Mode entry / foreground: catch up on commands issued before we were listening. */
    suspend fun consumePendingCommandsNow() {
        val cid = childID ?: return
        val d = runCatching { childRef(cid).get().await().data }.getOrNull() ?: return
        consumeCommands(cid, d)
    }

    /** 💝 Gift command → the GIFT pocket, exactly once (read + zero in one transaction). */
    private fun applyPendingGift(cid: String) {
        val ref = childRef(cid); val sRef = stateRef(cid); val myID = me
        scope.launch {
            val adj = try {
                db.runTransaction { txn ->
                    // EVERY read first.
                    val doc = txn.get(ref).data
                    val stateDoc = txn.get(sRef).data
                    val a = (doc?.get("pendingGiftAdjustment") as? Number)?.toInt() ?: 0
                    if (a == 0) return@runTransaction 0
                    // Can't credit the wallet → don't consume the command.
                    val cloud = stateDoc?.let { ProgressSnapshot.fromFirestore(it) } ?: return@runTransaction 0
                    val update = hashMapOf<String, Any?>("pendingGiftAdjustment" to 0)
                    (doc?.get("giftSentAt") as? Number)?.let { update["giftAppliedAt"] = it.toDouble() }
                    txn.update(ref, update)
                    if (a > 0) cloud.giftSecondsIn = (cloud.giftSecondsIn ?: 0) + a * 60
                    else cloud.giftSecondsOut = (cloud.giftSecondsOut ?: 0) + minOf(-a * 60, cloud.giftSecondsAvailable)
                    cloud.syncWalletMirrors()
                    cloud.revision += 1
                    cloud.lastModifiedAt = AppleTime.now()
                    cloud.deviceID = myID
                    txn.set(sRef, cloud.toFirestore(), SetOptions.merge())
                    a
                }.await() ?: 0
            } catch (ex: Exception) { 0 }
            if (adj != 0) session.onGiftApplied(cid, adj)
        }
    }

    /** ± earned minutes (parent control / approved chore) — exactly once, then published NOW. */
    private fun applyPendingMinuteGrant(cid: String) {
        val ref = childRef(cid); val sRef = stateRef(cid); val myID = me
        scope.launch {
            val adj = try {
                db.runTransaction { txn ->
                    val doc = txn.get(ref).data
                    val stateDoc = txn.get(sRef).data
                    val a = (doc?.get("pendingMinuteAdjustment") as? Number)?.toInt() ?: 0
                    if (a == 0) return@runTransaction 0
                    val cloud = stateDoc?.let { ProgressSnapshot.fromFirestore(it) } ?: return@runTransaction 0
                    txn.update(ref, hashMapOf<String, Any?>("pendingMinuteAdjustment" to 0))
                    if (a > 0) cloud.earnedSecondsIn = (cloud.earnedSecondsIn ?: 0) + a * 60
                    else cloud.earnedSecondsOut = (cloud.earnedSecondsOut ?: 0) + minOf(-a * 60, cloud.earnedSecondsAvailable)
                    cloud.syncWalletMirrors()
                    cloud.revision += 1
                    cloud.lastModifiedAt = AppleTime.now()
                    cloud.deviceID = myID
                    txn.set(sRef, cloud.toFirestore(), SetOptions.merge())
                    a
                }.await() ?: 0
            } catch (ex: Exception) { 0 }
            if (adj != 0) {
                session.onMinutesApplied(cid, adj)
                upload()   // the command is already zeroed — the credit must not sit only here
            }
        }
    }

    /** 🧹 Parent reset: consume once, wipe locally, then write the authoritative blank. */
    private fun applyPendingReset(cid: String) {
        val ref = childRef(cid)
        scope.launch {
            val requested = try {
                db.runTransaction { txn ->
                    val r = txn.get(ref).data?.get("resetRequestedAt") != null
                    if (r) txn.update(ref, hashMapOf<String, Any?>("resetRequestedAt" to FieldValue.delete()))
                    r
                }.await() == true
            } catch (ex: Exception) { false }
            if (!requested) return@launch
            session.onResetApplied(cid)
            writeBlankCloudState(cid)
        }
    }

    /**
     * A plain (non-ratchet) set of a blank at a revision above both sides and a
     * HIGHER resetEpoch — the wipe then wins wholesale on every device.
     */
    private suspend fun writeBlankCloudState(cid: String) {
        val e = session.engineFor(cid) ?: return
        val localRev = e.snapshot.revision
        val localEpoch = e.snapshot.resetEpoch
        val ref = stateRef(cid); val myID = me
        val res = try {
            db.runTransaction { txn ->
                val cloud = txn.get(ref).data?.let { ProgressSnapshot.fromFirestore(it) }
                val blank = ProgressSnapshot(deviceID = myID, lastModifiedAt = AppleTime.now())
                blank.revision = maxOf(cloud?.revision ?: 0, localRev) + 1
                blank.resetEpoch = maxOf(cloud?.resetEpoch ?: 0, localEpoch) + 1
                txn.set(ref, blank.toFirestore())   // NOT merge
                blank.revision to blank.resetEpoch
            }.await()
        } catch (ex: Exception) { lastError = ex.message; null } ?: return
        session.adoptBlankWrite(cid, res.first, res.second)
    }

    /** 💝🔒 Parent revoked all gift time: consume + ack in ONE transaction, then a newer gift. */
    private fun applyPendingGiftRevoke(cid: String) {
        val ref = childRef(cid)
        scope.launch {
            val stamp = try {
                db.runTransaction { txn ->
                    val s = (txn.get(ref).data?.get("revokeGiftAt") as? Number)?.toDouble() ?: return@runTransaction null
                    txn.update(ref, hashMapOf<String, Any?>("revokeGiftAt" to FieldValue.delete(), "revokeGiftAppliedAt" to s))
                    s
                }.await()
            } catch (ex: Exception) { null } ?: return@launch
            session.onGiftRevoked(cid, stamp)
            upload()
            applyPendingGift(cid)   // order: revoke first, THEN any gift given after it
        }
    }

    // ── childDevices row ────────────────────────────────────────────────────
    /** Register / refresh THIS device under the child — idempotent, keyed by install ID. */
    suspend fun registerDevice() {
        val cid = childID ?: return
        val hid = householdID ?: return
        val u = uid ?: return
        val ref = deviceRef(cid)
        val now = AppleTime.nowUnix()
        if (KidIdentity.fcmToken == null) {
            KidIdentity.fcmToken = withTimeoutOrNull(5000) { runCatching { FirebaseMessaging.getInstance().token.await() }.getOrNull() }
        }
        val existing = withTimeoutOrNull(5000) { runCatching { ref.get().await() }.getOrNull() }
        if (existing?.getBoolean("removed") == true) { session.onDeviceRemoved(cid); return }
        val joinedAt = (existing?.get("joinedAt") as? Number)?.toDouble() ?: now
        val data = hashMapOf<String, Any?>(
            "id" to "${cid}_$me", "childID" to cid, "householdID" to hid,
            // platform: lets the server word pushes for Android ("turn the lock back on in Accessibility",
            // not "Screen Time"). iOS rows have no such field.
            "platform" to "android",
            "deviceID" to me, "name" to KidIdentity.friendlyName, "kind" to KidIdentity.kind,
            "systemVersion" to KidIdentity.systemVersion,
            "joinedAt" to joinedAt, "lastSeenAt" to now,
            "ownerUID" to u,
        )
        KidIdentity.fcmToken?.let { data["fcmToken"] = it }
        session.shieldAuthorized?.let { data["shieldAuthorized"] = it }
        session.newAppsLocked?.let { data["newAppsLocked"] = it }
        val ok = withTimeoutOrNull(5000) { runCatching { ref.set(data, SetOptions.merge()).await() }.isSuccess } ?: true
        // A PARENT's phone in Kid Mode: keep its own "parent_<install>" row fresh,
        // AFTER this row — that order is what tells the two apart (see
        // AccountRepository.registerParentDevice).
        if (com.rani.tofy.DeviceRole.role == com.rani.tofy.DeviceRole.Role.PARENT && com.rani.tofy.DeviceRole.kidModeChildID != null) {
            withTimeoutOrNull(6000) { com.rani.tofy.data.AccountRepository.registerParentDevice(hid) }
        }
        if (ok) watchOwnDevice(cid)
        ref.set(hashMapOf<String, Any?>("appVersion" to KidIdentity.appVersion), SetOptions.merge())
        reportTimeState()
    }

    /**
     * The window state on our row — the parent's live countdown and the sibling
     * device's transfer card. Always carries childID/householdID so a merge onto
     * a missing row never creates an unreadable doc. Confirmed + self-healing.
     */
    fun reportTimeState() {
        val cid = childID ?: return
        val hid = householdID ?: return
        val e = session.engineFor(cid) ?: return
        val l = e.local
        val data = hashMapOf<String, Any?>(
            "frozenSeconds" to l.manualPausedSeconds, "childID" to cid,
            "householdID" to hid, "deviceID" to me,
        )
        val end = l.unlockEndsAt
        if (end != null && end > AppleTime.nowUnix()) {
            data["windowEndsAt"] = end
            data["windowIsManual"] = l.unlockIsManual
        } else {
            data["windowEndsAt"] = FieldValue.delete()
            data["windowIsManual"] = FieldValue.delete()
        }
        val ref = deviceRef(cid)
        scope.launch { confirmedWithHeal(ref, data) }
    }

    /** Doorbell for a transfer: stamp remoteLockAt on the OTHER device's row. */
    fun lockOtherDeviceWindow(deviceRowID: String) {
        val ref = db.collection("childDevices").document(deviceRowID)
        scope.launch { confirmedWithHeal(ref, mapOf("remoteLockAt" to AppleTime.nowUnix())) }
    }

    private suspend fun confirmedWithHeal(ref: DocumentReference, fields: Map<String, Any?>): WriteOutcome {
        var out = confirmedMerge(ref, fields)
        if (out == WriteOutcome.DENIED) { reassertMembership(); out = confirmedMerge(ref, fields) }
        return out
    }

    /** Re-add our uid to the household (the rules let anyone add ONLY themselves). */
    suspend fun reassertMembership() {
        val u = uid ?: return; val hid = householdID ?: return
        runCatching { db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(u)).await() }
    }

    /** Watch OUR row: removal, remote lock/unlock (stamp order), app-removal window. */
    private fun watchOwnDevice(cid: String) {
        if (ownDeviceReg != null) return
        val docID = "${cid}_$me"
        ownDeviceReg = deviceRef(cid).addSnapshotListener { snap, _ ->
            val data = snap?.data ?: return@addSnapshotListener
            if (childID != cid) return@addSnapshotListener
            if (data["removed"] == true) { session.onDeviceRemoved(cid); return@addSnapshotListener }
            val lockAt = (data["remoteLockAt"] as? Number)?.toDouble() ?: 0.0
            val unlockAt = (data["remoteUnlockAt"] as? Number)?.toDouble() ?: 0.0
            if (lockAt <= unlockAt) {
                applyRemoteLockIfNeeded(data, docID); applyRemoteUnlockIfNeeded(data, docID)
            } else {
                applyRemoteUnlockIfNeeded(data, docID); applyRemoteLockIfNeeded(data, docID)
            }
            applyRemoteAppRemovalIfNeeded(data, docID)
        }
    }

    private fun ack(docID: String, field: String, stamp: Double) {
        db.collection("childDevices").document(docID).set(hashMapOf<String, Any?>(field to stamp), SetOptions.merge())
    }

    // Device-global like iOS UserDefaults; a String keeps the full Double precision.
    private fun lastStamp(key: String): Double = KidIdentity.sharedPrefs?.getString(key, null)?.toDoubleOrNull() ?: 0.0
    private fun setLastStamp(key: String, v: Double) { KidIdentity.sharedPrefs?.edit()?.putString(key, v.toString())?.apply() }

    /** A parent re-locked this device. Exactly once per stamp; locks never expire. */
    private fun applyRemoteLockIfNeeded(data: Map<String, Any?>, docID: String) {
        val at = (data["remoteLockAt"] as? Number)?.toDouble() ?: return
        val last = lastStamp(LAST_LOCK)
        if (at <= last && ((data["remoteLockAppliedAt"] as? Number)?.toDouble() ?: 0.0) < at) ack(docID, "remoteLockAppliedAt", at)
        if (at <= last) return
        setLastStamp(LAST_LOCK, at)
        ack(docID, "remoteLockAppliedAt", at)
        scope.launch { session.onRemoteLock() }
    }

    /** A parent opened screen time from afar: once per stamp, only within 6 h. */
    private fun applyRemoteUnlockIfNeeded(data: Map<String, Any?>, docID: String) {
        val at = (data["remoteUnlockAt"] as? Number)?.toDouble() ?: return
        val minutes = (data["remoteUnlockMinutes"] as? Number)?.toInt() ?: return
        if (minutes <= 0) return
        val last = lastStamp(LAST_UNLOCK)
        val now = AppleTime.nowUnix()
        if (at <= last && ((data["remoteUnlockAppliedAt"] as? Number)?.toDouble() ?: 0.0) < at) ack(docID, "remoteUnlockAppliedAt", at)
        if (at <= last || now - at >= REMOTE_FRESHNESS) return
        setLastStamp(LAST_UNLOCK, at)
        ack(docID, "remoteUnlockAppliedAt", at)
        scope.launch { session.onRemoteUnlock(minutes) }
    }

    /** A parent allowed deleting apps for 5 minutes (iOS-only meaning; acked so the parent sees ✅). */
    private fun applyRemoteAppRemovalIfNeeded(data: Map<String, Any?>, docID: String) {
        val at = (data["appRemovalUnlockAt"] as? Number)?.toDouble() ?: return
        val last = lastStamp(LAST_APP_REMOVAL)
        val now = AppleTime.nowUnix()
        if (at <= last && ((data["appRemovalAppliedAt"] as? Number)?.toDouble() ?: 0.0) < at) ack(docID, "appRemovalAppliedAt", at)
        if (at <= last || now - at >= REMOTE_FRESHNESS) return
        setLastStamp(LAST_APP_REMOVAL, at)
        ack(docID, "appRemovalAppliedAt", at)
        session.onAppRemovalWindow(now + 5 * 60)
    }

    /** This device was removed: delete our tombstoned row (local wipe is KidSession's). */
    fun deleteOwnRow(cid: String) {
        runCatching { deviceRef(cid).delete() }
    }

    // ── LiveEventReporter ───────────────────────────────────────────────────
    /** One row in children/{id}/events — the parent's activity feed + push. */
    fun reportEvent(type: String, value: String? = null, topicName: String? = null, extra: Map<String, Any?> = emptyMap()) {
        val cid = childID ?: return
        val u = uid ?: return
        val doc = _childDoc.value
        val payload = hashMapOf<String, Any?>(
            "type" to type,
            "childName" to (doc?.get("name") as? String ?: ""),
            "gender" to (doc?.get("gender") as? String ?: ""),
            "originUID" to u,
            "originToken" to (KidIdentity.fcmToken ?: ""),
            "deviceID" to me,
            "deviceKind" to KidIdentity.kind,
            "deviceName" to KidIdentity.friendlyName,
            "createdAt" to AppleTime.nowUnix(),
        )
        value?.let { payload["value"] = it }
        topicName?.let { payload["topic"] = it }
        payload.putAll(extra)
        childRef(cid).collection("events").add(payload)
    }

    companion object {
        private const val LAST_LOCK = "lastRemoteLockAt"
        private const val LAST_UNLOCK = "lastRemoteUnlockAt"
        private const val LAST_APP_REMOVAL = "lastRemoteAppRemovalAt"
        /** How long a remote "open now" / app-removal command stays applicable. */
        const val REMOTE_FRESHNESS = 6 * 3600.0
    }
}

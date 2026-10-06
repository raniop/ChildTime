package com.rani.tofy.kid.core

import android.content.Context
import android.content.SharedPreferences
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.data.QuietHours
import com.rani.tofy.data.QuietOccurrence
import com.rani.tofy.data.map
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  KidSession — the ONE facade the kid UI builds on
 * ════════════════════════════════════════════════════════════════════════════
 *
 * Binds this device to a child (a child device, or later Kid Mode on a parent
 * phone) and wires [ProgressEngine] (rules) + [KidSync] (Firestore) +
 * [PlayWindowLeaseManager] (the one play window). Everything runs on Main.
 *
 * SETUP
 *   KidSession.init(context)                 once (Application.onCreate is fine)
 *   KidSession.bind(childID)                 start being that child (loads the local
 *                                            copy, attaches listeners, heartbeat)
 *   KidSession.unbind()                      stop (keeps the local copy)
 *   KidSession.onForeground() / onBackground()
 *
 * OBSERVE
 *   state: StateFlow<KidState?>              snapshot (stars, diamonds, wallets, today…),
 *                                            local window state, session one-shots
 *   lease: StateFlow<PlayWindowLease>        the family-wide window (held elsewhere? → transfer card)
 *   childDoc: StateFlow<Map?>                children/{id} (name, gender, settings…)
 *   opening: StateFlow<Opening?>             "we're opening it" while a claim runs
 *   events: SharedFlow<KidEvent>             remote lock/unlock, gift arrived, reset, removed…
 *   engine()                                 read-only helpers (redeemableSecondsNow,
 *                                            openableSeconds, atDailyCap, dailyChallenge…)
 *
 * ACT
 *   answerCorrect(ctx, …) → AnswerOutcome    answerWrong(topic, …) → seconds lost
 *   answer(correct, topic, …)                convenience over the two
 *   miniGameAnswer(…)                        MiniGameLedger.record
 *   edit { engine -> … }                     any other engine op (chest, shop, hint, worlds…)
 *   startSession()                           registerSessionToday + resetSessionScore + beginSitting
 *   openEarned() / openGift() / transferHere()   suspend → OpenResult
 *   stop() → banked minutes                  "עצור ושמור" (releases the lease)
 *   consumePendingCommandsNow() · pushNow() · reportEvent(type, …)
 *
 * The UI shows its own (tr()) copy for each OpenResult — the iOS lines are
 * noted on each case. No failure language toward kids.
 */

/** Things the UI must react to (shield/lock UI, toasts, navigation). */
sealed class KidEvent {
    /** A parent re-locked this device — the window was stopped and saved. */
    data object RemoteLock : KidEvent()
    /** A parent opened screen time from afar (a fixed manual window is now open). */
    data class RemoteUnlock(val minutes: Int) : KidEvent()
    /** The child's other device took the window ("transfer"); we stopped and saved. */
    data object WindowTakenByOtherDevice : KidEvent()
    /** The open window ran out. */
    data object WindowEnded : KidEvent()
    data class GiftArrived(val minutes: Int) : KidEvent()
    data class MinutesAdjusted(val delta: Int) : KidEvent()
    /** Parent reset this child (UI should also clear question memory). */
    data class ResetApplied(val windowWasOpen: Boolean) : KidEvent()
    data class GiftRevoked(val closedWindow: Boolean) : KidEvent()
    /** iOS-only meaning (delete apps for 5 min) — acked; Android may ignore. */
    data class AppRemovalWindow(val untilUnix: Double) : KidEvent()
    /** The parent removed this device — local data wiped; go back to the start screen. */
    data object DeviceRemoved : KidEvent()
    /** A claim hasn't answered for 20 s ("רֶגַע, הָאִינְטֶרְנֶט קְצָת אִטִּי — נְנַסֶּה שׁוּב? 😊"). */
    data object OpenSlow : KidEvent()
    data class Progress(val event: ProgressEvent) : KidEvent()
}

sealed class OpenResult {
    data class Opened(val seconds: Int, val gift: Boolean) : OpenResult()
    /** "הַזְּמַן שֶׁלְּךָ פָּתוּחַ עַכְשָׁיו בְּמַכְשִׁיר אַחֵר 🎮" — offer transferHere(). */
    data class HeldElsewhere(val ownerKind: String, val secondsLeft: Int) : OpenResult()
    /** Earned: "עוֹד קְצָת דַּקּוֹת וְנִפְתַּח לְךָ! 💪". */
    data object Insufficient : OpenResult()
    /** "רֶגַע, לֹא הִצְלַחְנוּ לִפְתֹּחַ עַכְשָׁיו — נְנַסֶּה שׁוּב 😊" (earned) / gift: see tellParent. */
    data class Failed(val tellParent: Boolean = false) : OpenResult()
    data object AlreadyOpen : OpenResult()
    data object NothingToOpen : OpenResult()
    data object Busy : OpenResult()
    /** 🏫🌙 Inside school time / bedtime: "…הַדַּקּוֹת שֶׁלְּךָ מְחַכּוֹת לְךָ בְּ-13:30". */
    data class Quiet(val occurrence: QuietOccurrence) : OpenResult()
}

data class Opening(val gift: Boolean)

object KidSession : LeaseHost {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private var prefs: SharedPreferences? = null
    private var initialized = false

    private var engine: ProgressEngine? = null
    private var childID: String? = null
    /** True when a PARENT phone is being the child (Kid Mode). */
    var kidMode: Boolean = false
        private set
    /** Device-level settings under the per-child overrides (iOS ParentSettings defaults). */
    var baseSettings: KidSettings = KidSettings()
        set(v) { field = v; engine?.settings = KidSettings.fromChildDoc(lastChildDoc ?: emptyMap(), v) }
    private var lastChildDoc: Map<String, Any?>? = null
    /** Reported on the device row; null = not reported (Android has no Screen Time grant). */
    var shieldAuthorized: Boolean? = null
    var newAppsLocked: Boolean? = null

    private lateinit var sync: KidSync
    private lateinit var leases: PlayWindowLeaseManager

    private val _state = MutableStateFlow<KidState?>(null)
    val state: StateFlow<KidState?> = _state
    private val _events = MutableSharedFlow<KidEvent>(extraBufferCapacity = 64)
    val events: SharedFlow<KidEvent> = _events
    private val _opening = MutableStateFlow<Opening?>(null)
    val opening: StateFlow<Opening?> = _opening
    val lease: StateFlow<PlayWindowLease> get() = leases.lease
    val childDoc: StateFlow<Map<String, Any?>?> get() = sync.childDoc

    private var ticker: Job? = null
    private var openingWatchdog: Job? = null
    private var inFlightWatchdog: Job? = null
    private var giftOpenFailureStreak = 0

    fun init(context: Context) {
        if (initialized) return
        initialized = true
        KidIdentity.init(context)
        prefs = context.applicationContext.getSharedPreferences("tofy.kid.state", Context.MODE_PRIVATE)
        sync = KidSync(this, scope)
        leases = PlayWindowLeaseManager(FirebaseFirestore.getInstance(), this, scope) { engine?.settings?.leaseEnabled ?: true }
    }

    /** The bound engine, for read-only helpers (don't mutate it directly — use [edit]). */
    fun engine(): ProgressEngine? = engine
    val boundChildID: String? get() = childID

    // ── binding ─────────────────────────────────────────────────────────────
    fun bind(childID: String, kidMode: Boolean = false) {
        check(initialized) { "KidSession.init(context) first" }
        if (this.childID == childID && this.kidMode == kidMode) return
        unbind()
        this.childID = childID
        this.kidMode = kidMode
        val saved = prefs?.getString(childID, null)?.let { KidPersistence.decode(it) }
        engine = ProgressEngine(baseSettings, AndroidKidClock, KidIdentity.installID, saved?.first, saved?.second)
        publish()
        leases.startIfNeeded(childID)
        sync.start(childID)
        ticker = scope.launch { while (true) { delay(1000); tick() } }
        onForeground()
    }

    fun unbind() {
        val cid = childID ?: return
        // Kid Mode exit is a stop path on iOS too: save the open window (the
        // release transaction settles it in the cloud) before letting go.
        if (kidMode && engine?.isUnlocked == true) stop()
        persist()
        ticker?.cancel(); ticker = null
        sync.stop()
        leases.stop()
        com.rani.tofy.kid.location.KidLocation.bind(null, null)
        engine = null
        childID = null
        lastChildDoc = null
        _state.value = null
        _opening.value = null
        if (kidMode) {
            prefs?.edit()?.remove(cid)?.apply()   // Kid Mode leaves nothing kid-specific behind
            // …nor a device row: the parent's phone published itself as this child's
            // device while Kid Mode was on (iOS removeKidModeDeviceRow). Left behind,
            // it stayed under the child and kept receiving child-device pushes.
            runCatching {
                com.google.firebase.firestore.FirebaseFirestore.getInstance()
                    .collection("childDevices").document("${cid}_${KidIdentity.installID}").delete()
            }
        }
        kidMode = false
    }

    fun onForeground() {
        val cid = childID ?: return
        edit { it.applyDailyRolloverIfNeeded() }
        tick()
        leases.reconcileOfflineWindowIfNeeded(cid)
        sync.startHeartbeat()
        scope.launch { sync.consumePendingCommandsNow() }
    }

    /** App left the foreground: ONE "finished playing" report, heartbeat paused. */
    fun onBackground() {
        edit { it.endSittingAndReport() }
        sync.pauseHeartbeat()
        persist()
    }

    // ── mutation plumbing ───────────────────────────────────────────────────
    /** Run any engine op; publishes, persists, forwards events, schedules the upload. */
    fun <T> edit(block: (ProgressEngine) -> T): T? {
        val e = engine ?: return null
        val seq = e.localEditSeq
        val win = windowKey(e)
        val r = block(e)
        afterChange(e, seq, win)
        return r
    }

    private fun windowKey(e: ProgressEngine) = e.local.let { Triple(it.unlockEndsAt, it.unlockIsManual, it.manualPausedSeconds) }

    private fun afterChange(e: ProgressEngine, seqBefore: Int, windowBefore: Triple<Double?, Boolean, Int>) {
        publish()
        persist()
        for (ev in e.drainEvents()) {
            _events.tryEmit(KidEvent.Progress(ev))
            when (ev) {
                is ProgressEvent.LevelUp -> sync.reportEvent("levelUp", value = ev.level.toString())
                is ProgressEvent.PersonalBest -> sync.reportEvent("personalBest", value = ev.streak.toString())
                ProgressEvent.SessionStart -> sync.reportEvent("sessionStart")
                is ProgressEvent.SessionEnd -> sync.reportEvent("sessionEnd", extra = ev.extra)
                is ProgressEvent.WorldUnlocked -> Unit   // the UI reports it with the world's NAME
            }
        }
        if (e.localEditSeq != seqBefore) sync.uploadSoon()
        if (windowKey(e) != windowBefore) sync.reportTimeState()
    }

    private fun publish() { _state.value = engine?.state }

    private fun persist() {
        val e = engine ?: return; val cid = childID ?: return
        prefs?.edit()?.putString(cid, KidPersistence.encode(e.snapshot, e.local))?.apply()
    }

    // ── answers ─────────────────────────────────────────────────────────────
    fun answerCorrect(
        ctx: AnswerContext, responseMs: Double = 0.0, hadMistakeThisQuestion: Boolean = false,
        hintUsed: Boolean = false, grantsScreenTime: Boolean = true, cycleMultiplier: Double = 1.0,
        affectsAdaptive: Boolean = true,
    ): AnswerOutcome? = edit {
        it.recordCorrect(ctx, responseMs, hadMistakeThisQuestion, hintUsed, grantsScreenTime, cycleMultiplier, affectsAdaptive)
    }

    fun answerWrong(topic: String, hintUsed: Boolean = false, grantsScreenTime: Boolean = true, affectsAdaptive: Boolean = true): Int =
        edit { it.recordWrong(topic, hintUsed, grantsScreenTime, affectsAdaptive) } ?: 0

    /** Convenience: combo = the current streak, like the runner. Returns stars (right) or −seconds (wrong). */
    fun answer(correct: Boolean, topic: String, responseMs: Double = 0.0, hadMistakeThisQuestion: Boolean = false,
               hintUsed: Boolean = false, grantsScreenTime: Boolean = true): Int {
        val e = engine ?: return 0
        return if (correct) answerCorrect(AnswerContext(topic, e.snapshot.currentStreak), responseMs, hadMistakeThisQuestion, hintUsed, grantsScreenTime)?.stars ?: 0
        else -answerWrong(topic, hintUsed, grantsScreenTime)
    }

    fun miniGameAnswer(correct: Boolean, topic: String, responseMs: Double = 0.0, bucket: MiniGameEarnBucket?,
                       surprise: Boolean, retry: Boolean = false): ProgressEngine.MiniGameAnswer =
        edit { it.recordMiniGameAnswer(correct, topic, responseMs, bucket, surprise, retry) } ?: ProgressEngine.MiniGameAnswer()

    /** A fresh token bucket for one mini-game round, on the wall clock. */
    fun newMiniGameBucket(): MiniGameEarnBucket = MiniGameEarnBucket { AndroidKidClock.nowUnix() }

    /** The runner's session start (registerSessionToday + resetSessionScore + beginSitting). */
    fun startSession() {
        edit { it.registerSessionToday(); it.resetSessionScore(); it.beginSitting() }
        scope.launch { sync.registerDevice() }
    }

    // ── the play window ─────────────────────────────────────────────────────
    private val cloudStateIsFresh: Boolean
        get() = sync.syncActive && (sync.lastUploadAt?.let { AppleTime.nowUnix() - it < 120 } ?: false)

    private fun beginOpening(gift: Boolean) {
        _opening.value = Opening(gift)
        openingWatchdog?.cancel()
        openingWatchdog = scope.launch {
            delay(20_000)
            if (_opening.value != null) { _opening.value = null; _events.tryEmit(KidEvent.OpenSlow) }
        }
    }
    private fun endOpening() { openingWatchdog?.cancel(); openingWatchdog = null; _opening.value = null }

    /** Open earned minutes: the claim commits (debit + lease) BEFORE the window opens. */
    suspend fun openEarned(): OpenResult {
        quietNow()?.let { return OpenResult.Quiet(it) }
        val e = engine ?: return OpenResult.NothingToOpen
        val cid = childID ?: return OpenResult.NothingToOpen
        if (e.isUnlocked) return OpenResult.AlreadyOpen
        if (!e.settings.leaseEnabled) return legacyOpenEarned()
        val want = e.redeemableSecondsNow
        if (want <= 0) return OpenResult.NothingToOpen
        if (_opening.value != null) return OpenResult.Busy
        beginOpening(false)
        val out = leases.claim(cid, PlayWindowLease.Kind.EARNED, want)
        endOpening()
        if (childID != cid) return OpenResult.Failed()
        return when (out) {
            is ClaimOutcome.Granted -> {
                if (out.seconds <= 0) return OpenResult.Failed()
                val mins = out.seconds / 60
                edit {
                    out.wallet?.let { w -> it.applyClaimedWallet(w) }
                    it.startUnlock(mins, leaseID = out.leaseID, leaseKind = "earned", extraSeconds = out.seconds % 60)
                }
                sync.reportEvent("screenTimeStart", extra = mapOf("minutes" to maxOf(1, mins)))
                OpenResult.Opened(out.seconds, false)
            }
            is ClaimOutcome.HeldElsewhere -> OpenResult.HeldElsewhere(out.ownerKind, out.secondsLeft)
            ClaimOutcome.Insufficient -> OpenResult.Insufficient
            ClaimOutcome.Offline -> legacyOpenEarned()   // transactions don't queue offline
        }
    }

    /** Bounded local window (one minimum window when the cloud isn't fresh). */
    private fun legacyOpenEarned(): OpenResult {
        quietNow()?.let { return OpenResult.Quiet(it) }
        val e = engine ?: return OpenResult.NothingToOpen
        if (e.isUnlocked) return OpenResult.AlreadyOpen
        val fresh = cloudStateIsFresh
        val minutes = edit { it.consumeMinutesForUnlock(fresh) } ?: 0
        // "רֶגַע, אֲנִי בּוֹדֵק אֶת הַדַּקּוֹת שֶׁלְּךָ — נְנַסֶּה שׁוּב? 😊"
        if (minutes <= 0) return OpenResult.Failed()
        edit { it.startUnlock(minutes) }
        sync.reportEvent("screenTimeStart", extra = mapOf("minutes" to minutes))
        return OpenResult.Opened(minutes * 60, false)
    }

    /** 💝 Open the whole gift pocket as one fixed manual window (outside the daily cap). */
    suspend fun openGift(): OpenResult {
        quietNow()?.let { return OpenResult.Quiet(it) }
        val e = engine ?: return OpenResult.NothingToOpen
        val cid = childID ?: return OpenResult.NothingToOpen
        if (e.isUnlocked) return OpenResult.AlreadyOpen
        val want = e.openableSeconds(true)
        if (!e.settings.leaseEnabled || want <= 0) return legacyOpenGift()
        if (_opening.value != null) return OpenResult.Busy
        beginOpening(true)
        val out = leases.claim(cid, PlayWindowLease.Kind.GIFT, want)
        endOpening()
        if (childID != cid) return OpenResult.Failed()
        return when (out) {
            is ClaimOutcome.Granted -> {
                if (out.seconds <= 0) return giftOpenFailed("grantTooSmall")
                val mins = out.seconds / 60
                edit {
                    out.wallet?.let { w -> it.applyClaimedWallet(w) }
                    it.startUnlock(mins, manual = true, leaseID = out.leaseID, leaseKind = "gift", extraSeconds = out.seconds % 60)
                }
                sync.reportEvent("screenTimeStart", extra = mapOf("minutes" to maxOf(1, mins), "gift" to true))
                giftOpenFailureStreak = 0
                OpenResult.Opened(out.seconds, true)
            }
            is ClaimOutcome.HeldElsewhere -> OpenResult.HeldElsewhere(out.ownerKind, out.secondsLeft)
            ClaimOutcome.Insufficient -> giftOpenFailed("cloudInsufficient")
            ClaimOutcome.Offline -> legacyOpenGift()
        }
    }

    private fun legacyOpenGift(): OpenResult {
        quietNow()?.let { return OpenResult.Quiet(it) }
        val e = engine ?: return OpenResult.NothingToOpen
        if (e.isUnlocked) return OpenResult.AlreadyOpen
        val gift = edit { it.consumeParentGiftForUnlock() } ?: 0
        if (gift <= 0) return giftOpenFailed("walletDisagreement")
        edit { it.startUnlock(gift, manual = true, leaseKind = "gift") }
        giftOpenFailureStreak = 0
        sync.reportEvent("screenTimeStart", extra = mapOf("minutes" to gift, "gift" to true))
        return OpenResult.Opened(gift * 60, true)
    }

    /**
     * A gift that would not open. Nothing is taken away; the parent is told on the
     * SECOND failure in a row ("…סִפַּרְתִּי לַהוֹרִים שֶׁלְּךָ וְהֵם יַעַזְרוּ 😊").
     */
    private fun giftOpenFailed(reason: String): OpenResult {
        giftOpenFailureStreak += 1
        val tell = giftOpenFailureStreak >= 2
        if (tell) {
            val minutes = (engine?.openableSeconds(true) ?: 0) / 60
            sync.reportEvent("giftOpenFailed", extra = mapOf("minutes" to minutes, "reason" to reason))
            giftOpenFailureStreak = 0
        }
        return OpenResult.Failed(tellParent = tell)
    }

    /** "נעלו שם ופתחו כאן" — ask the owning device to let go, wait for idle, claim here. */
    suspend fun transferHere(): OpenResult {
        quietNow()?.let { return OpenResult.Quiet(it) }
        val e = engine ?: return OpenResult.NothingToOpen
        val cid = childID ?: return OpenResult.NothingToOpen
        val l = leases.lease.value
        val kind = l.kind
        val rowID = l.ownerDeviceID?.let { "${cid}_$it" }
        val want = maxOf(e.redeemableMinutesNow, l.remainingSeconds() / 60)
        val fromKind = l.ownerKind ?: ""
        val out = leases.transferHere(cid, rowID, kind, want * 60)
        if (childID != cid) return OpenResult.Failed()
        return when (out) {
            is ClaimOutcome.Granted -> {
                if (out.seconds <= 0) return OpenResult.Failed()
                val mins = out.seconds / 60
                edit {
                    out.wallet?.let { w -> it.applyClaimedWallet(w) }
                    it.startUnlock(mins, manual = kind == PlayWindowLease.Kind.GIFT, leaseID = out.leaseID,
                        leaseKind = kind.raw, extraSeconds = out.seconds % 60)
                }
                sync.reportEvent("screenTimeMoved", extra = mapOf("fromKind" to fromKind))
                OpenResult.Opened(out.seconds, kind == PlayWindowLease.Kind.GIFT)
            }
            is ClaimOutcome.HeldElsewhere -> OpenResult.HeldElsewhere(out.ownerKind, out.secondsLeft)
            else -> OpenResult.Failed()
        }
    }

    /**
     * "עצור ושמור" — stop and save. With a lease the release transaction pays the
     * refund (shown meanwhile as an in-flight refund); offline, it is paid locally.
     */
    fun stop(): Int {
        val cid = childID ?: return 0
        val out = edit { it.stopAndSaveCurrentUnlock() } ?: return 0
        val lid = out.releaseLeaseID
        if (lid != null) {
            inFlightWatchdog?.cancel()
            inFlightWatchdog = scope.launch {
                delay(12_000)
                if ((engine?.session?.inFlightRefundSeconds ?: 0) == out.remainingSeconds) edit { it.clearInFlightRefund() }
            }
            scope.launch {
                val ok = leases.release(cid, lid, out.remainingSeconds)
                if (!ok && childID == cid) edit { it.creditRefundLocally(out.remainingSeconds, out.wasManual) }
            }
        }
        return out.bankedMinutes
    }

    /** Once a second: a window that ran out (by wall OR monotonic clock) ends and hands the lease back. */
    fun tick() {
        val e = engine ?: return
        val cid = childID ?: return
        val l = e.local
        if (l.unlockEndsAt == null) return
        // 🏫🌙 A quiet time began while this window was open → close it with the
        // leftover as of its start (or the window's own start, if later).
        quietNow()?.let { q ->
            if (l.unlockKind != "grant") { closeForQuiet(maxOf(q.startUnix, l.unlockStartedAt ?: q.startUnix)); return }
        }
        if (e.isUnlocked && !e.unlockBudgetExhausted) return
        val lid = l.activeLeaseID
        edit { it.endUnlock() }
        if (lid != null) scope.launch { leases.release(cid, lid, 0) }
        _events.tryEmit(KidEvent.WindowEnded)
    }

    // ── 🏫🌙 school time + bedtime ─────────────────────────────────────────
    /** This child's quiet hours (children/{id}.quietHours). A parent's phone in Kid Mode has none. */
    val quietHours: QuietHours
        get() = if (kidMode) QuietHours() else QuietHours.from(lastChildDoc?.map("quietHours")) ?: QuietHours()

    fun quietNow(): QuietOccurrence? = quietHours.activeAt(AndroidKidClock.nowUnix())

    private fun closeForQuiet(cutUnix: Double) {
        val cid = childID ?: return
        val out = edit { it.closeForQuietTime(cutUnix) } ?: return
        val lid = out.releaseLeaseID
        if (lid != null) {
            inFlightWatchdog?.cancel()
            inFlightWatchdog = scope.launch {
                delay(12_000)
                if ((engine?.session?.inFlightRefundSeconds ?: 0) == out.remainingSeconds) edit { it.clearInFlightRefund() }
            }
            scope.launch {
                val ok = leases.release(cid, lid, out.remainingSeconds, asOfUnix = cutUnix)
                if (!ok && childID == cid) edit { it.creditRefundLocally(out.remainingSeconds, out.wasManual) }
            }
        }
        _events.tryEmit(KidEvent.WindowEnded)
    }

    // ── sync passthroughs ───────────────────────────────────────────────────
    fun pushNow() { scope.launch { sync.upload() } }
    suspend fun consumePendingCommandsNow() = sync.consumePendingCommandsNow()
    /** LiveEventReporter: e.g. reportEvent("worldUnlocked", value = worldName). */
    fun reportEvent(type: String, value: String? = null, topicName: String? = null, extra: Map<String, Any?> = emptyMap()) =
        sync.reportEvent(type, value, topicName, extra)

    // ── called by KidSync ───────────────────────────────────────────────────
    internal fun engineFor(cid: String): ProgressEngine? = if (childID == cid) engine else null

    internal fun onChildDoc(d: Map<String, Any?>) {
        // 📍 Location sharing follows the bound child (never Kid Mode on a parent's phone).
        if (!kidMode) com.rani.tofy.kid.location.KidLocation.bind(childID, d["householdID"] as? String)
        lastChildDoc = d
        engine?.settings = KidSettings.fromChildDoc(d, baseSettings)
        publish()
    }

    internal fun mergeRemote(cid: String, snap: ProgressSnapshot): Boolean =
        if (childID != cid) false else edit { it.mergeRemote(snap) } ?: false

    internal fun adoptUploaded(cid: String, r: Int, editedSince: Boolean) {
        if (childID != cid) return
        engine?.adoptUploadedGeneration(r, editedSince); publish(); persist()
    }

    internal fun onGiftApplied(cid: String, adj: Int) {
        if (childID != cid) return
        edit { it.addParentGiftMinutes(adj) }
        _events.tryEmit(KidEvent.GiftArrived(adj))
    }

    internal fun onMinutesApplied(cid: String, adj: Int) {
        if (childID != cid) return
        edit { it.addPendingMinutes(adj) }
        _events.tryEmit(KidEvent.MinutesAdjusted(adj))
    }

    internal fun onResetApplied(cid: String) {
        if (childID != cid) return
        val wasOpen = engine?.isUnlocked ?: false
        edit { it.resetAll() }
        _events.tryEmit(KidEvent.ResetApplied(wasOpen))
    }

    internal fun adoptBlankWrite(cid: String, rev: Int, epoch: Int) {
        if (childID != cid) return
        engine?.adoptRevision(rev)
        engine?.adoptResetEpoch(epoch)
        publish(); persist()
    }

    internal fun onGiftRevoked(cid: String, @Suppress("UNUSED_PARAMETER") stamp: Double) {
        if (childID != cid) return
        val out = edit { it.revokeAllParentTime() } ?: return
        out.releaseLeaseID?.let { lid -> scope.launch { leases.release(cid, lid, 0) } }
        _events.tryEmit(KidEvent.GiftRevoked(out.closedWindow))
    }

    internal suspend fun onRemoteLock() {
        stop()
        sync.upload()   // the sibling may be waiting on the banked leftover
        _events.tryEmit(KidEvent.RemoteLock)
    }

    /** Parent's remote grant: minted through the lease (outranks a sibling), opened as a fixed window. */
    internal suspend fun onRemoteUnlock(minutes: Int) {
        val cid = childID ?: return
        var leaseID: String? = null
        if (engine?.settings?.leaseEnabled != false) {
            val out = leases.claim(cid, PlayWindowLease.Kind.GRANT, minutes * 60, ClaimPolicy.PARENT_OVERRIDE)
            if (out is ClaimOutcome.Granted) {
                leaseID = out.leaseID
                out.wallet?.let { w -> edit { it.applyClaimedWallet(w) } }
            }
        }
        if (childID != cid) return
        edit { it.startUnlock(minutes, manual = true, leaseID = leaseID, leaseKind = "grant") }
        _events.tryEmit(KidEvent.RemoteUnlock(minutes))
    }

    internal fun onAppRemovalWindow(untilUnix: Double) { _events.tryEmit(KidEvent.AppRemovalWindow(untilUnix)) }

    /** The parent removed this device: never touch the cloud — wipe LOCAL data only. */
    internal fun onDeviceRemoved(cid: String) {
        if (childID != cid) return
        sync.deleteOwnRow(cid)
        val wasKidMode = kidMode
        unbind()
        if (!wasKidMode) prefs?.edit()?.remove(cid)?.apply()
        _events.tryEmit(KidEvent.DeviceRemoved)
    }

    // ── LeaseHost ───────────────────────────────────────────────────────────
    override val activeChildID: String? get() = childID
    override fun captureSnapshot(): ProgressSnapshot = engine?.capture() ?: ProgressSnapshot.blank()
    override val localEditSeq: Int get() = engine?.localEditSeq ?: 0
    override val localRevision: Int get() = engine?.snapshot?.revision ?: 0
    override val minimumUnlockSeconds: Int get() = ProgressEngine.MINIMUM_UNLOCK_MINUTES * 60
    override val isUnlocked: Boolean get() = engine?.isUnlocked ?: false
    override val activeLeaseID: String? get() = engine?.local?.activeLeaseID
    override val unlockSecondsRemaining: Int get() = engine?.unlockSecondsRemaining ?: 0
    override val unlockKind: String get() = engine?.local?.unlockKind ?: "earned"
    override fun adoptLeaseID(id: String) { edit { it.adoptLeaseID(id) } }
    override fun applyClaimedWallet(w: ClaimedWallet) { edit { it.applyClaimedWallet(w) } }
    override fun stopForPeerRequest() {
        stop()
        _events.tryEmit(KidEvent.WindowTakenByOtherDevice)
    }
    override fun ringOwnerDevice(deviceRowID: String) = sync.lockOtherDeviceWindow(deviceRowID)
    override val ownerKind: String get() = KidIdentity.kind
    override val ownerName: String get() = KidIdentity.friendlyName
}

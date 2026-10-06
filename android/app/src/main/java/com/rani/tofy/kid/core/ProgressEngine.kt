package com.rani.tofy.kid.core

import java.time.ZoneId

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  ProgressEngine — the earning rules of ChildTime/Models/ProgressStore.swift
 * ════════════════════════════════════════════════════════════════════════════
 *
 * An IO-free state machine over ONE child's [ProgressSnapshot] plus the
 * device-local play state iOS keeps beside it ([LocalPlayState]). No Firestore,
 * no Android APIs: time comes from a [KidClock], settings from [KidSettings].
 * Not thread-safe — drive it from one thread (KidSession uses Main).
 *
 * THE LWW INVARIANT (cross-device-progress-sync), mirrored exactly:
 *   • `revision` is a causal GENERATION. A local edit moves it to
 *     max(revision, baseRevision + 1) and stamps lastModifiedAt = now — ONCE per
 *     edit, never per field, never in [capture]. `baseRevision` = the last cloud
 *     generation this device adopted (device-local, never synced).
 *   • Which mutations count as an edit is iOS's exact trigger list
 *     (setupVersionTracking): wallet counters/mirrors, giftGivenToday, totals,
 *     stars, diamonds, xp, totalScore, the open window, minutesEarnedToday,
 *     streaks, today's counters, carryOverMinutes, cycleSeconds, owned
 *     characters, unlocked worlds, worldProgress, worldStage. Anything else (topic signals,
 *     chest date, …) rides along with the next edit.
 *   • [apply] adopts a snapshot without counting as an edit — but, exactly like
 *     iOS (its deferred deriveWalletMirrors publishes after the guard drops),
 *     it ends with one edit mark.
 *
 * PUBLIC API (all mutate the engine; read results through [state] / getters)
 *   Answers   recordCorrect(ctx,…) → AnswerOutcome · recordWrong(topic,…) → seconds lost ·
 *             recordBossAnswer · recordGameAnswer · recordMiniGameAnswer(…, bucket) ·
 *             chargeHint() · hintCostSeconds · recordAbandon · registerSessionToday ·
 *             beginSitting / endSittingAndReport
 *   Daily     applyDailyRolloverIfNeeded · atDailyCap() · minutesRemainingTodayCap() ·
 *             grantBonusMinutes · grantMinutesCapped · bonusMinutesRoom ·
 *             dailyChallengeProgress/GoalMet/Claimed/RewardReady · claimDailyChallenge ·
 *             openDailyChest · dailyChestAvailable · applyChestReward
 *   Economy   addStars/spendStars/addDiamonds/spendDiamonds/addXP/addScore/addOwnedCharacter ·
 *             unlockWorld · advanceRoom · 🏆 stage/worldTier/tierGradeOffset/markVisited/completeTier · wheel (freeWheelAvailable, resetWheelProgress,
 *             grantComebackWheelIfReturning) · level helpers
 *   Wallet    creditEarned/debitEarned/creditGift/debitGift · openableSeconds(gift) ·
 *             redeemableSecondsNow · redeemableMinutesNow · canRedeemNow ·
 *             dailyScreenTimeMaxedOut · addPendingMinutes · addParentGiftMinutes
 *   Window    startUnlock · extendUnlock · endUnlock · stopAndSaveCurrentUnlock → StopOutcome ·
 *             endUnlockAndReturnRemainingMinutes · pauseManualUnlock ·
 *             consumeMinutesForUnlock(cloudFresh) · consumeParentGiftForUnlock ·
 *             revokeAllParentTime → RevokeOutcome · creditRefundLocally ·
 *             applyClaimedWallet · adoptLeaseID · isUnlocked · unlockSecondsRemaining ·
 *             refundableUnlockSeconds · unlockBudgetExhausted
 *   Sync      capture() · apply(s) · mergeRemote(s) → needsUpload · adoptRevision ·
 *             adoptUploadedGeneration · adoptResetEpoch · resetAll · localEditSeq
 *   Events    drainEvents() — level-up / personal best / world unlocked / sitting
 */

/** Time source. Tests inject a fake; KidSync provides the Android one. */
interface KidClock {
    /** Wall clock, unix seconds. */
    fun nowUnix(): Double
    /** Monotonic seconds (elapsedRealtime) — a moved clock can't mint minutes. */
    fun uptimeSecs(): Double
    val zone: ZoneId
}

/**
 * The settings the earning rules read — iOS ParentSettings defaults plus the
 * per-child bits of Profile (daily cap, per-topic difficulty). On a child device
 * ParentSettings is never edited, so the defaults ARE the live values; the per-
 * child values come from the child doc ([fromChildDoc]).
 */
data class KidSettings(
    val batchAnswers: Int = 10,
    val batchMinutes: Int = 4,
    val questionsPerSession: Int = 15,
    val minutesPerCorrectAnswer: Int = 2,
    val penaltyEnabled: Boolean = true,
    val dailyCapEnabled: Boolean = true,
    val maxMinutesPerDay: Int = 60,
    /** Profile.dailyCapMinutes: nil → device setting; ≤0 → unlimited. */
    val childDailyCapMinutes: Int? = null,
    val questionsPerWheel: Int = 10,
    val difficultyByTopic: Map<String, String> = emptyMap(),
    val learningLevel: LearningLevel = LearningLevel.BEGINNER,
    /** Profile.playableTopics — seeds affinity 0.6 vs 0.4 for unseen topics. */
    val playableTopics: Set<String> = setOf("math", "hebrew", "english", "logic", "science", "reading"),
    /** PlayWindowLeaseManager.isEnabled kill switch (ON by default since build 138). */
    val leaseEnabled: Boolean = true,
) {
    data class DailyCap(val enabled: Boolean, val max: Int)

    /** ProgressStore.dailyCap — the per-child value overrides the device setting. */
    val dailyCap: DailyCap
        get() = childDailyCapMinutes?.let { if (it <= 0) DailyCap(false, 0) else DailyCap(true, it) }
            ?: DailyCap(dailyCapEnabled, maxMinutesPerDay)

    /** Profile.difficulty(for:) — explicit per-topic choice, else the learning level's seed. */
    fun difficulty(topic: String): Difficulty = Difficulty.of(difficultyByTopic[topic]) ?: learningLevel.seedDifficulty

    val bonusTargetSeconds: Int get() = maxOf(1, batchMinutes * 60)
    val cycleQuestionsTotal: Int get() = maxOf(1, batchAnswers)
    /** The "+Ns" one right answer is worth. */
    val secondsPerCorrect: Int get() = maxOf(1, bonusTargetSeconds / cycleQuestionsTotal)

    companion object {
        /** Overlay the per-child fields of a children/{id} doc (ChildRecord) on `base`. */
        fun fromChildDoc(doc: Map<String, Any?>, base: KidSettings = KidSettings()): KidSettings {
            @Suppress("UNCHECKED_CAST")
            val diff = (doc["difficultyByTopic"] as? Map<String, Any?>)?.mapNotNull { (k, v) -> (v as? String)?.let { k to it } }?.toMap()
            val topics = (doc["enabledTopics"] as? List<*>)?.filterIsInstance<String>()?.toSet()
            return base.copy(
                childDailyCapMinutes = (doc["dailyCapMinutes"] as? Number)?.toInt(),
                difficultyByTopic = diff ?: emptyMap(),
                learningLevel = LearningLevel.of(doc["learningLevel"] as? String) ?: base.learningLevel,
                playableTopics = topics ?: base.playableTopics,
            )
        }
    }
}

/** ProgressStore.AnswerContext. `combo` = the streak BEFORE this answer (the runner passes currentStreak). */
data class AnswerContext(
    val topic: String,
    val combo: Int,
    val isSuperQuestion: Boolean = false,
    val isMysteryPortal: Boolean = false,
    val isBonusQuestion: Boolean = false,
)

/** What a right answer paid — the runner's companion lines + popups read this. */
data class AnswerOutcome(
    val stars: Int,
    val diamonds: Int,
    val points: Int,
    /** Whole minutes this answer moved the session total across (per-answer seconds + variety bonus). */
    val minutesGranted: Int,
    val varietyBonusMinutes: Int,
    /** This answer reached the 30/day soft cap in its topic → nudge to another world. */
    val balanceNudge: Boolean,
    val recoveredMinutes: Int,
    val newStreakRecord: Boolean,
)

/** ProgressStore.BonusGrant. */
data class BonusGrant(val addedToday: Int = 0, val bankedForTomorrow: Int = 0, val bankFull: Boolean = false)

/** What a stop did; KidSession releases the lease with these numbers. */
data class StopOutcome(
    val bankedMinutes: Int,
    /** Non-null when the cloud lease must settle the refund (release transaction). */
    val releaseLeaseID: String? = null,
    val remainingSeconds: Int = 0,
    val wasManual: Boolean = false,
)

data class RevokeOutcome(val closedWindow: Boolean, val releaseLeaseID: String?)

/** Events the parent's activity centre cares about (LiveEventReporter on iOS). */
sealed class ProgressEvent {
    data class LevelUp(val level: Int) : ProgressEvent()
    data class PersonalBest(val streak: Int) : ProgressEvent()
    data class WorldUnlocked(val worldID: String) : ProgressEvent()
    data object SessionStart : ProgressEvent()
    /** ProgressStore.endSittingAndReport payload, same keys. */
    data class SessionEnd(val extra: Map<String, Any>) : ProgressEvent()
}

/** Device-local play state — ProgressStore's non-synced fields. Persisted, never uploaded. */
data class LocalPlayState(
    var baseRevision: Int = 0,
    /** UNIX secs the open window ends (iOS `unlockEndsAt`, deliberately per-device). */
    var unlockEndsAt: Double? = null,
    var unlockIsManual: Boolean = false,
    var unlockGrantedSeconds: Int = 0,
    var unlockStartedAt: Double? = null,
    var unlockStartedUptime: Double = 0.0,
    /** "earned" / "gift" / "grant". */
    var unlockKind: String = "earned",
    var activeLeaseID: String? = null,
    /** Legacy frozen parent time — always 0 in the current design (kept for frozenSeconds). */
    var manualPausedSeconds: Int = 0,
    var pendingBonusWheel: Boolean = false,
    /** 🌈 topic-balance counters for today (per child). */
    var topicAnsweredToday: Map<String, Int> = emptyMap(),
    var topicAnsweredDate: Double? = null,
    var bonusQuestionServedAt: Double? = null,
    var ownedCosmetics: Set<String> = emptySet(),
    var equippedCosmetic: String? = null,
    /**
     * ⏱ ProgressStore.EarnLedger — what per-answer pay keeps between answers, for
     * ONE day (`earnDay`, Apple secs of its start): seconds in the wallet the
     * whole-minute `minutesEarnedToday` hasn't counted yet (`earnCapCarry`), seconds
     * past the cap waiting to bank a minute for tomorrow (`earnOverflow`), and what
     * a miss/hint left owed by the next right answers (`earnDebt`, ≤ half a step).
     */
    var earnDay: Double? = null,
    var earnCapCarry: Int = 0,
    var earnOverflow: Int = 0,
    var earnDebt: Int = 0,
)

/** Transient per-session values (never persisted). */
data class SessionState(
    var sessionScore: Int = 0,
    var sessionStarsEarned: Int = 0,
    var sessionDiamondsEarned: Int = 0,
    var sessionMinutesEarned: Int = 0,
    var lastEarnedPoints: Int = 0,
    var lastPenaltyMinutes: Int = 0,
    var lastRecoveredMinutes: Int = 0,
    var newStreakRecord: Boolean = false,
    var topicBalanceNudgeTopic: String? = null,
    var varietyBonusJustEarned: Int = 0,
    /** Refund shown immediately while the release transaction is in flight (display only). */
    var inFlightRefundSeconds: Int = 0,
    var inFlightRefundIsGift: Boolean = false,
    var giftOpenFailureStreak: Int = 0,
    var sittingActive: Boolean = false,
)

/** Everything observable about the child, as one immutable value. */
data class KidState(
    val snapshot: ProgressSnapshot,
    val local: LocalPlayState,
    val session: SessionState,
    val localEditSeq: Int,
)

class ProgressEngine(
    var settings: KidSettings,
    private val clock: KidClock,
    /** Stamped on every snapshot this device writes (== lease ownerDeviceID on Android). */
    val deviceID: String,
    initialSnapshot: ProgressSnapshot? = null,
    initialLocal: LocalPlayState? = null,
) {
    private var s: ProgressSnapshot = normalize(
        initialSnapshot?.copy() ?: ProgressSnapshot(lastModifiedAt = AppleTime.DISTANT_PAST, deviceID = deviceID)
    )
    private var l: LocalPlayState = initialLocal?.copy() ?: LocalPlayState()
    private val ss = SessionState()

    /** In-memory count of local edits ("did the store change since I captured?"). */
    var localEditSeq: Int = 0
        private set

    private var applying = false
    private var dirty = false
    private var recordCelebratedThisRun = false
    private val events = ArrayList<ProgressEvent>()
    private var roundSeconds = 0

    // Sitting analytics (ProgressStore sitting*).
    private class SittingTopic { var q = 0; var correct = 0; var ms = 0.0 }
    private var sittingQuestions = 0
    private var sittingCorrect = 0
    private var sittingStars = 0
    private var sittingMinutes = 0
    private var sittingTopics = LinkedHashMap<String, SittingTopic>()
    private var sittingResponseMsTotal = 0.0
    private var sittingResponseCount = 0
    private var sittingXP = 0
    private var sittingWheelSpins = 0
    private var sittingMystery = 0

    val state: KidState get() = KidState(s.copy(), l.copy(), ss.copy(), localEditSeq)
    val snapshot: ProgressSnapshot get() = s.copy()
    val local: LocalPlayState get() = l.copy()
    val session: SessionState get() = ss.copy()

    fun drainEvents(): List<ProgressEvent> = ArrayList(events).also { events.clear() }

    // ── time ────────────────────────────────────────────────────────────────
    private val zone: ZoneId get() = clock.zone
    private fun nowApple(): Double = AppleTime.fromUnix(clock.nowUnix())
    private fun todayStart(): Double = DayMath.startOfDay(nowApple(), zone)
    private fun usedToday(stamp: Double?) = DayMath.usedToday(stamp, nowApple(), zone)

    // ── versioning (ProgressStore.markLocalChange & friends) ─────────────────
    private fun touch() { if (!applying) dirty = true }
    private fun commit() { if (dirty) { dirty = false; markLocalChange() } }
    private inline fun <T> op(block: () -> T): T { val r = block(); commit(); return r }

    private fun markLocalChange() {
        if (applying) return
        localEditSeq += 1
        s.revision = maxOf(s.revision, l.baseRevision + 1)
        s.lastModifiedAt = nowApple()
    }

    private fun noteAdoptedGeneration(r: Int) { l.baseRevision = maxOf(l.baseRevision, r) }

    private fun setXP(v: Int) {
        val was = RewardEngine.level(s.xp)
        s.xp = v; touch()
        if (applying) return
        val now = RewardEngine.level(v)
        if (now > was) events += ProgressEvent.LevelUp(now)
    }

    // ── 💰 wallets: four lifetime counters, mirrors derived ──────────────────
    private val ein get() = s.earnedSecondsIn ?: 0
    private val eout get() = s.earnedSecondsOut ?: 0
    private val gin get() = s.giftSecondsIn ?: 0
    private val gout get() = s.giftSecondsOut ?: 0
    val earnedSecondsAvailable: Int get() = maxOf(0, ein - eout)
    val giftSecondsAvailable: Int get() = maxOf(0, gin - gout)

    private fun recomputeWallets() {
        s.pendingMinutes = earnedSecondsAvailable / 60
        s.parentGiftMinutes = giftSecondsAvailable / 60
        touch()
    }
    private fun creditEarnedRaw(seconds: Int) { if (seconds <= 0) return; s.earnedSecondsIn = ein + seconds; recomputeWallets() }
    private fun debitEarnedRaw(seconds: Int) { if (seconds <= 0) return; s.earnedSecondsOut = eout + minOf(seconds, earnedSecondsAvailable); recomputeWallets() }
    private fun creditGiftRaw(seconds: Int) { if (seconds <= 0) return; s.giftSecondsIn = gin + seconds; recomputeWallets() }
    private fun debitGiftRaw(seconds: Int) { if (seconds <= 0) return; s.giftSecondsOut = gout + minOf(seconds, giftSecondsAvailable); recomputeWallets() }

    fun creditEarned(seconds: Int) = op { creditEarnedRaw(seconds) }
    fun debitEarned(seconds: Int) = op { debitEarnedRaw(seconds) }
    fun creditGift(seconds: Int) = op { creditGiftRaw(seconds) }
    fun debitGift(seconds: Int) = op { debitGiftRaw(seconds) }

    /** Only for an authoritative reset / demo seeding — never to "correct" a balance. */
    fun resetWallets(earnedMinutes: Int = 0, giftMinutes: Int = 0) = op {
        s.earnedSecondsOut = 0; s.giftSecondsOut = 0
        s.earnedSecondsIn = maxOf(0, earnedMinutes) * 60
        s.giftSecondsIn = maxOf(0, giftMinutes) * 60
        recomputeWallets()
    }

    /** Mirrors are derived, never adopted — the legacy field counts only when nobody holds counters. */
    private fun deriveWalletMirrors(from: ProgressSnapshot) {
        val earnedKnown = from.earnedSecondsIn != null || from.earnedSecondsOut != null || ein > 0 || eout > 0
        val giftKnown = from.giftSecondsIn != null || from.giftSecondsOut != null || gin > 0 || gout > 0
        s.pendingMinutes = if (earnedKnown) earnedSecondsAvailable / 60 else from.pendingMinutes
        s.parentGiftMinutes = if (giftKnown) giftSecondsAvailable / 60 else (from.parentGiftMinutes ?: 0)
        touch()
    }

    val pendingMinutes: Int get() = s.pendingMinutes
    val parentGiftMinutes: Int get() = s.parentGiftMinutes ?: 0

    // ── derived ─────────────────────────────────────────────────────────────
    val companionLevel: Int get() = RewardEngine.level(s.xp)
    val xpForCurrentLevel: Int get() = RewardEngine.xpForCurrentLevel(s.xp)
    val xpForNextLevel: Int get() = RewardEngine.xpForNextLevel(s.xp)
    val questionsUntilNextLevel: Int
        get() = Math.ceil(maxOf(0, xpForNextLevel - s.xp).toDouble() / maxOf(1, RewardEngine.xpPerCorrect)).toInt()
    val dailyChestAvailable: Boolean get() = !usedToday(s.lastDailyChestDate)
    fun accuracy(topic: String): Double = s.topicAccuracy[topic] ?: 0.7
    fun affinity(topic: String): Double = s.topicAffinity[topic] ?: if (topic in settings.playableTopics) 0.6 else 0.4
    fun responseMs(topic: String): Double? = s.topicResponseMs[topic]
    fun exposure(topic: String): Int = s.topicExposure[topic] ?: 0
    fun adaptiveLevel(topic: String, base: Difficulty = settings.difficulty(topic)): Double =
        s.topicAdaptiveLevel?.get(topic) ?: AdaptiveDifficultyEngine.level(base)
    val overallAccuracy: Double
        get() = s.topicAccuracy.values.let { if (it.isEmpty()) 0.7 else it.sum() / it.size }
    val questionsUntilWheel: Int get() = maxOf(0, settings.questionsPerWheel - s.wheelProgressCount)
    val freeWheelAvailable: Boolean get() = l.pendingBonusWheel || s.wheelProgressCount >= settings.questionsPerWheel
    /** Questions completed in the current bonus cycle (for the progress bar). */
    val cycleQuestionsDone: Int
        get() {
            val perSec = settings.bonusTargetSeconds.toDouble() / settings.cycleQuestionsTotal
            return minOf(settings.cycleQuestionsTotal, maxOf(0, (s.cycleSeconds / maxOf(1.0, perSec)).roundHalfAwayFromZero()))
        }

    // ── learning signals ────────────────────────────────────────────────────
    private fun adjustAdaptiveLevel(topic: String, correct: Boolean, fast: Boolean, hintUsed: Boolean, abandoned: Boolean) {
        val base = settings.difficulty(topic)
        val current = s.topicAdaptiveLevel?.get(topic) ?: AdaptiveDifficultyEngine.level(base)
        val next = AdaptiveDifficultyEngine.updatedLevel(current, base, AdaptiveDifficultyEngine.Signals(correct, fast, hintUsed, abandoned))
        s.topicAdaptiveLevel = (s.topicAdaptiveLevel ?: emptyMap()) + (topic to next)
    }

    private fun updateLearningSignals(topic: String, correct: Boolean, responseMs: Double, hintUsed: Boolean, affectsAdaptive: Boolean) {
        var fast = false
        if (responseMs > 0) {
            val prev = s.topicResponseMs[topic]
            if (prev != null) {
                fast = responseMs < prev * 0.9
                s.topicResponseMs = s.topicResponseMs + (topic to (prev * 0.8 + responseMs * 0.2))
            } else {
                s.topicResponseMs = s.topicResponseMs + (topic to responseMs)
            }
        }
        s.topicExposure = s.topicExposure + (topic to ((s.topicExposure[topic] ?: 0) + 1))
        var delta = if (correct) 0.06 else -0.04
        if (correct && fast) delta += 0.03
        s.topicAffinity = s.topicAffinity + (topic to minOf(1.0, maxOf(0.0, affinity(topic) + delta)))
        if (affectsAdaptive) adjustAdaptiveLevel(topic, correct, fast, hintUsed, false)
    }

    private fun updateTopicStat(topic: String, correct: Boolean) {
        s.topicAnswered = s.topicAnswered + (topic to ((s.topicAnswered[topic] ?: 0) + 1))
        s.topicCorrect = s.topicCorrect + (topic to ((s.topicCorrect[topic] ?: 0) + if (correct) 1 else 0))
        val prev = s.topicAccuracy[topic]
        val acc = if (prev != null) prev * 0.8 + (if (correct) 1.0 else 0.0) * 0.2 else if (correct) 1.0 else 0.0
        s.topicAccuracy = s.topicAccuracy + (topic to acc)
    }

    private fun recordHourly(correct: Boolean) {
        val h = DayMath.hour(nowApple(), zone)
        if (h !in 0..23) return
        val a = (s.hourlyAnswered?.takeIf { it.size == 24 } ?: List(24) { 0 }).toMutableList()
        a[h] += 1; s.hourlyAnswered = a
        if (correct) {
            val c = (s.hourlyCorrect?.takeIf { it.size == 24 } ?: List(24) { 0 }).toMutableList()
            c[h] += 1; s.hourlyCorrect = c
        }
    }

    /** Seed a brand-new child's affinities from the parent's interest picks (no-op once they answered). */
    fun seedLearning(interestTopics: Collection<String>) {
        if (s.totalAnswered != 0) return
        val boost = settings.learningLevel.affinityBoost
        for (t in interestTopics) {
            val base = if (t in settings.playableTopics) 0.6 else 0.4
            s.topicAffinity = s.topicAffinity + (t to minOf(1.0, base + boost))
        }
    }

    fun recordAbandon(topic: String) = op {
        s.topicAbandon = s.topicAbandon + (topic to ((s.topicAbandon[topic] ?: 0) + 1))
        s.topicAffinity = s.topicAffinity + (topic to minOf(1.0, maxOf(0.0, affinity(topic) - 0.08)))
        adjustAdaptiveLevel(topic, correct = false, fast = false, hintUsed = false, abandoned = true)
    }

    // ── 📅 daily counters (minutesEarnedTodayRespectingDate) ─────────────────
    private fun rollover(): Int {
        val today = DayMath.localDate(nowApple(), zone)
        s.dailyEarnedDate?.let { d ->
            val last = DayMath.localDate(d, zone)
            if (last == today) return s.minutesEarnedToday
            if (last > today) {
                // Future-dated (clock moved forward / bad peer): pin to today, KEEP the counters.
                s.dailyEarnedDate = todayStart()
                return s.minutesEarnedToday
            }
        }
        val carry = s.carryOverMinutes ?: 0
        if (carry > 0) {
            creditEarnedRaw(carry * 60)
            s.carryOverMinutes = 0; touch()
        }
        s.minutesEarnedToday = 0
        s.minutesUnlockedToday = 0
        s.returnedTodayMinutes = 0
        s.answeredToday = 0
        s.correctToday = 0
        s.dailyEarnedDate = todayStart()
        touch()
        return 0
    }

    fun applyDailyRolloverIfNeeded() = op { rollover(); Unit }

    /** ⚠️ Like iOS, these may roll the day over (and so count as an edit). */
    fun minutesRemainingTodayCap(): Int = op {
        val cap = settings.dailyCap
        if (!cap.enabled) Int.MAX_VALUE else maxOf(0, maxOf(0, cap.max) - rollover())
    }
    fun atDailyCap(): Boolean = settings.dailyCap.enabled && minutesRemainingTodayCap() == 0

    fun bonusMinutesRoom(): Int {
        val cap = settings.dailyCap
        if (!cap.enabled) return Int.MAX_VALUE
        return maxOf(0, cap.max - s.minutesEarnedToday) + maxOf(0, MAX_CARRY_OVER - (s.carryOverMinutes ?: 0))
    }

    /** Wheel / chest / bonus-question minutes: fill today's cap, bank the overflow (≤30) for tomorrow. */
    fun grantBonusMinutes(amount: Int): BonusGrant = op { grantBonusMinutesRaw(amount) }

    private fun grantBonusMinutesRaw(amount: Int): BonusGrant {
        if (amount <= 0) return BonusGrant()
        val cap = settings.dailyCap
        if (!cap.enabled) { creditEarnedRaw(amount * 60); return BonusGrant(addedToday = amount) }
        rollover()
        var added = 0; var banked = 0
        val toToday = minOf(amount, maxOf(0, cap.max - s.minutesEarnedToday))
        if (toToday > 0) {
            creditEarnedRaw(toToday * 60)
            s.minutesEarnedToday += toToday; touch()
            added = toToday
        }
        val overflow = amount - toToday
        if (overflow > 0) {
            val bank = minOf(overflow, maxOf(0, MAX_CARRY_OVER - (s.carryOverMinutes ?: 0)))
            if (bank > 0) { s.carryOverMinutes = (s.carryOverMinutes ?: 0) + bank; touch(); banked = bank }
        }
        return BonusGrant(added, banked, (s.carryOverMinutes ?: 0) >= MAX_CARRY_OVER)
    }

    /** Regular earning: what fits under today's cap is playable now, the overflow is banked (≤30). */
    fun grantMinutesCapped(amount: Int): Int = op { grantMinutesCappedRaw(amount) }

    private fun grantMinutesCappedRaw(amount: Int): Int {
        if (amount <= 0) return 0
        rollover()
        val cap = settings.dailyCap
        if (!cap.enabled) { creditEarnedRaw(amount * 60); return amount }
        val toToday = minOf(amount, maxOf(0, cap.max - s.minutesEarnedToday))
        if (toToday > 0) {
            creditEarnedRaw(toToday * 60)
            s.minutesEarnedToday += toToday; touch()
            if (s.dailyEarnedDate == null) s.dailyEarnedDate = todayStart()
        }
        val overflow = amount - toToday
        if (overflow > 0) {
            val room = maxOf(0, MAX_CARRY_OVER - (s.carryOverMinutes ?: 0))
            if (room > 0) { s.carryOverMinutes = (s.carryOverMinutes ?: 0) + minOf(overflow, room); touch() }
        }
        return toToday
    }

    // ── 💫 bonus question: once per child per day (device-local) ─────────────
    val bonusQuestionServedToday: Boolean get() = usedToday(l.bonusQuestionServedAt)
    fun markBonusQuestionServed() { l.bonusQuestionServedAt = nowApple() }

    // ── 🌈 topic balance ────────────────────────────────────────────────────
    private fun topicCountsToday(): Map<String, Int> =
        if (usedToday(l.topicAnsweredDate)) l.topicAnsweredToday else emptyMap()

    private fun bumpTopicAnsweredToday(topic: String): Int {
        val counts = topicCountsToday().toMutableMap()
        counts[topic] = (counts[topic] ?: 0) + 1
        l.topicAnsweredToday = counts
        l.topicAnsweredDate = nowApple()
        return counts[topic] ?: 1
    }

    private val varietyBonusGrantedToday: Boolean get() = usedToday(s.varietyBonusDate)

    // ── ✅ answers ──────────────────────────────────────────────────────────
    /**
     * ProgressStore.recordCorrect. `grantsScreenTime` false = Free Learning (no
     * minutes, no balance counting); `cycleMultiplier` 2 in the 💫 arena;
     * `affectsAdaptive` false in the arena / for a bonus question.
     */
    fun recordCorrect(
        ctx: AnswerContext,
        responseMs: Double = 0.0,
        hadMistakeThisQuestion: Boolean = false,
        hintUsed: Boolean = false,
        grantsScreenTime: Boolean = true,
        cycleMultiplier: Double = 1.0,
        affectsAdaptive: Boolean = true,
    ): AnswerOutcome = op {
        val minutesBefore = ss.sessionMinutesEarned
        var balanceNudge = false
        var variety = 0
        var recovered = 0
        var record = false

        s.totalAnswered += 1
        s.totalCorrect += 1
        touch()
        rollover()
        s.answeredToday += 1
        s.correctToday += 1
        recordHourly(true)
        s.currentStreak += 1
        s.wrongStreak = 0
        if (s.currentStreak == 5 || s.currentStreak == 10) l.pendingBonusWheel = true

        val earned = RewardEngine.starsForCorrect(s.currentStreak, ctx.isSuperQuestion, ctx.isMysteryPortal, ctx.isBonusQuestion)
        s.stars += earned
        val mult = GameEvent.current(nowApple(), zone).diamondMultiplier(ctx.topic)
        val earnedDiamonds = RewardEngine.diamondsForCorrect(s.currentStreak, ctx.isSuperQuestion, ctx.isMysteryPortal, ctx.isBonusQuestion) * mult
        s.diamonds += earnedDiamonds
        ss.sessionDiamondsEarned += earnedDiamonds
        if (s.currentStreak > s.bestStreak) {
            s.bestStreak = s.currentStreak
            if (s.currentStreak >= 3 && !recordCelebratedThisRun) {
                recordCelebratedThisRun = true
                ss.newStreakRecord = true
                record = true
                events += ProgressEvent.PersonalBest(s.currentStreak)
            }
        }
        ss.sessionStarsEarned += earned
        sittingQuestions += 1; sittingCorrect += 1; sittingStars += earned

        val pts = RewardEngine.pointsForCorrect(ctx.combo, ctx.isSuperQuestion, ctx.isMysteryPortal, settings.difficulty(ctx.topic), ctx.isBonusQuestion)
        s.totalScore += pts
        ss.sessionScore += pts
        ss.lastEarnedPoints = pts

        val topicCountToday = if (grantsScreenTime) bumpTopicAnsweredToday(ctx.topic) else 0
        lastPaidSeconds = 0
        if (grantsScreenTime) {
            // ⏱ Each right answer pays its seconds STRAIGHT into the wallet (Rani,
            // 2026-10-06 — it used to wait for a batch of 10). See [payEarned].
            val balanceFactor = if (topicCountToday > SAME_TOPIC_SOFT_CAP) 0.5 else 1.0
            if (topicCountToday == SAME_TOPIC_SOFT_CAP) { ss.topicBalanceNudgeTopic = ctx.topic; balanceNudge = true }
            val pay = settings.secondsPerCorrect * maxOf(1.0, cycleMultiplier) * balanceFactor
            lastPaidSeconds = payEarned(pay.roundHalfAwayFromZero())
            if (!varietyBonusGrantedToday) {
                val varied = topicCountsToday().values.count { it >= VARIETY_MIN_ANSWERS_PER_TOPIC }
                if (varied >= VARIETY_TOPICS_NEEDED) {
                    s.varietyBonusDate = nowApple()
                    val granted = grantMinutesCappedRaw(VARIETY_BONUS_MINUTES)
                    if (granted > 0) {
                        ss.sessionMinutesEarned += granted
                        sittingMinutes += granted
                        ss.varietyBonusJustEarned = granted
                        variety = granted
                    }
                }
            }
        }
        setXP(s.xp + RewardEngine.xpPerCorrect)
        updateTopicStat(ctx.topic, true)
        updateLearningSignals(ctx.topic, true, responseMs, hintUsed, affectsAdaptive)
        s.wheelProgressCount += 1

        sittingXP += RewardEngine.xpPerCorrect
        if (responseMs > 0) { sittingResponseMsTotal += responseMs; sittingResponseCount += 1 }
        if (ctx.isMysteryPortal) sittingMystery += 1
        val st = sittingTopics.getOrPut(ctx.topic) { SittingTopic() }
        st.q += 1; st.correct += 1; if (responseMs > 0) st.ms += responseMs

        // Risk & Recovery: a clean first-try answer redeems the pot (Earn mode only).
        if (grantsScreenTime && !hadMistakeThisQuestion && s.recoveryPot > 0) {
            val refund = s.recoveryPot
            creditEarnedRaw(refund * 60)
            s.recoveryPot = 0
            ss.lastRecoveredMinutes = refund
            recovered = refund
        }
        AnswerOutcome(earned, earnedDiamonds, pts, ss.sessionMinutesEarned - minutesBefore, variety, balanceNudge, recovered, record)
    }

    /**
     * ProgressStore.recordWrong — gentle: half a step off the cycle progress, never
     * a banked minute. Returns the SECONDS removed (for "−12 שניות · כמעט!").
     */
    fun recordWrong(topic: String, hintUsed: Boolean = false, grantsScreenTime: Boolean = true, affectsAdaptive: Boolean = true): Int = op {
        s.totalAnswered += 1
        touch()
        rollover()
        s.answeredToday += 1
        recordHourly(false)
        sittingQuestions += 1
        s.currentStreak = 0
        recordCelebratedThisRun = false
        s.wrongStreak += 1
        setXP(s.xp + RewardEngine.xpPerQuestion)
        updateTopicStat(topic, false)
        sittingXP += RewardEngine.xpPerQuestion
        sittingTopics.getOrPut(topic) { SittingTopic() }.q += 1
        if (affectsAdaptive) adjustAdaptiveLevel(topic, correct = false, fast = false, hintUsed = hintUsed, abandoned = false)
        s.topicAffinity = s.topicAffinity + (topic to minOf(1.0, maxOf(0.0, affinity(topic) - 0.04)))
        if (!grantsScreenTime || !settings.penaltyEnabled) return@op 0
        // Gentle: half a step taken off the NEXT right answer — never out of the
        // wallet, so the number the child sees never drops.
        ss.lastPenaltyMinutes = 0
        oweEarned(halfStepSeconds)
    }

    /** Legacy: half the per-correct reward, ≥1; 0 when penalties are off. */
    fun mistakePenaltyMinutes(minutesPerCorrect: Int): Int =
        if (!settings.penaltyEnabled || minutesPerCorrect <= 0) 0 else maxOf(1, (minutesPerCorrect / 2.0).roundHalfAwayFromZero())

    /** 🐉 Boss / 🎮 mini-game answer: counts in the reports, pays nothing per answer. */
    fun recordBossAnswer(correct: Boolean) = op {
        s.totalAnswered += 1
        touch()
        rollover()
        s.answeredToday += 1
        if (correct) { s.totalCorrect += 1; s.correctToday += 1 }
        recordHourly(correct)
    }
    fun recordGameAnswer(correct: Boolean) = recordBossAnswer(correct)

    /** 💡 A hint costs what a mistake costs: half a step of the cycle. */
    val hintCostSeconds: Int
        get() = if (!settings.penaltyEnabled) 0 else halfStepSeconds

    /** Owed by the next right answer, like a mistake. Seconds owed (0 when a miss already owes it). */
    fun chargeHint(): Int = op {
        if (!settings.penaltyEnabled) return@op 0
        oweEarned(hintCostSeconds)
    }

    // ── ⏱ per-answer pay (ProgressStore.payEarned) ──────────────────────────
    /** Seconds the last [recordCorrect] actually put in the wallet — the "+Ns" to show. */
    var lastPaidSeconds = 0
        private set

    /** Half of what a right answer pays — what a miss or a hint costs. */
    private val halfStepSeconds: Int get() = (settings.secondsPerCorrect / 2.0).roundHalfAwayFromZero()

    /** The per-answer ledger, cleared when the day changed. */
    private fun earnLedgerToday() {
        val today = todayStart()
        val d = l.earnDay
        if (d == null || DayMath.localDate(d, zone) != DayMath.localDate(today, zone)) {
            l.earnDay = today; l.earnCapCarry = 0; l.earnOverflow = 0; l.earnDebt = 0
        }
    }

    /**
     * Pays `seconds` of earned play time into the wallet NOW, minus what a miss
     * left owed. Today's cap is honoured to the second; past it the seconds bank
     * for tomorrow (≤ [MAX_CARRY_OVER] minutes), like the batches did. Returns
     * the seconds that reached the wallet.
     */
    private fun payEarned(seconds: Int): Int {
        rollover()
        earnLedgerToday()
        // Progress an older build left toward its next batch — paid out once.
        var amount = maxOf(0, seconds)
        if (s.cycleSeconds > 0) {
            amount += s.cycleSeconds.roundHalfAwayFromZero()
            s.cycleSeconds = 0.0; touch()
        }
        val owed = minOf(l.earnDebt, amount)
        l.earnDebt -= owed
        amount -= owed
        if (amount <= 0) return 0
        val cap = settings.dailyCap
        var toWallet = amount
        if (cap.enabled) {
            val room = maxOf(0, (maxOf(0, cap.max) - s.minutesEarnedToday) * 60 - l.earnCapCarry)
            toWallet = minOf(amount, room)
            l.earnOverflow += amount - toWallet
            while (l.earnOverflow >= 60 && (s.carryOverMinutes ?: 0) < MAX_CARRY_OVER) {
                s.carryOverMinutes = (s.carryOverMinutes ?: 0) + 1; touch()
                l.earnOverflow -= 60
            }
            l.earnOverflow = minOf(l.earnOverflow, 59)
        }
        if (toWallet <= 0) return 0
        creditEarnedRaw(toWallet)
        l.earnCapCarry += toWallet
        while (l.earnCapCarry >= 60) {
            l.earnCapCarry -= 60
            if (cap.enabled) { s.minutesEarnedToday += 1; touch() }
            ss.sessionMinutesEarned += 1
            sittingMinutes += 1
        }
        if (s.dailyEarnedDate == null) { s.dailyEarnedDate = todayStart(); touch() }
        return toWallet
    }

    /** A miss / hint: owed by the next right answers, ≤ half a step in all. Seconds newly owed. */
    private fun oweEarned(seconds: Int): Int {
        if (seconds <= 0) return 0
        earnLedgerToday()
        val added = minOf(seconds, maxOf(0, halfStepSeconds - l.earnDebt))
        l.earnDebt += added
        return added
    }

    // ── 🎮 mini-games (MiniGameEarning.swift) ───────────────────────────────
    data class MiniGameAnswer(
        val paidSeconds: Int = 0,
        val stars: Int = 0,
        val minutesGranted: Int = 0,
        val lostSeconds: Int = 0,
        val capReached: Boolean = false,
        /** 🌈 The variety bonus this answer unlocked — the only "+N דקות" pop left. */
        val varietyBonus: Int = 0,
    )

    /**
     * MiniGameLedger.record. `bucket` null or `surprise` → reports only. A right
     * answer pays minutes only when the token bucket allows (`paidSeconds` > 0
     * then); stars/diamonds always. `retry` pays in full but doesn't claim the pot.
     */
    fun recordMiniGameAnswer(
        correct: Boolean, topic: String, responseMs: Double = 0.0,
        bucket: MiniGameEarnBucket?, surprise: Boolean, retry: Boolean = false,
    ): MiniGameAnswer {
        if (bucket == null) {
            recordGameAnswer(correct)
            // ⚡ A surprise round from an earning session: a right answer pays its seconds too.
            if (!(surprise && correct)) return MiniGameAnswer()
            val before = pendingMinutes
            val paid = creditSurpriseAnswer(topic)
            roundSeconds += paid
            return MiniGameAnswer(paidSeconds = paid, minutesGranted = maxOf(0, pendingMinutes - before), capReached = atDailyCap())
        }
        if (correct) {
            val paysMinutes = bucket.takeCredit()
            val cappedBefore = atDailyCap()
            val before = pendingMinutes
            val out = recordCorrect(
                AnswerContext(topic, s.currentStreak), responseMs = responseMs,
                hadMistakeThisQuestion = retry, grantsScreenTime = paysMinutes,
            )
            val granted = maxOf(0, pendingMinutes - before)
            ss.varietyBonusJustEarned = 0; ss.topicBalanceNudgeTopic = null
            ss.lastRecoveredMinutes = 0; ss.newStreakRecord = false
            val paid = if (paysMinutes && !cappedBefore) lastPaidSeconds else 0
            roundSeconds += paid
            return MiniGameAnswer(paidSeconds = paid, stars = out.stars, minutesGranted = granted, capReached = atDailyCap(),
                varietyBonus = out.varietyBonusMinutes)
        }
        // A miss is owed by the next right answer, which then pays (and adds to
        // `roundSeconds`) that much less — nothing to take off here.
        val lost = recordWrong(topic, grantsScreenTime = true)
        return MiniGameAnswer(lostSeconds = lost)
    }

    /**
     * ProgressStore.creditSurpriseAnswer — only the TIME share of [recordCorrect]
     * (Rani, 2026-10-06: the surprise round's end card shows ⏱ too); the round
     * still pays its own ⭐/💎 ×2 at the end. Seconds credited, 0 at today's cap.
     */
    private fun creditSurpriseAnswer(topic: String): Int = op {
        if (atDailyCap()) return@op 0
        touch()
        rollover()
        val topicCountToday = bumpTopicAnsweredToday(topic)
        val balanceFactor = if (topicCountToday > SAME_TOPIC_SOFT_CAP) 0.5 else 1.0
        payEarned((settings.secondsPerCorrect * balanceFactor).roundHalfAwayFromZero())
    }

    /** ⏱ Seconds this round paid (taken once at the round's end). */
    fun takeRoundSeconds(): Int = roundSeconds.also { roundSeconds = 0 }

    // ── 🎁 chests, daily challenge, worlds, wheel ───────────────────────────
    fun applyChestReward(reward: ChestReward): BonusGrant = op {
        s.stars += reward.stars
        s.diamonds += reward.diamonds
        touch()
        val g = grantBonusMinutesRaw(reward.minutes)
        reward.cosmeticID?.let { l.ownedCosmetics = l.ownedCosmetics + it }
        g
    }

    fun openDailyChest() { s.lastDailyChestDate = nowApple() }

    val dailyChallengeProgress: Int get() = minOf(s.correctToday, DAILY_CHALLENGE_TARGET)
    val dailyChallengeGoalMet: Boolean get() = s.correctToday >= DAILY_CHALLENGE_TARGET
    val dailyChallengeClaimed: Boolean get() = usedToday(s.lastDailyChallengeDate)
    val dailyChallengeRewardReady: Boolean get() = dailyChallengeGoalMet && !dailyChallengeClaimed

    /** Diamonds + 3 bonus minutes, growing gently with the day streak (capped at a week). */
    fun claimDailyChallenge(): BonusGrant {
        if (!dailyChallengeRewardReady) return BonusGrant()
        s.lastDailyChallengeDate = nowApple()
        val streakBonus = minOf(s.dayStreak, 7)
        return applyChestReward(ChestReward(0, 15 + streakBonus * 2, 3))
    }

    fun unlockWorld(id: String) = op {
        val isNew = id !in s.unlockedWorlds
        if (isNew) s.unlockedWorlds = s.unlockedWorlds + id
        touch()
        if (isNew) events += ProgressEvent.WorldUnlocked(id)
    }
    fun canUnlock(starsToUnlock: Int): Boolean = s.stars >= starsToUnlock

    // ── 🏆 World tiers (ProgressStore "World tiers" — the numbers live in [WorldStage]) ──

    /** tier × 10 + room. Legacy kids (rooms only) read as bronze at their room. */
    fun stage(worldID: String): Int = WorldStage.stage(s.worldStage, s.worldProgress, worldID)

    /** 0 = ⭐ bronze, 1 = ⭐⭐ silver, 2 = ⭐⭐⭐ gold, 3 = champion. */
    fun worldTier(worldID: String): Int = WorldStage.tier(stage(worldID))

    /** Grades added to this world's questions: one per tier, at most two. */
    fun tierGradeOffset(worldID: String): Int = WorldStage.gradeOffset(stage(worldID))

    /** Room index 0…9 within the current tier (a champion sits in the last room, so the boss stays there to replay). */
    fun progress(worldID: String): Int = WorldStage.room(stage(worldID))

    fun advanceRoom(worldID: String) = op {
        // The stage BEFORE the legacy bump — read after it, a fresh world would
        // jump two rooms (max(stage, the just-bumped legacy room) + 1).
        val st = stage(worldID)
        // The legacy counter keeps old builds on other devices right.
        s.worldProgress = s.worldProgress + (worldID to minOf((s.worldProgress[worldID] ?: 0) + 1, 9))
        if (st < WorldStage.CHAMPION) s.worldStage = s.worldStage + (worldID to minOf(st + 1, (st / 10) * 10 + 9))
        touch()
    }

    /** A world this child has played in at all (on any device). */
    fun hasVisited(worldID: String): Boolean = WorldStage.visited(s.worldStage, s.worldProgress, worldID)

    /** First time in a world: marks it visited and pays the 💎 nudge once. Returns the diamonds paid (0 later). */
    fun markVisited(worldID: String): Int = op {
        if (hasVisited(worldID)) return@op 0
        s.worldStage = s.worldStage + (worldID to 0)
        s.diamonds += WorldStage.FIRST_VISIT_DIAMONDS
        touch()
        WorldStage.FIRST_VISIT_DIAMONDS
    }

    /** The boss was beaten in the last room: completes the tier. Returns the tier just completed (0 bronze…2 gold), or null on a replay. */
    fun completeTier(worldID: String): Int? = op {
        val st = stage(worldID)
        if (st >= WorldStage.CHAMPION || st % 10 != 9) return@op null
        val done = st / 10
        s.worldStage = s.worldStage + (worldID to (done + 1) * 10)
        s.diamonds += WorldStage.TIER_COMPLETE_DIAMONDS
        touch()
        done
    }

    fun grantBonusWheel() { l.pendingBonusWheel = true }
    fun resetWheelProgress() = op {
        s.wheelProgressCount = 0
        l.pendingBonusWheel = false
        sittingWheelSpins += 1
    }
    /** A "welcome back" spin after ≥20h away — at most once per calendar day. */
    fun grantComebackWheelIfReturning() {
        val last = s.lastSessionDate ?: return
        if ((nowApple() - last) / 3600 < 20) return
        if (usedToday(s.lastComebackWheelAt)) return
        s.lastComebackWheelAt = nowApple()
        grantBonusWheel()
    }

    // ── currencies ──────────────────────────────────────────────────────────
    fun spendPendingMinutes(count: Int): Boolean = op {
        if (count <= 0) return@op true
        if (s.pendingMinutes < count) return@op false
        debitEarnedRaw(count * 60); true
    }
    fun spendStars(amount: Int) = op { if (amount > 0) { s.stars = maxOf(0, s.stars - amount); touch() } }
    fun addStars(amount: Int) = op { if (amount > 0) { s.stars += amount; touch() } }
    fun spendDiamonds(amount: Int) = op { if (amount > 0) { s.diamonds = maxOf(0, s.diamonds - amount); touch() } }
    fun addDiamonds(amount: Int) = op { if (amount > 0) { s.diamonds += amount; touch() } }
    fun addXP(amount: Int) = op { if (amount > 0) setXP(s.xp + amount) }
    fun addScore(amount: Int) = op { if (amount > 0) { s.totalScore += amount; ss.sessionScore += amount; touch() } }
    fun addOwnedCharacter(id: String) = op {
        if (id !in s.ownedCharacterIDs) s.ownedCharacterIDs = s.ownedCharacterIDs + id
        touch()
    }
    fun resetCombo() = op { s.currentStreak = 0; touch() }

    // ── sessions & sittings ─────────────────────────────────────────────────
    fun resetSessionScore() {
        ss.sessionScore = 0; ss.sessionStarsEarned = 0; ss.sessionDiamondsEarned = 0
        ss.sessionMinutesEarned = 0; ss.lastEarnedPoints = 0
    }

    /** One-shot UI flags — the consumer clears them after reading. */
    fun clearOneShots() {
        ss.lastPenaltyMinutes = 0; ss.lastRecoveredMinutes = 0; ss.newStreakRecord = false
        ss.topicBalanceNudgeTopic = null; ss.varietyBonusJustEarned = 0; ss.lastEarnedPoints = 0
    }

    fun registerSessionToday() = op {
        s.dayStreak = nextDayStreak(s.dayStreak, s.lastSessionDate, nowApple(), zone)
        touch()
        s.lastSessionDate = nowApple()
    }

    fun beginSitting() {
        if (ss.sittingActive) return
        ss.sittingActive = true
        clearSitting()
        events += ProgressEvent.SessionStart
    }

    fun endSittingAndReport() {
        if (!ss.sittingActive) return
        ss.sittingActive = false
        val answered = maxOf(sittingQuestions, sittingCorrect)
        val accuracy = if (answered > 0) (sittingCorrect.toDouble() / answered * 100).toInt() else 0
        val avgMs = if (sittingResponseCount > 0) (sittingResponseMsTotal / sittingResponseCount).toInt() else 0
        val topics = sittingTopics.mapValues { (_, t) ->
            mapOf("q" to t.q, "correct" to t.correct, "avgMs" to if (t.correct > 0) (t.ms / t.correct).toInt() else 0)
        }
        events += ProgressEvent.SessionEnd(
            mapOf(
                "questions" to answered, "correct" to sittingCorrect, "accuracy" to accuracy,
                "minutes" to sittingMinutes, "stars" to sittingStars, "xp" to sittingXP,
                "avgResponseMs" to avgMs, "wheelSpins" to sittingWheelSpins, "mystery" to sittingMystery,
                "topics" to topics,
            )
        )
        clearSitting()
    }

    private fun clearSitting() {
        sittingQuestions = 0; sittingCorrect = 0; sittingStars = 0; sittingMinutes = 0
        sittingTopics = LinkedHashMap(); sittingResponseMsTotal = 0.0; sittingResponseCount = 0
        sittingXP = 0; sittingWheelSpins = 0; sittingMystery = 0
    }

    // ── ⏱ the play window ───────────────────────────────────────────────────
    val isUnlocked: Boolean get() = l.unlockEndsAt?.let { it > clock.nowUnix() } ?: false
    val unlockSecondsRemaining: Int get() = l.unlockEndsAt?.let { maxOf(0, (it - clock.nowUnix()).toInt()) } ?: 0

    private val elapsedSinceUnlockStart: Int
        get() {
            val up = clock.uptimeSecs()
            if (l.unlockStartedUptime > 0 && up >= l.unlockStartedUptime) return (up - l.unlockStartedUptime).toInt()
            l.unlockStartedAt?.let { return maxOf(0, (clock.nowUnix() - it).toInt()) }
            return 0
        }

    /** Never more than the wall-clock remainder NOR (granted − monotonic elapsed). */
    val refundableUnlockSeconds: Int
        get() {
            if (l.unlockGrantedSeconds <= 0) return unlockSecondsRemaining
            return minOf(unlockSecondsRemaining, maxOf(0, l.unlockGrantedSeconds - elapsedSinceUnlockStart))
        }

    /** The granted budget has really elapsed (monotonic) — a rolled-back clock can't revive it. */
    val unlockBudgetExhausted: Boolean
        get() {
            val granted = l.unlockGrantedSeconds; val startUp = l.unlockStartedUptime
            if (granted <= 0 || startUp <= 0) return false
            val up = clock.uptimeSecs()
            if (up < startUp) return false
            return up - startUp >= granted
        }

    /** Window still live by BOTH clocks (ProgressStore.hasLiveUnlockGrant). */
    val hasLiveUnlockGrant: Boolean get() = isUnlocked && !unlockBudgetExhausted

    private val minutesUnlockedTodayResolved: Int
        get() = if (!usedToday(s.dailyEarnedDate)) 0 else maxOf(0, s.minutesUnlockedToday - s.returnedTodayMinutes)

    /** What the kid PLAYED against today's cap ("שיחקת היום X מתוך Y"). */
    val minutesPlayedToday: Int get() = minutesUnlockedTodayResolved

    fun openableSeconds(gift: Boolean): Int {
        val settled = if (gift) giftSecondsAvailable else earnedSecondsAvailable
        return settled + if (ss.inFlightRefundIsGift == gift) ss.inFlightRefundSeconds else 0
    }

    /** The earned pocket the button may open RIGHT NOW, to the second (wallet ∧ today's room). */
    val redeemableSecondsNow: Int
        get() {
            val wallet = openableSeconds(false)
            val cap = settings.dailyCap
            if (!cap.enabled) return wallet
            return minOf(wallet, maxOf(0, cap.max - minutesUnlockedTodayResolved) * 60)
        }

    val redeemableMinutesNow: Int
        get() {
            val wallet = earnedSecondsAvailable / 60
            val cap = settings.dailyCap
            if (!cap.enabled) return wallet
            return minOf(wallet, maxOf(0, cap.max - minutesUnlockedTodayResolved))
        }

    val canRedeemNow: Boolean get() = redeemableMinutesNow >= MINIMUM_UNLOCK_MINUTES
    val dailyScreenTimeMaxedOut: Boolean
        get() = settings.dailyCap.enabled && !canRedeemNow && s.pendingMinutes > redeemableMinutesNow

    val giftGivenTodayResolved: Int get() = if (usedToday(s.giftGivenDate)) s.giftGivenToday ?: 0 else 0
    fun minutesUntilMidnight(): Int = DayMath.minutesUntilMidnight(nowApple(), zone)

    /**
     * Offline / lease-off open: debit today's allowance from the wallet. When the
     * cloud isn't fresh (no upload in 2 min) cap it at one minimum window, so an
     * airplane-mode child can't open the full wallet on two devices.
     */
    fun consumeMinutesForUnlock(cloudFresh: Boolean): Int = op {
        rollover()
        var amount = redeemableMinutesNow
        if (amount <= 0) return@op 0
        if (!cloudFresh) amount = minOf(amount, MINIMUM_UNLOCK_MINUTES)
        debitEarnedRaw(amount * 60)
        s.minutesUnlockedToday += amount
        amount
    }

    /** 💝 Open the whole gift pocket — counters decide, a sub-minute pocket still opens (≥1). */
    fun consumeParentGiftForUnlock(): Int = op {
        val seconds = giftSecondsAvailable
        if (seconds <= 0) return@op 0
        debitGiftRaw(seconds)
        maxOf(1, seconds / 60)
    }

    /** Parent ±minutes command applied locally (earned pocket). */
    fun addPendingMinutes(delta: Int) = op {
        if (delta > 0) creditEarnedRaw(delta * 60) else if (delta < 0) debitEarnedRaw(-delta * 60)
    }

    /** 💝 Parent gift applied locally + "given today" for the until-midnight cap. */
    fun addParentGiftMinutes(delta: Int) = op {
        if (delta == 0) return@op
        if (delta > 0) creditGiftRaw(delta * 60) else debitGiftRaw(-delta * 60)
        if (delta > 0) {
            if (usedToday(s.giftGivenDate)) s.giftGivenToday = (s.giftGivenToday ?: 0) + delta
            else { s.giftGivenToday = delta; s.giftGivenDate = nowApple() }
            touch()
        }
    }

    /**
     * Open a window. `extraSeconds` overrides the local carry (with the lease the
     * odd seconds come back inside the grant). An open EARNED window is banked first.
     */
    fun startUnlock(minutes: Int, manual: Boolean = false, leaseID: String? = null, leaseKind: String? = null, extraSeconds: Int? = null) = op {
        if (isUnlocked && !l.unlockIsManual) endUnlockAndReturnRemainingMinutesRaw()
        val extra = extraSeconds ?: if (manual) 0 else (s.secondsCarry ?: 0)
        if (extraSeconds == null && !manual) s.secondsCarry = 0
        val now = clock.nowUnix()
        l.unlockIsManual = manual
        l.unlockEndsAt = now + minutes * 60 + extra
        touch()
        l.unlockGrantedSeconds = minutes * 60 + extra
        l.unlockStartedAt = now
        l.unlockStartedUptime = clock.uptimeSecs()
        l.unlockKind = leaseKind ?: if (manual) "grant" else "earned"
        if (leaseID != null) l.activeLeaseID = leaseID
    }

    /** Add minutes to an open MANUAL window; otherwise start a fresh gift window. */
    fun extendUnlock(minutes: Int) = op {
        val end = l.unlockEndsAt
        if (minutes <= 0 || end == null || end <= clock.nowUnix() || !l.unlockIsManual) {
            startUnlock(minutes, manual = true, leaseKind = "gift"); return@op
        }
        l.unlockEndsAt = end + minutes * 60
        l.unlockGrantedSeconds += minutes * 60
        touch()
    }

    fun endUnlock() = op { endUnlockRaw() }
    private fun endUnlockRaw() {
        l.unlockEndsAt = null
        touch()
        l.unlockIsManual = false
        l.unlockGrantedSeconds = 0
        l.unlockStartedAt = null
        l.unlockStartedUptime = 0.0
        l.activeLeaseID = null
    }

    /** Stop early, bank the EXACT leftover (minutes + 0…59 carry). A manual grant banks nothing. */
    fun endUnlockAndReturnRemainingMinutes(): Int = op { endUnlockAndReturnRemainingMinutesRaw() }
    private fun endUnlockAndReturnRemainingMinutesRaw(): Int {
        if (l.unlockIsManual) { endUnlockRaw(); return 0 }
        val total = (s.secondsCarry ?: 0) + refundableUnlockSeconds
        val minutes = total / 60
        s.secondsCarry = total % 60
        if (minutes > 0) {
            creditEarnedRaw(minutes * 60)
            s.returnedTodayMinutes += minutes
        }
        l.unlockEndsAt = null
        touch()
        return minutes
    }

    /** A parent window's leftover goes back to the SYNCED gift pocket. */
    fun pauseManualUnlock() = op {
        if (!l.unlockIsManual) return@op
        val remaining = refundableUnlockSeconds
        if (remaining > 0) creditGiftRaw(remaining)
        endUnlockRaw()
    }

    /**
     * "עצור ושמור" — every stop path funnels here. With a lease, the window closes
     * WITHOUT paying locally (the release transaction pays; paying twice is what
     * doubled children's time) and an in-flight refund is shown meanwhile. The
     * caller must run the release with [StopOutcome] and, if the cloud can't take
     * it, call [creditRefundLocally].
     */
    fun stopAndSaveCurrentUnlock(): StopOutcome = op {
        if (!isUnlocked) return@op StopOutcome(0)
        val leaseID = l.activeLeaseID
        val remaining = refundableUnlockSeconds
        val wasManual = l.unlockIsManual
        when {
            settings.leaseEnabled && leaseID != null -> {
                endUnlockRaw()
                beginInFlightRefund(remaining, wasManual)
                StopOutcome(remaining / 60, leaseID, remaining, wasManual)
            }
            wasManual -> { pauseManualUnlock(); StopOutcome(0) }
            else -> StopOutcome(endUnlockAndReturnRemainingMinutesRaw())
        }
    }

    private fun beginInFlightRefund(seconds: Int, gift: Boolean) {
        if (seconds <= 0) return
        ss.inFlightRefundSeconds = seconds
        ss.inFlightRefundIsGift = gift
    }
    fun clearInFlightRefund() { ss.inFlightRefundSeconds = 0 }

    /** The cloud could not take the refund (offline) — pay it here, to the pocket that funded it. */
    fun creditRefundLocally(seconds: Int, manual: Boolean) = op {
        clearInFlightRefund()
        if (seconds <= 0) return@op
        if (manual) creditGiftRaw(seconds) else creditEarnedRaw(seconds)
    }

    /** Mirror of creditRefundLocally for a spend the cloud already made. */
    fun debitSpendLocally(seconds: Int, gift: Boolean) = op {
        if (seconds <= 0) return@op
        if (gift) debitGiftRaw(seconds) else debitEarnedRaw(seconds)
    }

    /**
     * Parent "נעל ואפס דקות מתנה": wipe the gift pocket and close a parent window;
     * an EARNED window is banked back. The caller releases [RevokeOutcome.releaseLeaseID] with refund 0.
     */
    fun revokeAllParentTime(): RevokeOutcome = op {
        debitGiftRaw(giftSecondsAvailable)
        l.manualPausedSeconds = 0
        if (!isUnlocked) return@op RevokeOutcome(false, null)
        val leaseID = l.activeLeaseID
        if (l.unlockIsManual) endUnlockRaw() else endUnlockAndReturnRemainingMinutesRaw()
        RevokeOutcome(true, if (settings.leaseEnabled) leaseID else null)
    }

    fun adoptLeaseID(id: String) { if (isUnlocked) l.activeLeaseID = id }

    /**
     * Apply what a lease transaction moved to THIS device's counters (increments
     * converge with the cloud's under max-merge), then adopt its generation.
     */
    fun applyClaimedWallet(w: ClaimedWallet) {
        clearInFlightRefund()
        op {
            if (w.deltaSeconds > 0) { if (w.deltaIsGift) creditGiftRaw(w.deltaSeconds) else creditEarnedRaw(w.deltaSeconds) }
            else if (w.deltaSeconds < 0) { if (w.deltaIsGift) debitGiftRaw(-w.deltaSeconds) else debitEarnedRaw(-w.deltaSeconds) }
        }
        s.minutesUnlockedToday = maxOf(s.minutesUnlockedToday, w.minutesUnlockedToday)
        adoptRevision(w.revision)
    }

    // ── sync: capture / apply / merge ───────────────────────────────────────
    /** The store as a snapshot. Carries the REAL version — never stamps lastModifiedAt. */
    fun capture(): ProgressSnapshot {
        val c = s.copy(
            unlockEndsAt = null, purgeCacheAt = null, deviceID = deviceID,
            earnedSecondsIn = ein, earnedSecondsOut = eout, giftSecondsIn = gin, giftSecondsOut = gout,
            secondsCarry = s.secondsCarry ?: 0, carryIsGift = s.carryIsGift ?: false,
            carryOverMinutes = s.carryOverMinutes ?: 0, giftGivenToday = s.giftGivenToday ?: 0,
            topicAdaptiveLevel = s.topicAdaptiveLevel ?: emptyMap(),
            hourlyAnswered = s.hourlyAnswered?.takeIf { it.size == 24 } ?: List(24) { 0 },
            hourlyCorrect = s.hourlyCorrect?.takeIf { it.size == 24 } ?: List(24) { 0 },
        )
        c.syncWalletMirrors()   // AFTER the counters are in
        return c
    }

    /** Overwrite the store with a snapshot (profile switch / winning remote). Counters max; mirrors derived. */
    fun apply(x: ProgressSnapshot) {
        applying = true
        s.totalCorrect = x.totalCorrect
        s.totalAnswered = x.totalAnswered
        s.earnedSecondsIn = maxOf(ein, x.earnedSecondsIn ?: 0)
        s.earnedSecondsOut = maxOf(eout, x.earnedSecondsOut ?: 0)
        s.giftSecondsIn = maxOf(gin, x.giftSecondsIn ?: 0)
        s.giftSecondsOut = maxOf(gout, x.giftSecondsOut ?: 0)
        x.secondsCarry?.let { s.secondsCarry = maxOf(0, minOf(59, it)) }
        x.carryIsGift?.let { s.carryIsGift = it }
        s.stars = x.stars
        s.diamonds = x.diamonds
        setXP(x.xp)
        s.currentStreak = x.currentStreak
        s.dayStreak = x.dayStreak
        s.lastSessionDate = x.lastSessionDate
        s.lastDailyChestDate = x.lastDailyChestDate
        s.lastDailyChallengeDate = x.lastDailyChallengeDate
        x.hourlyAnswered?.takeIf { it.size == 24 }?.let { s.hourlyAnswered = it }
        x.hourlyCorrect?.takeIf { it.size == 24 }?.let { s.hourlyCorrect = it }
        s.unlockedWorlds = x.unlockedWorlds.distinct()
        s.worldProgress = x.worldProgress
        s.worldStage = x.worldStage
        s.topicAccuracy = x.topicAccuracy
        s.topicAnswered = x.topicAnswered
        s.topicCorrect = x.topicCorrect
        s.batchCounter = x.batchCounter
        s.cycleSeconds = x.cycleSeconds
        s.wrongStreak = x.wrongStreak
        s.totalScore = x.totalScore
        s.lastComebackWheelAt = x.lastComebackWheelAt
        x.varietyBonusDate?.let { if (it > (s.varietyBonusDate ?: AppleTime.DISTANT_PAST)) s.varietyBonusDate = it }
        s.minutesEarnedToday = x.minutesEarnedToday
        s.minutesUnlockedToday = x.minutesUnlockedToday
        s.returnedTodayMinutes = x.returnedTodayMinutes
        s.dailyEarnedDate = x.dailyEarnedDate
        s.answeredToday = x.answeredToday
        s.correctToday = x.correctToday
        s.carryOverMinutes = x.carryOverMinutes ?: 0
        s.bestStreak = maxOf(s.bestStreak, x.bestStreak)
        s.topicResponseMs = x.topicResponseMs
        s.topicAffinity = x.topicAffinity
        s.topicExposure = x.topicExposure
        s.topicAbandon = x.topicAbandon
        s.topicAdaptiveLevel = x.topicAdaptiveLevel ?: emptyMap()
        s.wheelProgressCount = x.wheelProgressCount
        s.recoveryPot = x.recoveryPot
        s.giftGivenToday = x.giftGivenToday ?: 0
        s.giftGivenDate = x.giftGivenDate
        s.ownedCharacterIDs = x.ownedCharacterIDs.distinct()
        // iOS `defer`: the guard drops FIRST, then the version is adopted, then the
        // mirrors are derived — and that last publish counts as one local edit.
        applying = false
        s.resetEpoch = x.resetEpoch
        s.revision = x.revision
        noteAdoptedGeneration(x.revision)
        s.lastModifiedAt = x.lastModifiedAt
        deriveWalletMirrors(x)
        commit()
    }

    /**
     * Merge a remote snapshot of THIS child without losing local progress. Returns
     * true when the caller should re-upload (we hold something the remote lacked).
     */
    fun mergeRemote(remote: ProgressSnapshot): Boolean {
        val local = capture()
        noteAdoptedGeneration(remote.revision)
        val merged = ProgressSnapshot.ratchetMerged(local, remote, nowApple(), zone)
        val changedLocal = !ProgressSnapshot.sameProgressData(merged, local)
        val aheadOfRemote = !ProgressSnapshot.sameProgressData(merged, remote)
        if (changedLocal) {
            if (aheadOfRemote) {
                merged.revision = maxOf(local.revision, remote.revision) + 1
                merged.lastModifiedAt = nowApple()
            } else {
                merged.revision = remote.revision
                merged.lastModifiedAt = remote.lastModifiedAt
            }
            merged.deviceID = deviceID
            apply(merged)
            return aheadOfRemote
        }
        if (aheadOfRemote) {
            noteAdoptedGeneration(remote.revision)
            s.revision = maxOf(local.revision, remote.revision) + 1
            s.lastModifiedAt = nowApple()
            return true
        }
        return false
    }

    /** After an authoritative cloud write — never restamps lastModifiedAt. */
    fun adoptRevision(r: Int) {
        s.revision = maxOf(s.revision, r)
        noteAdoptedGeneration(r)
    }

    /** After OUR upload landed at generation `r`; edits made meanwhile must outrank it. */
    fun adoptUploadedGeneration(r: Int, editedSince: Boolean) {
        noteAdoptedGeneration(r)
        s.revision = maxOf(s.revision, if (editedSince) r + 1 else r)
    }

    fun adoptResetEpoch(e: Int) { s.resetEpoch = maxOf(s.resetEpoch, e) }

    /**
     * Parent reset (ProgressStore.resetAll). Faithful to iOS, including that the
     * wallet counters and bestStreak survive locally (apply() max-merges them).
     */
    fun resetAll() {
        val next = s.revision + 1
        apply(ProgressSnapshot(deviceID = deviceID, lastModifiedAt = nowApple()))
        s.revision = next
        s.lastModifiedAt = nowApple()
        l.manualPausedSeconds = 0
        l.earnDay = null; l.earnCapCarry = 0; l.earnOverflow = 0; l.earnDebt = 0
        if (isUnlocked) endUnlock()
        ss.sessionScore = 0; ss.lastEarnedPoints = 0; ss.lastPenaltyMinutes = 0; ss.lastRecoveredMinutes = 0
    }

    companion object {
        const val MAX_CARRY_OVER = 30
        const val SAME_TOPIC_SOFT_CAP = 30
        const val VARIETY_BONUS_MINUTES = 10
        const val VARIETY_TOPICS_NEEDED = 3
        const val VARIETY_MIN_ANSWERS_PER_TOPIC = 5
        const val DAILY_CHALLENGE_TARGET = 10
        /** Smallest earned window — always 15 (iOS can't re-lock shorter reliably; kept for parity). */
        const val MINIMUM_UNLOCK_MINUTES = 15

        /** Same day → unchanged; next day → +1; a gap (or first play) → 1. */
        fun nextDayStreak(current: Int, last: Double?, nowApple: Double, zone: ZoneId): Int {
            if (last == null) return 1
            return when (DayMath.daysBetween(last, nowApple, zone)) {
                0L -> current
                1L -> current + 1
                else -> 1
            }
        }

        /** The store's own shape: counters and the always-present optionals filled in (ProgressStore.init). */
        private fun normalize(x: ProgressSnapshot): ProgressSnapshot = x.copy(
            earnedSecondsIn = x.earnedSecondsIn ?: 0, earnedSecondsOut = x.earnedSecondsOut ?: 0,
            giftSecondsIn = x.giftSecondsIn ?: 0, giftSecondsOut = x.giftSecondsOut ?: 0,
            carryOverMinutes = x.carryOverMinutes ?: 0, parentGiftMinutes = x.parentGiftMinutes ?: 0,
            giftGivenToday = x.giftGivenToday ?: 0, topicAdaptiveLevel = x.topicAdaptiveLevel ?: emptyMap(),
            secondsCarry = x.secondsCarry ?: 0, carryIsGift = x.carryIsGift ?: false,
            hourlyAnswered = x.hourlyAnswered?.takeIf { it.size == 24 } ?: List(24) { 0 },
            hourlyCorrect = x.hourlyCorrect?.takeIf { it.size == 24 } ?: List(24) { 0 },
            unlockEndsAt = null, purgeCacheAt = null,
        )
    }
}

/**
 * MiniGameEarnSession's token bucket: one credited answer every 6 s of play, at
 * most 4 banked, 3 at the start — no game may become a cheap minute farm.
 */
class MiniGameEarnBucket(private val nowSecs: () -> Double) {
    private var tokens = START_TOKENS
    private var lastRefill = nowSecs()

    fun takeCredit(): Boolean {
        val now = nowSecs()
        tokens = minOf(CAPACITY, tokens + (now - lastRefill) / SECONDS_PER_CREDIT)
        lastRefill = now
        if (tokens < 1) return false
        tokens -= 1
        return true
    }

    companion object {
        const val SECONDS_PER_CREDIT = 6.0
        const val CAPACITY = 4.0
        const val START_TOKENS = 3.0
    }
}

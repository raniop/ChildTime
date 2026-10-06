package com.rani.tofy.kid.ui.games

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.AndroidKidClock
import com.rani.tofy.kid.core.ChestReward
import com.rani.tofy.kid.core.DayMath
import com.rani.tofy.kid.core.AppleTime
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.MiniGameEarnBucket
import com.rani.tofy.kid.core.ProgressEngine
import com.rani.tofy.kid.ui.play.LearningHistoryRecorder
import com.rani.tofy.ui.child.Topic
import java.time.ZoneId
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Where a game's answers and its round-end prize go. The app uses [KidSink]
 * (KidSession → ProgressEngine → sync); tests plug a bare ProgressEngine in.
 */
interface GameProgressSink {
    fun miniGameAnswer(correct: Boolean, topic: String, responseMs: Double, bucket: MiniGameEarnBucket?,
                       surprise: Boolean, retry: Boolean): ProgressEngine.MiniGameAnswer
    /** MiniGameLedger.takeRoundSeconds — what this round paid, taken once at its end. */
    fun takeRoundSeconds(): Int
    /** ProgressStore.applyChestReward — minutes go through the daily-cap-aware bonus path. */
    fun applyChest(stars: Int, diamonds: Int, minutes: Int = 0)
    /** 🐉 recordBossAnswer: counts in the reports, pays nothing per answer. */
    fun bossAnswer(correct: Boolean)
    val secondsPerCorrect: Int
    val currentStreak: Int
    fun newBucket(): MiniGameEarnBucket
    /** The runner's session start (registerSessionToday + beginSitting + device row). */
    fun startSession()
    fun recordHistory(topic: String, correct: Boolean, responseMs: Double, earnedMinutes: Int, streak: Int, voluntary: Boolean)
    /** Unix seconds + the zone, for the day gates. */
    fun nowUnix(): Double
    val zone: ZoneId
}

object KidSink : GameProgressSink {
    override fun miniGameAnswer(correct: Boolean, topic: String, responseMs: Double, bucket: MiniGameEarnBucket?,
                                surprise: Boolean, retry: Boolean) =
        KidSession.miniGameAnswer(correct, topic, responseMs, bucket, surprise, retry)
    override fun takeRoundSeconds(): Int = KidSession.edit { it.takeRoundSeconds() } ?: 0
    override fun applyChest(stars: Int, diamonds: Int, minutes: Int) { KidSession.edit { it.applyChestReward(ChestReward(stars, diamonds, minutes)) } }
    override fun bossAnswer(correct: Boolean) { KidSession.edit { it.recordBossAnswer(correct) } }
    override val secondsPerCorrect: Int get() = KidSession.engine()?.settings?.secondsPerCorrect ?: 24
    override val currentStreak: Int get() = KidSession.engine()?.snapshot?.currentStreak ?: 0
    override fun newBucket(): MiniGameEarnBucket = KidSession.newMiniGameBucket()
    override fun startSession() {
        KidSession.startSession()
        KidSession.boundChildID?.let { LearningHistoryRecorder.recordSessionStart(it) }
    }
    override fun recordHistory(topic: String, correct: Boolean, responseMs: Double, earnedMinutes: Int, streak: Int, voluntary: Boolean) {
        val cid = KidSession.boundChildID ?: return
        LearningHistoryRecorder.recordAnswer(cid, topic, correct, responseMs, earnedMinutes, streak, voluntary)
    }
    override fun nowUnix(): Double = AndroidKidClock.nowUnix()
    override val zone: ZoneId get() = AndroidKidClock.zone
}

// MARK: - ⏱ Earning screen time from a game (MiniGameEarning.swift)

/**
 * A game opened from a world's chooser earns screen time exactly like the
 * regular questions: every right answer goes through the SAME recordCorrect
 * the runner uses, a miss is recordWrong (half a step off the cycle). Credits
 * come from a token bucket (one per 6 s, ≤ 4 banked, 3 at the start) so no
 * game is a cheap farm. ⚡ Surprise rounds never get one: ⭐/💎 only.
 *
 * Also the UI state of the "+24 שְׁנִיּוֹת" flash, the "+4 דקות" pop and the
 * daily-cap line (MiniGameEarnOverlay).
 */
class MiniGameEarnSession(private val scope: CoroutineScope, startSession: Boolean = true) {
    val bucket: MiniGameEarnBucket = MiniGameLedger.sink.newBucket()

    var flashText by mutableStateOf<String?>(null); private set
    var flashPositive by mutableStateOf(true); private set
    var flashID by mutableIntStateOf(0); private set
    var popupMinutes by mutableIntStateOf(0); private set
    /** Bumps on every "+N דקות" pop (EarnedMinutesPopup's trigger). */
    var popupTrigger by mutableIntStateOf(0); private set
    var capReached by mutableStateOf(false); private set
    private var flashJob: Job? = null

    init {
        // The runner's session start, so the parent sees the sitting.
        if (startSession) MiniGameLedger.sink.startSession()
    }

    fun flash(text: String, positive: Boolean) {
        flashPositive = positive
        flashID += 1
        val id = flashID
        flashText = text
        flashJob?.cancel()
        flashJob = scope.launch { delay(1100); if (flashID == id) flashText = null }
    }

    fun popMinutes(minutes: Int) { popupMinutes = minutes; popupTrigger += 1 }

    fun noteCap() { if (!capReached) capReached = true }
}

/** The one place a game reports an answer (MiniGameLedger). */
object MiniGameLedger {
    var sink: GameProgressSink = KidSink

    /** ⚡ Set by the runner while its surprise round is on screen (an earning session). */
    var surpriseEarnsTime = false

    /**
     * One answer in `topic`. From a chooser (`earn` set, not a surprise): the
     * runner's own path — minutes, cycle, cap, adaptive level, ⭐/💎. Otherwise
     * counted for the parent's reports; ⚡ a surprise round's right answer also
     * pays its seconds (the end card's ⏱).
     * `retry` = right after a miss on the SAME item: pays in full but doesn't
     * claim the recovery pot.
     */
    fun record(correct: Boolean, topic: Topic, responseMs: Double = 0.0, streak: Int = 0,
               earn: MiniGameEarnSession?, surprise: Boolean, retry: Boolean = false) {
        if (earn == null || surprise) {
            // ⚡ `surprise` here asks the engine to pay the answer's seconds too.
            val out = sink.miniGameAnswer(correct, topic.raw, responseMs, null, surprise = surprise && surpriseEarnsTime, retry = false)
            sink.recordHistory(topic.raw, correct, responseMs, out.minutesGranted, streak, false)
            return
        }
        val out = sink.miniGameAnswer(correct, topic.raw, responseMs, earn.bucket, surprise = false, retry = retry)
        if (correct) {
            // paid > 0 ⇔ the bucket paid AND today wasn't capped — so "voluntary" is its complement.
            sink.recordHistory(topic.raw, true, responseMs, out.minutesGranted, sink.currentStreak, voluntary = out.paidSeconds == 0)
            // Answering right is NEVER silent: seconds when earned, the stars themselves when not.
            if (out.paidSeconds > 0) earn.flash(tr("+%lld שְׁנִיּוֹת", out.paidSeconds), positive = true)
            else earn.flash("⭐ +${out.stars}", positive = true)
            // Seconds land one answer at a time now; only a real bonus gets the big "+N דקות" pop.
            if (out.varietyBonus > 0) earn.popMinutes(out.varietyBonus)
            if (out.capReached) earn.noteCap()
        } else {
            sink.recordHistory(topic.raw, false, 0.0, 0, 0, false)
            // No "−12 שניות": the balance never drops — just the encouraging word.
            if (out.lostSeconds > 0) earn.flash(tr("כִּמְעַט!"), positive = false)
        }
    }
}

// MARK: - 🎁 Mini-game rewards (⭐ + 💎 at the end; the ⏱ seconds were paid per answer)

object MiniGameReward {
    /** What a finished round paid: ⭐, 💎, and ⏱ the screen-time SECONDS it earned (the build-198 end card). */
    data class Grant(val stars: Int, val diamonds: Int, val full: Boolean, val doubled: Boolean = false, val seconds: Int = 0)

    /** How much bigger the day's FIRST round of a game is than a replay. */
    const val FULL_MULTIPLIER = 3

    private fun dayKey(game: String) = "minigame.full.$game.${GameEnv.childKey}"

    internal fun usedToday(game: String): Boolean = GameDayGate.usedToday(dayKey(game))

    /**
     * From a world screen: the day's FIRST finished round pays ×3 per correct
     * answer (capped); replays pay ×1; a round with nothing solved still pays
     * 3⭐ / 2💎 and leaves today's big prize unspent. ⚡ A surprise round always
     * pays the full amount ×2 — the 12–15 real questions before it are the gate.
     */
    fun grant(game: String, correct: Int, starsPer: Int, diamondsPer: Int, cap: Int, surprise: Boolean = false): Grant {
        val n = maxOf(0, minOf(correct, cap))
        val seconds = MiniGameLedger.sink.takeRoundSeconds()
        val grant = if (surprise) {
            val m = SurpriseRound.REWARD_MULTIPLIER
            Grant(n * starsPer * m, n * diamondsPer * m, full = true, doubled = true, seconds = seconds)
        } else {
            val used = usedToday(game)
            when {
                n == 0 -> Grant(3, 2, full = !used, seconds = seconds)
                !used -> {
                    GameDayGate.mark(dayKey(game))
                    Grant(n * starsPer * FULL_MULTIPLIER, n * diamondsPer * FULL_MULTIPLIER, full = true, seconds = seconds)
                }
                else -> Grant(n * starsPer, n * diamondsPer, full = false, seconds = seconds)
            }
        }
        if (grant.stars > 0 || grant.diamonds > 0) MiniGameLedger.sink.applyChest(grant.stars, grant.diamonds)
        return grant
    }
}

/** DayGate.swift over the games' prefs: a stamp dated today OR LATER counts as used (a moved clock never re-opens it). */
object GameDayGate {
    fun usedToday(key: String): Boolean {
        val stamp = GameEnv.prefs.getString(key)?.toDoubleOrNull() ?: return false
        val s = MiniGameLedger.sink
        return DayMath.usedToday(AppleTime.fromUnix(stamp), AppleTime.fromUnix(s.nowUnix()), s.zone)
    }

    fun mark(key: String) = GameEnv.prefs.putString(key, MiniGameLedger.sink.nowUnix().toString())
}

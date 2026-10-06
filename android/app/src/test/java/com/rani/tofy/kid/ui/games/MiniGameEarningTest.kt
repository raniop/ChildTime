package com.rani.tofy.kid.ui.games

import com.rani.tofy.ui.child.Topic
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** MiniGameReward.grant (the ×3 first-of-day rule, zero-correct 3⭐/2💎, ⚡ ×2) and MiniGameLedger.record. */
class MiniGameEarningTest {
    private lateinit var sink: EngineSink
    private val scope = CoroutineScope(Dispatchers.Unconfined)

    @Before fun setUp() { sink = GameTestSupport.install() }

    // ── 🎁 the round-end grant ───────────────────────────────────────────────
    @Test fun firstRoundOfTheDayPaysTriple() {
        val g = MiniGameReward.grant("pairs", correct = 5, starsPer = 2, diamondsPer = 2, cap = 5)
        assertEquals(30, g.stars); assertEquals(30, g.diamonds)
        assertTrue(g.full); assertFalse(g.doubled)
        assertEquals(30, sink.engine.snapshot.stars)
    }

    @Test fun replaySameDayPaysSingle() {
        MiniGameReward.grant("balloon", 10, 1, 1, 15)
        val g = MiniGameReward.grant("balloon", 10, 1, 1, 15)
        assertEquals(10, g.stars); assertEquals(10, g.diamonds); assertFalse(g.full)
    }

    @Test fun eachGameHasItsOwnDailyBigPrize() {
        MiniGameReward.grant("balloon", 4, 1, 1, 15)
        assertTrue(MiniGameReward.grant("crush", 4, 2, 1, 10).full)
    }

    @Test fun bigPrizeComesBackTomorrow() {
        MiniGameReward.grant("word", 5, 2, 2, 5)
        sink.clock.advance(24 * 3600.0)
        val g = MiniGameReward.grant("word", 5, 2, 2, 5)
        assertTrue(g.full); assertEquals(30, g.stars)
    }

    @Test fun zeroCorrectStillPaysThreeStarsTwoDiamondsAndKeepsTheBigPrize() {
        val g = MiniGameReward.grant("lightning", 0, 1, 1, 15)
        assertEquals(3, g.stars); assertEquals(2, g.diamonds); assertTrue(g.full)
        assertEquals(3, sink.engine.snapshot.stars); assertEquals(2, sink.engine.snapshot.diamonds)
        // Today's big one is still there for the next round.
        assertTrue(MiniGameReward.grant("lightning", 2, 1, 1, 15).full)
    }

    @Test fun zeroCorrectAfterTheBigPrizeIsNotFull() {
        MiniGameReward.grant("sort", 3, 1, 1, 10)
        val g = MiniGameReward.grant("sort", 0, 1, 1, 10)
        assertEquals(3, g.stars); assertEquals(2, g.diamonds); assertFalse(g.full)
    }

    @Test fun capLimitsTheCount() {
        val g = MiniGameReward.grant("balloon", 40, 1, 1, 15)
        assertEquals(45, g.stars)
    }

    @Test fun surpriseRoundPaysDoubleAndNeverTouchesTheDayGate() {
        val g = MiniGameReward.grant("pairs", 5, 2, 2, 5, surprise = true)
        assertEquals(20, g.stars); assertEquals(20, g.diamonds); assertTrue(g.doubled); assertTrue(g.full)
        assertTrue(MiniGameReward.grant("pairs", 5, 2, 2, 5).full)
    }

    @Test fun surpriseAnswersPaySecondsOnlyInAnEarningSession() {
        val per = sink.secondsPerCorrect
        MiniGameLedger.surpriseEarnsTime = true
        try {
            repeat(3) { MiniGameLedger.record(true, Topic.MATH, earn = null, surprise = true) }
            MiniGameLedger.record(false, Topic.MATH, earn = null, surprise = true)   // a miss costs nothing here
            assertEquals(3 * per, MiniGameReward.grant("vault", 3, 2, 1, 4, surprise = true).seconds)
        } finally { MiniGameLedger.surpriseEarnsTime = false }
        repeat(3) { MiniGameLedger.record(true, Topic.MATH, earn = null, surprise = true) }
        assertEquals(0, MiniGameReward.grant("vault", 3, 2, 1, 4, surprise = true).seconds)
    }

    @Test fun movedClockCannotReopenTheBigPrize() {
        sink.clock.advance(3 * 24 * 3600.0)
        MiniGameReward.grant("vault", 5, 2, 1, 10)
        sink.clock.advance(-3 * 24 * 3600.0)   // back to "yesterday": a stamp in the future still counts as used
        assertFalse(MiniGameReward.grant("vault", 5, 2, 1, 10).full)
    }

    // ── ⏱ the ledger (MiniGameEarning.swift) ────────────────────────────────
    @Test fun chooserAnswersPaySecondsPacedByTheBucket() {
        val earn = MiniGameEarnSession(scope)
        val per = sink.secondsPerCorrect
        // Three credits at the start; the fourth instant answer pays stars only.
        repeat(3) { MiniGameLedger.record(true, Topic.MATH, earn = earn, surprise = false) }
        assertEquals("+$per שְׁנִיּוֹת", earn.flashText)
        assertTrue(earn.flashPositive)
        MiniGameLedger.record(true, Topic.MATH, earn = earn, surprise = false)
        assertTrue(earn.flashText!!.startsWith("⭐ +"))
        val g = MiniGameReward.grant("crush", 4, 2, 1, 10)
        assertEquals(3 * per, g.seconds)
        // Taken once: the next round starts from zero.
        assertEquals(0, MiniGameReward.grant("crush", 1, 2, 1, 10).seconds)
    }

    @Test fun bucketRefillsWithTime() {
        val earn = MiniGameEarnSession(scope)
        repeat(4) { MiniGameLedger.record(true, Topic.MATH, earn = earn, surprise = false) }
        sink.clock.advance(6.0)
        MiniGameLedger.record(true, Topic.MATH, earn = earn, surprise = false)
        assertEquals(4 * sink.secondsPerCorrect, MiniGameReward.grant("crush", 5, 2, 1, 10).seconds)
    }

    @Test fun aMissCostsHalfAStepAndIsGentle() {
        val earn = MiniGameEarnSession(scope)
        repeat(3) { MiniGameLedger.record(true, Topic.MATH, earn = earn, surprise = false) }
        MiniGameLedger.record(false, Topic.MATH, earn = earn, surprise = false)
        assertFalse(earn.flashPositive)
        assertTrue(earn.flashText!!.contains("כִּמְעַט"))
        // The miss is owed by the NEXT right answer, so the round's ⏱ shows what really landed.
        val before = sink.engine.earnedSecondsAvailable
        MiniGameLedger.record(true, Topic.MATH, earn = earn, surprise = false)
        val g = MiniGameReward.grant("crush", 4, 2, 1, 10)
        assertEquals(sink.engine.earnedSecondsAvailable - before + 3 * sink.secondsPerCorrect, g.seconds)
    }

    @Test fun surpriseAnswersPayNoMinutes() {
        val before = sink.engine.snapshot.cycleSeconds
        repeat(5) { MiniGameLedger.record(true, Topic.SOCCER, earn = null, surprise = true) }
        assertEquals(before, sink.engine.snapshot.cycleSeconds, 0.0001)
        assertEquals(5, sink.engine.snapshot.totalCorrect)
        assertEquals(0, MiniGameReward.grant("balloon", 5, 1, 1, 12, surprise = true).seconds)
        assertEquals(5, sink.historyRows)
    }

    @Test fun earnSessionStartsTheSittingAndShowsTheCap() {
        val earn = MiniGameEarnSession(scope)
        assertEquals(1, sink.sessions)
        assertFalse(earn.capReached)
        earn.noteCap(); assertTrue(earn.capReached)
        earn.popMinutes(4); assertEquals(4, earn.popupMinutes); assertEquals(1, earn.popupTrigger)
    }

    @Test fun flashClearsItself() = kotlinx.coroutines.test.runTest {
        val earn = MiniGameEarnSession(this, startSession = false)
        earn.flash("x", true)
        assertNotNull(earn.flashText)
        testScheduler.advanceTimeBy(1200)
        assertNull(earn.flashText)
    }

    // ── 🧱 the day gate helper ───────────────────────────────────────────────
    @Test fun dayGateMarksToday() {
        assertFalse(GameDayGate.usedToday("boss.won.math_kingdom"))
        GameDayGate.mark("boss.won.math_kingdom")
        assertTrue(GameDayGate.usedToday("boss.won.math_kingdom"))
        sink.clock.advance(24 * 3600.0)
        assertFalse(GameDayGate.usedToday("boss.won.math_kingdom"))
    }
}

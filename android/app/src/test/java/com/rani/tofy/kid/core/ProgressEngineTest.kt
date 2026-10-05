package com.rani.tofy.kid.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.ZoneId

/** Ports of ChildTimeTests.swift (wallet counters, streaks, chests) + the earning rules. */
class ProgressEngineTest {

    private class FakeClock(override val zone: ZoneId = ZoneId.of("Asia/Jerusalem")) : KidClock {
        // Wednesday 2026-10-07 10:00 local — a weekday, so 💎 for "math" is ×1.
        var unix = LocalDateTime.of(2026, 10, 7, 10, 0).atZone(zone).toEpochSecond().toDouble()
        var up = 1000.0
        override fun nowUnix() = unix
        override fun uptimeSecs() = up
        fun advance(seconds: Double) { unix += seconds; up += seconds }
    }

    private val clock = FakeClock()
    private fun engine(settings: KidSettings = KidSettings(), id: String = "DEV-A") = ProgressEngine(settings, clock, id)
    private val noCap = KidSettings(childDailyCapMinutes = 0)

    @Test fun clockIsAWeekday() {
        assertEquals(DayOfWeek.WEDNESDAY, DayMath.localDate(AppleTime.fromUnix(clock.unix), clock.zone).dayOfWeek)
    }

    // ── 💰 wallet counters (WalletCounterTests) ─────────────────────────────
    @Test fun exactToTheSecond() {
        val p = engine()
        p.creditEarned(29 * 60 + 40)
        assertEquals(29 * 60 + 40, p.earnedSecondsAvailable)
        p.debitEarned(40)
        assertEquals(29 * 60, p.earnedSecondsAvailable)
        assertEquals(29, p.pendingMinutes)
    }

    @Test fun pocketsAreSeparate() {
        val p = engine()
        p.creditGift(45)
        assertEquals(45, p.giftSecondsAvailable); assertEquals(0, p.earnedSecondsAvailable)
        p.creditEarned(300)
        assertEquals(45, p.giftSecondsAvailable)
    }

    @Test fun cannotOverspend() {
        val p = engine()
        p.creditGift(100); p.debitGift(999)
        assertEquals(0, p.giftSecondsAvailable)
        assertEquals(100, p.snapshot.giftSecondsOut)
    }

    @Test fun roundTripConserves() {
        val p = engine()
        p.creditGift(30 * 60)
        repeat(10) {
            val before = p.giftSecondsAvailable
            p.debitGift(before)
            assertEquals(0, p.giftSecondsAvailable)
            p.creditGift(before - 70)
        }
        assertEquals(30 * 60 - 700, p.giftSecondsAvailable)
    }

    @Test fun uploadGenerationIsAdopted() {
        val p = engine()
        val landed = p.snapshot.revision + 1_000
        p.adoptUploadedGeneration(landed, editedSince = false)
        assertEquals(landed, p.snapshot.revision)
        p.creditEarned(60)
        assertEquals(landed + 1, p.snapshot.revision)
        val landed2 = p.snapshot.revision + 1_000
        p.adoptUploadedGeneration(landed2, editedSince = true)
        assertEquals(landed2 + 1, p.snapshot.revision)
    }

    @Test fun legacySnapshotCannotEraseTheGiftMirror() {
        val p = engine()
        p.creditGift(3600)
        assertEquals(60, p.parentGiftMinutes)
        p.apply(ProgressSnapshot(parentGiftMinutes = 0, revision = p.snapshot.revision + 1))
        assertEquals(3600, p.giftSecondsAvailable)
        assertEquals(60, p.parentGiftMinutes)
    }

    @Test fun openReadsTheCountersNotTheMirror() {
        val p = engine()
        p.creditGift(3600)
        p.apply(ProgressSnapshot(parentGiftMinutes = 0, revision = p.snapshot.revision + 1))
        assertEquals(3600, p.openableSeconds(true))
        assertEquals(60, p.consumeParentGiftForUnlock())
        assertEquals(0, p.giftSecondsAvailable)
    }

    @Test fun subMinuteGiftIsHonoured() {
        val p = engine()
        p.creditGift(40)
        assertEquals(1, p.consumeParentGiftForUnlock())
        assertEquals(0, p.giftSecondsAvailable)
    }

    @Test fun emptyPocketOpensNothing() { assertEquals(0, engine().consumeParentGiftForUnlock()) }

    @Test fun legacySnapshotIsBelievedOnABlankDevice() {
        val p = engine()
        p.apply(ProgressSnapshot(parentGiftMinutes = 25, pendingMinutes = 10, revision = p.snapshot.revision + 1))
        assertEquals(25, p.parentGiftMinutes)
        assertEquals(10, p.pendingMinutes)
    }

    // ── chests, streaks ─────────────────────────────────────────────────────
    @Test fun sessionChests_grantBonusMinutes() {
        assertEquals(1, RewardEngine.chestContents(ChestKind.WOOD).minutes)
        assertEquals(3, RewardEngine.chestContents(ChestKind.GOLD).minutes)
        assertEquals(5, RewardEngine.chestContents(ChestKind.MAGIC).minutes)
        assertEquals(15, RewardEngine.chestContents(ChestKind.LEGENDARY).minutes)
        val p = engine(noCap)
        assertFalse(p.settings.dailyCap.enabled)
        val before = p.pendingMinutes
        p.applyChestReward(RewardEngine.chestContents(ChestKind.GOLD))
        assertEquals(before + 3, p.pendingMinutes)
        assertEquals(9, p.snapshot.stars)
    }

    @Test fun dayStreak_transitions() {
        val utc = ZoneId.of("UTC")
        fun at(d: Int, h: Int) = AppleTime.fromUnix(LocalDateTime.of(2026, 3, d, h, 0).atZone(utc).toEpochSecond().toDouble())
        assertEquals(1, ProgressEngine.nextDayStreak(0, null, at(15, 9), utc))
        assertEquals(5, ProgressEngine.nextDayStreak(5, at(15, 9), at(15, 21), utc))
        assertEquals(6, ProgressEngine.nextDayStreak(5, at(15, 9), at(16, 9), utc))
        assertEquals(1, ProgressEngine.nextDayStreak(5, at(15, 9), at(17, 9), utc))
    }

    @Test fun levels() {
        assertEquals(1, RewardEngine.level(0)); assertEquals(2, RewardEngine.level(10))
        assertEquals(11, RewardEngine.level(1500)); assertEquals(12, RewardEngine.level(2000))
        assertEquals(30, RewardEngine.levelThresholds.size)
        assertEquals(100, RewardEngine.levelUpDiamonds(10))
    }

    // ── ✅ earning ──────────────────────────────────────────────────────────
    private fun ProgressEngine.correct(topic: String = "math") =
        recordCorrect(AnswerContext(topic, snapshot.currentStreak))

    @Test fun tenRightAnswersBankOneBatch() {
        val p = engine()
        val outs = (1..10).map { p.correct() }
        val s = p.snapshot
        assertEquals(4, p.pendingMinutes)
        assertEquals(240, p.earnedSecondsAvailable)
        assertEquals(4, s.minutesEarnedToday)
        assertEquals(4, outs.last().minutesGranted)
        assertEquals(0.0, s.cycleSeconds, 0.011)
        assertEquals(10, s.answeredToday); assertEquals(10, s.correctToday); assertEquals(10, s.totalCorrect)
        assertEquals(3 + 3 + 6 + 6 + 9 * 5 + 12, s.stars)        // combo ×1,×1,×2,×2,×3…,×4
        assertEquals(4 * 1 + 5 * 2 + 3, s.diamonds)              // weekday, "math" never featured
        assertEquals(20, s.xp)
        assertEquals(10, s.bestStreak)
        assertTrue(p.freeWheelAvailable)                          // the streak-5 bonus spin
        assertEquals(10, s.hourlyAnswered!![10])
        assertEquals(1.0, s.topicAccuracy["math"]!!, 1e-9)
        assertEquals(10, s.topicExposure["math"])
        assertEquals(24, p.settings.secondsPerCorrect)
    }

    @Test fun pointsUseThePreAnswerCombo() {
        val p = engine(KidSettings(difficultyByTopic = mapOf("math" to "medium")))
        val first = p.correct()
        assertEquals(15, first.points)   // 10 + medium 5, combo 0
    }

    @Test fun dailyCapBanksTheOverflowForTomorrow() {
        val p = engine(KidSettings(childDailyCapMinutes = 8))
        repeat(30) { p.correct() }                                // 3 batches = 12 minutes
        assertEquals(8, p.pendingMinutes)
        assertEquals(4, p.snapshot.carryOverMinutes)
        assertTrue(p.atDailyCap())
        clock.advance(86_400.0)
        p.applyDailyRolloverIfNeeded()
        assertEquals(12, p.pendingMinutes)                        // yesterday's bank is playable now
        assertEquals(0, p.snapshot.carryOverMinutes)
        assertEquals(0, p.snapshot.minutesEarnedToday)
        assertEquals(0, p.snapshot.answeredToday)
    }

    @Test fun carryOverIsCappedAt30() {
        val p = engine(KidSettings(childDailyCapMinutes = 1))
        val g = p.grantBonusMinutes(100)
        assertEquals(1, g.addedToday); assertEquals(30, g.bankedForTomorrow); assertTrue(g.bankFull)
    }

    @Test fun sameTopicSoftCapHalvesTheRate() {
        val p = engine(noCap)
        var nudged = 0
        repeat(30) { if (p.correct().balanceNudge) nudged++ }
        assertEquals(1, nudged)
        val before = p.snapshot.cycleSeconds
        p.correct()                                               // the 31st in the same topic
        assertEquals(12.0, p.snapshot.cycleSeconds - before, 1e-9)
        p.correct("logic")
        assertEquals(36.0, p.snapshot.cycleSeconds - before, 1e-9)
    }

    @Test fun varietyBonusOncePerDay() {
        val p = engine(noCap)
        var bonus = 0
        for (t in listOf("math", "logic", "science")) repeat(5) { bonus += p.correct(t).varietyBonusMinutes }
        assertEquals(10, bonus)
        repeat(5) { bonus += p.correct("hebrew").varietyBonusMinutes }
        assertEquals(10, bonus)
        assertNotNull(p.snapshot.varietyBonusDate)
    }

    @Test fun mistakeCostsHalfAStepNeverBankedMinutes() {
        val p = engine()
        p.correct(); p.correct()
        assertEquals(48.0, p.snapshot.cycleSeconds, 1e-9)
        assertEquals(12, p.recordWrong("math"))
        assertEquals(36.0, p.snapshot.cycleSeconds, 1e-9)
        assertEquals(0, p.snapshot.currentStreak)
        assertEquals(12, p.hintCostSeconds)
        assertEquals(12, p.chargeHint())
        repeat(5) { p.recordWrong("math") }
        assertEquals(0.0, p.snapshot.cycleSeconds, 1e-9)          // floors at zero
        assertEquals(0, p.pendingMinutes)
        val off = engine(KidSettings(penaltyEnabled = false))
        off.correct()
        assertEquals(0, off.recordWrong("math"))
        assertEquals(0, off.hintCostSeconds)
    }

    @Test fun freeLearningPaysNoMinutes() {
        val p = engine()
        repeat(12) { p.recordCorrect(AnswerContext("math", p.snapshot.currentStreak), grantsScreenTime = false) }
        assertEquals(0, p.pendingMinutes)
        assertEquals(0.0, p.snapshot.cycleSeconds, 0.0)
        assertTrue(p.snapshot.stars > 0)
    }

    @Test fun dailyChallenge() {
        val p = engine(noCap)
        repeat(9) { p.correct() }
        assertFalse(p.dailyChallengeRewardReady)
        p.correct()
        assertTrue(p.dailyChallengeRewardReady)
        val diamondsBefore = p.snapshot.diamonds; val minutesBefore = p.pendingMinutes
        p.claimDailyChallenge()
        assertEquals(diamondsBefore + 15, p.snapshot.diamonds)   // dayStreak 0 → 15 + 0
        assertEquals(minutesBefore + 3, p.pendingMinutes)
        assertTrue(p.dailyChallengeClaimed)
        assertEquals(BonusGrant(), p.claimDailyChallenge())       // once a day
    }

    @Test fun futureDatedDayIsPinnedNotRolledOver() {
        val p = engine()
        p.apply(ProgressSnapshot(dailyEarnedDate = AppleTime.fromUnix(clock.unix) + 400 * 86_400.0,
            minutesUnlockedToday = 50, carryOverMinutes = 20, revision = 5))
        p.applyDailyRolloverIfNeeded()
        val s = p.snapshot
        assertEquals(50, s.minutesUnlockedToday)                 // caps keep biting
        assertEquals(20, s.carryOverMinutes)                     // carry NOT released
        assertTrue(DayMath.usedToday(s.dailyEarnedDate, AppleTime.fromUnix(clock.unix), clock.zone))
        assertFalse(DayMath.isFutureDay(s.dailyEarnedDate, AppleTime.fromUnix(clock.unix), clock.zone))
    }

    // ── ⏱ windows ──────────────────────────────────────────────────────────
    @Test fun offlineOpenIsBoundedAndStopBanksTheExactLeftover() {
        val p = engine(KidSettings(leaseEnabled = false, childDailyCapMinutes = 90))
        p.creditEarned(40 * 60)
        assertEquals(40 * 60, p.redeemableSecondsNow)
        val m = p.consumeMinutesForUnlock(cloudFresh = false)
        assertEquals(15, m)                                       // one minimum window offline
        p.startUnlock(m)
        assertTrue(p.isUnlocked)
        clock.advance(5 * 60 + 10.0)
        val out = p.stopAndSaveCurrentUnlock()
        assertNull(out.releaseLeaseID)
        assertEquals(9, out.bankedMinutes)                        // 9:50 left → 9 min + 50 s carry
        assertEquals(50, p.snapshot.secondsCarry)
        assertEquals(25 * 60 + 9 * 60, p.earnedSecondsAvailable)
        assertEquals(15 - 9, p.minutesPlayedToday)
        assertFalse(p.isUnlocked)
    }

    @Test fun leaseStopDoesNotPayLocally_inFlightIsShown() {
        val p = engine()
        p.creditEarned(20 * 60)
        p.debitEarned(10 * 60)                                    // what the claim debited
        p.startUnlock(10, leaseID = "L1", leaseKind = "earned")
        clock.advance(100.0)
        val out = p.stopAndSaveCurrentUnlock()
        assertEquals("L1", out.releaseLeaseID)
        assertEquals(500, out.remainingSeconds)
        assertEquals(10 * 60, p.earnedSecondsAvailable)           // not paid twice
        assertEquals(10 * 60 + 500, p.openableSeconds(false))     // but shown at once
        p.creditRefundLocally(500, manual = false)                // offline fallback
        assertEquals(10 * 60 + 500, p.earnedSecondsAvailable)
        assertEquals(10 * 60 + 500, p.openableSeconds(false))
        assertNull(p.local.activeLeaseID)
    }

    @Test fun movingTheClockBackCannotMintMinutes() {
        val p = engine(KidSettings(leaseEnabled = false))
        p.startUnlock(15)
        clock.up += 600.0                                        // 10 real minutes…
        clock.unix -= 12 * 3600.0                                // …and the clock rolled back 12 h
        assertEquals(300, p.refundableUnlockSeconds)
        assertEquals(5, p.stopAndSaveCurrentUnlock().bankedMinutes)
    }

    @Test fun parentWindowLeftoverReturnsToTheGiftPocket() {
        val p = engine(KidSettings(leaseEnabled = false))
        p.startUnlock(30, manual = true, leaseKind = "gift")
        clock.advance(600.0)
        p.stopAndSaveCurrentUnlock()
        assertEquals(20 * 60, p.giftSecondsAvailable)
        assertEquals(0, p.earnedSecondsAvailable)
    }

    @Test fun revokeAllParentTime() {
        val p = engine()
        p.creditGift(3600)
        p.startUnlock(10, manual = true, leaseID = "G", leaseKind = "gift")
        val out = p.revokeAllParentTime()
        assertTrue(out.closedWindow)
        assertEquals("G", out.releaseLeaseID)
        assertEquals(0, p.giftSecondsAvailable)
        assertFalse(p.isUnlocked)
    }

    @Test fun claimedWalletAppliesTheDeltaAndAdoptsTheGeneration() {
        val p = engine()
        p.creditEarned(30 * 60)
        p.applyClaimedWallet(ClaimedWallet(pendingMinutes = 10, parentGiftMinutes = 0, minutesUnlockedToday = 20,
            secondsCarry = 0, revision = 77, deltaSeconds = -20 * 60))
        assertEquals(10 * 60, p.earnedSecondsAvailable)
        assertEquals(20, p.snapshot.minutesUnlockedToday)
        assertTrue(p.snapshot.revision >= 77)
    }

    // ── the LWW invariant ───────────────────────────────────────────────────
    @Test fun captureNeverStampsTheVersion() {
        val p = engine()
        p.correct()
        val a = p.capture()
        clock.advance(30.0)
        val b = p.capture()
        assertEquals(a.lastModifiedAt, b.lastModifiedAt, 0.0)
        assertEquals(a.revision, b.revision)
        assertEquals(24, b.hourlyAnswered!!.size)
        assertNotNull(b.earnedSecondsIn)                          // counters always present in a capture
        assertNull(b.unlockEndsAt)                                // the window is never synced
    }

    @Test fun editsLandOnOneGenerationAboveTheCloud() {
        val p = engine()
        p.adoptRevision(40)
        p.correct(); p.correct(); p.recordWrong("math")
        assertEquals(41, p.snapshot.revision)                     // a burst = ONE generation
        val seq = p.localEditSeq
        p.recordAbandon("math")                                   // not a version trigger
        assertEquals(seq, p.localEditSeq)
        assertEquals(41, p.snapshot.revision)
    }

    @Test fun mergeRemoteConverges() {
        val a = engine(id = "AAA"); val b = engine(id = "BBB")
        repeat(3) { a.correct() }
        val cloud = a.capture()
        assertFalse(b.mergeRemote(cloud))                         // b just catches up
        assertEquals(cloud.stars, b.snapshot.stars)
        assertFalse(b.mergeRemote(cloud))                         // and stays converged
        b.correct("logic")
        assertTrue(b.mergeRemote(cloud))                          // b now holds more → re-upload
    }

    @Test fun resetKeepsTheWalletLikeIOS() {
        val p = engine(noCap)
        repeat(10) { p.correct() }
        val rev = p.snapshot.revision
        p.resetAll()
        val s = p.snapshot
        assertEquals(0, s.stars); assertEquals(0, s.totalAnswered); assertEquals(0, s.xp)
        assertEquals(4, p.pendingMinutes)                         // apply(.blank) max-merges counters
        assertEquals(10, s.bestStreak)                            // …and bestStreak
        assertTrue(s.revision > rev)
    }

    @Test fun persistenceRoundTrip() {
        val p = engine()
        repeat(4) { p.correct("science") }
        p.startUnlock(15, leaseID = "L9", leaseKind = "earned")
        val json = KidPersistence.encode(p.snapshot, p.local)
        val (snap, local) = KidPersistence.decode(json)!!
        assertEquals(p.snapshot, snap)
        assertEquals(p.local, local)
        assertNull(KidPersistence.decode("not json"))
    }

    @Test fun miniGameBucketPacesCredits() {
        var t = 0.0
        val bucket = MiniGameEarnBucket { t }
        assertTrue(bucket.takeCredit()); assertTrue(bucket.takeCredit()); assertTrue(bucket.takeCredit())
        assertFalse(bucket.takeCredit())
        t += 6.0
        assertTrue(bucket.takeCredit())
        val p = engine()
        val paid = p.recordMiniGameAnswer(true, "math", bucket = MiniGameEarnBucket { t }, surprise = false)
        assertEquals(24, paid.paidSeconds)
        assertEquals(24, p.takeRoundSeconds())
        val surprise = p.recordMiniGameAnswer(true, "math", bucket = null, surprise = true)
        assertEquals(0, surprise.paidSeconds)
        assertEquals(2, p.snapshot.totalAnswered)
    }
}

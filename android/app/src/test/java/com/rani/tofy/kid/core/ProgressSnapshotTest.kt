package com.rani.tofy.kid.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId

/** Ports of ChildTimeTests.swift (snapshot decode + ratchetMerged) plus wire-format checks. */
class ProgressSnapshotTest {
    private val zone = ZoneId.systemDefault()
    private fun now() = AppleTime.now()
    private fun days(n: Int) = now() + n * 86_400.0
    private fun merge(l: ProgressSnapshot, r: ProgressSnapshot) = ProgressSnapshot.ratchetMerged(l, r)

    // ── decode ──────────────────────────────────────────────────────────────
    @Test fun oldSnapshotMissingDiamonds_keepsStars() {
        val snap = ProgressSnapshot.fromFirestore(mapOf(
            "stars" to 12_345L, "gems" to 7L, "xp" to 88L, "totalScore" to 4_200L,
            "ownedCharacterIDs" to listOf("fox", "bear"), "revision" to 9L,
        ))
        assertEquals(12_345, snap.stars)
        assertEquals(7, snap.diamonds)
        assertEquals(88, snap.xp)
        assertEquals(4_200, snap.totalScore)
        assertEquals(listOf("fox", "bear"), snap.ownedCharacterIDs)
        assertEquals(9, snap.revision)
    }

    @Test fun emptySnapshot_decodesToBlankNotThrow() {
        val snap = ProgressSnapshot.fromFirestore(emptyMap())
        assertEquals(0, snap.stars)
        assertEquals(0, snap.diamonds)
        assertEquals(listOf("numbers_kingdom"), snap.unlockedWorlds)
    }

    @Test fun badFieldKeepsDefault_andNeverWipesTheRest() {
        val snap = ProgressSnapshot.fromFirestore(mapOf(
            "stars" to "lots", "diamonds" to 5.5, "xp" to 40.0, "topicAnswered" to mapOf("math" to 3L, "logic" to "x"),
            "hourlyAnswered" to List(24) { it.toLong() }, "carryIsGift" to 1L, "totalCorrect" to 12L,
        ))
        assertEquals(0, snap.stars)               // wrong type → default
        assertEquals(0, snap.diamonds)            // non-integral number isn't an Int (Swift parity)
        assertEquals(40, snap.xp)                 // integral double IS accepted
        assertEquals(emptyMap<String, Int>(), snap.topicAnswered)   // one bad value fails the dict
        assertEquals(23, snap.hourlyAnswered!![23])
        assertNull(snap.carryIsGift)
        assertEquals(12, snap.totalCorrect)
    }

    // ── wire format ─────────────────────────────────────────────────────────
    @Test fun encode_omitsNilOptionals_likeJSONEncoder() {
        val m = ProgressSnapshot(deviceID = "A").toFirestore()
        for (k in listOf("unlockEndsAt", "carryOverMinutes", "parentGiftMinutes", "earnedSecondsIn", "giftGivenDate",
            "topicAdaptiveLevel", "hourlyAnswered", "purgeCacheAt", "secondsCarry", "carryIsGift", "dailyEarnedDate")) {
            assertFalse("$k must be omitted", m.containsKey(k))
        }
        for (k in listOf("pendingMinutes", "stars", "diamonds", "cycleSeconds", "resetEpoch", "revision", "lastModifiedAt", "deviceID")) {
            assertTrue("$k must be present", m.containsKey(k))
        }
    }

    @Test fun dates_roundTripExactlyInAppleReferenceSeconds() {
        val lm = 781_234_567.123456   // an iOS-written lastModifiedAt (2025)
        val s = ProgressSnapshot(lastModifiedAt = lm, dailyEarnedDate = 781_200_000.0, giftSecondsIn = 600, deviceID = "D")
        val back = ProgressSnapshot.fromFirestore(s.toFirestore())
        assertEquals(s, back)
        assertEquals(lm, back.lastModifiedAt, 0.0)
        // Apple ref seconds → unix is +978307200 (2001-01-01).
        assertEquals(1_759_541_767.123456, AppleTime.toUnix(lm), 1e-6)
        // "now" is ~25 years after the reference date, never ~56 (a unix value read as Apple).
        assertTrue(AppleTime.now() in 7.5e8..1.2e9)
    }

    // ── ratchetMerged ───────────────────────────────────────────────────────
    @Test fun ratchetMerge_neverLowersCloudStars() {
        val local = ProgressSnapshot(stars = 153, revision = 197, diamonds = 34)
        val cloud = ProgressSnapshot(stars = 4100, revision = 198, diamonds = 34)
        val merged = merge(local, cloud)
        assertEquals(4100, merged.stars)
        assertEquals(4100, merge(cloud, local).stars)
        assertTrue(ProgressSnapshot.sameProgressData(merged, cloud))
    }

    @Test fun merge_spendWinsOverBusierPeerAtSameGeneration() {
        val n = now()
        val spender = ProgressSnapshot(parentGiftMinutes = 0, pendingMinutes = 0, diamonds = 40, revision = 7, lastModifiedAt = n)
        val busy = ProgressSnapshot(parentGiftMinutes = 60, pendingMinutes = 60, diamonds = 100, revision = 7, lastModifiedAt = n - 120)
        for (m in listOf(merge(busy, spender), merge(spender, busy))) {
            assertEquals(0, m.parentGiftMinutes); assertEquals(0, m.pendingMinutes); assertEquals(40, m.diamonds)
        }
    }

    @Test fun merge_causalGenerationBeatsSkewedClock() {
        val newer = ProgressSnapshot(pendingMinutes = 0, revision = 9, lastModifiedAt = now() - 3600)
        val skewed = ProgressSnapshot(pendingMinutes = 90, revision = 8, lastModifiedAt = now() + 365 * 86_400.0)
        assertEquals(0, merge(skewed, newer).pendingMinutes)
        assertEquals(0, merge(newer, skewed).pendingMinutes)
    }

    @Test fun merge_isTotalOrderOnTies() {
        val t = now()
        val x = ProgressSnapshot(pendingMinutes = 10, revision = 5, lastModifiedAt = t, deviceID = "AAA")
        val y = ProgressSnapshot(pendingMinutes = 20, revision = 5, lastModifiedAt = t, deviceID = "BBB")
        assertEquals(merge(x, y).pendingMinutes, merge(y, x).pendingMinutes)
        assertEquals(20, merge(x, y).pendingMinutes)
    }

    @Test fun todayQuestionCounters_mergeAsMaxWithinSameDay() {
        val today = now()
        val child = ProgressSnapshot(dailyEarnedDate = today, answeredToday = 7, correctToday = 7, revision = 36_000)
        val cloud = ProgressSnapshot(dailyEarnedDate = today, answeredToday = 3, correctToday = 3, revision = 36_001)
        merge(child, cloud).let { assertEquals(7, it.answeredToday); assertEquals(7, it.correctToday) }
        merge(cloud, child).let { assertEquals(7, it.answeredToday); assertEquals(7, it.correctToday) }
        val stale = ProgressSnapshot(dailyEarnedDate = days(-1), answeredToday = 40, correctToday = 39, revision = 99_999)
        val m = merge(child, stale)
        assertEquals(7, m.answeredToday); assertEquals(7, m.correctToday)
        assertTrue(DayMath.sameDay(m.dailyEarnedDate!!, today, zone))
    }

    @Test fun minutesUnlockedToday_mergesAsMaxWithinSameDay() {
        val a = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 60, revision = 10)
        val b = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 45, revision = 99)
        assertEquals(60, merge(a, b).minutesUnlockedToday)
        assertEquals(60, merge(b, a).minutesUnlockedToday)
    }

    @Test fun dailyEarnedDate_futureDatedPeerIsNotAdopted() {
        val local = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 30)
        val evil = ProgressSnapshot(dailyEarnedDate = days(400), minutesUnlockedToday = 0, revision = 9_999)
        val d = merge(local, evil).dailyEarnedDate
        assertTrue(d == null || DayMath.localDate(d, zone) <= DayMath.localDate(now(), zone))
        assertEquals(30, merge(local, evil).minutesUnlockedToday)
    }

    @Test fun dayGate_futureStampCountsAsAlreadyUsed() {
        val n = now()
        assertFalse(DayMath.usedToday(null, n, zone))
        assertTrue(DayMath.usedToday(n, n, zone))
        assertTrue(DayMath.usedToday(days(1), n, zone))
        assertTrue(DayMath.usedToday(days(365), n, zone))
        assertFalse(DayMath.usedToday(days(-1), n, zone))
        assertTrue(DayMath.isFutureDay(days(1), n, zone))
        assertFalse(DayMath.isFutureDay(n, n, zone))
    }

    @Test fun ratchetMerge_diamondsAreSpendableLWW() {
        val local = ProgressSnapshot(diamonds = 40, stars = 500, revision = 200)
        val cloud = ProgressSnapshot(diamonds = 100, stars = 500, revision = 199)
        assertEquals(40, merge(local, cloud).diamonds)
        assertEquals(40, merge(ProgressSnapshot(diamonds = 100, revision = 199), ProgressSnapshot(diamonds = 40, revision = 200)).diamonds)
        assertEquals(120, merge(ProgressSnapshot(diamonds = 120, revision = 201), ProgressSnapshot(diamonds = 80, revision = 200)).diamonds)
        assertEquals(500, merge(local, cloud).stars)
    }

    @Test fun ratchetMerge_raisesStarsWhenLocalAhead() {
        val local = ProgressSnapshot(stars = 4200, revision = 199)
        val cloud = ProgressSnapshot(stars = 4100, revision = 198)
        val merged = merge(local, cloud)
        assertEquals(4200, merged.stars)
        assertFalse(ProgressSnapshot.sameProgressData(merged, cloud))
    }

    @Test fun merge_dayStreak_followsMostRecentPlay() {
        val earlier = AppleTime.fromUnix(1_000_000.0); val later = AppleTime.fromUnix(2_000_000.0)
        val m = merge(ProgressSnapshot(dayStreak = 6, lastSessionDate = later, revision = 50),
            ProgressSnapshot(dayStreak = 5, lastSessionDate = earlier, revision = 51))
        assertEquals(6, m.dayStreak); assertEquals(later, m.lastSessionDate!!, 0.0)
        val m2 = merge(ProgressSnapshot(dayStreak = 4, lastSessionDate = earlier, revision = 60),
            ProgressSnapshot(dayStreak = 7, lastSessionDate = later, revision = 59))
        assertEquals(7, m2.dayStreak); assertEquals(later, m2.lastSessionDate!!, 0.0)
    }

    @Test fun resetEpoch_winsWholesale() {
        val stale = ProgressSnapshot(stars = 900, xp = 500, revision = 80, resetEpoch = 0, giftSecondsIn = 3600)
        val wiped = ProgressSnapshot(revision = 3, resetEpoch = 1)
        for (m in listOf(merge(stale, wiped), merge(wiped, stale))) {
            assertEquals(0, m.stars); assertEquals(0, m.xp); assertNull(m.giftSecondsIn); assertEquals(1, m.resetEpoch)
        }
    }

    @Test fun unionsHourlyAndLaterDates() {
        val a = ProgressSnapshot(unlockedWorlds = listOf("numbers_kingdom", "a"), ownedCharacterIDs = listOf("fox"),
            hourlyAnswered = List(24) { if (it == 9) 5 else 0 }, lastDailyChestDate = 100.0, revision = 2)
        val b = ProgressSnapshot(unlockedWorlds = listOf("b"), ownedCharacterIDs = listOf("bear", "fox"),
            hourlyAnswered = List(24) { if (it == 9) 3 else 1 }, lastDailyChestDate = 200.0, revision = 1)
        val m = merge(a, b)
        assertEquals(setOf("numbers_kingdom", "a", "b"), m.unlockedWorlds.toSet())
        assertEquals(setOf("fox", "bear"), m.ownedCharacterIDs.toSet())
        assertEquals(5, m.hourlyAnswered!![9]); assertEquals(1, m.hourlyAnswered!![0])
        assertEquals(200.0, m.lastDailyChestDate!!, 0.0)
        // a malformed (non-24) array never wins over a good one
        assertEquals(m.hourlyAnswered, ProgressSnapshot.mergeHourly(listOf(1, 2), m.hourlyAnswered))
    }

    // ── 💰 wallet counters in the merge (WalletCounterTests) ────────────────
    @Test fun staleDeviceCannotDestroyMinutes() {
        val ahead = ProgressSnapshot(earnedSecondsIn = 120 * 60, earnedSecondsOut = 0, revision = 5)
        val behind = ProgressSnapshot(earnedSecondsIn = 0, earnedSecondsOut = 0, revision = 99)
        val m = merge(behind, ahead)
        assertEquals(120 * 60, m.earnedSecondsAvailable)
        assertEquals(120, m.pendingMinutes)   // mirror re-derived from the merged counters
    }

    @Test fun deliberateRemovalSurvives() {
        val afterRemoval = ProgressSnapshot(earnedSecondsIn = 120 * 60, earnedSecondsOut = 10 * 60, revision = 5)
        val stale = ProgressSnapshot(earnedSecondsIn = 120 * 60, earnedSecondsOut = 0, revision = 99)
        assertEquals(110 * 60, merge(stale, afterRemoval).earnedSecondsAvailable)
    }

    @Test fun mergeTakesMaxPerCounter() {
        val m = merge(ProgressSnapshot(earnedSecondsIn = 500, earnedSecondsOut = 100, revision = 1),
            ProgressSnapshot(earnedSecondsIn = 300, earnedSecondsOut = 250, revision = 2))
        assertEquals(500, m.earnedSecondsIn); assertEquals(250, m.earnedSecondsOut)
    }

    @Test fun refundedMinutesStayRefunded() {
        val opened = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 90, revision = 5)
        val afterStop = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 90, returnedTodayMinutes = 68, revision = 6)
        assertEquals(22, merge(afterStop, opened).netUnlockedToday)
    }

    @Test fun twoDevicesShareOneDailyCap() {
        val iPad = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 30, revision = 4)
        val phone = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 50, revision = 5)
        assertTrue(merge(phone, iPad).netUnlockedToday >= 50)
    }

    @Test fun refundSurvivesAStaleSibling() {
        val stale = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 60, revision = 9)
        val fresh = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 60, returnedTodayMinutes = 45, revision = 10)
        assertEquals(15, merge(fresh, stale).netUnlockedToday)
        assertEquals(15, merge(stale, fresh).netUnlockedToday)
    }

    @Test fun newDayClearsTheRefundToo() {
        val yesterday = ProgressSnapshot(dailyEarnedDate = days(-1), minutesUnlockedToday = 90, returnedTodayMinutes = 68, revision = 3)
        val today = ProgressSnapshot(dailyEarnedDate = now(), minutesUnlockedToday = 0, revision = 4)
        val m = merge(today, yesterday)
        assertEquals(0, m.netUnlockedToday); assertEquals(0, m.returnedTodayMinutes)
    }

    @Test fun nilNeverErases() {
        val written = ProgressSnapshot(giftSecondsIn = 600)
        val blank = ProgressSnapshot()
        assertEquals(600, merge(blank, written).giftSecondsAvailable)
        assertEquals(600, merge(written, blank).giftSecondsAvailable)
    }
}

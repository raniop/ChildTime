package com.rani.tofy.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * 🏆 Port of FamilyContestTests.swift: goals follow what each child really did,
 * the jar pays at ⅓ ⅔ and full, the crown goes by percent of your OWN goal, and
 * a week is Sunday → Saturday.
 */
class FamilyContestTest {
    @Test fun goalGrowsAfterAStrongWeek() {
        assertEquals(660, FamilyContest.goal(lastWeek = 600, weekBefore = 500))
    }

    @Test fun aWeakWeekPullsTheGoalDownNotUp() {
        val g = FamilyContest.goal(lastWeek = 200, weekBefore = 600)
        assertEquals(440, g)                       // (200 + 600) / 2 × 1.1
        assertTrue(g < FamilyContest.goal(600, 500))
    }

    @Test fun aNewChildStartsFromTheirDailyAverage() {
        assertEquals(310, FamilyContest.goal(0, 0, recentDailyAverage = 40.0))   // 40 × 7 × 1.1
        assertEquals(FamilyContest.MIN_GOAL, FamilyContest.goal(0, 0))
    }

    @Test fun stagesAreThirdsInRoundTens() {
        assertEquals(listOf(400, 800, 1200), FamilyContest.stages(1200))
        assertEquals(listOf(370, 740, 1110), FamilyContest.stages(1110))
        assertEquals(listOf(0, 1), FamilyContest.reached(820, 1200))
        assertEquals(listOf(0, 1, 2), FamilyContest.reached(1200, 1200))
        assertTrue(FamilyContest.reached(0, 0).isEmpty())
    }

    @Test fun theLittleOneCanWin() {
        val s = listOf(FamilyContest.Standing("big", 800, 480), FamilyContest.Standing("little", 150, 120))   // 60% · 80%
        assertEquals(setOf("little"), FamilyContest.champions(s))
        assertEquals(FamilyContest.CHAMPION_PRIZE, FamilyContest.endPrize(s[1], s, 0))
        assertEquals(0, FamilyContest.endPrize(s[0], s, 0))
    }

    @Test fun goalPlusCrown() {
        val s = listOf(FamilyContest.Standing("a", 100, 120), FamilyContest.Standing("b", 100, 100))
        assertEquals(FamilyContest.GOAL_PRIZE + FamilyContest.CHAMPION_PRIZE, FamilyContest.endPrize(s[0], s, 0))
        assertEquals(FamilyContest.GOAL_PRIZE, FamilyContest.endPrize(s[1], s, 0))
    }

    @Test fun nobodyLeadsBeforeAnyAnswer() {
        assertTrue(FamilyContest.champions(listOf(FamilyContest.Standing("a", 100, 0), FamilyContest.Standing("b", 90, 0))).isEmpty())
    }

    @Test fun tiesShareTheCrown() {
        val s = listOf(FamilyContest.Standing("a", 100, 50), FamilyContest.Standing("b", 200, 100), FamilyContest.Standing("c", 100, 10))
        assertEquals(setOf("a", "b"), FamilyContest.champions(s))
    }

    @Test fun oneChildRacesLastWeek() {
        val me = FamilyContest.Standing("me", 300, 250)
        assertEquals(FamilyContest.CHAMPION_PRIZE, FamilyContest.endPrize(me, listOf(me), 200))
        assertEquals(0, FamilyContest.endPrize(me, listOf(me), 260))
    }

    @Test fun theWeekStartsOnSunday() {
        val wed = LocalDate.of(2026, 10, 28)
        assertEquals("2026-10-25", FamilyContest.weekKey(wed))
        assertEquals("2026-10-31", FamilyContest.dayKeys(FamilyContest.weekStart(wed)).last())
        assertEquals(4, FamilyContest.daysLeft(wed))
        assertEquals("2026-10-25", FamilyContest.weekKey(LocalDate.of(2026, 10, 25)))   // Sunday is its own week
        assertEquals(1, FamilyContest.daysLeft(LocalDate.of(2026, 10, 31)))               // Saturday: the last day
    }

    @Test fun theGoalComesFromTheHistory() {
        val now = LocalDate.of(2026, 10, 28)
        // Last week 600, the week before 500 → 660.
        val h = listOf(ContestDay("2026-10-19", 400, 300), ContestDay("2026-10-24", 400, 300),
            ContestDay("2026-10-12", 600, 500), ContestDay("2026-10-26", 50, 40))
        assertEquals(600, FamilyContest.correct(h, FamilyContest.previousWeekStart(now)))
        assertEquals(40, FamilyContest.correct(h, FamilyContest.weekStart(now)))
        assertEquals(660, FamilyContest.goal(h, now))
        // A child with one small day last week: never under the minimum.
        assertEquals(FamilyContest.MIN_GOAL, FamilyContest.goal(listOf(ContestDay("2026-10-27", 50, 40)), LocalDate.of(2026, 11, 4)))
        // Big days only last week (300 + 300 = 600 > 0 the week before) → 660.
        assertEquals(660, FamilyContest.goal(listOf(ContestDay("2026-10-26", 350, 300), ContestDay("2026-10-27", 350, 300)), LocalDate.of(2026, 11, 4)))
    }

    @Test fun rollingKeepsOnlyTheWeekJustBefore() {
        val last = ContestRecord(ContestRecord.Week("2026-10-18", 500, 0, listOf(0)))
        val rolled = last.rolled("2026-10-25", "2026-10-18", 550)
        assertEquals("2026-10-18", rolled.prev?.week); assertEquals(listOf(0), rolled.prev?.paid)
        assertEquals(550, rolled.current.goal); assertTrue(rolled.current.paid.isEmpty())
        val stale = ContestRecord(ContestRecord.Week("2026-10-04", 500, 0, emptyList()))
        assertNull(stale.rolled("2026-10-25", "2026-10-18", 550).prev)
        assertEquals(rolled, rolled.rolled("2026-10-25", "2026-10-18", 999))
    }

    @Test fun recordSurvivesFirestoreShape() {
        val r = ContestRecord(ContestRecord.Week("2026-10-25", 660, 40, listOf(0, 1)),
            ContestRecord.Week("2026-10-18", 600, 0, listOf(0)), settled = "2026-10-11")
        // Firestore hands numbers back as Long.
        fun longs(v: Any?): Any? = when (v) {
            is Int -> v.toLong()
            is List<*> -> v.map { longs(it) }
            is Map<*, *> -> v.mapValues { longs(it.value) }
            else -> v
        }
        @Suppress("UNCHECKED_CAST")
        assertEquals(r, ContestRecord.from(longs(r.toMap()) as Map<String, Any?>))
        // A fresh record: prev and settled are written as nulls, and read back as such.
        val fresh = ContestRecord(ContestRecord.Week("2026-10-25", 70, 0, emptyList()))
        assertTrue(fresh.toMap().containsKey("prev") && fresh.toMap()["prev"] == null)
        assertEquals(fresh, ContestRecord.from(fresh.toMap()))
    }
}

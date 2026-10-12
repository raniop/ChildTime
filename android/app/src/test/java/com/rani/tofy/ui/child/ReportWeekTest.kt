package com.rani.tofy.ui.child

import com.rani.tofy.data.DailyStat
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import java.util.Calendar

/**
 * "השבוע" is a calendar week (Sunday first), in the numbers and in the chart —
 * the same days ChildReportTests.swift pins: Wednesday 2026-10-14.
 */
class ReportWeekTest {
    private fun day(d: Int, hour: Int = 12) = Calendar.getInstance().apply { clear(); set(2026, Calendar.OCTOBER, d, hour, 0, 0) }
    private fun stat(d: Int, q: Int, c: Int, earned: Int = 0) =
        DailyStat(dayKey(day(d)), q, c, q - c, earned, 0, 0, 0, 1, 1, 0, 0, mapOf("math" to DailyStat.TopicDay(q, c, null)))

    @Before fun onAWednesday() { reportClock = { day(14) } }
    @After fun realClock() { reportClock = { Calendar.getInstance() } }

    @Test fun theWeekStartsOnSunday() {
        assertEquals("2026-10-11", dayKey(weekStart()))
    }

    @Test fun weekNumbersCountFromSundayNotSevenDaysBack() {
        // Saturday the 10th is LAST week; Sunday the 11th and today are this week.
        val e = ReportEngine(listOf(stat(8, 20, 10), stat(10, 30, 15), stat(11, 10, 9), stat(14, 6, 6)))
        assertEquals(16, e.summary(ReportPeriod.WEEK).questions)
        assertEquals(15, e.summary(ReportPeriod.WEEK).correct)
        assertEquals(6, e.summary(ReportPeriod.TODAY).questions)
    }

    @Test fun improvementComparesWithTheWholeWeekBefore() {
        // Last week (4th–10th): 20 answers at 50 %. This week: 20 at 90 %.
        val e = ReportEngine(listOf(stat(5, 10, 5), stat(9, 10, 5), stat(11, 10, 9), stat(13, 10, 9)))
        val delta = e.overallDelta(ReportPeriod.WEEK)
        assertNotNull(delta)
        assertEquals(40.0, delta!!, 0.001)
        // Too little this week to compare → nothing is said.
        assertNull(ReportEngine(listOf(stat(5, 10, 5), stat(9, 10, 5), stat(11, 4, 4))).overallDelta(ReportPeriod.WEEK))
    }

    @Test fun theChartIsSundayToSaturdayWithTodayMarked() {
        val points = ReportEngine(listOf(stat(10, 30, 15), stat(11, 10, 9, earned = 12), stat(14, 6, 6))).weekPoints()
        assertEquals(7, points.size)
        assertEquals(listOf("2026-10-11", "2026-10-12", "2026-10-13", "2026-10-14", "2026-10-15", "2026-10-16", "2026-10-17"), points.map { it.date })
        assertEquals(listOf(10, 0, 0, 6, 0, 0, 0), points.map { it.questions })
        assertEquals(12, points[0].earned)
        assertEquals(listOf(3), points.indices.filter { points[it].isToday })
        assertEquals(listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ש׳"), points.map { it.weekday })
    }

    @Test fun onSundayTheWeekIsOnlyToday() {
        reportClock = { day(11) }
        val e = ReportEngine(listOf(stat(9, 20, 10), stat(10, 30, 15), stat(11, 7, 7)))
        assertEquals(7, e.summary(ReportPeriod.WEEK).questions)
        assertEquals(0, e.weekPoints().indexOfFirst { it.isToday })
    }
}

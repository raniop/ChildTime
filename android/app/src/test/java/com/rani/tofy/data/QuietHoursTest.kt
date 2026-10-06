package com.rani.tofy.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

/** Port of QuietHoursTests.swift (QuietHoursSchedule) — the same week, the same answers. */
class QuietHoursTest {
    private val zone = ZoneId.of("Asia/Jerusalem")
    /** 2026-10-06 is a Tuesday; the 9th a Friday; the 10th a Saturday. */
    private fun at(day: Int, h: Int, m: Int = 0) = ZonedDateTime.of(2026, 10, day, h, m, 0, 0, zone)
    private val both = QuietHours(school = QuietHours.SCHOOL_DEFAULT, bedtime = QuietHours.BEDTIME_DEFAULT)

    @Test fun schoolHoursOnASchoolDay() {
        assertNull(both.active(at(6, 7, 59)))
        val s = both.active(at(6, 8, 0))
        assertEquals(QuietKind.SCHOOL, s?.kind)
        assertEquals(at(6, 13, 30), s?.end)
        assertNull(both.active(at(6, 13, 30)))
    }

    @Test fun fridayEndsEarlyAndSaturdayIsFree() {
        assertEquals(at(9, 12, 0), both.active(at(9, 11, 59))?.end)
        assertNull(both.active(at(9, 12, 30)))
        assertNull(both.active(at(10, 10, 0)))
    }

    @Test fun bedtimeCrossesMidnight() {
        assertNull(both.active(at(6, 20, 29)))
        val night = both.active(at(6, 23, 0))
        assertEquals(QuietKind.BEDTIME, night?.kind)
        assertEquals(at(7, 7, 0), night?.end)
        assertEquals(at(7, 7, 0), both.active(at(7, 3, 0))?.end)
        assertNull(both.active(at(7, 7, 0)))
    }

    @Test fun bedtimeOnlyOnChosenNights() {
        val q = QuietHours(bedtime = QuietHours.BEDTIME_DEFAULT.copy(days = listOf(1, 2, 3, 4, 5)))
        assertNotNull(q.active(at(6, 22, 0)))
        assertNull(q.active(at(9, 22, 0)))
        assertNull(q.active(at(10, 2, 0)))
    }

    @Test fun noSchoolTodayAndVacation() {
        var q = both.copy(schoolOffDay = QuietHours.dayKey(LocalDate.of(2026, 10, 6)))
        assertNull(q.active(at(6, 9, 0)))
        assertEquals(QuietKind.SCHOOL, q.active(at(7, 9, 0))?.kind)
        assertEquals(QuietKind.BEDTIME, q.active(at(6, 21, 0))?.kind)
        q = both.copy(schoolPaused = true)
        assertNull(q.active(at(7, 9, 0)))
    }

    @Test fun backToBackWindowsReadAsOne() {
        val q = both.copy(school = QuietHours.SCHOOL_DEFAULT.copy(start = 7 * 60))
        val o = q.active(at(6, 6, 0))
        assertEquals(QuietKind.BEDTIME, o?.kind)
        assertEquals(at(6, 13, 30), o?.end)
    }

    @Test fun nextStartAndOffWindows() {
        assertEquals(at(6, 20, 30), both.nextStart(at(6, 13, 30)))
        val off = both.copy(school = both.school!!.copy(enabled = false), bedtime = both.bedtime!!.copy(enabled = false))
        assertTrue(off.isEmpty)
        assertNull(off.active(at(6, 9, 0)))
        assertNull(QuietHours().nextStart(at(6, 9, 0)))
    }

    @Test fun firestoreShapeRoundTripsAndClearsWithExplicitValues() {
        val q = both.copy(schoolOffDay = "2026-10-06")
        // Stable through the cloud: what is read back writes back identically.
        assertEquals(q.toMap(), QuietHours.from(q.toMap())!!.toMap())
        assertEquals(q.active(at(6, 23, 0)), QuietHours.from(q.toMap())!!.active(at(6, 23, 0)))
        // "Off" travels as "" / false / the regular end, so a MERGE write clears it.
        val m = QuietHours(school = QuietHours.SCHOOL_DEFAULT.copy(fridayEnd = null)).toMap()
        assertEquals("", m["schoolOffDay"]); assertEquals(false, m["schoolPaused"])
        @Suppress("UNCHECKED_CAST")
        assertEquals(13 * 60 + 30, (m["school"] as Map<String, Any?>)["fridayEnd"])
        // …and reads back as "no off-day".
        assertEquals(QuietKind.SCHOOL, QuietHours.from(m)!!.active(at(6, 9, 0))?.kind)
    }

    @Test fun iosWeekdayNumbering() {
        assertEquals(1, QuietHours.appleWeekday(LocalDate.of(2026, 10, 4)))   // Sunday
        assertEquals(3, QuietHours.appleWeekday(LocalDate.of(2026, 10, 6)))   // Tuesday
        assertEquals(7, QuietHours.appleWeekday(LocalDate.of(2026, 10, 10)))  // Saturday
    }
}

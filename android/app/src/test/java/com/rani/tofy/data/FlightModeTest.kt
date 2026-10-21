package com.rani.tofy.data

import com.rani.tofy.kid.core.PlayWindowLease
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.ZoneId
import java.time.ZonedDateTime

/** Port of FlightModeTests.swift — opens only while the parents are away, only with the right code, and five wrong tries mean a short wait. */
class FlightModeTest {
    @Before fun reset() { FlightCodeGuard.store = FlightCodeGuard.MemoryStore() }

    private val active get() = FlightMode("4821", nowSecs() + 86400, nowSecs())

    @Test fun theRightCodeOpens() {
        assertTrue(FlightCodeGuard.check("4821", active))
        assertFalse(FlightCodeGuard.check("1111", active))
    }

    @Test fun anExpiredCodeNeverOpens() {
        val over = FlightMode("4821", nowSecs() - 60, 0.0)
        assertFalse(over.isActive())
        assertFalse(FlightCodeGuard.check("4821", over))
        // Ended by the parent: until 0, no code.
        assertFalse(FlightMode.off().isActive())
    }

    @Test fun fiveWrongTriesMeanAWait() {
        repeat(FlightCodeGuard.MAX_TRIES) { FlightCodeGuard.check("0001", active) }
        assertTrue(FlightCodeGuard.waitSeconds() > 0)
        // Even the right code waits.
        assertFalse(FlightCodeGuard.check("4821", active))
        // …and a minute later it opens again.
        assertTrue(FlightCodeGuard.check("4821", active, now = nowSecs() + 61))
    }

    @Test fun codesAreFourDigitsAndNeverObvious() {
        repeat(500) {
            val c = FlightMode.newCode()
            assertTrue(c.length == 4 && c.all { it.isDigit() })
            assertFalse(c in setOf("0000", "1234", "1111"))
        }
    }

    @Test fun readsTheFirestoreShape() {
        val m = FlightMode.from(mapOf("code" to "4821", "until" to 1_800_000_000.0, "setAt" to 1_700_000_000L))
        assertEquals(FlightMode("4821", 1_800_000_000.0, 1_700_000_000.0), m)
        assertEquals(m, FlightMode.from(m!!.toMap()))
        assertNull(FlightMode.from(null))
    }

    // ── how long ────────────────────────────────────────────────────────────
    private val zone = ZoneId.of("Asia/Jerusalem")
    /** 2026-10-06 is a Tuesday (Apple weekday 3). */
    private fun at(h: Int, m: Int = 0) = ZonedDateTime.of(2026, 10, 6, h, m, 0, 0, zone)
    private fun until(t: ZonedDateTime, minutes: Long) = FlightMode("4821", t.plusMinutes(minutes).toEpochSecond().toDouble(), 0.0)
    private val bedtime = QuietHours(bedtime = QuietHours.BEDTIME_DEFAULT)   // every night 20:30

    @Test fun theFixedLengthsAndTonightsBedtime() {
        val now = at(17, 0)
        val c = FlightMode.choices(until(now, 5 * 24 * 60), now, bedtime)
        assertEquals(listOf(15, 30, 60, 120, 180, 210), c.map { it.minutes })
        assertTrue(c.last().bedtime)
        // No bedtime set → no bedtime button.
        assertEquals(5, FlightMode.choices(until(now, 5 * 24 * 60), now, null).size)
    }

    @Test fun neverPastTheReturn() {
        val now = at(17, 0)
        assertEquals(listOf(15, 30), FlightMode.choices(until(now, 45), now, bedtime).map { it.minutes })
        // Ten minutes left: just those.
        val c = FlightMode.choices(until(now, 10), now, bedtime)
        assertEquals(1, c.size); assertTrue(c[0].leftOnly); assertEquals(10, c[0].minutes)
    }

    @Test fun bedtimeOnlyWhenItIsStillAhead() {
        assertNull(FlightMode.minutesUntilBedtime(at(21, 0), bedtime))
        assertEquals(30, FlightMode.minutesUntilBedtime(at(20, 0), bedtime))
        // Under 20 minutes away: not worth a button.
        assertFalse(FlightMode.choices(until(at(20, 15), 600), at(20, 15), bedtime).any { it.bedtime })
        // Not on a night the bedtime is off.
        val weekendsOff = QuietHours(bedtime = QuietHours.BEDTIME_DEFAULT.copy(days = listOf(1, 2, 4, 5, 6, 7)))
        assertNull(FlightMode.minutesUntilBedtime(at(17, 0), weekendsOff))
    }

    @Test fun noChoiceRunsPastBedtimeOrSchool() {
        // 20:00, bedtime at 20:30: half an hour at most, "until bedtime" included.
        val evening = FlightMode.choices(until(at(20, 0), 5 * 24 * 60), at(20, 0), bedtime)
        assertTrue(evening.all { it.minutes <= 30 })
        assertEquals(listOf(15, 30, 30), evening.map { it.minutes }); assertTrue(evening.last().bedtime)
        // 07:20, school at 08:00: never past 40 minutes, and no "until bedtime".
        val both = QuietHours(school = QuietHours.SCHOOL_DEFAULT, bedtime = QuietHours.BEDTIME_DEFAULT)
        val morning = FlightMode.choices(until(at(7, 20), 5 * 24 * 60), at(7, 20), both)
        assertEquals(listOf(15, 30), morning.map { it.minutes })
    }

    @Test fun anOfflineFlightWindowIsAdoptedAsAGrant() {
        assertEquals(PlayWindowLease.Kind.GRANT, PlayWindowLease.Kind.ofLocal("flight"))
        assertEquals(PlayWindowLease.Kind.GIFT, PlayWindowLease.Kind.ofLocal("gift"))
        assertEquals(PlayWindowLease.Kind.EARNED, PlayWindowLease.Kind.ofLocal(null))
    }
}

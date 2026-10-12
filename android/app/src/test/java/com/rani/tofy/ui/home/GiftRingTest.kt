package com.rani.tofy.ui.home

import androidx.compose.ui.geometry.Offset
import org.junit.Assert.assertEquals
import org.junit.Test

/** The ring's arithmetic — the same cases as GiftRing.minutes(at:) on iOS. */
class GiftRingTest {
    private val c = Offset(100f, 100f)
    private fun at(x: Float, y: Float, from: Int, ceiling: Int = 120) = giftRingMinutes(Offset(x, y), c, ceiling, from)

    @Test fun clockwiseFromTheTopInStepsOfFive() {
        assertEquals(30, at(200f, 100f, 30))    // 3 o'clock = a quarter of two hours
        assertEquals(60, at(100f, 200f, 30))    // 6 o'clock
        assertEquals(90, at(0f, 100f, 60))      // 9 o'clock
        assertEquals(0, at(200f, 100f, 30) % 5)
    }

    @Test fun neverUnderFiveNorOverTheCeiling() {
        assertEquals(5, at(101f, 0f, 10))                  // just past the top
        assertEquals(45, at(0f, 100f, 40, ceiling = 45))   // late in the evening: 45 minutes are left
    }

    @Test fun crossingTheTopStopsAtTheEnd() {
        assertEquals(120, at(110f, 0f, 115))   // full ring, finger slips past the top → stays full
        assertEquals(5, at(90f, 0f, 10))       // near empty, finger slips back past the top → stays at 5
    }
}

package com.rani.tofy.data

import java.time.ZonedDateTime
import java.util.Locale
import kotlin.random.Random

/*
 * ✈️ מצב טיסה — the twin of iOS Models/FlightMode.swift (Rani, 2026-10-16:
 * "אני ואישתי טסנו והילדים נשארו לבד"). The parents fly, the children stay
 * home, and nobody can approve anything from the air. Before leaving, the
 * parent sets the date they're back and Tofy makes a 4-digit code for THIS
 * child. The child types it on their own device and picks how long to open —
 * as often as they like — until that date. Then the code stops by itself.
 *
 * It works with no internet on the child's device (the code arrives with the
 * child's doc beforehand and is checked locally), 🌙 bedtime still closes the
 * device (the window opens as kind "flight", not "grant"), and every opening
 * reaches the parents like any other (screenTimeStart, flight: true).
 *
 * Firestore shape (children/{id}.flightMode), written ONLY by
 * Commands.setFlightMode — never inside any other child write:
 *   { code: "4821", until: <unix secs>, setAt: <unix secs> }
 * Ended = { code: "", until: 0, setAt: now }.
 */
data class FlightMode(
    /** Four digits. The child is GIVEN the code, so it is kept in the clear —
     *  the parent's other phone must be able to show it again. */
    val code: String,
    /** Back home at (unix seconds). 0 = off. */
    val until: Double,
    val setAt: Double,
) {
    fun isActive(now: Double = nowSecs()): Boolean = code.isNotEmpty() && until > now

    fun toMap(): Map<String, Any?> = mapOf("code" to code, "until" to until, "setAt" to setAt)

    companion object {
        /** What "end flight mode" writes: no code, no date. */
        fun off(now: Double = nowSecs()) = FlightMode("", 0.0, now)

        fun from(d: Doc?): FlightMode? {
            d ?: return null
            return FlightMode(code = d.str("code") ?: "", until = d.secs("until") ?: 0.0, setAt = d.secs("setAt") ?: 0.0)
        }

        // No 0000/1234-style codes a child would simply guess.
        private val weak = setOf("0000", "1111", "2222", "3333", "4444", "5555", "6666", "7777", "8888", "9999",
            "1234", "4321", "1212", "0123")

        fun newCode(random: Random = Random.Default): String {
            var code: String
            do { code = String.format(Locale.ROOT, "%04d", random.nextInt(0, 10_000)) } while (code in weak)
            return code
        }

        /**
         * The child's choices (FlightCodeSheet.choices): 15 · 30 · an hour · two
         * hours · three hours, plus "until bedtime" when one is set for tonight.
         * Never past the moment the parents are back, nor past the next school
         * time / bedtime.
         */
        fun choices(mode: FlightMode, now: ZonedDateTime, quiet: QuietHours?): List<FlightChoice> {
            val nowUnix = now.toEpochSecond().toDouble()
            // Never past the parents' return, nor past bedtime / school time.
            var left = maxOf(1, ((mode.until - nowUnix) / 60).toInt())
            quiet?.secondsUntilQuiet(now)?.let { left = maxOf(1, minOf(left, it / 60)) }
            val list = listOf(15, 30, 60, 120, 180).filter { it <= left }.map { FlightChoice(it) }.toMutableList()
            minutesUntilBedtime(now, quiet)?.let { m -> if (m >= 20 && m <= left) list += FlightChoice(m, bedtime = true) }
            if (list.isEmpty()) list += FlightChoice(left, leftOnly = true)
            return list
        }

        /** Minutes from [now] to tonight's bedtime, if one is set for today. */
        fun minutesUntilBedtime(now: ZonedDateTime, quiet: QuietHours?): Int? {
            val b = quiet?.bedtime ?: return null
            if (!b.enabled || QuietHours.appleWeekday(now.toLocalDate()) !in b.days) return null
            val m = b.start - (now.hour * 60 + now.minute)
            return if (m > 0) m else null
        }
    }
}

/** One "how long" button: a fixed length, tonight's bedtime, or just what is left. */
data class FlightChoice(val minutes: Int, val bedtime: Boolean = false, val leftOnly: Boolean = false)

/**
 * The child's guard against guessing (FlightModeStore.check): five wrong tries
 * → a minute's wait — never a scolding. Kept on the device ([store] is the
 * kid's SharedPreferences once KidSession is up; memory in unit tests).
 */
object FlightCodeGuard {
    const val MAX_TRIES = 5
    private const val WAIT_SECONDS = 60

    interface Store { var tries: Int; var waitUntil: Double }
    class MemoryStore : Store { override var tries = 0; override var waitUntil = 0.0 }
    var store: Store = MemoryStore()

    /** Seconds left to wait before another try (0 = may try now). */
    fun waitSeconds(now: Double = nowSecs()): Int = maxOf(0, (store.waitUntil - now).toInt())

    /** Checks a typed code. A right one resets the count. */
    fun check(typed: String, mode: FlightMode, now: Double = nowSecs()): Boolean {
        if (waitSeconds(now) > 0 || !mode.isActive(now)) return false
        if (typed == mode.code) { store.tries = 0; return true }
        val tries = store.tries + 1
        if (tries >= MAX_TRIES) { store.tries = 0; store.waitUntil = now + WAIT_SECONDS }
        else store.tries = tries
        return false
    }

    fun reset() { store.tries = 0; store.waitUntil = 0.0 }
}

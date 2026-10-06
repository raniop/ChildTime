package com.rani.tofy.data

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.Locale

/*
 * 🏫 School time and 🌙 bedtime — the twin of iOS ShieldCore/QuietHours.swift.
 * Pure (java.time only) so every rule is unit-tested in QuietHoursTest.
 *
 * Inside a quiet window no EARNED or GIFT play window opens; one that is open
 * when it starts closes, and its leftover goes back to the wallet as of that
 * moment. The parent's own manual open is never touched. Tofy and the parent's
 * "what stays open" apps stay reachable — the child may keep answering.
 *
 * Firestore shape (children/{id}.quietHours), written by both apps:
 *   { school:  { enabled, days:[1..7 Sun=1], start, end, fridayEnd? },
 *     bedtime: { enabled, days, start, end },
 *     schoolOffDay: "yyyy-MM-dd"?, schoolPaused: true? }
 * Minutes after local midnight; end ≤ start = ends the next day.
 */
data class QuietWindow(
    val enabled: Boolean,
    /** Weekdays the window STARTS on: 1 = Sunday … 7 = Saturday (Apple's numbering). */
    val days: List<Int>,
    val start: Int,
    val end: Int,
    /** A different end on Friday — the short school day. null = same as [end]. */
    val fridayEnd: Int? = null,
) {
    fun endMinute(weekday: Int): Int = if (weekday == 6) fridayEnd ?: end else end

    fun toMap(): Map<String, Any?> = buildMap {
        // Merge-written: "off" travels as the regular end, never as a missing key.
        put("enabled", enabled); put("days", days.sorted()); put("start", start); put("end", end)
        put("fridayEnd", fridayEnd ?: end)
    }

    companion object {
        fun from(d: Doc?): QuietWindow? {
            d ?: return null
            return QuietWindow(
                enabled = d.bool("enabled") ?: false,
                days = (d["days"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList(),
                start = d.int("start") ?: return null,
                end = d.int("end") ?: return null,
                fridayEnd = d.int("fridayEnd"),
            )
        }
    }
}

enum class QuietKind { SCHOOL, BEDTIME }

data class QuietOccurrence(val kind: QuietKind, val start: ZonedDateTime, val end: ZonedDateTime) {
    val startUnix: Double get() = start.toEpochSecond().toDouble()
    val endUnix: Double get() = end.toEpochSecond().toDouble()
}

data class QuietHours(
    val school: QuietWindow? = null,
    val bedtime: QuietWindow? = null,
    /** "yyyy-MM-dd" on the child device's calendar: the parent's "no school today". */
    val schoolOffDay: String? = null,
    /** Vacation: every school window off until the parent turns it back on. */
    val schoolPaused: Boolean? = null,
) {
    val isEmpty: Boolean get() = school?.enabled != true && bedtime?.enabled != true

    fun toMap(): Map<String, Any?> = buildMap {
        school?.let { put("school", it.toMap()) }
        bedtime?.let { put("bedtime", it.toMap()) }
        // Written explicitly ("" / false) — a merge must be able to turn these OFF,
        // and iOS writes the same values.
        put("schoolOffDay", schoolOffDay ?: "")
        put("schoolPaused", schoolPaused == true)
    }

    /** Occurrences that START on a day from [fromDay] to [toDay] around [now]'s day, in start order. */
    fun occurrences(now: ZonedDateTime, fromDay: Long = -1, toDay: Long = 8): List<QuietOccurrence> {
        val today = now.toLocalDate()
        val out = mutableListOf<QuietOccurrence>()
        for (offset in fromDay..toDay) {
            val day = today.plusDays(offset)
            val weekday = appleWeekday(day)
            for ((kind, w) in listOf(QuietKind.SCHOOL to school, QuietKind.BEDTIME to bedtime)) {
                if (w == null || !w.enabled || weekday !in w.days) continue
                if (kind == QuietKind.SCHOOL && (schoolPaused == true || schoolOffDay == dayKey(day))) continue
                val endMin = w.endMinute(weekday)
                if (endMin == w.start) continue
                val midnight = day.atStartOfDay(now.zone)
                val s = midnight.plusMinutes(w.start.toLong())
                val e = midnight.plusMinutes((endMin + if (endMin < w.start) 24 * 60 else 0).toLong())
                out += QuietOccurrence(kind, s, e)
            }
        }
        return out.sortedBy { it.start }
    }

    /** The quiet time in force at [now]; back-to-back windows read as one. */
    fun active(now: ZonedDateTime): QuietOccurrence? {
        val all = occurrences(now)
        var cur = all.filter { !it.start.isAfter(now) && now.isBefore(it.end) }.maxByOrNull { it.end } ?: return null
        var grew = true
        while (grew) {
            grew = false
            for (o in all) if (!o.start.isAfter(cur.end) && o.end.isAfter(cur.end)) {
                cur = QuietOccurrence(cur.kind, cur.start, o.end); grew = true
            }
        }
        return cur
    }

    fun activeAt(unix: Double, zone: ZoneId = ZoneId.systemDefault()): QuietOccurrence? =
        active(ZonedDateTime.ofInstant(Instant.ofEpochMilli((unix * 1000).toLong()), zone))

    fun nextStart(now: ZonedDateTime): ZonedDateTime? =
        occurrences(now, 0, 8).firstOrNull { it.start.isAfter(now) }?.start

    companion object {
        /** Sunday–Friday 08:00–13:30, Friday until 12:00. */
        val SCHOOL_DEFAULT = QuietWindow(true, listOf(1, 2, 3, 4, 5, 6), 8 * 60, 13 * 60 + 30, 12 * 60)
        /** Every night 20:30–07:00. */
        val BEDTIME_DEFAULT = QuietWindow(true, listOf(1, 2, 3, 4, 5, 6, 7), 20 * 60 + 30, 7 * 60)

        fun from(d: Doc?): QuietHours? {
            d ?: return null
            return QuietHours(
                school = QuietWindow.from(d.map("school")),
                bedtime = QuietWindow.from(d.map("bedtime")),
                schoolOffDay = d.str("schoolOffDay"),
                schoolPaused = d.bool("schoolPaused"),
            )
        }

        fun dayKey(day: LocalDate): String = day.toString()   // ISO yyyy-MM-dd

        /** java.time Monday=1…Sunday=7 → Apple Sunday=1…Saturday=7. */
        fun appleWeekday(day: LocalDate): Int = if (day.dayOfWeek == DayOfWeek.SUNDAY) 1 else day.dayOfWeek.value + 1

        fun clock(minutes: Int): String = String.format(Locale.ROOT, "%02d:%02d", (minutes / 60) % 24, minutes % 60)
        fun clock(t: ZonedDateTime): String = String.format(Locale.ROOT, "%02d:%02d", t.hour, t.minute)
    }
}

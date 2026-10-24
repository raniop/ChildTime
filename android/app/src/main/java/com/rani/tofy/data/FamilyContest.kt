package com.rani.tofy.data

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import kotlin.math.abs

/*
 * 🏆 The weekly family contest (Rani, 2026-10-24) — the twin of iOS
 * Models/FamilyContest.swift, same numbers, same Firestore doc.
 *
 * - 🫙 The family jar: every correct answer of every child fills ONE jar. At
 *   ⅓, ⅔ and full, every child gets 10, 20, then 30 minutes.
 * - 👑 The champion: each child against THEIR OWN goal (percent), so the
 *   little one can win. At the week's end: reaching your goal pays 10 minutes,
 *   the champion another 20. Nobody "loses".
 * - One child: the jar is the child's own goal, and the parents add to it with
 *   family tasks. Instead of siblings, the child races last week.
 *
 * The goal is dynamic: what the child REALLY answered correctly in the last
 * weeks, plus 10%. A week is Sunday → Saturday on the device's calendar; its
 * key is the Sunday as yyyy-MM-dd (the dailyStats day key).
 */

/** One day of a child's history, as the contest reads it (children/{id}/dailyStats). */
data class ContestDay(val date: String, val answered: Int, val correct: Int)

object FamilyContest {
    /** Minutes for every child at each jar stage (Rani: "10 20 30"). */
    val stagePrizes = listOf(10, 20, 30)
    const val GOAL_PRIZE = 10
    const val CHAMPION_PRIZE = 20
    const val MIN_GOAL = 70
    /** Family tasks a parent can add to a one-child jar. */
    const val BOOST_PER_TASK = 20

    // ── weeks ────────────────────────────────────────────────────────────────

    /** The Sunday that starts [d]'s week. */
    fun weekStart(d: LocalDate = LocalDate.now()): LocalDate = d.minusDays((d.dayOfWeek.value % 7).toLong())
    fun weekKey(d: LocalDate = LocalDate.now()): String = weekStart(d).toString()
    fun previousWeekStart(d: LocalDate = LocalDate.now()): LocalDate = weekStart(d).minusDays(7)
    fun dayKeys(start: LocalDate): List<String> = (0L until 7L).map { start.plusDays(it).toString() }

    fun correct(history: List<ContestDay>, weekFrom: LocalDate): Int {
        val keys = dayKeys(weekFrom).toSet()
        return history.filter { it.date in keys }.sumOf { it.correct }
    }

    /** Days left including today (Saturday → 1). */
    fun daysLeft(now: LocalDate = LocalDate.now()): Int =
        maxOf(1, 7 - ChronoUnit.DAYS.between(weekStart(now), now).toInt())

    // ── the goal ─────────────────────────────────────────────────────────────

    /**
     * Next week's goal from the child's real answers: a strong week raises it
     * (+10%); a weak week (ill, a trip) only pulls it toward the average, so it
     * never jumps out of reach. [recentDailyAverage] is for a child with no full week yet.
     */
    fun goal(lastWeek: Int, weekBefore: Int, recentDailyAverage: Double = 0.0): Int {
        val base = when {
            lastWeek == 0 && weekBefore == 0 -> recentDailyAverage * 7
            lastWeek >= weekBefore -> lastWeek.toDouble()
            else -> (lastWeek + weekBefore) / 2.0
        }
        return maxOf(MIN_GOAL, round10(base * 1.1))
    }

    fun goal(history: List<ContestDay>, now: LocalDate = LocalDate.now()): Int {
        val last = previousWeekStart(now)
        val before = last.minusDays(7)
        val recent = history.filter { it.date >= before.toString() && it.date < weekKey(now) && it.correct > 0 }
        val avg = if (recent.isEmpty()) 0.0 else recent.sumOf { it.correct }.toDouble() / recent.size
        return goal(correct(history, last), correct(history, before), avg)
    }

    /** To the nearest ten, halves up (Swift's .rounded()). */
    fun round10(x: Double): Int = Math.round(x / 10).toInt() * 10

    // ── the jar ──────────────────────────────────────────────────────────────

    /** ⅓, ⅔ and full, in round tens; the last is exactly the target. */
    fun stages(target: Int): List<Int> =
        if (target <= 0) listOf(0, 0, 0) else listOf(round10(target / 3.0), round10(target * 2 / 3.0), target)

    fun reached(filled: Int, target: Int): List<Int> =
        stages(target).withIndex().filter { filled >= it.value && it.value > 0 }.map { it.index }

    fun stagePrize(i: Int): Int = stagePrizes[minOf(i, 2)]

    // ── standings ────────────────────────────────────────────────────────────

    data class Standing(val childID: String, val goal: Int, val done: Int) {
        val fraction: Double get() = if (goal > 0) done.toDouble() / goal else 0.0
        val percent: Int get() = Math.round(fraction * 100).toInt()
        val reachedGoal: Boolean get() = done >= goal && goal > 0
    }

    /** Everyone sharing the top percent (ties share the crown). Nobody leads before anyone has answered. */
    fun champions(s: List<Standing>): Set<String> {
        val best = s.maxOfOrNull { it.fraction } ?: return emptySet()
        if (best <= 0) return emptySet()
        return s.filter { abs(it.fraction - best) < 0.0001 }.map { it.childID }.toSet()
    }

    /** What one child is owed at the week's end. */
    fun endPrize(me: Standing, all: List<Standing>, lastWeekDone: Int): Int {
        var minutes = if (me.reachedGoal) GOAL_PRIZE else 0
        if (all.size > 1) {
            if (me.childID in champions(all)) minutes += CHAMPION_PRIZE
        } else if (me.done > lastWeekDone && me.done > 0) {
            minutes += CHAMPION_PRIZE   // one child: beat last week's self
        }
        return minutes
    }
}

/**
 * children/{id}/memory/contest:
 *   { week, goal, boost, paid: [stage indices], prev: {week, goal, boost, paid} | null, settled: weekKey | null }
 */
data class ContestRecord(val current: Week, val prev: Week? = null, val settled: String? = null) {
    data class Week(val week: String, val goal: Int, val boost: Int, val paid: List<Int>)

    fun toMap(): Map<String, Any?> = dict(current) + mapOf("prev" to prev?.let { dict(it) }, "settled" to settled)

    /**
     * The record moved into [weekKey]: the old current becomes `prev` only when
     * it was the week just before (a skipped week settles nothing).
     */
    fun rolled(weekKey: String, prevKey: String, goal: Int): ContestRecord {
        if (current.week == weekKey) return this
        val newPrev = if (current.week == prevKey) current else prev?.takeIf { it.week == prevKey }
        return ContestRecord(Week(weekKey, goal, 0, emptyList()), newPrev, settled)
    }

    companion object {
        fun from(d: Map<String, Any?>?): ContestRecord? {
            val w = week(d) ?: return null
            @Suppress("UNCHECKED_CAST")
            return ContestRecord(w, week(d?.get("prev") as? Map<String, Any?>), d?.get("settled") as? String)
        }

        private fun week(d: Map<String, Any?>?): Week? {
            val w = d?.get("week") as? String ?: return null
            return Week(w, (d["goal"] as? Number)?.toInt() ?: FamilyContest.MIN_GOAL, (d["boost"] as? Number)?.toInt() ?: 0,
                (d["paid"] as? List<*>)?.mapNotNull { (it as? Number)?.toInt() } ?: emptyList())
        }

        private fun dict(w: Week): Map<String, Any?> = mapOf("week" to w.week, "goal" to w.goal, "boost" to w.boost, "paid" to w.paid)
    }
}

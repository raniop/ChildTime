package com.rani.tofy.kid.core

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import kotlin.math.floor

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  ProgressSnapshot — port of ChildTime/Models/ProgressSnapshot.swift
 * ════════════════════════════════════════════════════════════════════════════
 *
 * The one document a child's devices share: children/{childID}/state/current.
 * An iPad and an Android phone of the SAME child read and write it, so every
 * key, type and merge rule here is iOS's, byte for byte.
 *
 * WIRE FORMAT (the one trap): iOS encodes this doc with a PLAIN JSONEncoder, so
 * every Date is seconds since 2001-01-01 (Apple's reference date), NOT unix.
 * All Date-typed fields below are therefore kept as `Double?` in APPLE seconds —
 * exactly the number on the wire, never converted back and forth (a round trip
 * through unix would drift a float ulp, and `lastModifiedAt` is compared for
 * EQUALITY in the merge). Use [AppleTime] to get unix/millis for display.
 *   • `purgeCacheAt` is the exception: it is a plain Double written by the
 *     parent as UNIX seconds (it is not a Swift Date).
 *
 * PUBLIC API
 *   ProgressSnapshot(...)                    — every field, iOS defaults
 *   ProgressSnapshot.fromFirestore(map)      — resilient decode (never throws; a
 *                                              missing/bad key keeps its default;
 *                                              `diamonds` falls back to legacy `gems`)
 *   snapshot.toFirestore()                   — the map iOS's JSONEncoder would
 *                                              produce (nil optionals OMITTED, so a
 *                                              merge-write leaves them untouched)
 *   ProgressSnapshot.ratchetMerged(l, r)     — THE conflict-free merge (all rules)
 *   ProgressSnapshot.sameProgressData(a, b)  — equality ignoring version metadata
 *   snapshot.syncWalletMirrors()             — derive legacy minute mirrors
 *   earnedSecondsAvailable / giftSecondsAvailable / walletMinutesShown /
 *   giftMinutesShown / netUnlockedToday      — the balances every reader must use
 *   WalletSeconds.spend / refund             — seconds-exact pocket arithmetic
 *   AppleTime / DayMath                      — reference-date + calendar-day helpers
 *                                              (DayMath.usedToday == iOS DayGate)
 */

/** Apple-reference-date time (seconds since 2001-01-01 UTC) ⇄ unix. */
object AppleTime {
    const val OFFSET = 978307200.0
    /** Swift's `Date.distantPast` (0001-01-01) in reference seconds. */
    const val DISTANT_PAST = -63114076800.0

    fun fromUnix(unix: Double): Double = unix - OFFSET
    fun toUnix(apple: Double): Double = apple + OFFSET
    fun toMillis(apple: Double): Long = floor((apple + OFFSET) * 1000.0).toLong()
    fun nowUnix(): Double = System.currentTimeMillis() / 1000.0
    fun now(): Double = fromUnix(nowUnix())
}

/**
 * Calendar-day math in the device's time zone (iOS `Calendar.current`), on
 * Apple-reference seconds. [usedToday] / [isFutureDay] are DayGate.swift: a
 * stamp dated today OR LATER counts as already used — a child moving the clock
 * forward must never re-open a daily reward.
 */
object DayMath {
    fun localDate(apple: Double, zone: ZoneId): LocalDate =
        Instant.ofEpochMilli(AppleTime.toMillis(apple)).atZone(zone).toLocalDate()

    fun startOfDay(apple: Double, zone: ZoneId): Double =
        AppleTime.fromUnix(localDate(apple, zone).atStartOfDay(zone).toEpochSecond().toDouble())

    fun sameDay(a: Double, b: Double, zone: ZoneId): Boolean = localDate(a, zone) == localDate(b, zone)

    fun usedToday(stamp: Double?, nowApple: Double, zone: ZoneId): Boolean =
        stamp != null && localDate(stamp, zone) >= localDate(nowApple, zone)

    fun isFutureDay(stamp: Double?, nowApple: Double, zone: ZoneId): Boolean =
        stamp != null && localDate(stamp, zone) > localDate(nowApple, zone)

    fun hour(apple: Double, zone: ZoneId): Int =
        Instant.ofEpochMilli(AppleTime.toMillis(apple)).atZone(zone).hour

    /** Whole calendar days from `from`'s day to `to`'s day (DST-safe). */
    fun daysBetween(from: Double, to: Double, zone: ZoneId): Long =
        ChronoUnit.DAYS.between(localDate(from, zone), localDate(to, zone))

    /** Minutes left until local midnight (ProgressStore.minutesUntilMidnight). */
    fun minutesUntilMidnight(nowApple: Double, zone: ZoneId): Int {
        val midnight = localDate(nowApple, zone).plusDays(1).atStartOfDay(zone).toEpochSecond().toDouble()
        return maxOf(0, ((midnight - AppleTime.toUnix(nowApple)) / 60).toInt())
    }
}

data class ProgressSnapshot(
    var pendingMinutes: Int = 0,
    var totalCorrect: Int = 0,
    var totalAnswered: Int = 0,
    /** Apple secs. Never synced by iOS (per-device OS state) — kept for decode parity. */
    var unlockEndsAt: Double? = null,
    var stars: Int = 0,
    /** 💎 spendable wallet — LWW (never max-merged; purchases lower it). */
    var diamonds: Int = 0,
    var xp: Int = 0,
    var currentStreak: Int = 0,
    var dayStreak: Int = 0,
    var lastSessionDate: Double? = null,
    var lastDailyChestDate: Double? = null,
    var lastDailyChallengeDate: Double? = null,
    var unlockedWorlds: List<String> = listOf("numbers_kingdom"),
    var worldProgress: Map<String, Int> = emptyMap(),
    /**
     * 🏆 World tiers: tier × 10 + room (room 0…9), only ever grows, so the
     * max-merge stays right across devices. 0…9 ⭐ bronze, 10…19 ⭐⭐ silver,
     * 20…29 ⭐⭐⭐ gold, 30 = champion. A key's presence also means "visited".
     * `worldProgress` stays the legacy room counter (capped at 9) for old builds.
     */
    var worldStage: Map<String, Int> = emptyMap(),
    var topicAccuracy: Map<String, Double> = emptyMap(),
    var topicAnswered: Map<String, Int> = emptyMap(),
    var topicCorrect: Map<String, Int> = emptyMap(),
    var batchCounter: Int = 0,
    var wrongStreak: Int = 0,
    var totalScore: Int = 0,
    var minutesEarnedToday: Int = 0,
    /** Minutes OPENED today against the daily cap — merged as a max within one day. */
    var minutesUnlockedToday: Int = 0,
    /** Minutes handed back today by stopping early — climbs only, max-merged. */
    var returnedTodayMinutes: Int = 0,
    var dailyEarnedDate: Double? = null,
    var answeredToday: Int = 0,
    var correctToday: Int = 0,
    /** Bonus minutes banked for tomorrow (≤30). */
    var carryOverMinutes: Int? = null,
    var bestStreak: Int = 0,
    /** Fractional progress (seconds) toward the next play-minutes bonus. */
    var cycleSeconds: Double = 0.0,
    var topicResponseMs: Map<String, Double> = emptyMap(),
    var topicAffinity: Map<String, Double> = emptyMap(),
    var topicExposure: Map<String, Int> = emptyMap(),
    var topicAbandon: Map<String, Int> = emptyMap(),
    var topicAdaptiveLevel: Map<String, Double>? = null,
    var hourlyAnswered: List<Int>? = null,
    var hourlyCorrect: List<Int>? = null,
    var wheelProgressCount: Int = 0,
    var recoveryPot: Int = 0,
    var ownedCharacterIDs: List<String> = emptyList(),
    /** 💝 legacy mirror of the gift pocket (derived from the counters). */
    var parentGiftMinutes: Int? = null,
    var secondsCarry: Int? = null,
    var carryIsGift: Boolean? = null,
    // 💰 The wallets, as lifetime counters that only ever go UP (merged by max).
    var earnedSecondsIn: Int? = null,
    var earnedSecondsOut: Int? = null,
    var giftSecondsIn: Int? = null,
    var giftSecondsOut: Int? = null,
    /** UNIX seconds (plain Double written by the parent, not a Swift Date). */
    var purgeCacheAt: Double? = null,
    var giftGivenToday: Int? = null,
    var giftGivenDate: Double? = null,
    var lastComebackWheelAt: Double? = null,
    var varietyBonusDate: Double? = null,
    /** 🧹 Reset generation — a higher epoch wins the merge WHOLESALE. */
    var resetEpoch: Int = 0,
    var revision: Int = 0,
    var lastModifiedAt: Double = AppleTime.now(),
    var deviceID: String = defaultDeviceID,
) {
    /** What today's cap has actually been charged: opened minus handed back. */
    val netUnlockedToday: Int get() = maxOf(0, minutesUnlockedToday - returnedTodayMinutes)

    val earnedSecondsAvailable: Int get() = maxOf(0, (earnedSecondsIn ?: 0) - (earnedSecondsOut ?: 0))
    val giftSecondsAvailable: Int get() = maxOf(0, (giftSecondsIn ?: 0) - (giftSecondsOut ?: 0))

    /** The balance to SHOW — counters first; the legacy field only for a pre-counter snapshot. */
    val walletMinutesShown: Int
        get() = if (earnedSecondsIn == null && earnedSecondsOut == null) pendingMinutes else earnedSecondsAvailable / 60
    val giftMinutesShown: Int
        get() = if (giftSecondsIn == null && giftSecondsOut == null) (parentGiftMinutes ?: 0) else giftSecondsAvailable / 60

    /** Keep the legacy minute fields in step with the counters (dashboards / old builds read them). */
    fun syncWalletMirrors() {
        pendingMinutes = maxOf(0, (earnedSecondsIn ?: 0) - (earnedSecondsOut ?: 0)) / 60
        parentGiftMinutes = maxOf(0, (giftSecondsIn ?: 0) - (giftSecondsOut ?: 0)) / 60
    }

    /** iOS JSONEncoder output: synthesized Encodable skips nil optionals. */
    fun toFirestore(): Map<String, Any> {
        val m = LinkedHashMap<String, Any>()
        fun put(k: String, v: Any?) { if (v != null) m[k] = v }
        put("pendingMinutes", pendingMinutes)
        put("totalCorrect", totalCorrect)
        put("totalAnswered", totalAnswered)
        put("unlockEndsAt", unlockEndsAt)
        put("stars", stars)
        put("diamonds", diamonds)
        put("xp", xp)
        put("currentStreak", currentStreak)
        put("dayStreak", dayStreak)
        put("lastSessionDate", lastSessionDate)
        put("lastDailyChestDate", lastDailyChestDate)
        put("lastDailyChallengeDate", lastDailyChallengeDate)
        put("unlockedWorlds", unlockedWorlds)
        put("worldProgress", worldProgress)
        put("worldStage", worldStage)
        put("topicAccuracy", topicAccuracy)
        put("topicAnswered", topicAnswered)
        put("topicCorrect", topicCorrect)
        put("batchCounter", batchCounter)
        put("wrongStreak", wrongStreak)
        put("totalScore", totalScore)
        put("minutesEarnedToday", minutesEarnedToday)
        put("minutesUnlockedToday", minutesUnlockedToday)
        put("returnedTodayMinutes", returnedTodayMinutes)
        put("dailyEarnedDate", dailyEarnedDate)
        put("answeredToday", answeredToday)
        put("correctToday", correctToday)
        put("carryOverMinutes", carryOverMinutes)
        put("bestStreak", bestStreak)
        put("cycleSeconds", cycleSeconds)
        put("topicResponseMs", topicResponseMs)
        put("topicAffinity", topicAffinity)
        put("topicExposure", topicExposure)
        put("topicAbandon", topicAbandon)
        put("topicAdaptiveLevel", topicAdaptiveLevel)
        put("hourlyAnswered", hourlyAnswered)
        put("hourlyCorrect", hourlyCorrect)
        put("wheelProgressCount", wheelProgressCount)
        put("recoveryPot", recoveryPot)
        put("ownedCharacterIDs", ownedCharacterIDs)
        put("parentGiftMinutes", parentGiftMinutes)
        put("secondsCarry", secondsCarry)
        put("carryIsGift", carryIsGift)
        put("earnedSecondsIn", earnedSecondsIn)
        put("earnedSecondsOut", earnedSecondsOut)
        put("giftSecondsIn", giftSecondsIn)
        put("giftSecondsOut", giftSecondsOut)
        put("purgeCacheAt", purgeCacheAt)
        put("giftGivenToday", giftGivenToday)
        put("giftGivenDate", giftGivenDate)
        put("lastComebackWheelAt", lastComebackWheelAt)
        put("varietyBonusDate", varietyBonusDate)
        put("resetEpoch", resetEpoch)
        put("revision", revision)
        put("lastModifiedAt", lastModifiedAt)
        put("deviceID", deviceID)
        return m
    }

    companion object {
        /**
         * Swift's `ProgressSnapshot.thisDeviceID` — the install id stamped on every
         * write (echo skipping + the final merge tie-break). Set once at startup by
         * [KidIdentity]; "" in plain unit tests.
         */
        @Volatile var defaultDeviceID: String = ""

        fun blank(): ProgressSnapshot = ProgressSnapshot()

        /**
         * Resilient decode (ProgressSnapshot.init(from:)): start from all-defaults and
         * overwrite ONLY keys that are present AND of the right type — a missing,
         * renamed or garbage field can never wipe the rest.
         */
        fun fromFirestore(raw: Map<String, Any?>): ProgressSnapshot {
            val s = ProgressSnapshot()
            raw.int("pendingMinutes")?.let { s.pendingMinutes = it }
            raw.int("totalCorrect")?.let { s.totalCorrect = it }
            raw.int("totalAnswered")?.let { s.totalAnswered = it }
            raw.dbl("unlockEndsAt")?.let { s.unlockEndsAt = it }
            raw.int("stars")?.let { s.stars = it }
            val dia = raw.int("diamonds") ?: raw.int("gems")   // legacy "gems" recovery
            dia?.let { s.diamonds = it }
            raw.int("xp")?.let { s.xp = it }
            raw.int("currentStreak")?.let { s.currentStreak = it }
            raw.int("dayStreak")?.let { s.dayStreak = it }
            raw.dbl("lastSessionDate")?.let { s.lastSessionDate = it }
            raw.dbl("lastDailyChestDate")?.let { s.lastDailyChestDate = it }
            raw.dbl("lastDailyChallengeDate")?.let { s.lastDailyChallengeDate = it }
            raw.strList("unlockedWorlds")?.let { s.unlockedWorlds = it }
            raw.intMap("worldProgress")?.let { s.worldProgress = it }
            raw.intMap("worldStage")?.let { s.worldStage = it }
            raw.dblMap("topicAccuracy")?.let { s.topicAccuracy = it }
            raw.intMap("topicAnswered")?.let { s.topicAnswered = it }
            raw.intMap("topicCorrect")?.let { s.topicCorrect = it }
            raw.int("batchCounter")?.let { s.batchCounter = it }
            raw.int("wrongStreak")?.let { s.wrongStreak = it }
            raw.int("totalScore")?.let { s.totalScore = it }
            raw.int("minutesEarnedToday")?.let { s.minutesEarnedToday = it }
            raw.int("minutesUnlockedToday")?.let { s.minutesUnlockedToday = it }
            raw.int("returnedTodayMinutes")?.let { s.returnedTodayMinutes = it }
            raw.dbl("dailyEarnedDate")?.let { s.dailyEarnedDate = it }
            raw.int("answeredToday")?.let { s.answeredToday = it }
            raw.int("correctToday")?.let { s.correctToday = it }
            raw.int("carryOverMinutes")?.let { s.carryOverMinutes = it }
            raw.int("bestStreak")?.let { s.bestStreak = it }
            raw.dbl("cycleSeconds")?.let { s.cycleSeconds = it }
            raw.dblMap("topicResponseMs")?.let { s.topicResponseMs = it }
            raw.dblMap("topicAffinity")?.let { s.topicAffinity = it }
            raw.intMap("topicExposure")?.let { s.topicExposure = it }
            raw.intMap("topicAbandon")?.let { s.topicAbandon = it }
            raw.dblMap("topicAdaptiveLevel")?.let { s.topicAdaptiveLevel = it }
            raw.intList("hourlyAnswered")?.let { s.hourlyAnswered = it }
            raw.intList("hourlyCorrect")?.let { s.hourlyCorrect = it }
            raw.int("wheelProgressCount")?.let { s.wheelProgressCount = it }
            raw.int("recoveryPot")?.let { s.recoveryPot = it }
            raw.strList("ownedCharacterIDs")?.let { s.ownedCharacterIDs = it }
            raw.int("parentGiftMinutes")?.let { s.parentGiftMinutes = it }
            raw.int("secondsCarry")?.let { s.secondsCarry = it }
            (raw["carryIsGift"] as? Boolean)?.let { s.carryIsGift = it }
            raw.dbl("purgeCacheAt")?.let { s.purgeCacheAt = it }
            raw.int("earnedSecondsIn")?.let { s.earnedSecondsIn = it }
            raw.int("earnedSecondsOut")?.let { s.earnedSecondsOut = it }
            raw.int("giftSecondsIn")?.let { s.giftSecondsIn = it }
            raw.int("giftSecondsOut")?.let { s.giftSecondsOut = it }
            raw.int("giftGivenToday")?.let { s.giftGivenToday = it }
            raw.dbl("giftGivenDate")?.let { s.giftGivenDate = it }
            raw.dbl("lastComebackWheelAt")?.let { s.lastComebackWheelAt = it }
            raw.dbl("varietyBonusDate")?.let { s.varietyBonusDate = it }
            raw.int("resetEpoch")?.let { s.resetEpoch = it }
            raw.int("revision")?.let { s.revision = it }
            raw.dbl("lastModifiedAt")?.let { s.lastModifiedAt = it }
            (raw["deviceID"] as? String)?.let { s.deviceID = it }
            return s
        }

        /** `max` over two optionals, nil only when BOTH are nil — an unwritten counter can't erase one. */
        fun maxOpt(a: Int?, b: Int?): Int? = when {
            a == null -> b
            b == null -> a
            else -> maxOf(a, b)
        }

        /**
         * Pure ratchet-merge of two snapshots of the SAME child (iOS ratchetMerged,
         * rule for rule): resetEpoch wins wholesale; LWW fields from the total-order
         * winner (revision → lastModifiedAt → deviceID); wallet counters + lifetime
         * accumulators by max; owned sets union; dayStreak follows the most recent
         * play; today's counters merge as a unit with `dailyEarnedDate` (max within
         * the same day, else the later day, a future day clamped away); "latest"
         * dates take the later; hourly buckets element-wise max; mirrors re-derived.
         */
        fun ratchetMerged(
            local: ProgressSnapshot,
            remote: ProgressSnapshot,
            nowApple: Double = AppleTime.now(),
            zone: ZoneId = ZoneId.systemDefault(),
        ): ProgressSnapshot {
            if (remote.resetEpoch != local.resetEpoch) {
                return (if (remote.resetEpoch > local.resetEpoch) remote else local).copy()
            }
            val remoteWins = when {
                remote.revision != local.revision -> remote.revision > local.revision
                remote.lastModifiedAt != local.lastModifiedAt -> remote.lastModifiedAt > local.lastModifiedAt
                else -> remote.deviceID > local.deviceID
            }
            val m = (if (remoteWins) remote else local).copy()
            m.earnedSecondsIn = maxOpt(local.earnedSecondsIn, remote.earnedSecondsIn)
            m.earnedSecondsOut = maxOpt(local.earnedSecondsOut, remote.earnedSecondsOut)
            m.giftSecondsIn = maxOpt(local.giftSecondsIn, remote.giftSecondsIn)
            m.giftSecondsOut = maxOpt(local.giftSecondsOut, remote.giftSecondsOut)
            m.stars = maxOf(local.stars, remote.stars)
            // 💎 diamonds stay the winner's (LWW) — they are spendable.
            m.xp = maxOf(local.xp, remote.xp)
            m.totalScore = maxOf(local.totalScore, remote.totalScore)
            m.totalCorrect = maxOf(local.totalCorrect, remote.totalCorrect)
            m.totalAnswered = maxOf(local.totalAnswered, remote.totalAnswered)
            m.bestStreak = maxOf(local.bestStreak, remote.bestStreak)
            m.topicAnswered = mergeMaxInt(local.topicAnswered, remote.topicAnswered)
            m.topicCorrect = mergeMaxInt(local.topicCorrect, remote.topicCorrect)
            m.topicExposure = mergeMaxInt(local.topicExposure, remote.topicExposure)
            m.topicAbandon = mergeMaxInt(local.topicAbandon, remote.topicAbandon)
            m.worldProgress = mergeMaxInt(local.worldProgress, remote.worldProgress)
            m.worldStage = mergeMaxInt(local.worldStage, remote.worldStage)
            m.unlockedWorlds = LinkedHashSet(local.unlockedWorlds).apply { addAll(remote.unlockedWorlds) }.toList()
            m.ownedCharacterIDs = LinkedHashSet(local.ownedCharacterIDs).apply { addAll(remote.ownedCharacterIDs) }.toList()
            // dayStreak is paired with lastSessionDate: follow whoever played last.
            m.dayStreak = if ((remote.lastSessionDate ?: AppleTime.DISTANT_PAST) > (local.lastSessionDate ?: AppleTime.DISTANT_PAST))
                remote.dayStreak else local.dayStreak
            // Same-day group, with a FUTURE-dated day clamped away (clock tampering).
            val today = DayMath.localDate(nowApple, zone)
            fun sane(d: Double?): Double? = d?.takeIf { DayMath.localDate(it, zone) <= today }
            val localDay = sane(local.dailyEarnedDate)
            val remoteDay = sane(remote.dailyEarnedDate)
            val sameDay = when {
                localDay == null && remoteDay == null -> true          // distantPast vs distantPast
                localDay == null || remoteDay == null -> false
                else -> DayMath.sameDay(localDay, remoteDay, zone)
            }
            val lDay = localDay ?: AppleTime.DISTANT_PAST
            val rDay = remoteDay ?: AppleTime.DISTANT_PAST
            when {
                sameDay -> {
                    m.dailyEarnedDate = localDay ?: remoteDay
                    m.minutesEarnedToday = maxOf(local.minutesEarnedToday, remote.minutesEarnedToday)
                    m.minutesUnlockedToday = maxOf(local.minutesUnlockedToday, remote.minutesUnlockedToday)
                    m.returnedTodayMinutes = maxOf(local.returnedTodayMinutes, remote.returnedTodayMinutes)
                    m.answeredToday = maxOf(local.answeredToday, remote.answeredToday)
                    m.correctToday = maxOf(local.correctToday, remote.correctToday)
                }
                rDay > lDay -> {
                    m.dailyEarnedDate = remoteDay
                    m.minutesEarnedToday = remote.minutesEarnedToday
                    m.minutesUnlockedToday = remote.minutesUnlockedToday
                    m.returnedTodayMinutes = remote.returnedTodayMinutes
                    m.answeredToday = remote.answeredToday
                    m.correctToday = remote.correctToday
                }
                else -> {
                    m.dailyEarnedDate = localDay
                    m.minutesEarnedToday = local.minutesEarnedToday
                    m.minutesUnlockedToday = local.minutesUnlockedToday
                    m.returnedTodayMinutes = local.returnedTodayMinutes
                    m.answeredToday = local.answeredToday
                    m.correctToday = local.correctToday
                }
            }
            m.lastSessionDate = laterDate(local.lastSessionDate, remote.lastSessionDate)
            m.lastDailyChestDate = laterDate(local.lastDailyChestDate, remote.lastDailyChestDate)
            m.lastDailyChallengeDate = laterDate(local.lastDailyChallengeDate, remote.lastDailyChallengeDate)
            m.lastComebackWheelAt = laterDate(local.lastComebackWheelAt, remote.lastComebackWheelAt)
            m.varietyBonusDate = laterDate(local.varietyBonusDate, remote.varietyBonusDate)
            m.hourlyAnswered = mergeHourly(local.hourlyAnswered, remote.hourlyAnswered)
            m.hourlyCorrect = mergeHourly(local.hourlyCorrect, remote.hourlyCorrect)
            // Re-derive the LWW mirrors from the merged counters — once any exist.
            if (m.earnedSecondsIn != null || m.earnedSecondsOut != null || m.giftSecondsIn != null || m.giftSecondsOut != null) {
                m.syncWalletMirrors()
            }
            return m
        }

        /** Element-wise max of two 24-slot hour-bucket arrays. */
        fun mergeHourly(a: List<Int>?, b: List<Int>?): List<Int>? {
            if (a == null || a.size != 24) return b
            if (b == null || b.size != 24) return a
            return List(24) { maxOf(a[it], b[it]) }
        }

        /** Equal ignoring version metadata and the order of the set-derived arrays. */
        fun sameProgressData(a: ProgressSnapshot, b: ProgressSnapshot): Boolean {
            fun norm(s: ProgressSnapshot) = s.copy(
                revision = 0, lastModifiedAt = AppleTime.DISTANT_PAST, deviceID = "",
                unlockedWorlds = s.unlockedWorlds.sorted(), ownedCharacterIDs = s.ownedCharacterIDs.sorted(),
            )
            return norm(a) == norm(b)
        }

        fun mergeMaxInt(a: Map<String, Int>, b: Map<String, Int>): Map<String, Int> {
            val out = LinkedHashMap(a)
            for ((k, v) in b) out[k] = maxOf(out[k] ?: 0, v)
            return out
        }

        fun laterDate(a: Double?, b: Double?): Double? = when {
            a != null && b != null -> maxOf(a, b)
            else -> a ?: b
        }

        // ── resilient field readers (Swift's `try? decodeIfPresent`) ─────────
        private fun asInt(v: Any?): Int? = when (v) {
            is Boolean -> null
            is Int -> v
            is Long -> if (v in Int.MIN_VALUE..Int.MAX_VALUE) v.toInt() else null
            is Short -> v.toInt()
            is Byte -> v.toInt()
            is Number -> {
                val d = v.toDouble()
                if (d.isFinite() && d == floor(d) && d >= Int.MIN_VALUE && d <= Int.MAX_VALUE) d.toInt() else null
            }
            else -> null
        }
        private fun asDbl(v: Any?): Double? = if (v is Number) v.toDouble() else null

        private fun Map<String, Any?>.int(k: String): Int? = asInt(this[k])
        private fun Map<String, Any?>.dbl(k: String): Double? = asDbl(this[k])
        private fun Map<String, Any?>.strList(k: String): List<String>? {
            val l = this[k] as? List<*> ?: return null
            return if (l.all { it is String }) l.map { it as String } else null
        }
        private fun Map<String, Any?>.intList(k: String): List<Int>? {
            val l = this[k] as? List<*> ?: return null
            val out = l.map { asInt(it) ?: return null }
            return out
        }
        private fun Map<String, Any?>.intMap(k: String): Map<String, Int>? {
            val m = this[k] as? Map<*, *> ?: return null
            val out = LinkedHashMap<String, Int>()
            for ((kk, vv) in m) { out[kk as? String ?: return null] = asInt(vv) ?: return null }
            return out
        }
        private fun Map<String, Any?>.dblMap(k: String): Map<String, Double>? {
            val m = this[k] as? Map<*, *> ?: return null
            val out = LinkedHashMap<String, Double>()
            for ((kk, vv) in m) { out[kk as? String ?: return null] = asDbl(vv) ?: return null }
            return out
        }
    }
}

/**
 * Seconds-exact wallet arithmetic (PlayWindowLease.swift `WalletSeconds`): time is
 * neither minted nor lost. Spending rounds the pocket withdrawal UP and hands
 * the unspent part back to the 0…59 carry.
 */
object WalletSeconds {
    data class Spend(val granted: Int, val minutesOut: Int, val carryLeft: Int)
    data class Refund(val minutesIn: Int, val carryLeft: Int)

    fun spend(want: Int, minutes: Int, carry: Int): Spend {
        val c = maxOf(0, minOf(59, carry))
        val mins = maxOf(0, minutes)
        val granted = maxOf(0, minOf(want, mins * 60 + c))
        val minutesOut = (maxOf(0, granted - c) + 59) / 60
        return Spend(granted, minutesOut, minutesOut * 60 + c - granted)
    }

    fun refund(seconds: Int, carry: Int): Refund {
        val total = maxOf(0, seconds) + maxOf(0, minOf(59, carry))
        return Refund(total / 60, total % 60)
    }
}

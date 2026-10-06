package com.rani.tofy.kid.ui.games

import com.rani.tofy.kid.content.MemoryContentPrefs
import com.rani.tofy.kid.core.ChestReward
import com.rani.tofy.kid.core.KidClock
import com.rani.tofy.kid.core.KidSettings
import com.rani.tofy.kid.core.MiniGameEarnBucket
import com.rani.tofy.kid.core.ProgressEngine
import java.time.LocalDateTime
import java.time.ZoneId

/** A movable clock for the earning rules and the day gates. */
class GameFakeClock(override val zone: ZoneId = ZoneId.of("Asia/Jerusalem")) : KidClock {
    // Wednesday 2026-10-07 10:00 local — a weekday (💎 ×1).
    var unix = LocalDateTime.of(2026, 10, 7, 10, 0).atZone(zone).toEpochSecond().toDouble()
    var up = 1000.0
    override fun nowUnix() = unix
    override fun uptimeSecs() = up
    fun advance(seconds: Double) { unix += seconds; up += seconds }
}

/** The games' sink over a bare ProgressEngine — the real earning rules, no Android. */
class EngineSink(val engine: ProgressEngine, val clock: GameFakeClock) : GameProgressSink {
    var historyRows = 0
    var sessions = 0
    override fun miniGameAnswer(correct: Boolean, topic: String, responseMs: Double, bucket: MiniGameEarnBucket?, surprise: Boolean, retry: Boolean) =
        engine.recordMiniGameAnswer(correct, topic, responseMs, bucket, surprise, retry)
    override fun takeRoundSeconds() = engine.takeRoundSeconds()
    override fun applyChest(stars: Int, diamonds: Int, minutes: Int) { engine.applyChestReward(ChestReward(stars, diamonds, minutes)) }
    override fun bossAnswer(correct: Boolean) { engine.recordBossAnswer(correct) }
    override val secondsPerCorrect: Int get() = engine.settings.secondsPerCorrect
    override val currentStreak: Int get() = engine.snapshot.currentStreak
    override fun newBucket() = MiniGameEarnBucket { clock.unix }
    override fun startSession() { sessions++ }
    override fun recordHistory(topic: String, correct: Boolean, responseMs: Double, earnedMinutes: Int, streak: Int, voluntary: Boolean) { historyRows++ }
    override fun nowUnix() = clock.unix
    override val zone: ZoneId get() = clock.zone
}

object GameTestSupport {
    /** A fresh child (grade `grade`, Hebrew), empty prefs, and a real engine behind the ledger. */
    fun install(grade: Int = 3, settings: KidSettings = KidSettings(childDailyCapMinutes = 0)): EngineSink {
        GameEnv.source = FakeSource(grade = grade)
        GameEnv.prefs = MemoryContentPrefs()
        val clock = GameFakeClock()
        val sink = EngineSink(ProgressEngine(settings, clock, "DEV-T"), clock)
        MiniGameLedger.sink = sink
        GameContent.clearCache()
        return sink
    }
}

/**
 * A tiny evaluator for the games' printed arithmetic ("(−3) × (−4)", "√144 ÷ 2",
 * "5² − 3²", "12 ÷ 4 + 2") so a test can check that every shown fact is TRUE.
 */
object Arith {
    fun eval(s0: String): Double {
        val s = s0.replace("‎", "").replace("⁦", "").replace("⁩", "").replace(" ", " ")
            .replace("−", "-").replace("×", "*").replace("÷", "/").replace(" ", "")
        var i = 0
        fun peek() = if (i < s.length) s[i] else '\u0000'
        lateinit var expr: () -> Double
        fun primary(): Double {
            val c = peek()
            if (c == '(') { i++; val v = expr(); check(peek() == ')') { "missing ) in $s0" }; i++; return v }
            val start = i
            while (i < s.length && (s[i].isDigit() || s[i] == '.')) i++
            check(i > start) { "number expected at $i in $s0" }
            return s.substring(start, i).toDouble()
        }
        fun postfix(): Double {
            var v = primary()
            while (true) {
                when (peek()) { '²' -> { i++; v *= v }; '³' -> { i++; v = v * v * v }; else -> return v }
            }
        }
        fun factor(): Double = when (peek()) {
            '-' -> { i++; -factor() }
            '√' -> { i++; Math.sqrt(postfix()) }
            else -> postfix()
        }
        fun term(): Double {
            var v = factor()
            while (true) { when (peek()) { '*' -> { i++; v *= factor() }; '/' -> { i++; v /= factor() }; else -> return v } }
        }
        expr = {
            var v = term()
            while (true) { when (peek()) { '+' -> { i++; v += term() }; '-' -> { i++; v -= term() }; else -> break } }
            v
        }
        val v = expr()
        check(i == s.length) { "trailing input in $s0" }
        return v
    }
}

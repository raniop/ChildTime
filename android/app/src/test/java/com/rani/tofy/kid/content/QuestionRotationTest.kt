package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlinx.serialization.encodeToString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import kotlin.random.Random

/** Rani, 2026-10-17: "שאלות שנשאלו לא יחזרו" (QuestionRotationTests.swift). */
class QuestionRotationTest {
    @Before fun setUp() = ContentTestSupport.install()

    /** Each pick a millisecond later than the last, so "the oldest" is never a tie. */
    private class TickingClock { var t = 1_000_000.0; fun now(): Double { t += 0.001; return t } }

    /** Records what would go to Firestore. */
    private class FakeCloud(val remote: Map<String, Map<String, Double>> = emptyMap()) : QuestionMemoryCloud {
        val pushed = mutableListOf<Triple<String, String, String>>()
        val covered = mutableMapOf<String, Pair<Int, Int>>()
        override fun pull(child: String, merge: (Map<String, Map<String, Double>>) -> Unit) = merge(remote)
        override fun push(child: String, topic: String, fingerprint: String, at: Double) { pushed += Triple(child, topic, fingerprint) }
        override fun coverage(child: String, topic: String, seen: Int, pool: Int, at: Double) { covered[topic] = seen to pool }
    }

    private fun sciencePool(n: Int): List<BankQuestion> {
        val bank = (QuestionBanks.bank(Topic.SCIENCE, AppLanguage.HE) ?: emptyList()).distinctBy { it.key }
        assertTrue("the science bank should be deep enough", bank.size >= n)
        return bank.take(n)
    }

    /**
     * Every question of a world is asked once before ANY comes back, across
     * many sessions — and then the one asked longest ago is first to return.
     */
    @Test fun wholeWorldBeforeAnyRepeat() {
        val pool = sciencePool(30)
        val clock = TickingClock()
        val m = QuestionMemory(MemoryContentPrefs(), "kid", clock = clock::now)
        val rng = Random(7)
        val order = mutableListOf<String>()
        for (session in 0 until 6) {
            m.beginSession()
            repeat(5) {
                val q = m.pickFresh(pool, Topic.SCIENCE, Difficulty.MEDIUM, rng)!!
                assertFalse("session $session: a question came back before the world was used up", q.key in order)
                order += q.key
            }
        }
        assertEquals(pool.size, order.size)
        // The world is used up: the next one is the FIRST asked.
        m.beginSession()
        assertEquals(order.first(), m.pickFresh(pool, Topic.SCIENCE, Difficulty.MEDIUM, rng)!!.key)
        // …and a relaunch remembers all of it.
        assertEquals(pool.size, m.seenCount(pool, Topic.SCIENCE))
    }

    /** What the child's other device asked counts as asked here too. */
    @Test fun anotherDevicesQuestionsAreNotAskedAgain() {
        val pool = sciencePool(10)
        val elsewhere = pool.take(9).associate { QuestionMemory.fingerprint(it.key) to 1_700_000_000.0 }
        val m = QuestionMemory(MemoryContentPrefs(), "kid", FakeCloud(mapOf("science" to elsewhere)))
        m.beginSession()   // pulls the other device's entries
        val q = m.pickFresh(pool, Topic.SCIENCE, Difficulty.MEDIUM, Random(3))
        assertEquals("the only question the other device didn't ask", pool[9].prompt, q?.prompt)
    }

    /** The later time wins when the two devices disagree. */
    @Test fun mergeKeepsTheLaterTime() {
        val pool = sciencePool(1)
        val m = QuestionMemory(MemoryContentPrefs(), "kid", clock = { 500.0 })
        m.pickFresh(pool, Topic.SCIENCE, Random(1))
        val fp = QuestionMemory.fingerprint(pool[0].key)
        m.merge(mapOf("science" to mapOf(fp to 100.0)))
        assertEquals(500.0, m.askedAt(pool[0], Topic.SCIENCE)!!, 0.0)
        m.merge(mapOf("science" to mapOf(fp to 900.0)))
        assertEquals(900.0, m.askedAt(pool[0], Topic.SCIENCE)!!, 0.0)
    }

    /** The fingerprint iOS computes too — pinned so the two never drift. */
    @Test fun fingerprintIsStable() {
        assertEquals("ba7816bf8f01", QuestionMemory.fingerprint("abc"))
    }

    /** The old recent-list memory becomes timestamps in the same order — nothing seen is forgotten. */
    @Test fun theOldMemoryIsMigratedOldestFirst() {
        val pool = (1..5).map { BankQuestion("q$it", "a$it", listOf("x", "y", "z"), Difficulty.MEDIUM, 1, 6) }
        val prefs = MemoryContentPrefs()
        prefs.putString("questionMemory.kid", contentJson.encodeToString(mapOf("logic" to pool.take(4).map { it.key })))
        val m = QuestionMemory(prefs, "kid", clock = { 1000.0 })
        assertEquals(996.0, m.askedAt(pool[0], Topic.LOGIC)!!, 0.0)
        assertEquals(999.0, m.askedAt(pool[3], Topic.LOGIC)!!, 0.0)
        assertEquals("q5", m.pickFresh(pool, Topic.LOGIC, Random(1))!!.prompt)
        // The whole pool asked: the oldest of the migrated list comes back first.
        m.beginSession()
        assertEquals("q1", m.pickFresh(pool, Topic.LOGIC, Random(1))!!.prompt)
    }

    /** Each pick goes to the cloud with its world's coverage; no profile, no cloud. */
    @Test fun picksArePushedWithCoverage() {
        val pool = (1..4).map { BankQuestion("q$it", "a$it", listOf("x", "y", "z"), Difficulty.MEDIUM, 1, 6) }
        val cloud = FakeCloud()
        val m = QuestionMemory(MemoryContentPrefs(), "kid", cloud)
        m.pickFresh(pool, Topic.LOGIC, Difficulty.MEDIUM, Random(1))
        m.pickFresh(pool, Topic.LOGIC, Difficulty.MEDIUM, Random(1))
        assertEquals(2, cloud.pushed.size)
        assertTrue(cloud.pushed.all { it.first == "kid" && it.second == "logic" && it.third.length == 12 })
        assertEquals(2 to 4, cloud.covered["logic"])
        val anonymous = FakeCloud()
        QuestionMemory(MemoryContentPrefs(), null, anonymous).pickFresh(pool, Topic.LOGIC, Random(1))
        assertTrue(anonymous.pushed.isEmpty())
    }

    /** 👶 גן thinking questions go through the memory too: all of them before any comes back. */
    @Test fun pictureQuestionsAreNotAskedAgain() {
        val pictures = (0 until 10).map {
            BankQuestion("🔬\nשְׁאֵלָה $it", "🧊", listOf("🔥", "🌈", "🍃"), Difficulty.EASY, 0, 0)
        }
        val m = QuestionMemory(MemoryContentPrefs(), "kid")
        val asked = (0 until 10).map { PreReaderContent.pictureQuestion(pictures, Topic.SCIENCE, Random(it), memory = m) }
        asked.forEach { assertNotNull(it) }
        assertEquals(10, asked.map { it!!.prompt }.toSet().size)
        assertEquals(10, m.seenCount(pictures, Topic.SCIENCE))
    }
}

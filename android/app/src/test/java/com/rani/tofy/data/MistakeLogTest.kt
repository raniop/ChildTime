package com.rani.tofy.data

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** ❌ The wrong-answers log (iOS MistakeLog): one record shape, newest last, ≤ 30 per topic, merged newest first. */
class MistakeLogTest {
    private fun m(i: Int, q: String = "q$i") = Mistake(q, "a$i", "c$i", 1_000.0 + i)

    @Test fun theQuestionTextIsSpokenAndPromptWithoutNiqqud() {
        assertEquals("מה בא אחרי? · 🔴 🔵 ❓", MistakeLog.questionText("מָה בָּא אַחֲרֵי?", "🔴 🔵 ❓"))
        // The same line twice is said once; an empty spoken line is left out.
        assertEquals("כמה זה 2+3?", MistakeLog.questionText("כַּמָּה זֶה 2+3?", "כַּמָּה זֶה 2+3?").let { MistakeLog.strip(it) })
        assertEquals("7×8", MistakeLog.questionText("", "7×8"))
        assertEquals("7×8", MistakeLog.questionText(null, "7×8"))
    }

    @Test fun recordingKeepsTheLatestThirtyNewestLast() {
        var list = emptyList<Mistake>()
        for (i in 1..35) list = MistakeLog.appended(list, m(i))
        assertEquals(MistakeLog.PER_TOPIC, list.size)
        assertEquals("q6", list.first().q)
        assertEquals("q35", list.last().q)
    }

    @Test fun theParentSeesBothCopiesOnceNewestFirst() {
        val local = mapOf("math" to listOf(m(1), m(3)))
        val cloud = mapOf("math" to listOf(m(1), m(2)), "english" to listOf(m(5)))
        val out = MistakeLog.merged(local, cloud)
        assertEquals(listOf("q3", "q2", "q1"), out["math"]!!.map { it.q })
        assertEquals(listOf("q5"), out["english"]!!.map { it.q })
        val many = MistakeLog.merged(mapOf("math" to (1..20).map { m(it) }), mapOf("math" to (21..40).map { m(it) }))
        assertEquals(30, many["math"]!!.size)
        assertEquals("q40", many["math"]!!.first().q)
    }

    @Test fun theFirestoreShapeRoundTrips() {
        val rows = MistakeLog.rows(listOf(m(1), m(2)))
        assertEquals(setOf("q", "a", "c", "at"), rows.first().keys)
        assertTrue(rows.first()["at"] is Double)
        val back = MistakeLog.fromFirestore(mapOf("math" to rows, "junk" to "x", "logic" to listOf(mapOf("q" to "only q"))))
        assertEquals(listOf(m(1), m(2)), back["math"])
        assertEquals(emptyList<Mistake>(), back["logic"])
        // Local copy (SharedPreferences JSON).
        val all = mapOf("math" to listOf(m(1)))
        assertEquals(all, MistakeLog.decode(MistakeLog.encode(all)))
        assertEquals(emptyMap<String, List<Mistake>>(), MistakeLog.decode("not json"))
    }
}

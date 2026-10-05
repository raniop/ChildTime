package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Difficulty
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class CurriculumMathTest {
    /** Strip the bidi isolates / no-break spaces / RLM marks the generator adds. */
    private fun plain(s: String) = s.replace(Regex("[\u2066-\u2069\u200F]"), "").replace('\u00A0', ' ').replace('−', '-')

    private val add = Regex("""^(-?\d+) \+ (-?\d+) = \?$""")
    private val sub = Regex("""^(-?\d+) - (-?\d+) = \?$""")
    private val mul = Regex("""^(-?\d+) × (-?\d+) = \?$""")
    private val div = Regex("""^(\d+) ÷ (\d+) = \?$""")
    private val mulAdd = Regex("""^(\d+) × (\d+) \+ (\d+) = \?$""")
    private val complete = Regex("""^(\d+) \+ \? = 10$""")

    /** For the purely arithmetic prompts, recompute the answer independently. */
    private fun expected(prompt: String): Long? {
        val p = plain(prompt).replace(Regex("""\((-\d+)\)"""), "$1")
        add.find(p)?.let { return it.groupValues[1].toLong() + it.groupValues[2].toLong() }
        sub.find(p)?.let { return it.groupValues[1].toLong() - it.groupValues[2].toLong() }
        mulAdd.find(p)?.let { return it.groupValues[1].toLong() * it.groupValues[2].toLong() + it.groupValues[3].toLong() }
        mul.find(p)?.let { return it.groupValues[1].toLong() * it.groupValues[2].toLong() }
        div.find(p)?.let { val a = it.groupValues[1].toLong(); val b = it.groupValues[2].toLong(); return if (a % b == 0L) a / b else null }
        complete.find(p)?.let { return 10 - it.groupValues[1].toLong() }
        return null
    }

    @Test fun everyGradeAndDifficultyProducesAValidQuestion() {
        val rng = Random(2026)
        var checked = 0
        for (lang in AppLanguage.entries) for (grade in 1..8) for (d in Difficulty.entries) repeat(200) {
            val q = CurriculumMath.generate(grade, d, lang, rng)
            val tag = "g$grade/$d/$lang: ${q.prompt} ${q.options}"
            assertTrue(tag, q.prompt.isNotBlank())
            assertTrue(tag, q.options.size in 2..4)
            assertTrue(tag, q.correctIndex in q.options.indices)
            assertEquals("distinct options $tag", q.options.size, q.options.toSet().size)
            val distractors = q.options.filterIndexed { i, _ -> i != q.correctIndex }
            assertTrue(tag, q.correctAnswer !in distractors)
            expected(q.prompt)?.let { want ->
                assertEquals(tag, want.toString(), plain(q.correctAnswer).trim())
                checked++
            }
        }
        assertTrue("arithmetic prompts were actually recomputed ($checked)", checked > 1000)
    }

    @Test fun middleSchoolMathCarriesSkillTags() {
        val rng = Random(7)
        val skills = (1..400).mapNotNull { CurriculumMath.generate(8, Difficulty.MEDIUM, AppLanguage.HE, rng).skill }.toSet()
        assertTrue(skills.containsAll(setOf("equations", "pythagoras", "roots", "linearFunction", "volume", "powers", "probability", "circle")))
    }

    @Test fun moneyIsShekelsInIsraelAndDollarsInEnglish() {
        val he = (1..400).map { CurriculumMath.generate(7, Difficulty.MEDIUM, AppLanguage.HE, Random(it)) }
            .filter { it.skill == "proportion" || it.skill == "percent" }
        assertTrue(he.isNotEmpty() && he.all { q -> q.options.all { it.endsWith(" ₪") } })
        val en = (1..400).map { CurriculumMath.generate(7, Difficulty.MEDIUM, AppLanguage.EN, Random(it)) }
            .filter { it.skill == "proportion" || it.skill == "percent" }
        assertTrue(en.isNotEmpty() && en.all { q -> q.options.all { plain(it).startsWith("$") } })
    }

    @Test fun helpersMatchSwift() {
        assertEquals("2.5", CurriculumMath.fmt(2.5))
        assertEquals("3", CurriculumMath.fmt(3.0000001))
        assertEquals("12.56", CurriculumMath.fmt(3.14 * 4))
        assertEquals("−3", CurriculumMath.signed(-3))
        assertEquals("(−7)", CurriculumMath.paren(-7))
        assertEquals("", CurriculumMath.coef(1)); assertEquals("−", CurriculumMath.coef(-1)); assertEquals("3", CurriculumMath.coef(3))
        assertEquals("²⁵", CurriculumMath.superscript(25))
        // לְדָנָה: the dagesh of ד drops after the shva prefix.
        assertEquals("דָנָה", CurriculumMath.afterShvaPrefix("דָּנָה"))
        assertEquals("נֹעָה", CurriculumMath.afterShvaPrefix("נֹעָה"))
        assertEquals(2.0, swiftRound(1.5), 0.0); assertEquals(3.0, swiftRound(2.5), 0.0)
    }
}

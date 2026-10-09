package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.io.File
import kotlinx.serialization.encodeToString
import kotlin.random.Random

class SelectionTest {
    @Before fun setUp() = ContentTestSupport.install()

    private fun child(grade: Int = 3, lang: AppLanguage = AppLanguage.HE, id: String = "kid-1") =
        ChildContentProfile(profileId = id, grade = grade, language = lang)

    private fun item(i: Int, tier: Difficulty = Difficulty.MEDIUM, lo: Int = 1, hi: Int = 6) =
        BankQuestion("q$i", "a$i", listOf("x$i", "y$i", "z$i"), tier, lo, hi)

    // MARK: determinism

    private fun run(seed: Int, mode: ContentMode, lang: AppLanguage, grade: Int): List<String> {
        ContentTestSupport.install(seed)
        val s = QuestionSource.session(child(grade, lang), mode)
        return List(25) { s.next(bonus = it == 10).question.let { q -> q.prompt + "|" + q.options.joinToString() + "|" + q.correctIndex } }
    }

    @Test fun seededSessionsAreDeterministic() {
        for ((mode, lang, grade) in listOf(
            Triple(ContentMode.World(Topic.MATH), AppLanguage.HE, 4),
            Triple(ContentMode.World(Topic.SCIENCE), AppLanguage.EN, 2),
            Triple(ContentMode.World(Topic.READING), AppLanguage.RU, 3),
            Triple(ContentMode.SmartFeed, AppLanguage.HE, 5),
            Triple(ContentMode.BonusArena, AppLanguage.AR, 6),
        )) {
            assertEquals("$mode/$lang", run(99, mode, lang, grade), run(99, mode, lang, grade))
        }
        assertNotEquals(run(1, ContentMode.World(Topic.LOGIC), AppLanguage.HE, 2), run(2, ContentMode.World(Topic.LOGIC), AppLanguage.HE, 2))
    }

    @Test fun readingServesWholePassagesWithTheTextAttached() {
        val s = QuestionSource.session(child(2), ContentMode.World(Topic.READING))
        val qs = List(12) { s.next().question }
        assertTrue(qs.all { it.passage != null && it.topic == Topic.READING })
        // Consecutive questions share a passage until the group is done.
        val groups = qs.map { it.passage }.zipWithNext().count { (a, b) -> a != b }
        assertTrue("passage switches=$groups", groups in 2..6)
    }

    @Test fun preReaderGetsPictureQuestions() {
        val s = QuestionSource.session(child(0), ContentMode.World(Topic.MATH))
        // Count, add, take away, compare, find the digit — always read aloud,
        // and a plain row of pictures is answered by counting it.
        repeat(60) {
            val q = s.next().question
            assertTrue(q.spoken != null)
            assertTrue(q.correctIndex in q.options.indices)
            val marked = listOf("➕", "➖", "⚖️", "👂").any { it in q.prompt }
            if (!marked) assertEquals(q.correctAnswer.toInt(), q.prompt.split(" ").size)
            if ("➕" in q.prompt) {
                val (a, b) = q.prompt.split("➕").map { side -> side.trim().split(" ").size }
                assertEquals(a + b, q.correctAnswer.toInt())
            }
            if ("➖" in q.prompt) {
                val (a, b) = q.prompt.split("➖").map { side -> side.trim().split(" ").size }
                assertEquals(a - b, q.correctAnswer.toInt())
            }
        }
    }

    @Test fun parentHiddenQuestionsAreSkipped() {
        val bank = QuestionBanks.bank(Topic.LOGIC, AppLanguage.HE)!!
        val prefs = MemoryContentPrefs()
        ContentTestSupport.install(5, prefs)
        // The parent reported a handful of grade-2 items on this device.
        val hidden = bank.filter { it.inGrade(2) }.take(8).map { it.prompt }.toSet()
        prefs.putString("reportedHiddenPrompts", contentJson.encodeToString(hidden.toList()))
        QuestionReporter.init(prefs)
        assertTrue(hidden.all { QuestionReporter.isHidden(it) })
        val s = QuestionSource.session(child(2), ContentMode.World(Topic.LOGIC))
        repeat(60) { assertFalse(s.next().question.prompt in hidden) }
    }

    @Test fun bossBitesFromOneGradeUpAtTheTopBand() {
        val strong = child(1).copy(topicAdaptiveLevel = mapOf("math" to 1.9))
        val q = QuestionSource.bossQuestion(strong, Topic.MATH)
        assertTrue(q.topic == Topic.MATH)
    }

    // MARK: adaptive engine — exact iOS constants

    @Test fun adaptiveStepsMatchSwift() {
        val e = AdaptiveDifficultyEngine
        assertEquals(0.17, e.RISE_STRONG, 0.0); assertEquals(0.09, e.RISE_SOLID, 0.0); assertEquals(0.03, e.RISE_SHAKY, 0.0)
        assertEquals(0.34, e.EASE_MISS, 0.0); assertEquals(0.45, e.EASE_GIVE_UP, 0.0)
        fun step(correct: Boolean = true, fast: Boolean = false, hint: Boolean = false, gaveUp: Boolean = false) =
            e.updatedLevel(1.0, Difficulty.MEDIUM, AdaptiveDifficultyEngine.Signals(correct, fast, hint, gaveUp))
        assertEquals(1.17, step(fast = true), 1e-9)
        assertEquals(1.09, step(), 1e-9)
        assertEquals(1.03, step(hint = true, fast = true), 1e-9)
        assertEquals(0.66, step(correct = false), 1e-9)
        assertEquals(0.55, step(correct = false, gaveUp = true), 1e-9)
        // Anchor ±1 and the 0…2 scale.
        assertEquals(1.0, e.updatedLevel(0.95, Difficulty.EASY, AdaptiveDifficultyEngine.Signals(true, true, false, false)), 1e-9)
        assertEquals(0.0, e.updatedLevel(0.1, Difficulty.EASY, AdaptiveDifficultyEngine.Signals(false, false, false, true)), 1e-9)
        assertEquals(2.0, e.updatedLevel(1.95, Difficulty.HARD, AdaptiveDifficultyEngine.Signals(true, true, false, false)), 1e-9)
        assertEquals(Difficulty.MEDIUM, e.difficulty(0.5))   // Swift rounds half away from zero
        assertEquals(Difficulty.EASY, e.difficulty(0.49))
        assertEquals(Difficulty.HARD, e.difficulty(1.5))
    }

    @Test fun sampledMixIsSeventyTwentyTen() {
        val rng = Random(3)
        val n = 20_000
        val counts = (1..n).groupingBy { AdaptiveDifficultyEngine.sampledDifficulty(1.0, Difficulty.MEDIUM, rng) }.eachCount()
        assertEquals(0.70, counts[Difficulty.MEDIUM]!! / n.toDouble(), 0.02)
        assertEquals(0.20, counts[Difficulty.HARD]!! / n.toDouble(), 0.02)
        assertEquals(0.10, counts[Difficulty.EASY]!! / n.toDouble(), 0.02)
        // Struggling (below the anchor): 10% harder, 30% easier.
        val low = (1..n).groupingBy { AdaptiveDifficultyEngine.sampledDifficulty(0.9, Difficulty.HARD, rng) }.eachCount()
        assertEquals(0.10, low[Difficulty.HARD]!! / n.toDouble(), 0.02)
        assertEquals(0.30, low[Difficulty.EASY]!! / n.toDouble(), 0.02)
    }

    // MARK: QuestionMemory

    @Test fun noRepeatWithinASessionUntilThePoolIsExhausted() {
        val prefs = MemoryContentPrefs()
        val m = QuestionMemory(prefs, "p1")
        val pool = (1..40).map { item(it) }
        val rng = Random(11)
        val seen = (1..40).map { m.pickFresh(pool, Topic.LOGIC, Difficulty.MEDIUM, rng)!!.key }
        assertEquals(40, seen.toSet().size)
        // The cross-session window holds 85% of the pool.
        assertEquals(QuestionMemory.windowFor(40), m.recentKeys(Topic.LOGIC).size)
        assertEquals(34, QuestionMemory.windowFor(40))
        assertEquals(5, QuestionMemory.windowFor(3))
    }

    @Test fun recencyWindowSurvivesANewSessionAndAnotherInstance() {
        val prefs = MemoryContentPrefs()
        val pool = (1..20).map { item(it) }
        val first = QuestionMemory(prefs, "p1")
        val rng = Random(4)
        val served = (1..10).map { first.pickFresh(pool, Topic.SCIENCE, rng)!!.key }.toSet()
        val again = QuestionMemory(prefs, "p1")   // relaunch: memory comes back from prefs
        again.beginSession()
        val next = (1..10).map { again.pickFresh(pool, Topic.SCIENCE, rng)!!.key }.toSet()
        assertTrue("fresh items first after relaunch", next.intersect(served).isEmpty())
        // Another profile has its own memory.
        assertTrue(QuestionMemory(prefs, "p2").recentKeys(Topic.SCIENCE).isEmpty())
    }

    @Test fun tierPreferenceFallsBackToNeighbours() {
        val m = QuestionMemory(MemoryContentPrefs(), "p")
        val pool = listOf(item(1, Difficulty.EASY), item(2, Difficulty.MEDIUM), item(3, Difficulty.HARD))
        val rng = Random(1)
        assertEquals("q3", m.pickFresh(pool, Topic.MONEY, Difficulty.HARD, rng)!!.prompt)
        assertEquals("q2", m.pickFresh(pool, Topic.MONEY, Difficulty.HARD, rng)!!.prompt)   // hard used → medium
        assertEquals("q1", m.pickFresh(pool, Topic.MONEY, Difficulty.HARD, rng)!!.prompt)   // then easy
        assertTrue(m.pickFresh(pool, Topic.MONEY, Difficulty.HARD, rng) != null)          // all served → lenient repeat
        assertNull(m.pickFresh(emptyList(), Topic.MONEY, Difficulty.HARD, rng))
    }

    @Test fun reAskAllowsAWrongQuestionBack() {
        val m = QuestionMemory(MemoryContentPrefs(), "p")
        m.markServedThisSession("x|y"); assertTrue(m.wasServedThisSession("x|y"))
        m.allowReask("x|y"); assertFalse(m.wasServedThisSession("x|y"))
    }

    // MARK: generator

    @Test fun gradePoolIsToppedUpToThirtyFromTheNearestGrades() {
        val bank = (1..10).map { item(it, lo = 3, hi = 3) } + (11..40).map { item(it, lo = 4, hi = 4) } + (41..80).map { item(it, lo = 8, hi = 8) }
        val pool = QuestionGenerator.gradePool(bank, 3, Random(1))
        assertEquals(30, pool.size)
        assertTrue(pool.take(10).all { it.inGrade(3) })
        assertTrue(pool.drop(10).all { it.inGrade(4) })
        val deep = (1..35).map { item(it, lo = 2, hi = 2) }
        assertEquals(35, QuestionGenerator.gradePool(deep, 2, Random(1)).size)
    }

    @Test fun everyBankTopicServesItsOwnGradeWindowWhenDeep() {
        for (lang in AppLanguage.entries) for (t in Topic.entries) {
            val bank = QuestionBanks.bank(t, lang) ?: continue
            if (bank.isEmpty()) continue
            for (g in 0..8) {
                val pool = QuestionGenerator.effectivePool(t, g, lang, Random(g))
                assertTrue("$lang/$t/g$g", pool.size >= minOf(30, bank.size))
            }
        }
    }

    @Test fun bonusMathIsTwoStepFromGradeThree() {
        val c = child(5)
        repeat(50) {
            val q = QuestionSource.bonus(c, Topic.MATH)
            assertTrue(q.correctIndex in q.options.indices)
            assertEquals(4, q.options.toSet().size)
        }
    }

    @Test fun smartFeedOnlyServesPlayableTopics() {
        val c = child(3).copy(enabledTopics = setOf(Topic.MATH, Topic.SCIENCE, Topic.HISTORY))
        val s = QuestionSource.session(c, ContentMode.SmartFeed)
        repeat(30) { assertTrue(s.next().topic in setOf(Topic.MATH, Topic.SCIENCE, Topic.HISTORY)) }
        // Never three in a row of the same topic.
        val h = s.topicHistory
        assertTrue(h.windowed(3).none { it.toSet().size == 1 })
    }

    @Test fun packsNeedAccessAndTheCloudSwitch() {
        val c = child(3).copy(packAccess = setOf("soccer"))
        assertFalse(c.allows(Topic.SOCCER, livePacks = emptySet()))
        assertTrue(c.allows(Topic.SOCCER, livePacks = setOf("soccer")))
        assertFalse(c.copy(disabledPacks = setOf("soccer")).allows(Topic.SOCCER, livePacks = setOf("soccer")))
        assertFalse(c.allows(Topic.SPACE, livePacks = setOf("space")))
    }

    // MARK: cloud bank

    @Test fun cloudItemsAreValidatedApprovedOnlyAndMergedWithoutDuplicates() {
        fun row(id: String, prompt: String, answer: String, vararg extra: Pair<String, Any?>) =
            mapOf("id" to id, "prompt" to prompt, "correctAnswer" to answer, "distractors" to listOf("d1", "d2", "d3"),
                "gradeLo" to 2L, "gradeHi" to 4.0, "tier" to "hard") + extra
        assertNull(RemoteQuestionBank.itemFrom(row("x", "p", "a", "status" to "draft"), "science"))
        assertNull(RemoteQuestionBank.itemFrom(mapOf("id" to "x"), "science"))
        val ok = RemoteQuestionBank.itemFrom(row("c1", "שְׁאֵלָה חֲדָשָׁה?", "תְּשׁוּבָה"), "science")!!
        assertEquals(2, ok.gradeLo); assertEquals(4, ok.gradeHi)
        assertFalse(RemoteQuestionBank.isPlayable(ok.copy(distractors = listOf("תְּשׁוּבָה", "b", "c"))))
        assertFalse(RemoteQuestionBank.isPlayable(ok.copy(distractors = listOf("b", "b", "c"))))
        assertFalse(RemoteQuestionBank.isPlayable(ok.copy(gradeHi = 9)))
        val builtIn = QuestionBanks.bank(Topic.SCIENCE, AppLanguage.HE)!!
        val dup = RemoteQuestionBank.itemFrom(row("c2", builtIn[0].prompt, builtIn[0].correctAnswer), "science")!!
        val english = RemoteQuestionBank.itemFrom(row("c3", "New?", "Yes", "lang" to "en"), "science")!!
        RemoteQuestionBank.replaceForTest(mapOf("science" to listOf(ok, dup, english)))
        val merged = QuestionBanks.bank(Topic.SCIENCE, AppLanguage.HE)!!
        assertEquals(builtIn.size + 1, merged.size)
        assertEquals(Difficulty.HARD, merged.last().difficulty)
        assertEquals(QuestionBanks.bank(Topic.SCIENCE, AppLanguage.EN)!!.last().prompt, "New?")
        RemoteQuestionBank.replaceForTest(emptyMap())
    }

    // MARK: strings

    /** Every tr("…") key in the content package exists in the exported iOS catalog. */
    @Test fun everyTrKeyIsAnIosCatalogKey() {
        val dir = listOf("src/main/java/com/rani/tofy/kid/content", "app/src/main/java/com/rani/tofy/kid/content").map(::File).first { it.exists() }
        val catalog = kotlinx.serialization.json.Json.parseToJsonElement(File(ContentTestSupport.assetsDir, "i18n/en.json").readText()) as kotlinx.serialization.json.JsonObject
        val call = Regex("""(?<![\w.])tr\("((?:[^"\\]|\\.)*)"""")
        val keys = dir.listFiles()!!.filter { it.name.endsWith(".kt") }.flatMap { f -> call.findAll(f.readText()).map { it.groupValues[1] }.toList() }
            .map { it.replace("\\\"", "\"").replace("\\n", "\n").replace("\\$", "$") }
        assertTrue(keys.size > 60)
        val missing = keys.filter { it !in catalog }.distinct()
        assertTrue("missing catalog keys: $missing", missing.isEmpty())
    }
}

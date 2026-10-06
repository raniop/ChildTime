package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.kid.content.ContentTestSupport
import com.rani.tofy.kid.content.Question
import com.rani.tofy.ui.child.Topic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** MiniGameGrading.swift (bands, the game × grade table, ladders) + which games a world / surprise round offers. */
class MiniGameGradingTest {
    private lateinit var src: FakeSource

    @Before fun setUp() {
        ContentTestSupport.install()
        GameTestSupport.install(grade = 3)
        src = GameEnv.source as FakeSource
    }

    @Test fun bands() {
        assertEquals(MiniGameBand.PRE_READER, MiniGameBand.of(0)); assertEquals(MiniGameBand.PRE_READER, MiniGameBand.of(-1))
        assertEquals(MiniGameBand.LOWER, MiniGameBand.of(2)); assertEquals(MiniGameBand.MIDDLE, MiniGameBand.of(3))
        assertEquals(MiniGameBand.UPPER, MiniGameBand.of(6)); assertEquals(MiniGameBand.TOP, MiniGameBand.of(8))
    }

    @Test fun preReaderGetsExactlyTheFiveTextFreeGames() {
        assertEquals(listOf(MiniGameKind.BALLOON, MiniGameKind.SORT, MiniGameKind.PAIRS, MiniGameKind.PATTERN, MiniGameKind.CRUSH), MiniGameGradeFit.roster(0))
        assertFalse(MiniGameGradeFit.offered(MiniGameKind.WORD, 0))
        assertTrue(MiniGameKind.CRUSH.hasPreReaderForm); assertFalse(MiniGameKind.VAULT.hasPreReaderForm)
    }

    @Test fun theGradeTable() {
        // 🔢 2048 from ג׳, 🔐 vault from ב׳.
        assertEquals((3..8).toList(), MiniGameGradeFit.grades(MiniGameKind.GAME2048))
        assertEquals((2..8).toList(), MiniGameGradeFit.grades(MiniGameKind.VAULT))
        // 🧩 Hebrew is the mother tongue for an Israeli child: to ח׳. English (second language): ג׳–ו׳.
        assertEquals((1..8).toList(), MiniGameGradeFit.grades(MiniGameKind.WORD, SpellScript.HEBREW))
        assertEquals((3..6).toList(), MiniGameGradeFit.grades(MiniGameKind.WORD, SpellScript.ENGLISH))
        assertEquals((3..8).toList(), MiniGameGradeFit.grades(MiniGameKind.WORD_SEARCH, SpellScript.ENGLISH))
        // 🧠 the alphabet pattern is a freebie after ה׳.
        assertEquals((0..5).toList(), MiniGameGradeFit.grades(MiniGameKind.PATTERN, topic = Topic.HEBREW))   // גן plays its picture form
        // An American child: English IS the mother tongue.
        src.lang = AppLanguage.EN
        assertEquals((1..8).toList(), MiniGameGradeFit.grades(MiniGameKind.WORD, SpellScript.ENGLISH))
        assertFalse(SpellScript.HEBREW.isMotherTongue)
        src.lang = AppLanguage.RU
        assertTrue(SpellScript.HEBREW.isMotherTongue); assertTrue(SpellScript.CYRILLIC.isMotherTongue)
    }

    @Test fun wordSearchShape() {
        assertEquals(6, WordSearchShape.size(1, SpellScript.HEBREW, false))
        assertEquals(9, WordSearchShape.size(8, SpellScript.HEBREW, false))
        assertEquals(10, WordSearchShape.size(6, SpellScript.HEBREW, true))
        assertEquals(7, WordSearchShape.size(6, SpellScript.ENGLISH, false))
        assertTrue(WordSearchShape.diagonals(3, SpellScript.HEBREW)); assertFalse(WordSearchShape.diagonals(3, SpellScript.ENGLISH))
        assertTrue(WordSearchShape.backwards(5, SpellScript.HEBREW)); assertFalse(WordSearchShape.backwards(8, SpellScript.ENGLISH))
    }

    @Test fun hebrewLadderNeverStepsDownWhenTheRungIsFull() {
        repeat(20) {
            val upper = HebrewLadder.words(null, 6, 10, 5).map { it.word }.toSet()
            val upperRung = HebrewLadder.general.filter { it.band == MiniGameBand.UPPER }.map { it.word }.toSet()
            assertTrue(upper.isNotEmpty() && upper.all { it in upperRung })   // a ה׳ child never meets כלב
        }
        // A short grid steps down for filler, never below א׳–ב׳.
        val small = HebrewLadder.words(Topic.SOCCER, 8, 6, 5)
        assertTrue(small.size >= 5 && small.all { it.word.length <= 6 })
    }

    @Test fun englishLadderStaysGentleForASecondLanguage() {
        val w = EnglishLadder.words(8, 8, 5, motherTongue = false).map { it.word }
        val gentle = (EnglishLadder.firstWords + EnglishLadder.everyday).map { it.word }.toSet()
        assertTrue(w.all { it in gentle })
        val native = EnglishLadder.words(8, 12, 5, motherTongue = true).map { it.word }.toSet()
        assertTrue(native.any { n -> EnglishLadder.nativeTop.any { it.word == n } })
    }

    @Test fun numericOffsetsGrowWithTheBand() {
        assertEquals(listOf(-2, -1, 1, 2), MiniGameDistractors.numericOffsets(30, 1))
        assertTrue(-60 in MiniGameDistractors.numericOffsets(30, 8))   // the sign error, from ז׳
        assertNull(MiniGameDistractors.pick("x", emptyList(), 5))
    }

    // ── which games a world carries ─────────────────────────────────────────
    @Test fun mathWorldLeadsWithCrush() {
        src.grade = 4
        val g = WorldGameFit.games(Topic.MATH, 4)
        assertEquals(MiniGameKind.CRUSH, g.first())
        assertTrue(MiniGameKind.GAME2048 in g && MiniGameKind.VAULT in g && MiniGameKind.BALANCE in g)
        assertFalse(MiniGameKind.WORD in g)
    }

    @Test fun preReaderWorldsAllShowTheGanRoster() {
        src.grade = 0
        assertEquals(MiniGameGradeFit.preReaderRoster, WorldGameFit.games(Topic.SCIENCE, 0))
    }

    @Test fun arenaMixes() {
        assertEquals(listOf(MiniGameKind.LIGHTNING, MiniGameKind.PAIRS, MiniGameKind.BALLOON), WorldGameFit.games(null, 3))
    }

    @Test fun englishWorldSpells() {
        val g = WorldGameFit.games(Topic.ENGLISH, 3)
        assertEquals(MiniGameKind.WORD, g.first())
    }

    @Test fun gameItemsAreShortAndSelfContained() {
        val items = GameContent.items(Topic.ANIMALS, 3, maxPrompt = 60, maxAnswer = 24, standalone = true)
        assertTrue(items.isNotEmpty())
        items.forEach { i ->
            assertTrue(Question.stripNiqqud(i.prompt).graphemes() <= 60)
            assertTrue((listOf(i.answer) + i.distractors).all { Question.stripNiqqud(it).graphemes() <= 24 })
            assertFalse(GameContent.refersToOptions(i.prompt))
            assertTrue(i.distractors.size in 2..3)
        }
        assertEquals(GameContent.distinctAnswers(items).size, GameContent.distinctAnswers(items).map { Question.stripNiqqud(it.answer) }.toSet().size)
    }

    @Test fun spellableTakesOneWordInOneScript() {
        assertEquals("כלב" to SpellScript.HEBREW, GameContent.spellable("כֶּלֶב"))
        assertEquals("Paris" to SpellScript.ENGLISH, GameContent.spellable("Paris"))
        assertNull(GameContent.spellable("New York")); assertNull(GameContent.spellable("7")); assertNull(GameContent.spellable("א"))
    }

    // ── ⚡ the surprise round ────────────────────────────────────────────────
    @Test fun surpriseTriggersOnlyWhenTheRunnerAllows() {
        fun t(i: Int = 13, at: Int = 13, n: Int = 0, arena: Boolean = false, pre: Boolean = false, rq: Boolean = true,
              passage: Boolean = false, bonus: Boolean = false, games: Boolean = true) =
            SurpriseRound.shouldTrigger(i, at, n, arena, pre, rq, passage, bonus, games)
        assertTrue(t())
        assertFalse(t(i = 12)); assertFalse(t(n = 2)); assertFalse(t(arena = true)); assertFalse(t(pre = true))
        assertFalse(t(rq = false)); assertFalse(t(passage = true)); assertFalse(t(bonus = true)); assertFalse(t(games = false))
        repeat(50) { assertTrue(SurpriseRound.nextGap() in 12..15) }
    }

    @Test fun surprisePlanNeverRepeatsTheLastWorldOrGame() {
        src.grade = 4
        var last: SurprisePlan? = null
        repeat(15) {
            val p = SurpriseRound.plan(4, Topic.MATH)
            assertNotNull("eligible: ${SurpriseRound.eligibleTopics(4)}", p); p!!
            assertTrue(p.topic in SurpriseRound.interestTopics)
            assertTrue(p.game in SurpriseRound.games(p.topic, 4, Topic.MATH))
            last?.let { l -> if (SurpriseRound.eligibleTopics(4).size > 1) assertTrue(p.topic != l.topic) }
            last = p
        }
    }

    @Test fun surpriseGamesFitTheContext() {
        val inMoney = SurpriseRound.games(Topic.SOCCER, 4, Topic.MONEY)
        assertTrue(MiniGameKind.GROCERY in inMoney); assertFalse(MiniGameKind.CRUSH in inMoney)
        val inFeed = SurpriseRound.games(Topic.SOCCER, 4, null)
        assertTrue(MiniGameKind.CRUSH in inFeed && MiniGameKind.GAME2048 in inFeed)
        assertEquals(MiniGameGradeFit.preReaderRoster, SurpriseRound.games(Topic.SEA, 0, null))
    }
}

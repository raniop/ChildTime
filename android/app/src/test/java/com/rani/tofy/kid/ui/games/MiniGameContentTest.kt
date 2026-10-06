package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.ui.child.Topic
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import kotlin.math.abs

/** The computed content: every printed fact is true, every board solvable, every vault provable. */
class MiniGameContentTest {
    @Before fun setUp() { GameTestSupport.install() }

    // ── 🧮 MathFacts ─────────────────────────────────────────────────────────
    @Test fun everyMathFactIsTrue() {
        for (g in 1..8) repeat(300) {
            val f = MathFacts.fact(g)
            assertEquals("grade $g: ${f.expression}", f.answer.toDouble(), Arith.eval(f.expression), 1e-9)
        }
    }

    @Test fun firstGradeStaysWithinTwenty() {
        repeat(300) { val f = MathFacts.fact(1); assertTrue(f.answer in 0..20) }
    }

    @Test fun negativesShowARealMinus() {
        assertEquals("−4", MathFacts.show(-4)); assertEquals("7", MathFacts.show(7))
    }

    // ── ⚡ Lightning ─────────────────────────────────────────────────────────
    @Test fun lightningMathCardsTellTheTruthAboutThemselves() {
        for (g in 1..8) {
            val seen = HashSet<String>()
            repeat(80) {
                val s = LightningStatements.math(g, seen)
                val (lhs, rhs) = s.claim.split("=").map { it.trim() }
                val right = abs(Arith.eval(lhs) - Arith.eval(rhs)) < 1e-9
                assertEquals("grade $g: ${s.claim}", right, s.isTrue)
                if (g < 7 && !s.isTrue) assertFalse("no negative shown below ז׳: ${s.claim}", rhs.contains("−") && !lhs.contains("−"))
            }
        }
    }

    // ── 🧱 Crush ─────────────────────────────────────────────────────────────
    @Test fun crushRulesArithmetic() {
        val sum = CrushRules(CrushMode.SUM, 10, (1..9).toList())
        assertTrue(sum.hits(listOf(3, 7))); assertFalse(sum.hits(listOf(10)))
        assertTrue(sum.canStillReach(listOf(3, 4))); assertFalse(sum.canStillReach(listOf(6, 5)))
        assertEquals(7, sum.complement(3))
        assertEquals("3 + 7", sum.expression(listOf(3, 7)))
        val prod = CrushRules(CrushMode.PRODUCT, 24, listOf(2, 3, 4, 6))
        assertTrue(prod.hits(listOf(4, 6))); assertTrue(prod.canStillReach(listOf(2, 3)))
        assertFalse(prod.canStillReach(listOf(7))); assertEquals(6, prod.complement(4))
        val frac = CrushRules(CrushMode.FRACTION, 12, listOf(2, 3, 4, 6, 8, 9, 10))
        assertEquals("½", frac.display(6)); assertEquals("1", frac.targetText); assertTrue(frac.hits(listOf(4, 8)))
        val signed = CrushRules(CrushMode.SUM, -6, (-12..-1).toList() + (1..12).toList())
        assertTrue(signed.signed); assertEquals("8 + (−5)", signed.expression(listOf(8, -5)))
        assertTrue(signed.canStillReach(listOf(12, 12, 12))); assertFalse(signed.canStillReach(listOf(1, 1, 1, 1)))
    }

    @Test fun everyCrushBoardIsSolvable() {
        data class B(val id: Long, val v: Int)
        for (g in 1..8) repeat(60) {
            val rules = CrushBoards.rules(g, Topic.MATH)
            assertTrue("grade $g has a value set", rules.values.isNotEmpty())
            val cols = List(4) { List(3) { B(nextId(), CrushBoards.randomValue(rules)) } }
            val fixed = CrushBoards.ensureSolvable(cols, cols.flatten().map { it.id }.toSet(), rules, { it.id }, { it.v }, { _, v -> B(nextId(), v) })
            assertTrue("grade $g ${rules.mode} → ${fixed.flatten().map { it.v }}", CrushBoards.isSolvable(fixed.flatten().map { it.v }, rules))
            assertEquals(12, fixed.flatten().size)
        }
    }

    // ── 🔐 Vault ─────────────────────────────────────────────────────────────
    @Test fun everyVaultIsProvablyUnique() {
        for (g in 1..8) repeat(6) {
            val r = VaultGen.round(g)
            assertEquals(VaultGen.digits(g), r.code.size)
            assertEquals(r.code.size, r.code.toSet().size)
            assertTrue(r.code.all { it in 1..9 })
            assertTrue("grade $g", VaultGen.verify(r))
            assertTrue(r.needed in 1..r.clues.size)
            assertTrue(r.clues.all { it.text.isNotBlank() })
        }
        // ⚡ the surprise round's short deduction
        repeat(10) { val r = VaultGen.round(5, 3, 4); assertEquals(3, r.code.size); assertTrue(VaultGen.verify(r)) }
    }

    @Test fun upperGradesNeverHandDigitsOver() {
        repeat(10) { r -> VaultGen.round(6).clues.forEach { assertFalse(r.toString(), it.kind is VaultClue.Kind.DigitIs) } }
    }

    @Test fun vaultCluesMeanWhatTheySay() {
        val code = listOf(3, 8, 5)
        assertTrue(VaultClue(VaultClue.Kind.PairSum(0, 2, 8)).holds(code))
        assertTrue(VaultClue(VaultClue.Kind.Bigger(1, 0)).holds(code))
        assertTrue(VaultClue(VaultClue.Kind.PrimeCount(2)).holds(code))
        assertTrue(VaultClue(VaultClue.Kind.EvenCount(1)).holds(code))
        assertFalse(VaultClue(VaultClue.Kind.PairTimes(0, 1, 2)).holds(code))
        assertEquals(504, VaultGen.allCodes(3).size); assertEquals(3024, VaultGen.allCodes(4).size)
    }

    @Test fun dialQuestionsAnswerTheirDigit() {
        for (g in 1..8) repeat(100) {
            val d = (1..9).random()
            val e = VaultGen.expression(d, g)
            assertEquals("grade $g: $e", d.toDouble(), Arith.eval(e), 1e-9)
        }
        val q = VaultGen.dialQuestion(4)
        assertTrue(q.answer in q.shuffledOptions()); assertEquals(3, q.distractors.size)
    }

    // ── ⚖️ Balance ───────────────────────────────────────────────────────────
    @Test fun everyBalanceLevelsAtItsAnswer() {
        for (g in 1..8) repeat(120) {
            val p = BalanceGen.make(g, Topic.MATH)
            val v = assertNotNull(p.value(p.answer)).let { p.value(p.answer)!! }
            val (l, r) = p.weigh(v)
            assertEquals("grade $g: ${p.left} | ${p.right} with ${p.answer}", l, r, 1e-6)
            assertEquals(0.0, BalanceGen.tilt(p, p.answer), 0.0)
            assertTrue(p.answer in p.options)
            assertEquals(p.options.size, p.options.toSet().size)
            p.options.filter { it != p.answer }.forEach { o -> assertTrue("$o tilts", BalanceGen.tilt(p, o) != 0.0) }
        }
    }

    @Test fun compareBalanceUsesTheAnswersWeight() {
        val item = GameItem("כַּמָּה רַגְלַיִם לְעַכָּבִישׁ?", "8", listOf("6", "4", "10"), Topic.ANIMALS)
        val p = BalanceGen.compare(item, 2)!!
        assertEquals(0.0, BalanceGen.tilt(p, "8"), 0.0)
        assertTrue(BalanceGen.tilt(p, "6") > 0)   // too light → the 🎁 (right) pan goes down
        assertTrue(BalanceGen.tilt(p, "10") < 0)
    }

    // ── 🧠 Pattern ───────────────────────────────────────────────────────────
    @Test fun patternsHaveOneHoleAndTheAnswerOnOffer() {
        val topics = listOf(null, Topic.MATH, Topic.LOGIC, Topic.ENGLISH, Topic.HEBREW, Topic.SOCCER)
        for (g in 0..8) for (t in topics) repeat(20) {
            val r = PatternGen.make(t, g)
            assertEquals(1, r.cells.count { it == "?" })
            assertTrue("grade $g $t ${r.cells} ${r.options}", r.answer in r.options)
            assertEquals(r.options.size, r.options.toSet().size)
            if (g == 0) { assertEquals(5, r.cells.size); assertEquals(3, r.options.size) }
        }
    }

    // ── 🔢 2048 ──────────────────────────────────────────────────────────────
    @Test fun slideMergesOncePerTile() {
        val row = listOf(2, 2, 2, 2).mapIndexed { c, v -> Tile2048(nextId(), v, 0, c) }
        val s = Board2048.slide(row, Move2048.LEFT)
        assertEquals(listOf(4, 4), s.tiles.sortedBy { it.c }.map { it.value })
        assertEquals(listOf(0, 1), s.tiles.sortedBy { it.c }.map { it.c })
        assertEquals(8, s.points); assertTrue(s.moved); assertEquals(2, s.consumed.size)
        val right = Board2048.slide(listOf(Tile2048(1, 2, 0, 0), Tile2048(2, 4, 0, 1)), Move2048.RIGHT)
        assertEquals(setOf(2 to 2, 4 to 3), right.tiles.map { it.value to it.c }.toSet()); assertEquals(0, right.points)
        assertFalse(Board2048.slide(listOf(Tile2048(1, 2, 3, 0)), Move2048.DOWN).moved)
    }

    @Test fun canMoveSeesAFullStuckBoard() {
        val full = (0 until 16).map { i -> Tile2048(i.toLong(), if (i % 2 == (i / 4) % 2) 2 else 4, i / 4, i % 4) }
        assertFalse(Board2048.canMove(full))
        assertTrue(Board2048.canMove(full.drop(1)))
    }

    // ── 🛒 Grocery ───────────────────────────────────────────────────────────
    @Test fun moneyParsesAndPrints() {
        assertEquals(450, GroceryGen.cents("4.5")); assertEquals(450, GroceryGen.cents("4.50"))
        assertEquals(1200, GroceryGen.cents("12")); assertEquals(5, GroceryGen.cents(".05"))
        assertEquals(null, GroceryGen.cents("1.234")); assertEquals(null, GroceryGen.cents(""))
        assertEquals("4.50 ₪", GroceryGen.money(450)); assertEquals("7 ₪", GroceryGen.money(700))
        (GameEnv.source as FakeSource).lang = AppLanguage.EN
        assertEquals("$4.50", GroceryGen.money(450))
    }

    @Test fun everyTripFitsItsBudgetWithChangeToWorkOut() {
        for (g in 1..8) repeat(40) {
            val t = GroceryGen.trip(g)
            val total = t.list.sumOf { it.finalPrice }
            assertTrue("grade $g budget ${t.budget} total $total", t.budget > total)
            assertTrue(t.list.all { l -> t.shelf.any { it.id == l.id } })
            assertEquals(if (g <= 1) 2 else if (g >= 5) 4 else 3, t.list.size)
            assertTrue(t.shelf.size >= 5)
            if (g >= 7) assertTrue(t.list.count { it.discount > 0 } >= 2)
            t.list.filter { it.discount > 0 }.forEach { assertEquals(0, it.price * (100 - it.discount) % 100) }
        }
    }

    // ── 🎈 Balloons / 🧺 Sort / 🔗 Pairs ─────────────────────────────────────
    @Test fun numberBalloonsFollowTheirRule() {
        for (g in 1..8) repeat(30) {
            val s = BalloonSets.numbers(g)
            assertTrue(s.targets.isNotEmpty()); assertTrue(s.others.isNotEmpty())
            val t = s.targets.map { it.label }.toSet()
            assertTrue(s.others.none { it.label in t })
        }
        assertTrue(BalloonSets.isPrime(97)); assertFalse(BalloonSets.isPrime(91)); assertFalse(BalloonSets.isPrime(1))
    }

    @Test fun upperBandBalloonsAreTheGrownUpRule() {
        assertEquals(4, BalloonSets.make(Topic.SEA, 6).targets.size)        // sea MAMMALS
        assertEquals(8, BalloonSets.make(Topic.SEA, 3).targets.size)
        assertTrue(BalloonSets.hasCategory(Topic.FLAGS, 2)); assertFalse(BalloonSets.hasCategory(Topic.FLAGS, 1))
    }

    @Test fun sortRoundCoversEveryBasket() {
        for (t in listOf(Topic.MATH, Topic.ENGLISH, Topic.HEBREW, Topic.ANIMALS, Topic.SCIENCE, Topic.MONEY, Topic.FOOD, Topic.MUSIC))
            for (g in 1..8) {
                val set = SortSets.make(t, g)!!
                val round = SortSets.round(set)
                assertTrue(round.size <= SortSets.ROUND_ITEMS)
                assertEquals("$t grade $g", set.baskets.indices.toSet(), round.map { it.basket }.toSet())
                assertTrue(set.items.all { it.basket in set.baskets.indices })
            }
        assertEquals(null, SortSets.make(Topic.HISTORY, 3))
    }

    @Test fun mathPairsHaveDistinctAnswers() {
        for (g in 1..8) {
            val p = MatchPairsSource.mathPairs(6, g)
            assertEquals(6, p.size); assertEquals(6, p.map { it.right }.toSet().size)
        }
        val caps = MatchPairsSource.capitalPairs(5, 2)
        assertEquals(5, caps.size)
    }

    // ── 🔤 Word search ───────────────────────────────────────────────────────
    @Test fun wordSearchHidesEveryWordWhereItSays() {
        for (g in 1..8) for (script in listOf(SpellScript.HEBREW, SpellScript.ENGLISH)) repeat(5) {
            val size = WordSearchShape.size(g, script, false)
            val b = WordSearch.make(null, script, g, size)
            assertTrue("grade $g $script", b.words.size in 1..WordSearch.WORD_COUNT)
            b.words.forEach { w ->
                assertEquals(w.word, w.cells.joinToString("") { b.letters[it.r][it.c].toString() })
                // In a straight line.
                val dr = w.cells[1].r - w.cells[0].r; val dc = w.cells[1].c - w.cells[0].c
                w.cells.zipWithNext().forEach { (a, c) -> assertEquals(dr, c.r - a.r); assertEquals(dc, c.c - a.c) }
                if (!b.diagonals) assertTrue(dr == 0 || dc == 0)
                if (!b.backwards) assertTrue(dr >= 0 && dc >= 0)
            }
            assertEquals(size, b.letters.size); assertTrue(b.letters.all { it.size == size && it.none { c -> c == ' ' } })
        }
    }

    @Test fun dragSnapsToAStraightLine() {
        val s = GridCell(2, 2)
        assertEquals(listOf(GridCell(2, 2), GridCell(2, 3), GridCell(2, 4)), WordSearch.snappedLine(s, GridCell(3, 4), 6, diagonals = false))
        assertEquals(listOf(GridCell(2, 2), GridCell(3, 3), GridCell(4, 4)), WordSearch.snappedLine(s, GridCell(4, 3), 6, diagonals = true))
        assertEquals(listOf(s), WordSearch.snappedLine(s, s, 6, false))
    }

    // ── 👶 גן ────────────────────────────────────────────────────────────────
    @Test fun preReaderCountingHasExactlyOneRightCard() {
        repeat(200) {
            val c = PreReaderGames.collecting()
            assertEquals(PreReaderGames.COUNTING_CARDS, c.cards.size)
            assertEquals(1, c.cards.count { it == c.target })
            assertTrue(c.target in 2..5)
            assertEquals(c.target, c.cue.icons.size)
        }
    }

    @Test fun preReaderBasketsAreThreeAndThree() {
        repeat(30) {
            val r = PreReaderGames.baskets()
            val items = PreReaderGames.basketRound(r.set)
            assertEquals(6, items.size); assertEquals(3, items.count { it.basket == 0 })
            assertTrue(items.all { it.label.isEmpty() })   // nothing to read on a גן board
        }
    }

    @Test fun preReaderBalloonsHaveOneRule() {
        repeat(60) {
            val r = PreReaderGames.balloons()
            assertEquals(1, r.set.targets.size)
            assertTrue(r.set.targets.all { it.label.isEmpty() } && r.set.others.all { it.label.isEmpty() })
            assertTrue(r.cue.spoken.isNotBlank())
        }
        assertTrue(PreReaderGames.countPhrase(1, "x").startsWith(PreReaderGames.countWord(2)))
    }
}

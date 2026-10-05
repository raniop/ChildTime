package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlin.random.Random

/** What one generation call needs: the content language, the child's anti-repeat memory, the random source. */
class ContentContext(val lang: AppLanguage, val memory: QuestionMemory, val rng: Random = Random.Default)

/** QuestionGenerator.swift — one question for a topic at a difficulty and grade. */
object QuestionGenerator {
    /**
     * `grade` (effectiveGrade) aligns content to משרד החינוך: math routes to the
     * curriculum engine, banks serve grade-tagged items. null → legacy behavior
     * (e.g. the live quiz, where players span families).
     */
    fun generate(topic: Topic, difficulty: Difficulty, grade: Int?, ctx: ContentContext): Question = when (topic) {
        Topic.MATH ->
            if (grade != null && grade >= 1) CurriculumMath.generate(grade, difficulty, ctx.lang, ctx.rng)
            else makeMath(difficulty, ctx.rng)
        Topic.READING -> ReadingContent.singleQuestion(difficulty, grade, ctx.lang, ctx.memory, ctx.rng)
        else -> makeFromBank(topic, difficulty, grade, ctx)
    }

    /**
     * 💫 A BONUS question — the dedicated really-hard pool (Hebrew only, like
     * iOS); math is a two-step expression. Falls back to a regular hard question
     * at the child's grade when the pool is empty/exhausted.
     */
    fun generateBonus(topic: Topic, grade: Int?, ctx: ContentContext): Question {
        if (topic == Topic.MATH) return makeBonusMath(grade, ctx)
        var pool = if (ctx.lang == AppLanguage.HE) ContentAssets.bonus()[topic.raw] ?: emptyList() else emptyList()
        if (grade != null) {
            val inWindow = pool.filter { it.inGrade(grade) }
            pool = if (inWindow.size >= 5) inWindow
            else {
                // Small pools (~10): the nearest windows, so a 1st grader doesn't get a ה׳–ו׳ bonus.
                // shuffled() first so equal-distance ties don't always pick declaration order.
                pool.shuffled(ctx.rng).sortedBy { it.gradeDistance(grade) }.take(minOf(6, pool.size))
            }
        }
        val item = ctx.memory.pickFresh(pool, topic, Difficulty.HARD, ctx.rng)
            ?: return generate(topic, Difficulty.HARD, grade, ctx)
        return item.toQuestion(topic, ctx.rng)
    }

    /** Bonus math: a TWO-step expression — a real jump over the regular hard tier. */
    private fun makeBonusMath(grade: Int?, ctx: ContentContext): Question {
        val rng = ctx.rng
        // Young kids get a fair jump: one grade up at hard, not the universal "7×6+13".
        if (grade != null && grade <= 2) {
            return CurriculumMath.generate(minOf(CurriculumMath.TOP_GRADE, grade + 1), Difficulty.HARD, ctx.lang, rng)
        }
        val a = rng.nextInt(3, 13); val b = rng.nextInt(3, 13)
        val (prompt, answer) = when (rng.nextInt(4)) {
            0 -> { val c = rng.nextInt(5, 31); "$a × $b + $c = ?" to a * b + c }
            1 -> { val c = rng.nextInt(1, a * b); "$a × $b − $c = ?" to a * b - c }
            2 -> { val x = rng.nextInt(120, 481); val y = rng.nextInt(120, 481); "$x + $y = ?" to x + y }
            else -> { val x = rng.nextInt(250, 901); val y = rng.nextInt(100, 250); "$x − $y = ?" to x - y }
        }
        return makeNumericQuestion(prompt, answer, rng)
    }

    // MARK: - Legacy math (no grade): +/− and ×/÷

    private fun makeMath(d: Difficulty, rng: Random): Question {
        val useMulDiv = when (d) {
            Difficulty.EASY -> false
            Difficulty.MEDIUM -> rng.nextDouble() < 0.4
            Difficulty.HARD -> rng.nextBoolean()
        }
        return if (useMulDiv) makeMulDiv(d, rng) else makeAddSub(d, rng)
    }

    private fun makeAddSub(d: Difficulty, rng: Random): Question {
        val max = when (d) { Difficulty.EASY -> 10; Difficulty.MEDIUM -> 20; Difficulty.HARD -> 100 }
        val isAdd = rng.nextBoolean()
        val a = rng.nextInt(1, max + 1); val b = rng.nextInt(1, max + 1)
        return if (isAdd) makeNumericQuestion("$a + $b = ?", a + b, rng)
        else makeNumericQuestion("${maxOf(a, b)} − ${minOf(a, b)} = ?", maxOf(a, b) - minOf(a, b), rng)
    }

    private fun makeMulDiv(d: Difficulty, rng: Random): Question {
        val factorMax = when (d) { Difficulty.EASY -> 5; Difficulty.MEDIUM -> 10; Difficulty.HARD -> 12 }
        val isMul = rng.nextBoolean()
        val a = rng.nextInt(1, factorMax + 1); val b = rng.nextInt(1, factorMax + 1)
        return if (isMul) makeNumericQuestion("$a × $b = ?", a * b, rng)
        else makeNumericQuestion("${a * b} ÷ $a = ?", b, rng)
    }

    private fun makeNumericQuestion(prompt: String, answer: Int, rng: Random): Question {
        val options = linkedSetOf(answer)
        while (options.size < 4) {
            val delta = rng.nextInt(1, maxOf(3, answer / 2 + 2) + 1)
            val candidate = if (rng.nextBoolean()) answer + delta else answer - delta
            if (candidate >= 0) options.add(candidate)
        }
        val shuffled = options.shuffled(rng)
        return Question(Topic.MATH, prompt, shuffled.map { it.toString() }, shuffled.indexOf(answer).coerceAtLeast(0))
    }

    // MARK: - Bank-based questions

    /**
     * How many items a grade needs before the rotation stops feeling like a loop
     * (QuestionMemory remembers 85%, so a 12-item pool repeats after 10).
     */
    const val MIN_GRADE_POOL = 30

    /**
     * The pool a child of `grade` actually gets: the grade's own items first,
     * TOPPED UP from the nearest grades until the pool is deep enough to rotate.
     */
    fun gradePool(bank: List<BankQuestion>, grade: Int, rng: Random): List<BankQuestion> {
        val tagged = bank.filter { it.inGrade(grade) }
        if (tagged.size >= MIN_GRADE_POOL) return tagged
        // shuffled() first: equal-distance ties otherwise resolve by declaration order.
        val rest = bank.filter { !it.inGrade(grade) }.shuffled(rng).sortedBy { it.gradeDistance(grade) }
        return tagged + rest.take(maxOf(0, MIN_GRADE_POOL - tagged.size))
    }

    /** The pool a grade really gets (QuestionGenerator.effectivePool — also GameContent's source). */
    fun effectivePool(topic: Topic, grade: Int, lang: AppLanguage, rng: Random = Random.Default): List<BankQuestion> =
        gradePool(QuestionBanks.bank(topic, lang) ?: emptyList(), grade, rng)

    /** Below this many items at the asked-for tier, a grade is "thin" there. */
    const val STRETCH_MINIMUM = 12

    /**
     * 🎓 A child doing WELL must stay challenged: when the grade window is thin
     * at the asked tier (under a quarter of the pool), borrow the SAME tier from
     * ONE grade up before pickFresh walks down to easier tiers.
     */
    fun stretchItems(topic: Topic, difficulty: Difficulty, grade: Int, pool: List<BankQuestion>, lang: AppLanguage): List<BankQuestion> {
        if (difficulty == Difficulty.EASY) return emptyList()
        val have = pool.count { it.difficulty == difficulty }
        if (have >= maxOf(STRETCH_MINIMUM, pool.size / 4)) return emptyList()
        val present = pool.mapTo(HashSet()) { it.prompt + "\u001F" + it.correctAnswer }
        return (QuestionBanks.bank(topic, lang) ?: emptyList()).filter {
            it.difficulty == difficulty && it.inGrade(grade + 1) && (it.prompt + "\u001F" + it.correctAnswer) !in present
        }
    }

    private fun makeFromBank(topic: Topic, difficulty: Difficulty, grade: Int?, ctx: ContentContext): Question {
        var bank = QuestionBanks.bank(topic, ctx.lang) ?: emptyList()
        if (grade != null) {
            // 🎓 Serve ONLY the grade's window; sparse grades borrow the CLOSEST grades.
            bank = gradePool(bank, grade, ctx.rng)
            bank = bank + stretchItems(topic, difficulty, grade, bank, ctx.lang)
        }
        val item = ctx.memory.pickFresh(bank, topic, difficulty, ctx.rng)
            ?: return Question(topic, tr("אוֹפְּס... אֵין שְׁאֵלוֹת לַנּוֹשֵׂא הַזֶּה עֲדַיִן"),
                listOf(tr("בְּסֵדֶר"), tr("הַמְשֵׁךְ"), tr("תּוֹדָה"), tr("חֲזוֹר")), 0)
        return item.toQuestion(topic, ctx.rng)
    }
}

/** A bank item as a runner question: answer + distractors, shuffled. */
fun BankQuestion.toQuestion(topic: Topic, rng: Random = Random.Default): Question {
    val all = (listOf(correctAnswer) + distractors).shuffled(rng)
    return Question(topic, prompt, all, all.indexOf(correctAnswer).coerceAtLeast(0), skill = skill)
}

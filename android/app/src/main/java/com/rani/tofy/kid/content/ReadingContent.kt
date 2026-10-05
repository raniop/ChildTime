package com.rani.tofy.kid.content

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlin.math.abs
import kotlin.random.Random

/**
 * 📖 ReadingContent.swift — a passage the child READS, then 2–3 questions about
 * it. The unit is the PASSAGE: the runner serves all of a passage's questions
 * back-to-back, and each Question carries the passage text.
 */
object ReadingContent {
    fun passages(lang: AppLanguage): List<ReadingPassage> = ContentAssets.passages(lang)

    /**
     * The passages a grade reads: its own window, else the NEAREST grade's (never
     * the whole pool — a ז׳ child must not get a two-line א׳ story).
     */
    fun universe(grade: Int?, lang: AppLanguage): List<ReadingPassage> {
        val pool = passages(lang)
        val g = grade ?: return pool
        val inWindow = pool.filter { it.inGrade(g) }
        if (inWindow.isNotEmpty()) return inWindow
        fun distance(p: ReadingPassage) = minOf(abs(p.gradeLo - g), abs(p.gradeHi - g))
        val nearest = pool.minOfOrNull(::distance) ?: return pool
        return pool.filter { distance(it) == nearest }
    }

    /**
     * All questions of ONE fresh passage, options shuffled, passage attached.
     * (Parent-hidden prompts are filtered by the caller — [QuestionSource].)
     */
    fun nextGroup(target: Difficulty, grade: Int?, lang: AppLanguage, memory: QuestionMemory, rng: Random): List<Question> {
        val universe = universe(grade, lang)
        val passage = pickPassage(target, universe, memory, rng) ?: return emptyList()
        memory.markPassageUsed(passage.id, universe.size)
        return passage.questions.map { item ->
            val options = (listOf(item.correctAnswer) + item.distractors).shuffled(rng)
            Question(Topic.READING, item.prompt, options, options.indexOf(item.correctAnswer).coerceAtLeast(0), passage = passage.text)
        }
    }

    /** One passage question — for single-question callers (boss battle, bonus fallback). */
    fun singleQuestion(target: Difficulty, grade: Int?, lang: AppLanguage, memory: QuestionMemory, rng: Random): Question {
        nextGroup(target, grade, lang, memory, rng).randomOrNull(rng)?.let { return it }
        return Question(Topic.READING, tr("אוֹפְּס... אֵין קְטָעִים חֲדָשִׁים כָּרֶגַע"),
            listOf(tr("בְּסֵדֶר"), tr("הַמְשֵׁךְ"), tr("תּוֹדָה"), tr("חֲזוֹר")), 0)
    }

    /**
     * Prefer the target tier, then drift easier before harder; within a tier avoid
     * recently-used passages, and when everything was seen recycle the LEAST
     * recently used (never back-to-back).
     */
    private fun pickPassage(target: Difficulty, universe: List<ReadingPassage>, memory: QuestionMemory, rng: Random): ReadingPassage? {
        val order = when (target) {
            Difficulty.EASY -> listOf(Difficulty.EASY, Difficulty.MEDIUM, Difficulty.HARD)
            Difficulty.MEDIUM -> listOf(Difficulty.MEDIUM, Difficulty.EASY, Difficulty.HARD)
            Difficulty.HARD -> listOf(Difficulty.HARD, Difficulty.MEDIUM, Difficulty.EASY)
        }
        val recent = memory.readingRecentIDs()
        for (tier in order) {
            universe.filter { it.tier == tier && it.id !in recent }.randomOrNull(rng)?.let { return it }
        }
        fun lru(p: ReadingPassage) = recent.indexOf(p.id)   // -1 when not recent (never seen)
        for (tier in order) {
            universe.filter { it.tier == tier }.minByOrNull(::lru)?.let { return it }
        }
        return universe.minByOrNull(::lru) ?: universe.randomOrNull(rng)
    }
}

/**
 * PreReaderContent.swift — picture questions for children who can't read yet
 * (effective grade < 1). The on-screen content is visual; the instruction is
 * read aloud (`Question.spoken`).
 */
object PreReaderContent {
    fun generate(topic: Topic, rng: Random = Random.Default): Question = when (topic) {
        Topic.MATH -> counting(rng)
        // Logic / anything else → a "find the picture" round.
        else -> when (rng.nextInt(3)) {
            0 -> findOne(animals, rng)
            1 -> findOne(shapes, rng)
            else -> findOne(colors, rng)
        }
    }

    private val countables: List<Pair<String, String>>
        get() = listOf(
            "🍎" to tr("תַּפּוּחִים"), "⭐" to tr("כּוֹכָבִים"), "🐟" to tr("דָּגִים"), "🌸" to tr("פְּרָחִים"),
            "🎈" to tr("בַּלּוֹנִים"), "🍌" to tr("בָּנָנוֹת"), "🐝" to tr("דְּבוֹרִים"), "⚽" to tr("כַּדּוּרִים"),
            "🚗" to tr("מְכוֹנִיּוֹת"), "🦋" to tr("פַּרְפָּרִים"), "🍪" to tr("עוּגִיּוֹת"), "🐱" to tr("חֲתוּלִים"),
        )

    /** Show N objects → "how many?" → tap the number. */
    private fun counting(rng: Random): Question {
        val (emoji, plural) = countables.random(rng)
        val n = rng.nextInt(1, 6)
        val prompt = List(n) { emoji }.joinToString(" ")
        val nums = linkedSetOf(n)
        while (nums.size < 4) nums.add(rng.nextInt(1, 7))
        val options = nums.shuffled(rng).map { it.toString() }
        return Question(Topic.MATH, prompt, options, options.indexOf(n.toString()).coerceAtLeast(0),
            spoken = tr("כַּמָּה %@?", plural))
    }

    private val animals: List<Pair<String, String>>
        get() = listOf(
            "🐶" to tr("הַכֶּלֶב"), "🐱" to tr("הֶחָתוּל"), "🐰" to tr("הָאַרְנָב"), "🐸" to tr("הַצְּפַרְדֵּעַ"),
            "🐮" to tr("הַפָּרָה"), "🐷" to tr("הַחֲזִיר"), "🦁" to tr("הָאַרְיֵה"), "🐘" to tr("הַפִּיל"),
            "🐧" to tr("הַפִּינְגְּוִין"), "🦊" to tr("הַשּׁוּעָל"), "🐵" to tr("הַקּוֹף"), "🐯" to tr("הַנָּמֵר"),
        )
    private val shapes: List<Pair<String, String>>
        get() = listOf("🔴" to tr("הָעִגּוּל"), "🔺" to tr("הַמְּשׁוּלָּשׁ"), "🟦" to tr("הָרִבּוּעַ"), "⭐" to tr("הַכּוֹכָב"), "❤️" to tr("הַלֵּב"))
    private val colors: List<Pair<String, String>>
        get() = listOf("🔴" to tr("הָאָדוֹם"), "🟢" to tr("הַיָּרוֹק"), "🔵" to tr("הַכָּחוֹל"), "🟡" to tr("הַצָּהוֹב"),
            "🟣" to tr("הַסָּגוֹל"), "🟠" to tr("הַכָּתוֹם"))

    /** Hear "where's the dog?" → tap the matching emoji. The prompt is shown AND read aloud. */
    private fun findOne(pool: List<Pair<String, String>>, rng: Random): Question {
        val picks = pool.shuffled(rng).take(4)
        val target = picks.random(rng)
        val options = picks.map { it.first }
        return Question(Topic.LOGIC, tr("אֵיפֹה %@?", target.second), options, options.indexOf(target.first).coerceAtLeast(0))
    }
}

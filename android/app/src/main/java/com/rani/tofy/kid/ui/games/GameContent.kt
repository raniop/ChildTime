package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.kid.content.AdaptiveDifficultyEngine
import com.rani.tofy.kid.content.BankQuestion
import com.rani.tofy.kid.content.Question
import com.rani.tofy.kid.content.QuestionGenerator
import com.rani.tofy.kid.content.QuestionReporter
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

// 🎮 GameContent.swift — where a world's games get their content, and which
// games a world can really carry: a game appears in a world's chooser only
// when the world's own bank, at the child's grade and in the child's
// language, can fill a whole natural round for it.

/** One short multiple-choice item a game builds a round from. */
data class GameItem(val prompt: String, val answer: String, val distractors: List<String>, val topic: Topic) {
    /** Answer + distractors, shuffled. */
    fun shuffledOptions(): List<String> = (listOf(answer) + distractors).shuffled()
}

/** A word a spelling game can use: the clue (a picture or a question) and the word itself. */
data class GameWord(val clue: String, val word: String, val script: SpellScript, val topic: Topic) {
    /** The clue is a picture (an emoji), not a question line. */
    val isPicture: Boolean get() = clue.graphemes() <= 2 && clue.none { it.isLetter() }
}

/** Math and numbers read left-to-right in every language (MiniGameText, MiniGameKit.swift). */
object MiniGameText {
    /** An LRM on each side + non-breaking spaces: "90 ÷ 10" can never flip to "10 ÷ 90". */
    fun ltr(s: String): String = "‎" + s.replace(" ", " ") + "‎"

    /** No letters at all, and some digits → a number, an expression, a sequence. */
    fun isMath(s: String): Boolean = s.none { it.isLetter() } && s.any { it.isDigit() }

    /** `ltr` for math, the text untouched otherwise. */
    fun show(s: String): String = if (isMath(s)) ltr(s) else s
}

object GameContent {
    /** Reading has no short questions of its own: its games use the child's reading-language bank. */
    fun sourceTopic(topic: Topic?): Topic? {
        if (topic == null) return null
        if (topic != Topic.READING) return topic
        return when (GameEnv.lang) {
            AppLanguage.HE -> Topic.HEBREW
            AppLanguage.EN -> Topic.ENGLISH
            else -> null
        }
    }

    private val yesNo = setOf("כן", "לא", "נכון", "לא נכון", "yes", "no", "true", "false",
        "да", "нет", "верно", "неверно", "نعم", "لا", "صحيح", "خطأ")

    /** Prompts that only make sense next to their options ("מִי מֵהַבָּאִים…?", "which of these…"). */
    fun refersToOptions(prompt: String): Boolean {
        val p = Question.stripNiqqud(prompt).lowercase()
        val markers = listOf("הבאים", "מבין", "מהם", "מי מהן", "איזה מה", "איזו מה", "לא שיך", "לא שייך",
            "following", "of these", "which one", "из этих", "из перечисленных", "кто из", "что из",
            "التالي", "التالية", "أي من", "أيّ من")
        return markers.any { p.contains(it) }
    }

    /** The grade window of a world's bank, the adaptive tier first. */
    fun pool(topic: Topic, grade: Int): List<BankQuestion> {
        if (topic == Topic.MATH || topic == Topic.READING) return emptyList()
        val pool = gradePool(topic, grade).shuffled()
        val tier = MiniGameLevel.difficulty(topic)
        return pool.filter { it.difficulty == tier } + pool.filter { it.difficulty != tier }
    }

    /** The grade window, kept for a minute (the chooser asks a dozen questions of one bank). */
    private val poolCache = HashMap<String, Pair<Long, List<BankQuestion>>>()
    private fun gradePool(topic: Topic, grade: Int): List<BankQuestion> {
        val key = "${topic.raw}|$grade|${GameEnv.lang.code}"
        val now = System.currentTimeMillis()
        synchronized(poolCache) {
            poolCache[key]?.let { (at, items) -> if (now - at < 60_000) return items }
        }
        val items = QuestionGenerator.effectivePool(topic, grade, GameEnv.lang)
        synchronized(poolCache) { poolCache[key] = now to items }
        return items
    }

    /** Tests: forget the cached pools. */
    fun clearCache() = synchronized(poolCache) { poolCache.clear() }

    /** Short, self-contained items: a prompt that fits a card, answers that fit a tile, no yes/no. */
    fun items(topic: Topic, grade: Int, maxPrompt: Int = 60, maxAnswer: Int = 24, standalone: Boolean = false): List<GameItem> {
        val seen = HashSet<String>()
        val out = mutableListOf<GameItem>()
        for (q in pool(topic, grade)) {
            val p = Question.stripNiqqud(q.prompt)
            if (p.graphemes() > maxPrompt || q.distractors.size < 2 || p.contains("לא שיך") || p.contains("לא שייך") ||
                QuestionReporter.isHidden(q.prompt)) continue
            val options = listOf(q.correctAnswer) + q.distractors
            if (!options.all { Question.stripNiqqud(it).graphemes() <= maxAnswer }) continue
            if (options.any { Question.stripNiqqud(it).lowercase() in yesNo }) continue
            if (standalone && refersToOptions(q.prompt)) continue
            if (!seen.add(q.prompt + "|" + q.correctAnswer)) continue
            out += GameItem(q.prompt, q.correctAnswer, q.distractors.take(3), topic)
        }
        return out
    }

    /** The same items with DIFFERENT answers — a pairs board can't hold two "פָּרִיז". */
    fun distinctAnswers(items: List<GameItem>): List<GameItem> {
        val seen = HashSet<String>()
        return items.filter { seen.add(Question.stripNiqqud(it.answer)) }
    }

    // MARK: Words

    /** A single word of 2–8 letters in one script (niqqud / harakat dropped), or null. */
    fun spellable(raw: String): Pair<String, SpellScript>? {
        val s = Question.stripNiqqud(raw).filterNot { val c = it.code; c in 0x064B..0x065F || c == 0x0670 || c == 0x0640 }.trim()
        if (s.length !in 2..8) return null
        var script: SpellScript? = null
        for (ch in s) {
            val sc = when (ch.code) {
                in 0x05D0..0x05EA -> SpellScript.HEBREW
                in 0x41..0x5A, in 0x61..0x7A -> SpellScript.ENGLISH
                in 0x0410..0x044F, 0x0401, 0x0451 -> SpellScript.CYRILLIC
                in 0x0621..0x064A -> SpellScript.ARABIC
                else -> return null
            }
            if (script == null) script = sc else if (script != sc) return null
        }
        return script?.let { s to it }
    }

    /** The world's single-word answers, each with its question as the clue — in the most common script. */
    fun words(topic: Topic, grade: Int, maxLetters: Int = 8): List<GameWord> {
        val byScript = LinkedHashMap<SpellScript, MutableList<GameWord>>()
        val seen = HashSet<String>()
        for (item in items(topic, grade, maxPrompt = 70, maxAnswer = 12, standalone = true)) {
            val w = spellable(item.answer) ?: continue
            if (w.first.length > maxLetters || !seen.add(w.first.lowercase())) continue
            byScript.getOrPut(w.second) { mutableListOf() } += GameWord(item.prompt, w.first, w.second, topic)
        }
        return byScript.values.maxByOrNull { it.size } ?: emptyList()
    }

    // MARK: Numbers

    fun number(s: String): Int? = s.trim().replace("−", "-").toIntOrNull()

    /** Items whose answer AND options are whole numbers. */
    fun numericItems(topic: Topic, grade: Int): List<GameItem> =
        items(topic, grade, maxPrompt = 70, maxAnswer = 6, standalone = true).filter { item ->
            val a = number(item.answer) ?: return@filter false
            a in 0..10_000 && item.distractors.all { number(it) != null }
        }

    /** A computed fact as a card: "7 × 8 = ?" and four nearby numbers. */
    fun mathItem(grade: Int): GameItem {
        val f = MathFacts.fact(grade)
        val options = linkedSetOf(f.answer)
        var tries = 0
        while (options.size < 4 && tries < 60) {
            tries++
            val d = (1..max(3, abs(f.answer) / 4 + 2)).random()
            val c = if (kotlin.random.Random.nextBoolean()) f.answer + d else f.answer - d
            if (grade >= 7 || c >= 0) options += c
        }
        return GameItem(MiniGameText.ltr(f.expression + " = ?"), MathFacts.show(f.answer),
            (options - f.answer).map { MathFacts.show(it) }, Topic.MATH)
    }

    /** The next card for a world: its bank, or computed math where the world is math (or ran dry). */
    fun card(topic: Topic?, grade: Int, seen: MutableSet<String>): GameItem {
        val t = sourceTopic(topic)
        if (t != null && t != Topic.MATH) {
            val pool = items(t, grade, maxPrompt = 80, maxAnswer = 24)
            val fresh = pool.firstOrNull { it.prompt !in seen } ?: pool.randomOrNull()
            if (fresh != null) { seen += fresh.prompt; return fresh }
        }
        return mathItem(MiniGameLevel.grade(Topic.MATH))
    }
}

/**
 * The adaptive engine's view, for a game: a CONTENT level that never goes
 * below 1 (the generators index from א׳). Whether to draw the גן form is
 * [GameEnv.activeChildIsPreReader] — never this.
 */
object MiniGameLevel {
    /** The child's grade, one step up or down when the adaptive level has clearly moved. */
    fun grade(topic: Topic?): Int {
        val base = max(1, GameEnv.source.grade ?: 2)
        if (topic == null || GameEnv.source.grade == null) return base
        val anchor = GameEnv.source.difficulty(topic)
        val delta = GameEnv.adaptiveLevel(topic, anchor) - AdaptiveDifficultyEngine.level(anchor)
        if (delta >= 0.6) return min(8, base + 1)
        if (delta <= -0.6) return max(1, base - 1)
        return base
    }

    /** The bank tier to prefer — the runner's own 70/20/10 sampling. */
    fun difficulty(topic: Topic): Difficulty {
        val anchor = if (GameEnv.source.grade == null) Difficulty.EASY else GameEnv.source.difficulty(topic)
        return AdaptiveDifficultyEngine.sampledDifficulty(GameEnv.adaptiveLevel(topic, anchor), anchor)
    }
}

/** The games a world can carry for this child, best fit first. */
object WorldGameFit {
    fun games(topic: Topic?, grade: Int): List<MiniGameKind> {
        if (!MiniGameKind.availableForActiveChild) return emptyList()
        // 👶 גן plays the same five games everywhere — their boards come from PreReaderGames.
        if (PreReaderGames.isPreReader(grade)) return MiniGameGradeFit.preReaderRoster
        // 💫 The arena mixes every topic: the three games that mix too.
        if (topic == null) return listOf(MiniGameKind.LIGHTNING, MiniGameKind.PAIRS, MiniGameKind.BALLOON)
            .filter { MiniGameGradeFit.offered(it, grade, topic = null) }
        val probe = Probe(topic, grade)
        return order(topic).filter { probe.fits(it) }
    }

    /** Best fit first: the mechanic the world is really about leads. */
    fun order(topic: Topic): List<MiniGameKind> = when (topic) {
        Topic.MATH -> listOf(MiniGameKind.CRUSH, MiniGameKind.BALANCE, MiniGameKind.GAME2048, MiniGameKind.VAULT, MiniGameKind.LIGHTNING,
            MiniGameKind.PAIRS, MiniGameKind.PATTERN, MiniGameKind.SORT, MiniGameKind.BALLOON, MiniGameKind.GROCERY)
        Topic.ENGLISH, Topic.HEBREW, Topic.READING -> listOf(MiniGameKind.WORD, MiniGameKind.WORD_SEARCH, MiniGameKind.SORT, MiniGameKind.PAIRS,
            MiniGameKind.BALLOON, MiniGameKind.LIGHTNING, MiniGameKind.GROCERY, MiniGameKind.PATTERN, MiniGameKind.VAULT)
        Topic.MONEY -> listOf(MiniGameKind.GROCERY, MiniGameKind.LIGHTNING, MiniGameKind.SORT, MiniGameKind.BALANCE, MiniGameKind.CRUSH,
            MiniGameKind.PAIRS, MiniGameKind.BALLOON, MiniGameKind.VAULT)
        Topic.LOGIC, Topic.GIFTED -> listOf(MiniGameKind.PATTERN, MiniGameKind.VAULT, MiniGameKind.BALANCE, MiniGameKind.GAME2048,
            MiniGameKind.CRUSH, MiniGameKind.LIGHTNING, MiniGameKind.PAIRS, MiniGameKind.SORT, MiniGameKind.BALLOON)
        else -> listOf(MiniGameKind.SORT, MiniGameKind.PAIRS, MiniGameKind.BALLOON, MiniGameKind.LIGHTNING, MiniGameKind.WORD,
            MiniGameKind.WORD_SEARCH, MiniGameKind.VAULT, MiniGameKind.BALANCE)
    }

    /** Counts what one world's bank holds. */
    class Probe(val topic: Topic, val grade: Int) {
        val source: Topic? = GameContent.sourceTopic(topic)
        val numericWorld: Boolean = topic in listOf(Topic.MATH, Topic.MONEY, Topic.LOGIC, Topic.GIFTED)

        private fun count(maxPrompt: Int, maxAnswer: Int, standalone: Boolean, distinct: Boolean = false): Int {
            val s = source ?: return 0
            if (s == Topic.MATH) return 0
            val items = GameContent.items(s, grade, maxPrompt, maxAnswer, standalone)
            return if (distinct) GameContent.distinctAnswers(items).size else items.size
        }

        /** The alphabet a spelling game would use for this world. */
        val spellScript: SpellScript
            get() {
                val world = source ?: topic
                val s = source
                if (s != null && s != Topic.MATH && !WordSets.hasThemedList(world, grade)) {
                    GameContent.words(s, grade).firstOrNull()?.let { return it.script }
                }
                return WordSets.script(world, grade)
            }

        fun fits(kind: MiniGameKind): Boolean {
            val script: SpellScript? = when (kind) {
                MiniGameKind.WORD, MiniGameKind.WORD_SEARCH -> spellScript
                MiniGameKind.GROCERY -> if (topic == Topic.ENGLISH) SpellScript.ENGLISH else if (topic == Topic.HEBREW) SpellScript.HEBREW else null
                else -> null
            }
            if (!MiniGameGradeFit.offered(kind, grade, script, source ?: topic)) return false
            val s = source
            return when (kind) {
                MiniGameKind.LIGHTNING -> topic == Topic.MATH || count(70, 28, false) >= 12
                MiniGameKind.PAIRS -> when {
                    topic == Topic.MATH || topic == Topic.ENGLISH -> true
                    (topic == Topic.FLAGS || topic == Topic.GEOGRAPHY) && grade >= 2 -> true
                    else -> count(60, 24, true, distinct = true) >= 8
                }
                MiniGameKind.BALLOON -> BalloonSets.hasCategory(topic, grade) || count(70, 16, false) >= 8
                MiniGameKind.SORT -> SortSets.make(s ?: topic, grade) != null || count(45, 18, true) >= 10
                MiniGameKind.VAULT -> numericWorld || count(80, 24, false) >= 6
                MiniGameKind.WORD -> when {
                    WordSets.hasThemedList(s ?: topic, grade) -> true
                    s == null || s == Topic.MATH -> false
                    else -> GameContent.words(s, grade).size >= 6
                }
                MiniGameKind.WORD_SEARCH -> when {
                    WordSets.hasThemedList(s ?: topic, grade) -> true
                    s == null || s == Topic.MATH -> false
                    else -> GameContent.words(s, grade, maxLetters = 6).size >= 5
                }
                MiniGameKind.CRUSH -> numericWorld
                MiniGameKind.GAME2048 -> topic in listOf(Topic.MATH, Topic.LOGIC, Topic.GIFTED)
                MiniGameKind.BALANCE -> numericWorld || (s != null && GameContent.numericItems(s, grade).size >= 8)
                MiniGameKind.PATTERN -> topic in listOf(Topic.MATH, Topic.LOGIC, Topic.GIFTED) || s == Topic.ENGLISH || s == Topic.HEBREW
                MiniGameKind.GROCERY -> topic in listOf(Topic.MATH, Topic.MONEY) || s == Topic.ENGLISH || s == Topic.HEBREW
            }
        }
    }
}

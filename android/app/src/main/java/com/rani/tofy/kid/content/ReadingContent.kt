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
 * read aloud (`Question.spoken`). Math adds and subtracts with pictures, Hebrew
 * teaches the letters, and each theme world asks about its own pictures — every
 * world used to serve the same "where's the dog?" (Ben David, 2026-10-09).
 */
object PreReaderContent {
    fun generate(topic: Topic, rng: Random = Random.Default): Question = when {
        topic == Topic.MATH -> mathRound(rng)
        topic == Topic.HEBREW && com.rani.tofy.i18n.I18n.language == AppLanguage.HE -> lettersRound(rng)
        else -> {
            val pool = themedPool(topic)
            if (pool != null && rng.nextDouble() < 0.75) findOne(pool, rng, topic)
            else when (rng.nextInt(3)) {
                0 -> findOne(animals, rng)
                1 -> findOne(shapes, rng)
                else -> findOne(colors, rng)
            }
        }
    }

    // ── 🔢 Math: count, add, take away, compare, find the digit ──

    private fun mathRound(rng: Random): Question = when (rng.nextInt(9)) {
        0, 1, 2 -> counting(rng)
        3, 4 -> pictureAdd(rng)
        5, 6 -> pictureTakeAway(rng)
        7 -> whereMore(rng)
        else -> digitByEar(rng)
    }

    private val countables: List<Pair<String, String>>
        get() = listOf(
            "🍎" to tr("תַּפּוּחִים"), "⭐" to tr("כּוֹכָבִים"), "🐟" to tr("דָּגִים"), "🌸" to tr("פְּרָחִים"),
            "🎈" to tr("בַּלּוֹנִים"), "🍌" to tr("בָּנָנוֹת"), "🐝" to tr("דְּבוֹרִים"), "⚽" to tr("כַּדּוּרִים"),
            "🚗" to tr("מְכוֹנִיּוֹת"), "🦋" to tr("פַּרְפָּרִים"), "🍪" to tr("עוּגִיּוֹת"), "🐱" to tr("חֲתוּלִים"),
        )

    private fun row(emoji: String, n: Int) = List(n) { emoji }.joinToString(" ")

    /** Four numbers around `answer` (the right one included). */
    private fun numberOptions(answer: Int, range: IntRange, rng: Random): Pair<List<String>, Int> {
        val nums = linkedSetOf(answer)
        while (nums.size < 4) nums.add(rng.nextInt(range.first, range.last + 1))
        val options = nums.shuffled(rng).map { it.toString() }
        return options to options.indexOf(answer.toString()).coerceAtLeast(0)
    }

    private fun counting(rng: Random): Question {
        val (emoji, plural) = countables.random(rng)
        val n = rng.nextInt(1, 9)
        val (options, correct) = numberOptions(n, maxOf(1, n - 3)..(n + 3), rng)
        return Question(Topic.MATH, row(emoji, n), options, correct, spoken = tr("כַּמָּה %@?", plural))
    }

    /** 🍎🍎 ➕ 🍎 — "how many altogether?" (totals up to 7). */
    private fun pictureAdd(rng: Random): Question {
        val (emoji, plural) = countables.random(rng)
        val a = rng.nextInt(1, 5)
        val b = rng.nextInt(1, minOf(4, 7 - a) + 1)
        val (options, correct) = numberOptions(a + b, maxOf(1, a + b - 3)..(a + b + 3), rng)
        return Question(Topic.MATH, "${row(emoji, a)}  ➕  ${row(emoji, b)}", options, correct,
            spoken = tr("כַּמָּה %@ יֵשׁ בְּיַחַד?", plural), skill = "addSub")
    }

    /** 🍎🍎🍎 ➖ 🍎 — "how many are left?" */
    private fun pictureTakeAway(rng: Random): Question {
        val (emoji, plural) = countables.random(rng)
        val total = rng.nextInt(3, 8)
        val take = rng.nextInt(1, total)
        val left = total - take
        val (options, correct) = numberOptions(left, 0..(left + 3), rng)
        return Question(Topic.MATH, "${row(emoji, total)}  ➖  ${row(emoji, take)}", options, correct,
            spoken = tr("כַּמָּה %@ נִשְׁאֲרוּ?", plural), skill = "addSub")
    }

    /** Four groups — "where are there MORE apples?" */
    private fun whereMore(rng: Random): Question {
        val (emoji, plural) = countables.random(rng)
        val sizes = (1..6).shuffled(rng).take(4)
        val options = sizes.map { row(emoji, it) }
        return Question(Topic.MATH, "⚖️", options, sizes.indexOf(sizes.max()),
            spoken = tr("אֵיפֹה יֵשׁ יוֹתֵר %@?", plural), skill = "compare")
    }

    private val numberWords: List<String>
        get() = listOf(tr("אַחַת"), tr("שְׁתַּיִם"), tr("שָׁלוֹשׁ"), tr("אַרְבַּע"), tr("חָמֵשׁ"),
            tr("שֵׁשׁ"), tr("שֶׁבַע"), tr("שְׁמוֹנֶה"), tr("תֵּשַׁע"), tr("עֶשֶׂר"))

    /** "Where is the number three?" — the digits 1–10, heard not read. */
    private fun digitByEar(rng: Random): Question {
        val n = rng.nextInt(1, 11)
        val (options, correct) = numberOptions(n, 1..10, rng)
        return Question(Topic.MATH, "👂", options, correct, spoken = tr("אֵיפֹה הַמִּסְפָּר %@?", numberWords[n - 1]))
    }

    // ── 🔤 Hebrew letters ──

    private data class LetterWord(val emoji: String, val word: String, val clearPicture: Boolean = true)
    private data class Letter(val glyph: String, val name: String, val words: List<LetterWord>)

    /** Same list as PreReaderContent.swift — each word starts with its letter's own sound. */
    private val letters = listOf(
        Letter("א", "אָלֶף", listOf(LetterWord("🍉", "אֲבַטִּיחַ"), LetterWord("🦁", "אַרְיֵה"), LetterWord("🍍", "אֲנָנָס"))),
        Letter("ב", "בֵּית", listOf(LetterWord("🎈", "בַּלּוֹן"), LetterWord("🍌", "בָּנָנָה"), LetterWord("🏠", "בַּיִת"))),
        Letter("ג", "גִּימֶל", listOf(LetterWord("🐪", "גָּמָל"), LetterWord("🧀", "גְּבִינָה"), LetterWord("🎸", "גִּיטָרָה"))),
        Letter("ד", "דָּלֶת", listOf(LetterWord("🐟", "דָּג"), LetterWord("🐻", "דּוֹב"), LetterWord("🐝", "דְּבוֹרָה"))),
        Letter("ה", "הֵא", listOf(LetterWord("⛰️", "הַר"), LetterWord("🦛", "הִיפּוֹפּוֹטָם"))),
        Letter("ו", "וָו", listOf(LetterWord("🌹", "וֶרֶד"))),
        Letter("ז", "זַיִן", listOf(LetterWord("🦓", "זֶבְּרָה"), LetterWord("🫒", "זַיִת"))),
        Letter("ח", "חֵית", listOf(LetterWord("🐱", "חָתוּל"), LetterWord("🥛", "חָלָב"), LetterWord("🧵", "חוּט"))),
        Letter("ט", "טֵית", listOf(LetterWord("🦚", "טַוָּס"), LetterWord("🚜", "טְרַקְטוֹר"))),
        Letter("י", "יוּד", listOf(LetterWord("🌙", "יָרֵחַ"), LetterWord("🧒", "יֶלֶד", clearPicture = false))),
        Letter("כ", "כַּף", listOf(LetterWord("⚽", "כַּדּוּר"), LetterWord("🐶", "כֶּלֶב"), LetterWord("⭐", "כּוֹכָב"))),
        Letter("ל", "לָמֶד", listOf(LetterWord("🍋", "לִימוֹן"), LetterWord("❤️", "לֵב"))),
        Letter("מ", "מֵם", listOf(LetterWord("🚗", "מְכוֹנִית", clearPicture = false), LetterWord("🔑", "מַפְתֵּחַ"))),
        Letter("נ", "נוּן", listOf(LetterWord("🐯", "נָמֵר"), LetterWord("🕯️", "נֵר"), LetterWord("🐜", "נְמָלָה"))),
        Letter("ס", "סָמֶךְ", listOf(LetterWord("🐴", "סוּס"), LetterWord("📚", "סֵפֶר"))),
        Letter("ע", "עַיִן", listOf(LetterWord("🎂", "עוּגָה"), LetterWord("🌳", "עֵץ"), LetterWord("🐭", "עַכְבָּר"))),
        Letter("פ", "פֵּא", listOf(LetterWord("🐘", "פִּיל"), LetterWord("🌸", "פֶּרַח"))),
        Letter("צ", "צָדִי", listOf(LetterWord("🐢", "צָב"), LetterWord("🐸", "צְפַרְדֵּעַ"), LetterWord("🐦", "צִפּוֹר"))),
        Letter("ק", "קוֹף", listOf(LetterWord("🐒", "קוֹף"), LetterWord("🦔", "קִיפּוֹד"))),
        Letter("ר", "רֵישׁ", listOf(LetterWord("🤖", "רוֹבּוֹט"), LetterWord("🚂", "רַכֶּבֶת"))),
        Letter("ש", "שִׁין", listOf(LetterWord("☀️", "שֶׁמֶשׁ"), LetterWord("🕐", "שָׁעוֹן"), LetterWord("🦊", "שׁוּעָל"))),
        Letter("ת", "תָּו", listOf(LetterWord("🍎", "תַּפּוּחַ"), LetterWord("👶", "תִּינוֹק"))),
    )

    /** Letters a child can't tell apart by sound never stand side by side as options. */
    private val soundAlike = listOf(setOf("א", "ע"), setOf("ט", "ת"), setOf("כ", "ק", "ח"), setOf("ס", "ש"), setOf("ב", "ו"))
    private fun clash(a: String, b: String) = a == b || soundAlike.any { a in it && b in it }

    private fun distinctLetters(target: Letter, rng: Random): List<Letter> {
        val picked = mutableListOf(target)
        for (l in letters.shuffled(rng)) {
            if (picked.size >= 4) break
            if (picked.none { clash(it.glyph, l.glyph) }) picked += l
        }
        return picked
    }

    private fun lettersRound(rng: Random): Question = when (rng.nextInt(3)) {
        0 -> firstLetter(rng)
        1 -> pictureForLetter(rng)
        else -> letterByEar(rng)
    }

    /** 🍉 — "which letter does אֲבַטִּיחַ start with?" → א */
    private fun firstLetter(rng: Random): Question {
        val target = letters.random(rng)
        val word = target.words.random(rng)
        val options = distinctLetters(target, rng).map { it.glyph }.shuffled(rng)
        return Question(Topic.HEBREW, word.emoji, options, options.indexOf(target.glyph).coerceAtLeast(0),
            spoken = tr("בְּאֵיזוֹ אוֹת מַתְחִילָה הַמִּלָּה %@?", word.word), skill = "letters")
    }

    /** ב — "which picture starts with the letter בֵּית?" → 🎈 */
    private fun pictureForLetter(rng: Random): Question {
        val target = letters.filter { l -> l.words.any { it.clearPicture } }.random(rng)
        val right = target.words.filter { it.clearPicture }.random(rng)
        val others = distinctLetters(target, rng).drop(1).mapNotNull { l -> l.words.filter { it.clearPicture }.randomOrNull(rng) }
        val options = (listOf(right.emoji) + others.map { it.emoji }).shuffled(rng)
        return Question(Topic.HEBREW, target.glyph, options, options.indexOf(right.emoji).coerceAtLeast(0),
            spoken = tr("אֵיזוֹ תְּמוּנָה מַתְחִילָה בָּאוֹת %@?", target.name), skill = "letters")
    }

    /** 👂 — "where is the letter גִּימֶל?" → ג */
    private fun letterByEar(rng: Random): Question {
        val target = letters.random(rng)
        val options = distinctLetters(target, rng).map { it.glyph }.shuffled(rng)
        return Question(Topic.HEBREW, "👂", options, options.indexOf(target.glyph).coerceAtLeast(0),
            spoken = tr("אֵיפֹה הָאוֹת %@?", target.name), skill = "letters")
    }

    // ── Find the picture ──

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

    /** Each theme world's own pictures (PreReaderContent.swift themedPool). */
    private fun themedPool(topic: Topic): List<Pair<String, String>>? = when (topic) {
        Topic.ANIMALS -> animals
        Topic.SEA -> listOf("🐙" to tr("הַתַּמְנוּן"), "🐬" to tr("הַדּוֹלְפִין"), "🦈" to tr("הַכָּרִישׁ"), "🐢" to tr("הַצָּב"),
            "🦀" to tr("הַסַּרְטָן"), "🐳" to tr("הַלִּוְיָתָן"), "🐠" to tr("הַדָּג"), "🐚" to tr("הַצֶּדֶף"))
        Topic.SPACE -> listOf("🚀" to tr("הַחֲלָלִית"), "🌙" to tr("הַיָּרֵחַ"), "☀️" to tr("הַשֶּׁמֶשׁ"), "⭐" to tr("הַכּוֹכָב"),
            "🌍" to tr("כַּדּוּר הָאָרֶץ"), "👨‍🚀" to tr("הָאַסְטְרוֹנָאוּט"))
        Topic.VEHICLES -> listOf("🚗" to tr("הַמְּכוֹנִית"), "🚌" to tr("הָאוֹטוֹבּוּס"), "🚂" to tr("הָרַכֶּבֶת"), "✈️" to tr("הַמָּטוֹס"),
            "🚲" to tr("הָאוֹפַנַּיִם"), "🚁" to tr("הַמַּסּוֹק"), "🚒" to tr("הַכַּבָּאִית"), "🚢" to tr("הָאֳנִיָּה"))
        Topic.FOOD -> listOf("🍎" to tr("הַתַּפּוּחַ"), "🍌" to tr("הַבָּנָנָה"), "🍕" to tr("הַפִּיצָה"), "🥕" to tr("הַגֶּזֶר"),
            "🍞" to tr("הַלֶּחֶם"), "🧀" to tr("הַגְּבִינָה"), "🍉" to tr("הָאֲבַטִּיחַ"), "🍓" to tr("הַתּוּת"), "🥚" to tr("הַבֵּיצָה"))
        Topic.MUSIC -> listOf("🥁" to tr("הַתֹּף"), "🎸" to tr("הַגִּיטָרָה"), "🎹" to tr("הַפְּסַנְתֵּר"), "🎺" to tr("הַחֲצוֹצְרָה"),
            "🎻" to tr("הַכִּנּוֹר"), "🎤" to tr("הַמִּיקְרוֹפוֹן"))
        Topic.BODY -> listOf("👁️" to tr("הָעַיִן"), "👂" to tr("הָאֹזֶן"), "👃" to tr("הָאַף"), "👄" to tr("הַפֶּה"),
            "✋" to tr("הַיָּד"), "🦶" to tr("הָרֶגֶל"))
        Topic.SOCCER -> listOf("⚽" to tr("הַכַּדּוּר"), "🥅" to tr("הַשַּׁעַר"), "🏆" to tr("הַגָּבִיעַ"), "👟" to tr("הַנַּעַל"),
            "🧤" to tr("הַכְּפָפָה"), "🚩" to tr("הַדֶּגֶל"))
        Topic.SCIENCE -> listOf("🔬" to tr("הַמִּיקְרוֹסְקוֹפּ"), "🧲" to tr("הַמַּגְנֵט"), "💡" to tr("הַנּוּרָה"), "🌈" to tr("הַקֶּשֶׁת"),
            "🔥" to tr("הָאֵשׁ"), "💧" to tr("הַטִּפָּה"), "🌡️" to tr("הַמַּדְחֹם"))
        else -> null
    }

    /** Hear "where's the dog?" → tap the matching emoji. The prompt is shown AND read aloud. */
    private fun findOne(pool: List<Pair<String, String>>, rng: Random, topic: Topic = Topic.LOGIC): Question {
        val picks = pool.shuffled(rng).take(4)
        val target = picks.random(rng)
        val options = picks.map { it.first }
        return Question(topic, tr("אֵיפֹה %@?", target.second), options, options.indexOf(target.first).coerceAtLeast(0))
    }
}

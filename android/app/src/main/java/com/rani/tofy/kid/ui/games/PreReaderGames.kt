package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.child.Topic

// 👶 PreReaderGames.swift — גן mini-games for a child who cannot read a word.
// Five of the twelve games survive with no text at all (pop, sort, match,
// continue, collect); this is the content that feeds them for a pre-reader.
//   1️⃣ Pictures (and the words beside them, smaller, for a parent reading along).
//   2️⃣ The instruction is SPOKEN (on entry and on every 🔊).
//   3️⃣ Short, big and never on the clock — a גן round cannot be lost.
// A miss is a soft sound and a wobble; never a word of failure.

/** The rule as PICTURES, plus the sentence read aloud. */
data class PreReaderCue(val icons: List<String> = emptyList(), val spoken: String)

/** A picture and its name — the name only ever goes to the speech synthesizer. */
data class PreReaderPic(val emoji: String, val the: String)

object PreReaderGames {
    /** גן and below — effectiveGrade ≤ 0. */
    fun isPreReader(grade: Int): Boolean = MiniGameBand.of(grade) == MiniGameBand.PRE_READER

    /** Items a round holds — six, and the balloon round stops at six good pops. */
    const val ROUND_ITEMS = 6
    /** 🔗 four pairs: eight tiles is already a full screen at this age. */
    const val PAIR_COUNT = 4
    /** 🧠 four sequences, 🧱 five collections — about a minute. */
    const val PATTERN_COUNT = 4
    const val COUNTING_HITS = 5
    const val COUNTING_CARDS = 6

    val animals: List<PreReaderPic>
        get() = listOf(
            PreReaderPic("🐶", tr("הַכֶּלֶב")), PreReaderPic("🐱", tr("הֶחָתוּל")),
            PreReaderPic("🐰", tr("הָאַרְנָב")), PreReaderPic("🐸", tr("הַצְּפַרְדֵּעַ")),
            PreReaderPic("🐮", tr("הַפָּרָה")), PreReaderPic("🐷", tr("הַחֲזִיר")),
            PreReaderPic("🦁", tr("הָאַרְיֵה")), PreReaderPic("🐘", tr("הַפִּיל")),
            PreReaderPic("🐧", tr("הַפִּינְגְּוִין")), PreReaderPic("🦊", tr("הַשּׁוּעָל")),
            PreReaderPic("🐵", tr("הַקּוֹף")), PreReaderPic("🐯", tr("הַנָּמֵר")),
            PreReaderPic("🐻", tr("הַדֹּב")), PreReaderPic("🐴", tr("הַסּוּס")),
            PreReaderPic("🐔", tr("הַתַּרְנְגֹלֶת")), PreReaderPic("🐟", tr("הַדָּג"))
        )

    val things: List<PreReaderPic>
        get() = listOf(
            PreReaderPic("🍎", tr("הַתַּפּוּחַ")), PreReaderPic("🍌", tr("הַבַּנָּנָה")),
            PreReaderPic("🚗", tr("הַמְּכוֹנִית")), PreReaderPic("⚽", tr("הַכַּדּוּר")),
            PreReaderPic("🌸", tr("הַפֶּרַח")), PreReaderPic("⭐", tr("הַכּוֹכָב")),
            PreReaderPic("🍪", tr("הָעוּגִיָּה")), PreReaderPic("🚂", tr("הָרַכֶּבֶת")),
            PreReaderPic("👟", tr("הַנַּעַל")), PreReaderPic("🧢", tr("הַכּוֹבַע")),
            PreReaderPic("🔑", tr("הַמַּפְתֵּחַ")), PreReaderPic("🍉", tr("הָאֲבַטִּיחַ")),
            PreReaderPic("🥕", tr("הַגֶּזֶר")), PreReaderPic("🏠", tr("הַבַּיִת")),
            PreReaderPic("🌳", tr("הָעֵץ")), PreReaderPic("☂️", tr("הַמִּטְרִיָּה"))
        )

    /** A colour: its swatch, the balloon's own fill, and the plural adjective the sentence uses. */
    data class Hue(val swatch: String, val hex: String, val plural: String)

    val hues: List<Hue>
        get() = listOf(
            Hue("🔴", "FF4D4D", tr("הָאֲדֻמִּים")),
            Hue("🟢", "2ECC71", tr("הַיְּרֻקִּים")),
            Hue("🔵", "3B9BE8", tr("הַכְּחֻלִּים")),
            Hue("🟡", "FFD23F", tr("הַצְּהֻבִּים")),
            Hue("🟣", "9B5DE5", tr("הַסְּגֻלִּים")),
            Hue("🟠", "FF9F1C", tr("הַכְּתֻמִּים")),
        )

    /** Something to count, and its plural name — all masculine ("שְׁלוֹשָׁה תַּפּוּחִים"). */
    val countables: List<Pair<String, String>>
        get() = listOf(
            "🍎" to tr("תַּפּוּחִים"), "⭐" to tr("כּוֹכָבִים"), "🐟" to tr("דָּגִים"),
            "⚽" to tr("כַּדּוּרִים"), "🌸" to tr("פְּרָחִים"), "🦋" to tr("פַּרְפָּרִים"),
            "🍋" to tr("לִימוֹנִים"),
        )

    /** 2…6 as a masculine Hebrew word (the synthesizer reads a bare digit in the feminine). */
    fun countWord(n: Int): String = when {
        n <= 1 -> tr("אֶחָד")
        n == 2 -> tr("שְׁנֵי")
        n == 3 -> tr("שְׁלוֹשָׁה")
        n == 4 -> tr("אַרְבָּעָה")
        n == 5 -> tr("חֲמִשָּׁה")
        else -> tr("שִׁשָּׁה")
    }

    /** "שְׁלוֹשָׁה תַּפּוּחִים" — two and up only (Hebrew counts ONE the other way round). */
    fun countPhrase(n: Int, plural: String): String = countWord(maxOf(2, n)) + " " + plural

    // MARK: - 🎈 Balloons

    data class BalloonRound(val set: BalloonSet, val cue: PreReaderCue)

    /** 🎈 Three text-free rounds: one object · one colour · a quantity. */
    fun balloons(): BalloonRound = when ((0..2).random()) {
        0 -> balloonColour()
        1 -> balloonCount()
        else -> balloonPicture()
    }

    private fun balloonPicture(): BalloonRound {
        val pool = (if (kotlin.random.Random.nextBoolean()) animals else things).shuffled()
        val target = pool[0]
        val others = pool.drop(1).take(6)
        return BalloonRound(
            BalloonSet("", Topic.LOGIC, listOf(BalloonItem(target.emoji, "", true)), others.map { BalloonItem(it.emoji, "", false) }),
            PreReaderCue(listOf(target.emoji), tr("פּוֹצְצוּ אֶת כָּל הַבַּלּוֹנִים עִם %@!", target.the)),
        )
    }

    private fun balloonColour(): BalloonRound {
        val pool = hues.shuffled()
        val target = pool[0]
        val others = pool.drop(1).take(4)
        return BalloonRound(
            BalloonSet("", Topic.LOGIC, listOf(BalloonItem("", "", true, target.hex)), others.map { BalloonItem("", "", false, it.hex) }),
            PreReaderCue(listOf(target.swatch), tr("פּוֹצְצוּ אֶת כָּל הַבַּלּוֹנִים %@!", target.plural)),
        )
    }

    private fun balloonCount(): BalloonRound {
        val (emoji, plural) = countables.random()
        val n = (2..4).random()
        fun balloon(k: Int, correct: Boolean) = BalloonItem(emoji.repeat(k), "", correct)
        val others = (1..5).filter { it != n }.map { balloon(it, false) }
        return BalloonRound(
            BalloonSet("", Topic.MATH, listOf(balloon(n, true)), others),
            PreReaderCue(List(n) { emoji }, tr("פּוֹצְצוּ אֶת הַבַּלּוֹן שֶׁיֵּשׁ עָלָיו %@!", countPhrase(n, plural))),
        )
    }

    // MARK: - 🧺 Baskets

    data class BasketRound(val set: SortSet, val cue: PreReaderCue)

    /** 🧺 Two baskets wearing pictures instead of a label; the sentence naming the rule is spoken. */
    fun baskets(): BasketRound {
        fun set(a: String, b: String, left: List<String>, right: List<String>, spoken: String): BasketRound {
            val items = left.map { SortItem(it, "", basket = 0) } + right.map { SortItem(it, "", basket = 1) }
            return BasketRound(SortSet(listOf(SortBasket(a, ""), SortBasket(b, "")), items, Topic.LOGIC), PreReaderCue(spoken = spoken))
        }
        return when ((0..3).random()) {
            0 -> set("🐶🐱", "🍎🍌", listOf("🐰", "🐸", "🦁", "🐘", "🐧", "🐴"), listOf("🍉", "🥕", "🍪", "🍇", "🍞", "🧀"),
                tr("שִׂימוּ אֶת הַחַיּוֹת בַּסַּל שֶׁיֵּשׁ עָלָיו כֶּלֶב וְחָתוּל, וְאֶת הָאֹכֶל בַּסַּל שֶׁיֵּשׁ עָלָיו תַּפּוּחַ וּבַנָּנָה."))
            1 -> set("🐘", "🐭", listOf("🐋", "🚌", "🏠", "🌳", "🚂", "🦒"), listOf("🐜", "🐞", "🔑", "🍓", "🪙", "🦷"),
                tr("שִׂימוּ כָּל דָּבָר גָּדוֹל בַּסַּל שֶׁל הַפִּיל, וְכָל דָּבָר קָטָן בַּסַּל שֶׁל הָעַכְבָּר."))
            2 -> set("🌊", "🌳", listOf("🐟", "🐙", "🐬", "🦈", "🐳", "🦀"), listOf("🦁", "🐘", "🐶", "🐴", "🐓", "🦒"),
                tr("שִׂימוּ אֶת מִי שֶׁחַי בַּמַּיִם בַּסַּל שֶׁל הַגַּלִּים, וְאֶת מִי שֶׁחַי בַּיַּבָּשָׁה בַּסַּל שֶׁל הָעֵץ."))
            else -> set("🔴", "🔵", listOf("🍎", "🍓", "🌹", "🚒", "🟥", "❤️"), listOf("🫐", "🔵", "🟦", "💙", "🌊", "🐳"),
                tr("שִׂימוּ כָּל דָּבָר אָדֹם בַּסַּל הָאָדֹם, וְכָל דָּבָר כָּחֹל בַּסַּל הַכָּחֹל."))
        }
    }

    /** Six items, three from each basket, shuffled. */
    fun basketRound(set: SortSet): List<SortItem> = SortSets.round(set, ROUND_ITEMS)

    // MARK: - 🔗 Pairs

    /** 🔗 What goes with what — nothing to read, nothing to know, only to think. */
    private val goesTogether = listOf(
        "🐟" to "🌊", "🚗" to "🛣️", "🍌" to "🐵", "🦴" to "🐶", "🥕" to "🐰",
        "🧦" to "🦶", "☂️" to "🌧️", "🪥" to "🦷", "🔑" to "🚪", "🐝" to "🌸",
        "🥛" to "🐄", "⚽" to "🥅", "✏️" to "📒", "🍼" to "👶", "🐛" to "🦋",
        "🥚" to "🐣", "🌱" to "🌳", "🐑" to "🧶", "🧊" to "❄️", "🍯" to "🐻",
        "🌙" to "⭐", "☀️" to "🕶️", "🐦" to "🪶", "🌾" to "🍞",
    )

    data class PairsRound(val pairs: List<MatchPair>, val cue: PreReaderCue)

    fun pairs(count: Int = PAIR_COUNT): PairsRound = PairsRound(
        goesTogether.shuffled().take(count).map { MatchPair(it.first, it.second) },
        PreReaderCue(spoken = tr("חַבְּרוּ כָּל תְּמוּנָה לַתְּמוּנָה שֶׁהוֹלֶכֶת אִתָּהּ!")),
    )

    // MARK: - 🧠 The pattern

    val patternSets: List<List<String>>
        get() = listOf(
            listOf("🔴", "🔵", "🟡", "🟢"),
            listOf("⭐", "❤️", "🔺", "🟦"),
            listOf("🐶", "🐱", "🐰", "🦁"),
            listOf("🍎", "🍌", "🍇", "🍉"),
            listOf("🚗", "🚂", "✈️", "🚲"),
            listOf("🌸", "🌳", "🍄", "🌻"),
        )

    val patternCue: PreReaderCue
        get() = PreReaderCue(spoken = tr("מָה מַמְשִׁיךְ אֶת הַסִּדְרָה? בַּחֲרוּ אֶת הַתְּמוּנָה הַבָּאָה!"))

    // MARK: - 🧱 Collecting

    /** 🧱 גן counting: tap the ONE card that has exactly N (composing groups is a first-grade skill). */
    data class Collect(val emoji: String, val target: Int, val cards: List<Int>, val cue: PreReaderCue)

    fun collecting(): Collect {
        val (emoji, plural) = countables.random()
        val target = (2..5).random()
        // Five more cards, each a DIFFERENT count from the target; each remaining count once before repeats.
        val others = (1..5).filter { it != target }.shuffled()
        val cards = (listOf(target) + others).toMutableList()
        while (cards.size < COUNTING_CARDS) cards += others.randomOrNull() ?: 1
        return Collect(emoji, target, cards.shuffled(),
            PreReaderCue(List(target) { emoji }, tr("בַּחֲרוּ אֶת הַכַּרְטִיס שֶׁיֵּשׁ בּוֹ בְּדִיּוּק %@!", countPhrase(target, plural))))
    }

    // MARK: - 🧰 Shared chrome copy (spoken only)

    val startCue: String get() = tr("בּוֹאוּ נְשַׂחֵק!")
    val wellDone: String get() = tr("כָּל הַכָּבוֹד! אַלּוּפִים!")
    /** A gentle nudge, for the ear only — never printed, and never a failure. */
    val almost: String get() = tr("כִּמְעַט! נְנַסֶּה שׁוּב.")
}

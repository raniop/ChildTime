package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.BankQuestion
import com.rani.tofy.kid.content.ContentAvailability
import com.rani.tofy.kid.content.CurriculumMath
import com.rani.tofy.kid.content.QuestionBanks
import com.rani.tofy.kid.content.QuestionPacks
import com.rani.tofy.kid.content.Question
import com.rani.tofy.ui.child.Topic
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

// 🎮 MiniGameContent.swift — the content side of the mini-games:
//   🧱 CrushBoards · 🔗 MatchPairsSource · 🎈 BalloonSets · 🧩 WordSets /
//   🔤 WordSearch · ⚡ LightningStatements · ⚡ SurpriseRound.
// A ⚡ surprise round pays ⭐ and 💎 only. A game opened from a world's chooser
// earns minutes through the runner's own path (MiniGameEarning.kt).

/** Swift `String.count` — grapheme clusters, not UTF-16 units (emoji count as one). */
internal fun String.graphemes(): Int {
    val it = java.text.BreakIterator.getCharacterInstance()
    it.setText(this)
    var n = 0
    while (it.next() != java.text.BreakIterator.DONE) n++
    return n
}

// MARK: - 🧮 Computed math facts

object MathFacts {
    data class Fact(val expression: String, val answer: Int)

    private fun r(a: Int, b: Int) = (a..b).random()
    private fun coin() = kotlin.random.Random.nextBoolean()

    /** A grade-appropriate fact, computed — one short line (CurriculumMath's ladder). */
    fun fact(grade: Int): Fact {
        val g = max(1, grade)
        when (g) {
            1 -> {
                val a = r(1, 10); val b = r(1, 10)
                return if (coin()) Fact("$a + $b", a + b) else Fact("${max(a, b)} − ${min(a, b)}", max(a, b) - min(a, b))
            }
            2 -> return when (r(0, 2)) {
                0 -> { val a = r(11, 60); val b = r(2, 30); Fact("$a + $b", a + b) }
                1 -> { val a = r(30, 99); val b = r(2, 29); Fact("$a − $b", a - b) }
                else -> { val a = listOf(2, 5, 10).random(); val b = r(1, 10); Fact("$b × $a", a * b) }
            }
            3 -> {
                val a = r(2, 10); val b = r(2, 10)
                return if (r(0, 3) == 0) Fact("${a * b} ÷ $a", b) else Fact("$a × $b", a * b)
            }
            4 -> return when (r(0, 2)) {
                0 -> { val a = r(3, 12); val b = r(3, 12); Fact("$a × $b", a * b) }
                1 -> { val a = r(12, 40); val b = r(2, 5); Fact("$a × $b", a * b) }
                else -> { val a = r(3, 12); val b = r(3, 12); Fact("${a * b} ÷ $a", b) }
            }
            5 -> return when (r(0, 2)) {
                0 -> { val a = r(6, 12); val b = r(6, 12); Fact("$a × $b", a * b) }
                1 -> { val a = r(2, 20); val b = r(2, 9); val c = r(2, 9); Fact("$a + $b × $c", a + b * c) }
                else -> { val a = r(6, 12); val b = r(6, 12); Fact("${a * b} ÷ $a", b) }
            }
            6 -> return when (r(0, 3)) {
                // ו׳: brackets, three-digit × one-digit, long division.
                0 -> { val a = r(2, 9); val b = r(2, 9); val c = r(2, 12); Fact("($a + $b) × $c", (a + b) * c) }
                1 -> { val a = r(11, 40); val b = r(3, 9); Fact("$a × $b", a * b) }
                2 -> { val b = r(3, 9); val q = r(11, 40); Fact("${b * q} ÷ $b", q) }
                else -> { val a = r(2, 9); val b = r(2, 9); val c = r(2, 9); Fact("$a × $b − $c", a * b - c) }
            }
            7 -> return when (r(0, 2)) {
                // ז׳: signed numbers and powers.
                0 -> { val a = r(2, 12); val b = r(2, 15); Fact("(−$a) + $b", b - a) }
                1 -> { val a = r(2, 12); val b = r(2, 12); Fact("(−$a) × $b", -a * b) }
                else -> { val a = r(2, 15); Fact("$a²", a * a) }
            }
            else -> return when (r(0, 3)) {
                // ח׳: roots, cubes, a product of two negatives, a difference of squares.
                0 -> { val a = r(4, 20); Fact("√${a * a}", a) }
                1 -> { val a = r(2, 8); Fact("$a³", a * a * a) }
                2 -> { val a = r(2, 12); val b = r(2, 12); Fact("(−$a) × (−$b)", a * b) }
                else -> { val a = r(2, 9); val b = r(2, 6); Fact("$a² − $b²", a * a - b * b) }
            }
        }
    }

    /** "−4" with a real minus sign. */
    fun show(n: Int): String = if (n < 0) "−${abs(n)}" else "$n"
}

// MARK: - 🔗 Match pairs

data class MatchPair(val left: String, val right: String)

sealed class MatchPairsSource {
    data object Capitals : MatchPairsSource()
    data object EnglishWords : MatchPairsSource()
    data object Math : MatchPairsSource()
    data class Bank(val t: Topic) : MatchPairsSource()

    /** The topic the board's answers are recorded under (parent reports). */
    val topic: Topic
        get() = when (this) {
            Capitals -> Topic.GEOGRAPHY
            EnglishWords -> Topic.ENGLISH
            Math -> Topic.MATH
            is Bank -> t
        }

    /** Five pairs with five DIFFERENT right-hand items; a bank board that can't fill falls back to math. */
    fun pairs(count: Int, grade: Int): Pair<MatchPairsSource, List<MatchPair>> = when (this) {
        Math -> this to mathPairs(count, grade)
        Capitals -> this to capitalPairs(count, grade)
        EnglishWords -> this to englishPairs(count, grade)
        is Bank -> {
            val p = bankPairs(t, count, grade)
            if (p.size == count) this to p else Math to mathPairs(count, grade)
        }
    }

    companion object {
        /** Which board fits the world it was opened from. */
        fun pick(topic: Topic?, grade: Int): MatchPairsSource = when {
            topic == Topic.MATH -> Math
            topic == Topic.ENGLISH -> EnglishWords
            topic == Topic.FLAGS || topic == Topic.GEOGRAPHY -> if (grade >= 2) Capitals else Math
            topic != null && topic != Topic.READING && topic != Topic.HOLIDAYS -> Bank(topic)
            else -> {
                // Opened without a world: mix.
                val options = mutableListOf<MatchPairsSource>(Math)
                if (grade >= 2) options += Capitals
                if (grade >= 1) options += EnglishWords
                options.random()
            }
        }

        fun mathPairs(count: Int, grade: Int): List<MatchPair> {
            val out = mutableListOf<MatchPair>()
            val seenAnswers = HashSet<Int>(); val seenExpr = HashSet<String>()
            var tries = 0
            while (out.size < count && tries < 200) {
                tries++
                val f = MathFacts.fact(grade)
                if (f.answer in seenAnswers || f.expression in seenExpr) continue
                seenAnswers += f.answer; seenExpr += f.expression
                out += MatchPair(CurriculumMath.ltr(f.expression), CurriculumMath.ltr(MathFacts.show(f.answer)))
            }
            return out
        }

        data class Capital(val flag: String, val country: String, val city: String, val easy: Boolean)

        /** Timeless, uncontested capitals (Israel left out on purpose — the board ships in Arabic too). */
        val capitalList: List<Capital>
            get() = listOf(
                Capital("🇫🇷", tr("צָרְפַת"), tr("פָּרִיז"), true),
                Capital("🇮🇹", tr("אִיטַלְיָה"), tr("רוֹמָא"), true),
                Capital("🇬🇧", tr("בְּרִיטַנְיָה"), tr("לוֹנְדוֹן"), true),
                Capital("🇯🇵", tr("יַפָּן"), tr("טוֹקְיוֹ"), true),
                Capital("🇪🇸", tr("סְפָרַד"), tr("מַדְרִיד"), true),
                Capital("🇩🇪", tr("גֶּרְמַנְיָה"), tr("בֶּרְלִין"), true),
                Capital("🇺🇸", tr("אַרְצוֹת הַבְּרִית"), tr("וָשִׁינְגְּטוֹן"), true),
                Capital("🇬🇷", tr("יָוָן"), tr("אָתוּנָה"), true),
                Capital("🇷🇺", tr("רוּסְיָה"), tr("מוֹסְקְבָה"), true),
                Capital("🇪🇬", tr("מִצְרַיִם"), tr("קָהִיר"), true),
                Capital("🇨🇳", tr("סִין"), tr("בֵּייגִ'ינְג"), false),
                Capital("🇨🇦", tr("קָנָדָה"), tr("אוֹטָוָה"), false),
                Capital("🇦🇺", tr("אוֹסְטְרַלְיָה"), tr("קַנְבֶּרָה"), false),
                Capital("🇧🇷", tr("בְּרָזִיל"), tr("בְּרָזִילְיָה"), false),
                Capital("🇦🇷", tr("אַרְגֶּנְטִינָה"), tr("בּוּאֶנוֹס אַיְירֶס"), false),
                Capital("🇵🇹", tr("פּוֹרְטוּגָל"), tr("לִיסַבּוֹן"), false),
                Capital("🇳🇱", tr("הוֹלַנְד"), tr("אַמְסְטֶרְדָּם"), false),
                Capital("🇹🇷", tr("טוּרְקִיָּה"), tr("אַנְקָרָה"), false),
                Capital("🇰🇷", tr("דְּרוֹם קוֹרֵאָה"), tr("סֵאוּל"), false),
                Capital("🇮🇳", tr("הֹדּוּ"), tr("נְיוּ דֶּלְהִי"), false),
                Capital("🇸🇪", tr("שְׁוֶדְיָה"), tr("שְׁטוֹקְהוֹלְם"), false),
                Capital("🇦🇹", tr("אוֹסְטְרִיָּה"), tr("וִינָה"), false),
                Capital("🇹🇭", tr("תָּאִילַנְד"), tr("בַּנְגְקוֹק"), false),
                Capital("🇳🇴", tr("נוֹרְבֶגְיָה"), tr("אוֹסְלוֹ"), false),
            )

        fun capitalPairs(count: Int, grade: Int): List<MatchPair> {
            val all = capitalList
            val easy = all.filter { it.easy }; val hard = all.filter { !it.easy }
            val chosen = when {
                grade <= 3 -> easy.shuffled().take(count)
                grade == 4 -> easy.shuffled().take(3) + hard.shuffled().take(count - 3)
                else -> easy.shuffled().take(1) + hard.shuffled().take(count - 1)
            }
            return chosen.map { MatchPair("${it.flag} ${it.country}", it.city) }
        }

        private data class Word(val emoji: String, val label: String, val english: String)

        private val basicWords: List<Word>
            get() = listOf(
                Word("🐶", tr("כֶּלֶב"), "dog"),
                Word("🐱", tr("חָתוּל"), "cat"),
                Word("☀️", tr("שֶׁמֶשׁ"), "sun"),
                Word("🍎", tr("תַּפּוּחַ"), "apple"),
                Word("⚽", tr("כַּדּוּר"), "ball"),
                Word("🐟", tr("דָּג"), "fish"),
                Word("📖", tr("סֵפֶר"), "book"),
                Word("🚗", tr("מְכוֹנִית"), "car"),
                Word("🏠", tr("בַּיִת"), "house"),
                Word("🌳", tr("עֵץ"), "tree"),
                Word("🥛", tr("חָלָב"), "milk"),
                Word("🐦", tr("צִפּוֹר"), "bird"),
                Word("⭐", tr("כּוֹכָב"), "star"),
                Word("🌙", tr("יָרֵחַ"), "moon"),
                Word("🌸", tr("פֶּרַח"), "flower"),
                Word("🐮", tr("פָּרָה"), "cow"),
                Word("🦁", tr("אַרְיֵה"), "lion"),
                Word("🍞", tr("לֶחֶם"), "bread"),
                Word("💧", tr("מַיִם"), "water"),
            )

        /** ז׳–ח׳: textbook words, not hard spellings — the English ladder rises by vocabulary only. */
        private val laterWords: List<Word>
            get() = listOf(
                Word("🌦️", tr("מַזָּג אֲוִיר"), "weather"),
                Word("📚", tr("סִפְרִיָּה"), "library"),
                Word("🍳", tr("אֲרוּחַת בֹּקֶר"), "breakfast"),
                Word("🌍", tr("עוֹלָם"), "world"),
                Word("🚑", tr("אַמְבּוּלַנְס"), "ambulance"),
                Word("🏥", tr("בֵּית חוֹלִים"), "hospital"),
                Word("🧪", tr("נִסּוּי"), "experiment"),
                Word("🗺️", tr("מַסָּע"), "journey"),
                Word("🌉", tr("גֶּשֶׁר"), "bridge"),
                Word("🏖️", tr("חוֹף"), "beach"),
                Word("🎒", tr("שִׁעוּרֵי בַּיִת"), "homework"),
                Word("🌡️", tr("טֶמְפֶּרָטוּרָה"), "temperature"),
                Word("🦷", tr("רוֹפֵא שִׁנַּיִם"), "dentist"),
                Word("🎟️", tr("כַּרְטִיס"), "ticket"),
            )

        private val advancedWords: List<Word>
            get() = listOf(
                Word("🏫", tr("בֵּית סֵפֶר"), "school"),
                Word("🤝", tr("חָבֵר"), "friend"),
                Word("👨‍👩‍👧", tr("מִשְׁפָּחָה"), "family"),
                Word("🍳", tr("מִטְבָּח"), "kitchen"),
                Word("🪟", tr("חַלּוֹן"), "window"),
                Word("🌧️", tr("גֶּשֶׁם"), "rain"),
                Word("🐴", tr("סוּס"), "horse"),
                Word("🪑", tr("כִּסֵּא"), "chair"),
                Word("✈️", tr("מָטוֹס"), "airplane"),
                Word("🎂", tr("עוּגָה"), "cake"),
                Word("🐘", tr("פִּיל"), "elephant"),
                Word("🧀", tr("גְּבִינָה"), "cheese"),
                Word("🕐", tr("שָׁעוֹן"), "clock"),
                Word("🏔️", tr("הַר"), "mountain"),
                Word("❄️", tr("שֶׁלֶג"), "snow"),
                Word("👟", tr("נַעַל"), "shoe"),
                Word("🎒", tr("תִּיק"), "bag"),
            )

        /** Own-language word ↔ English word; in English the left side is the picture alone. */
        fun englishPairs(count: Int, grade: Int): List<MatchPair> {
            val list = when (MiniGameBand.of(grade)) {
                MiniGameBand.PRE_READER, MiniGameBand.LOWER, MiniGameBand.MIDDLE -> basicWords
                MiniGameBand.UPPER -> basicWords.shuffled().take(2) + advancedWords
                MiniGameBand.TOP -> advancedWords.shuffled().take(3) + laterWords
            }
            val pictureOnly = GameEnv.lang == AppLanguage.EN
            return list.shuffled().take(count).map { w -> MatchPair(if (pictureOnly) w.emoji else "${w.emoji} ${w.label}", w.english) }
        }

        /** Short prompt ↔ answer pairs from the world's own bank, five different answers. */
        fun bankPairs(topic: Topic, count: Int, grade: Int): List<MatchPair> =
            GameContent.distinctAnswers(GameContent.items(topic, grade, maxPrompt = 60, maxAnswer = 24, standalone = true))
                .take(count).map { MatchPair(it.prompt, it.answer) }
    }
}

// MARK: - 🎈 Balloon sets

data class BalloonItem(
    val emoji: String,
    val label: String,
    val correct: Boolean,
    /** 👶 A גן colour round: the balloon's own fill IS the answer. */
    val colorHex: String? = null,
)

/** One balloon round: the rule, and the items that float up — to pop and to let fly. */
data class BalloonSet(val prompt: String, val topic: Topic, val targets: List<BalloonItem>, val others: List<BalloonItem>)

object BalloonSets {
    /** Does this world have balloons of its own? (Any other world pops the answers to its own questions.) */
    fun hasCategory(topic: Topic, grade: Int): Boolean = when (topic) {
        Topic.SEA, Topic.ANIMALS, Topic.SPACE, Topic.DINOSAURS, Topic.SOCCER, Topic.ENGLISH, Topic.SCIENCE, Topic.MATH -> true
        Topic.FLAGS, Topic.GEOGRAPHY -> grade >= 2
        else -> false
    }

    /** Two rungs per set: the picture-level sort for א׳–ד׳, a real classification from ה׳. */
    fun make(topic: Topic?, grade: Int): BalloonSet {
        val hard = MiniGameBand.of(grade) >= MiniGameBand.UPPER
        return when (topic) {
            Topic.SEA, Topic.ANIMALS -> seaAnimals(hard)
            Topic.FLAGS, Topic.GEOGRAPHY -> if (grade >= 2) capitals(grade) else numbers(grade)
            Topic.SPACE -> planets(hard)
            Topic.DINOSAURS -> dinosaurs(hard)
            Topic.SOCCER -> soccer(hard)
            Topic.ENGLISH -> englishWords(hard)
            Topic.SCIENCE -> if (kotlin.random.Random.nextBoolean()) planets(hard) else seaAnimals(hard)
            Topic.MATH -> numbers(grade)
            else -> {
                val all = mutableListOf<() -> BalloonSet>({ numbers(grade) }, { seaAnimals(hard) }, { planets(hard) })
                if (grade >= 2) all += { capitals(grade) }
                all.random()()
            }
        }
    }

    fun seaMammals(): BalloonSet = BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל הַיּוֹנְקִים שֶׁחַיִּים בַּיָּם!"),
        topic = Topic.SEA,
        targets = listOf(
            BalloonItem("🐬", tr("דּוֹלְפִין"), true),
            BalloonItem("🐳", tr("לִוְיָתָן"), true),
            BalloonItem("🦭", tr("כֶּלֶב יָם"), true),
            BalloonItem("🐋", tr("אוֹרְקָה"), true),
        ),
        others = listOf(
            BalloonItem("🦈", tr("כָּרִישׁ"), false),
            BalloonItem("🐙", tr("תְּמָנוּן"), false),
            BalloonItem("🪼", tr("מֵדוּזָה"), false),
            BalloonItem("🦀", tr("סַרְטָן"), false),
            BalloonItem("🐠", tr("דָּג"), false),
            BalloonItem("🐢", tr("צָב יָם"), false),
            BalloonItem("🦑", tr("דְּיוֹנוּן"), false),
            BalloonItem("⭐", tr("כּוֹכַב יָם"), false),
        ))

    fun seaAnimals(hard: Boolean = false): BalloonSet = if (hard) seaMammals() else BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל הַחַיּוֹת שֶׁחַיּוֹת בַּיָּם!"),
        topic = Topic.SEA,
        targets = listOf(
            BalloonItem("🐙", tr("תְּמָנוּן"), true),
            BalloonItem("🐬", tr("דּוֹלְפִין"), true),
            BalloonItem("🦈", tr("כָּרִישׁ"), true),
            BalloonItem("🐳", tr("לִוְיָתָן"), true),
            BalloonItem("🦀", tr("סַרְטָן"), true),
            BalloonItem("🐠", tr("דָּג"), true),
            BalloonItem("🪼", tr("מֵדוּזָה"), true),
            BalloonItem("⭐", tr("כּוֹכַב יָם"), true),
        ),
        others = listOf(
            BalloonItem("🦁", tr("אַרְיֵה"), false),
            BalloonItem("🐘", tr("פִּיל"), false),
            BalloonItem("🦒", tr("גִ'ירָפָה"), false),
            BalloonItem("🐄", tr("פָּרָה"), false),
            BalloonItem("🐎", tr("סוּס"), false),
            BalloonItem("🐒", tr("קוֹף"), false),
            BalloonItem("🐇", tr("אַרְנָב"), false),
            BalloonItem("🐫", tr("גָּמָל"), false),
        ))

    fun gasGiants(): BalloonSet = BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל כּוֹכְבֵי הַלֶּכֶת הַגָּזִיִּים!"),
        topic = Topic.SPACE,
        targets = listOf(
            BalloonItem("🟠", tr("צֶדֶק"), true),
            BalloonItem("🪐", tr("שַׁבְּתַאי"), true),
            BalloonItem("🟢", tr("אוּרָנוּס"), true),
            BalloonItem("🔵", tr("נֶפְּטוּן"), true),
        ),
        others = listOf(
            BalloonItem("🟤", tr("כּוֹכָב חַמָּה"), false),
            BalloonItem("🟡", tr("נֹגַהּ"), false),
            BalloonItem("🌍", tr("כַּדּוּר הָאָרֶץ"), false),
            BalloonItem("🔴", tr("מַאְדִּים"), false),
            BalloonItem("🌙", tr("הַיָּרֵחַ"), false),
            BalloonItem("☄️", tr("שָׁבִיט"), false),
            BalloonItem("🪨", tr("אַסְטֶרוֹאִיד"), false),
        ))

    fun planets(hard: Boolean = false): BalloonSet = if (hard) gasGiants() else BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל כּוֹכְבֵי הַלֶּכֶת!"),
        topic = Topic.SPACE,
        targets = listOf(
            BalloonItem("🌍", tr("כַּדּוּר הָאָרֶץ"), true),
            BalloonItem("🔴", tr("מַאְדִּים"), true),
            BalloonItem("🪐", tr("שַׁבְּתַאי"), true),
            BalloonItem("🟠", tr("צֶדֶק"), true),
            BalloonItem("🔵", tr("נֶפְּטוּן"), true),
            BalloonItem("🟡", tr("נֹגַהּ"), true),
            BalloonItem("🟤", tr("כּוֹכָב חַמָּה"), true),
            BalloonItem("🟢", tr("אוּרָנוּס"), true),
        ),
        others = listOf(
            BalloonItem("☀️", tr("הַשֶּׁמֶשׁ"), false),
            BalloonItem("🌙", tr("הַיָּרֵחַ"), false),
            BalloonItem("☄️", tr("שָׁבִיט"), false),
            BalloonItem("🌌", tr("גָּלַקְסְיָה"), false),
            BalloonItem("🛰️", tr("לַוְיָן"), false),
            BalloonItem("🕳️", tr("חוֹר שָׁחֹר"), false),
            BalloonItem("🪨", tr("אַסְטֶרוֹאִיד"), false),
        ))

    fun dinosaurCarnivores(): BalloonSet = BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל הַדִּינוֹזָאוּרִים שֶׁאָכְלוּ בָּשָׂר!"),
        topic = Topic.DINOSAURS,
        targets = listOf(
            BalloonItem("🦖", tr("טִירָנוֹזָאוּרוּס"), true),
            BalloonItem("🦖", tr("וֶלוֹצִירַפְּטוֹר"), true),
            BalloonItem("🦖", tr("סְפִּינוֹזָאוּרוּס"), true),
            BalloonItem("🦖", tr("אַלוֹזָאוּרוּס"), true),
            BalloonItem("🦖", tr("דִּילוֹפוֹזָאוּרוּס"), true),
        ),
        others = listOf(
            BalloonItem("🦴", tr("טְרִיצֶרָטוֹפְּס"), false),
            BalloonItem("🦴", tr("סְטֶגוֹזָאוּרוּס"), false),
            BalloonItem("🦕", tr("בְּרָכִיוֹזָאוּרוּס"), false),
            BalloonItem("🦕", tr("דִּיפְּלוֹדוֹקוּס"), false),
            BalloonItem("🦴", tr("אַנְקִילוֹזָאוּרוּס"), false),
            BalloonItem("🦕", tr("פָּרָזָאוּרוֹלוֹפוּס"), false),
        ))

    fun dinosaurs(hard: Boolean = false): BalloonSet = if (hard) dinosaurCarnivores() else BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל הַדִּינוֹזָאוּרִים!"),
        topic = Topic.DINOSAURS,
        targets = listOf(
            BalloonItem("🦖", tr("טִירָנוֹזָאוּרוּס"), true),
            BalloonItem("🦕", tr("בְּרָכִיוֹזָאוּרוּס"), true),
            BalloonItem("🦕", tr("דִּיפְּלוֹדוֹקוּס"), true),
            BalloonItem("🦖", tr("וֶלוֹצִירַפְּטוֹר"), true),
            BalloonItem("🦴", tr("טְרִיצֶרָטוֹפְּס"), true),
            BalloonItem("🦴", tr("סְטֶגוֹזָאוּרוּס"), true),
            BalloonItem("🦴", tr("אַנְקִילוֹזָאוּרוּס"), true),
        ),
        others = listOf(
            BalloonItem("🐊", tr("תַּנִּין"), false),
            BalloonItem("🦣", tr("מָמוּתָה"), false),
            BalloonItem("🦎", tr("לְטָאָה"), false),
            BalloonItem("🐢", tr("צָב"), false),
            BalloonItem("🦏", tr("קַרְנַף"), false),
            BalloonItem("🐍", tr("נָחָשׁ"), false),
            BalloonItem("🐘", tr("פִּיל"), false),
        ))

    fun soccerRoles(): BalloonSet = BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל תַּפְקִידֵי הַהֲגָנָה!"),
        topic = Topic.SOCCER,
        targets = listOf(
            BalloonItem("🧤", tr("שׁוֹעֵר"), true),
            BalloonItem("🛡️", tr("בַּלָּם"), true),
            BalloonItem("🛡️", tr("מֵגֵן"), true),
        ),
        others = listOf(
            BalloonItem("🎯", tr("חָלוּץ"), false),
            BalloonItem("🎯", tr("כַּנְפָן"), false),
            BalloonItem("🔄", tr("קַשָּׁר"), false),
            BalloonItem("🧑‍🏫", tr("מְאַמֵּן"), false),
            BalloonItem("🧑‍⚖️", tr("שׁוֹפֵט"), false),
            BalloonItem("📣", tr("אוֹהֵד"), false),
        ))

    fun soccer(hard: Boolean = false): BalloonSet = if (hard) soccerRoles() else BalloonSet(
        prompt = tr("פּוֹצְצוּ אֶת כָּל מַה שֶּׁשַּׁיָּךְ לְכַדּוּרֶגֶל!"),
        topic = Topic.SOCCER,
        targets = listOf(
            BalloonItem("⚽", tr("כַּדּוּר"), true),
            BalloonItem("🥅", tr("שַׁעַר"), true),
            BalloonItem("🧤", tr("שׁוֹעֵר"), true),
            BalloonItem("🟨", tr("כַּרְטִיס צָהֹב"), true),
            BalloonItem("🟥", tr("כַּרְטִיס אָדֹם"), true),
            BalloonItem("🚩", tr("נִבְדָּל"), true),
            BalloonItem("🎯", tr("פֶּנְדֵּל"), true),
            BalloonItem("🏳️", tr("קֶרֶן"), true),
        ),
        others = listOf(
            BalloonItem("🏀", tr("כַּדּוּרְסַל"), false),
            BalloonItem("🎾", tr("טֶנִיס"), false),
            BalloonItem("🏓", tr("פִּינְג פּוֹנְג"), false),
            BalloonItem("⛳", tr("גּוֹלְף"), false),
            BalloonItem("🥊", tr("אִגְרוּף"), false),
            BalloonItem("🛹", tr("סְקֵייטְבּוֹרְד"), false),
            BalloonItem("🏸", tr("בַּדְמִינְטוֹן"), false),
        ))

    private sealed class Rule {
        data object Even : Rule(); data object Odd : Rule(); data class Multiple(val n: Int) : Rule()
        data object Square : Rule(); data object Prime : Rule()
    }

    internal fun isPrime(n: Int): Boolean {
        if (n <= 1) return false
        if (n < 4) return true
        if (n % 2 == 0) return false
        var d = 3
        while (d * d <= n) { if (n % d == 0) return false; d += 2 }
        return true
    }

    /** Even / odd / multiples of n / squares / primes — the rule and the range both climb. */
    fun numbers(grade: Int): BalloonSet {
        val g = max(1, grade)
        val band = MiniGameBand.of(g)
        val top = when (band) {
            MiniGameBand.PRE_READER, MiniGameBand.LOWER -> if (g <= 1) 20 else 100
            MiniGameBand.MIDDLE -> 200
            MiniGameBand.UPPER -> 500
            MiniGameBand.TOP -> 1000
        }
        val rules = mutableListOf<Rule>()
        if (band <= MiniGameBand.MIDDLE) rules += listOf(Rule.Even, Rule.Odd)
        if (g >= 3) rules += Rule.Multiple(listOf(3, 4, 5).random())
        if (g >= 5) rules += listOf(Rule.Multiple(listOf(6, 7, 9).random()), Rule.Square)
        if (g >= 6) rules += Rule.Multiple(listOf(11, 12, 15).random())
        if (g >= 7) rules += Rule.Prime
        val rule = rules.randomOrNull() ?: Rule.Even
        val squares = (1..40).map { it * it }.toSet()
        val (prompt, isTarget) = when (rule) {
            Rule.Even -> tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הַזּוּגִיִּים!") to { n: Int -> n % 2 == 0 }
            Rule.Odd -> tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הָאִי־זוּגִיִּים!") to { n: Int -> n % 2 == 1 }
            is Rule.Multiple -> tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים שֶׁמִּתְחַלְּקִים בְּ־%lld!", rule.n) to { n: Int -> n % rule.n == 0 }
            Rule.Square -> tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הָרִבּוּעִיִּים!") to { n: Int -> n in squares }
            Rule.Prime -> tr("פּוֹצְצוּ אֶת כָּל הַמִּסְפָּרִים הָרִאשׁוֹנִיִּים!") to { n: Int -> isPrime(n) }
        }
        val pool = (1..top).shuffled()
        // A sparse rule (squares, primes) needs its targets found across the WHOLE range.
        val targets = pool.filter(isTarget).take(14).map { BalloonItem("", "$it", true) }
        // Near misses: a square's neighbours, a prime's odd neighbours.
        val misses = pool.filter { !isTarget(it) && (isTarget(it - 1) || isTarget(it + 1)) }.take(7)
        val rest = pool.filter { !isTarget(it) && it !in misses }.take(14 - misses.size)
        val others = (misses + rest).map { BalloonItem("", "$it", false) }
        return BalloonSet(prompt, Topic.MATH, targets, others)
    }

    /** Capitals against big cities that are NOT capitals — each with its flag. */
    fun capitals(grade: Int): BalloonSet {
        val list = if (MiniGameBand.of(grade) >= MiniGameBand.UPPER) MatchPairsSource.capitalList
        else MatchPairsSource.capitalList.filter { it.easy }
        return BalloonSet(
            prompt = tr("פּוֹצְצוּ אֶת כָּל עָרֵי הַבִּירָה!"),
            topic = Topic.GEOGRAPHY,
            targets = list.map { BalloonItem(it.flag, it.city, true) },
            others = listOf(
                BalloonItem("🇪🇸", tr("בַּרְצֶלוֹנָה"), false),
                BalloonItem("🇮🇹", tr("מִילָאנוֹ"), false),
                BalloonItem("🇬🇧", tr("מַנְצֶ'סְטֶר"), false),
                BalloonItem("🇯🇵", tr("אוֹסָקָה"), false),
                BalloonItem("🇩🇪", tr("מִינְכֶן"), false),
                BalloonItem("🇺🇸", tr("נְיוּ יוֹרְק"), false),
                BalloonItem("🇦🇺", tr("סִידְנִי"), false),
                BalloonItem("🇹🇷", tr("אִיסְטַנְבּוּל"), false),
                BalloonItem("🇧🇷", tr("רִיוֹ דֶה זָ'נֵירוֹ"), false),
            ),
        )
    }

    /** English words, no pictures: ג׳–ד׳ animals vs everything; ה׳+ VERBS vs nouns. */
    fun englishWords(hard: Boolean = false): BalloonSet {
        if (hard) return BalloonSet(
            tr("פּוֹצְצוּ אֶת כָּל הַפְּעָלִים בְּאַנְגְּלִית!"), Topic.ENGLISH,
            listOf("run", "eat", "jump", "write", "sing", "read", "swim", "drink", "sleep", "think").map { BalloonItem("", it, true) },
            listOf("table", "water", "school", "friend", "window", "garden", "bread", "river", "chair", "flower").map { BalloonItem("", it, false) },
        )
        return BalloonSet(
            tr("פּוֹצְצוּ אֶת כָּל הַחַיּוֹת בְּאַנְגְּלִית!"), Topic.ENGLISH,
            listOf("dog", "cat", "horse", "lion", "fish", "bird", "cow", "monkey", "duck").map { BalloonItem("", it, true) },
            listOf("apple", "car", "book", "tree", "house", "chair", "milk", "bread", "shoe").map { BalloonItem("", it, false) },
        )
    }
}

// MARK: - 🧩 Build-the-word sets

/** One word to build: the picture (the only clue) and the word's letters in order. */
data class SpellWord(val emoji: String, val word: String)

object WordSets {
    const val WORD_COUNT = 5

    /** English world spells English, Hebrew world Hebrew; a surprise round by language and grade. */
    fun script(topic: Topic?, grade: Int): SpellScript = when (topic) {
        Topic.ENGLISH -> SpellScript.ENGLISH
        Topic.HEBREW -> SpellScript.HEBREW
        else -> when {
            GameEnv.lang == AppLanguage.EN -> SpellScript.ENGLISH
            GameEnv.lang == AppLanguage.HE && grade < 3 -> SpellScript.HEBREW
            else -> SpellScript.ENGLISH
        }
    }

    /** A world with its own picture list (the rest spell their own answers). */
    fun hasThemedList(topic: Topic?, grade: Int): Boolean = when (topic) {
        Topic.ENGLISH, Topic.HEBREW -> true
        Topic.SOCCER, Topic.SEA, Topic.SPACE, Topic.ANIMALS, Topic.DINOSAURS, Topic.FLAGS -> spellingAvailable(grade)
        else -> false
    }

    /** An English or Hebrew speaker always; ru/ar from ג׳ (when English starts at school). */
    fun spellingAvailable(grade: Int): Boolean = when (GameEnv.lang) {
        AppLanguage.EN, AppLanguage.HE -> true
        else -> grade >= 3
    }

    /** The five words one spelling board shows. */
    fun words(topic: Topic?, script: SpellScript, grade: Int, maxLetters: Int = 8): List<SpellWord> =
        list(topic, script, grade, maxLetters).take(WORD_COUNT)

    /** The child's own rung of the ladder, already shuffled. */
    fun list(topic: Topic?, script: SpellScript, grade: Int, maxLetters: Int = 8): List<SpellWord> = when (script) {
        SpellScript.HEBREW -> HebrewLadder.words(topic, grade, maxLetters, WORD_COUNT)
        SpellScript.ENGLISH, SpellScript.CYRILLIC, SpellScript.ARABIC -> english(topic, grade, maxLetters)
    }

    private fun english(topic: Topic?, grade: Int, maxLetters: Int): List<SpellWord> {
        fun w(e: String, s: String) = SpellWord(e, s)
        val themed = when (topic) {
            Topic.SOCCER -> listOf(w("⚽", "ball"), w("🥅", "goal"), w("👟", "shoe"), w("🚩", "flag"), w("🏆", "cup"), w("🧤", "glove"))
            Topic.SEA -> listOf(w("🐟", "fish"), w("🦀", "crab"), w("🦈", "shark"), w("🐳", "whale"), w("🐚", "shell"), w("🐙", "octopus"))
            Topic.SPACE -> listOf(w("☀️", "sun"), w("🌙", "moon"), w("⭐", "star"), w("🚀", "rocket"), w("🪐", "planet"), w("👽", "alien"))
            Topic.ANIMALS -> listOf(w("🐶", "dog"), w("🐱", "cat"), w("🐄", "cow"), w("🦁", "lion"), w("🐴", "horse"), w("🦆", "duck"), w("🐸", "frog"))
            Topic.DINOSAURS -> listOf(w("🦴", "bone"), w("🥚", "egg"), w("🦷", "tooth"), w("🍃", "leaf"), w("🪨", "rock"), w("🌋", "volcano"))
            Topic.FLAGS -> listOf(w("🚩", "flag"), w("🗺️", "map"), w("🏙️", "city"), w("🚢", "ship"), w("✈️", "plane"), w("🏝️", "island"))
            else -> emptyList()
        }
        val ladder = EnglishLadder.words(grade, maxLetters, WORD_COUNT, SpellScript.ENGLISH.isMotherTongue)
        if (themed.isEmpty()) return ladder
        val out = themed.filter { it.word.length <= maxLetters }.shuffled().toMutableList()
        if (out.size < WORD_COUNT) out += ladder.filter { l -> out.none { it.word == l.word } }
        return out
    }
}

// MARK: - 🔤 Word search

data class GridCell(val r: Int, val c: Int)

/** Cells in reading order (logical columns: 0 is where a line STARTS). */
data class HiddenWord(val word: String, val emoji: String, val cells: List<GridCell>)

class WordSearchBoard(
    val size: Int,
    /** letters[r][c], logical columns. */
    val letters: List<List<Char>>,
    val words: List<HiddenWord>,
    val script: SpellScript,
    /** The finger snaps the same way the board was built — the rule travels WITH the board. */
    val diagonals: Boolean,
    val backwards: Boolean,
)

object WordSearch {
    const val WORD_COUNT = 5

    /** 5 themed words hidden in the grid, the rest random letters. */
    fun make(topic: Topic?, script: SpellScript, grade: Int, size: Int): WordSearchBoard {
        val themed = WordSets.list(topic, script, grade, size)
        val general = WordSets.list(null, script, grade, size)
        val candidates = themed.toMutableList()
        for (g in general) if (candidates.none { it.word == g.word }) candidates += g
        return place(candidates.filter { it.word.length in 2..size }, script, grade, size)
    }

    /** The world's own short answers hidden in the grid (a world without a themed list). */
    fun make(words: List<SpellWord>, script: SpellScript, grade: Int, size: Int): WordSearchBoard =
        place(words.filter { it.word.length in 2..size }.shuffled(), script, grade, size)

    /** The drag snapped to a straight line from the start cell: across, down, or (when the board allows) diagonal. */
    fun snappedLine(s: GridCell, e: GridCell, n: Int, diagonals: Boolean): List<GridCell> {
        val dr = e.r - s.r; val dc = e.c - s.c
        val adr = abs(dr); val adc = abs(dc)
        if (adr == 0 && adc == 0) return listOf(s)
        var stepR = 0; var stepC = 0; val len: Int
        if (diagonals && adr > 0 && adc > 0 && min(adr, adc).toDouble() >= max(adr, adc) * 0.5) {
            stepR = Integer.signum(dr); stepC = Integer.signum(dc); len = max(adr, adc)
        } else if (adc >= adr) { stepC = Integer.signum(dc); len = adc }
        else { stepR = Integer.signum(dr); len = adr }
        val out = mutableListOf<GridCell>()
        for (i in 0..len) {
            val r = s.r + stepR * i; val c = s.c + stepC * i
            if (r !in 0 until n || c !in 0 until n) break
            out += GridCell(r, c)
        }
        return out
    }

    private fun place(candidates: List<SpellWord>, script: SpellScript, grade: Int, size: Int): WordSearchBoard {
        val diagonals = WordSearchShape.diagonals(grade, script)
        val backwards = WordSearchShape.backwards(grade, script)
        val directions = mutableListOf(0 to 1, 1 to 0)
        if (diagonals) directions += (1 to 1)
        if (backwards) {
            directions += listOf(0 to -1, -1 to 0)
            if (diagonals) directions += listOf(1 to -1, -1 to 1)
        }
        val grid = Array(size) { CharArray(size) { ' ' } }
        val placed = mutableListOf<HiddenWord>()
        val used = HashSet<String>()
        // The longest words first: they need the emptiest grid.
        for (cand in candidates.sortedByDescending { it.word.length }) {
            if (placed.size >= WORD_COUNT) break
            val word = script.display(cand.word)
            if (!used.add(word)) continue
            val letters = word.toList()
            val span = letters.size - 1
            var done = false
            var attempt = 0
            while (attempt < 200 && !done) {
                attempt++
                val (dr, dc) = directions.random()
                val rLo = if (dr < 0) span else 0; val rHi = if (dr > 0) size - 1 - span else size - 1
                val cLo = if (dc < 0) span else 0; val cHi = if (dc > 0) size - 1 - span else size - 1
                if (rLo > rHi || cLo > cHi) continue
                val r0 = (rLo..rHi).random(); val c0 = (cLo..cHi).random()
                val cells = letters.indices.map { GridCell(r0 + dr * it, c0 + dc * it) }
                val fits = cells.zip(letters).all { (cell, ch) -> grid[cell.r][cell.c] == ' ' || grid[cell.r][cell.c] == ch }
                if (!fits) continue
                for ((cell, ch) in cells.zip(letters)) grid[cell.r][cell.c] = ch
                placed += HiddenWord(word, cand.emoji, cells)
                done = true
            }
        }
        val alphabet = if (script == SpellScript.ENGLISH) "ABCDEFGHIJKLMNOPRSTUWY".toList() else script.alphabet
        for (r in 0 until size) for (c in 0 until size) if (grid[r][c] == ' ') grid[r][c] = alphabet.random()
        return WordSearchBoard(size, grid.map { it.toList() }, placed.shuffled(), script, diagonals, backwards)
    }
}

// MARK: - 🧱 Number crush

enum class CrushMode { SUM, PRODUCT, FRACTION, DECIMAL }

/** One "מְפַצְּחִים" round: whole units (twelfths, tenths) so the arithmetic is exact. */
data class CrushRules(val mode: CrushMode, val target: Int, val values: List<Int>) {
    fun display(v: Int): String = when (mode) {
        CrushMode.SUM, CrushMode.PRODUCT -> MathFacts.show(v)
        CrushMode.FRACTION -> when (v) {
            2 -> "⅙"; 3 -> "¼"; 4 -> "⅓"; 6 -> "½"; 8 -> "⅔"; 9 -> "¾"; 10 -> "⅚"; else -> "$v/12"
        }
        CrushMode.DECIMAL -> "0.$v"
    }

    val targetText: String get() = when (mode) { CrushMode.SUM, CrushMode.PRODUCT -> "$target"; else -> "1" }

    fun total(picked: List<Int>): Int = if (mode == CrushMode.PRODUCT) picked.fold(1) { a, b -> a * b } else picked.sum()

    /** Still on the way? A signed board can overshoot and come back (lets go after three blocks). */
    fun canStillReach(picked: List<Int>): Boolean {
        val t = total(picked)
        if (mode == CrushMode.PRODUCT) return t != 0 && abs(t) <= abs(target) && target % t == 0
        if (signed) return picked.size <= 3
        return t <= target
    }

    val signed: Boolean get() = values.any { it < 0 }

    fun hits(picked: List<Int>): Boolean = picked.size >= 2 && total(picked) == target

    /** "3 + 4" / "3 × 4" / "8 + (−5)". */
    fun expression(picked: List<Int>): String {
        val op = if (mode == CrushMode.PRODUCT) " × " else " + "
        return picked.joinToString(op) { v -> val s = display(v); if (v < 0 && picked.size > 1) "($s)" else s }
    }

    val symbol: String get() = if (mode == CrushMode.PRODUCT) "×" else "+"

    /** A value that pairs with `v` to hit the target, if there is one. */
    fun complement(v: Int): Int? {
        val c = if (mode == CrushMode.PRODUCT) {
            if (v <= 0 || target % v != 0) return null
            target / v
        } else target - v
        return if (c in values) c else null
    }
}

object CrushBoards {
    private fun stride(from: Int, through: Int, by: Int) = (from..through step by).toList()

    /** One rung per grade, following CurriculumMath (א׳ sums to 10 … ח׳ signed products, sums to 1000). */
    fun rules(grade: Int, topic: Topic?): CrushRules {
        val productChance = if (topic == Topic.MATH) 0.5 else 0.3
        fun roll() = kotlin.random.Random.nextDouble()
        return when (max(1, grade)) {
            1 -> CrushRules(CrushMode.SUM, 10, (1..9).toList())
            2 -> { val t = listOf(10, 12, 15, 20).random(); CrushRules(CrushMode.SUM, t, (1 until t).filter { it <= 15 }) }
            3 -> if (roll() < productChance) {
                val t = listOf(12, 18, 20, 24, 30).random()
                CrushRules(CrushMode.PRODUCT, t, listOf(2, 3, 4, 5, 6, 9, 10).filter { t % it == 0 && it < t })
            } else { val t = listOf(20, 25, 30).random(); CrushRules(CrushMode.SUM, t, (2..min(15, t - 2)).toList()) }
            4 -> if (roll() < productChance) {
                val t = listOf(36, 40, 48, 54, 60, 72).random()
                CrushRules(CrushMode.PRODUCT, t, listOf(2, 3, 4, 5, 6, 8, 9, 10, 12).filter { t % it == 0 && it < t })
            } else { val t = listOf(40, 50, 60).random(); CrushRules(CrushMode.SUM, t, (3..min(29, t - 3)).toList()) }
            5 -> when ((0..2).random()) {
                0 -> CrushRules(CrushMode.FRACTION, 12, listOf(2, 3, 4, 6, 8, 9, 10))
                1 -> CrushRules(CrushMode.DECIMAL, 10, (1..9).toList())
                else -> CrushRules(CrushMode.SUM, 100, stride(5, 95, 5))
            }
            6 -> when ((0..2).random()) {
                0 -> product(listOf(84, 96, 108, 120, 144), listOf(2, 3, 4, 6, 7, 8, 9, 12))
                1 -> CrushRules(CrushMode.FRACTION, 12, listOf(2, 3, 4, 6, 8, 9, 10))
                else -> { val t = listOf(150, 175, 200).random()
                    CrushRules(CrushMode.SUM, t, stride(25, 125, 25) + stride(10, 50, 10)) }
            }
            // ז׳: negative blocks, and a target that can be below zero.
            7 -> when ((0..1).random()) {
                0 -> { val t = listOf(-10, -6, -4, 4, 6, 10).random(); CrushRules(CrushMode.SUM, t, (-12..-1).toList() + (1..12).toList()) }
                else -> { val t = listOf(60, 72, 84, 90, 96).random()
                    CrushRules(CrushMode.PRODUCT, t, listOf(2, 3, 4, 5, 6, 7, 8, 9, 10, 12).filter { t % it == 0 && it < t }) }
            }
            else -> when ((0..2).random()) {
                0 -> { val t = listOf(-24, -18, 18, 24, 36).random(); CrushRules(CrushMode.SUM, t, (-20..-2).toList() + (2..20).toList()) }
                1 -> product(listOf(120, 144, 168, 180, 240), listOf(2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 15))
                else -> CrushRules(CrushMode.SUM, 1000, stride(50, 500, 50))
            }
        }
    }

    /**
     * A × round on the iOS target list — but only targets that two of the
     * round's own blocks can make. iOS's ו׳ list holds 120 with blocks
     * {2,3,4,6,8,12}, which no pair or triple reaches (and ח׳'s 240 has no
     * pair), so its "always solvable" guard could not hold there; Android skips
     * those targets rather than deal a board with no answer.
     */
    private fun product(targets: List<Int>, blocks: List<Int>): CrushRules {
        fun values(t: Int) = blocks.filter { t % it == 0 && it < t }
        val fair = targets.filter { t -> values(t).any { v -> t / v in values(t) } }
        val t = (fair.ifEmpty { targets }).random()
        return CrushRules(CrushMode.PRODUCT, t, values(t))
    }

    /** A product round mixes in a few non-divisors, so the board is a puzzle. */
    fun randomValue(rules: CrushRules): Int {
        if (rules.mode == CrushMode.PRODUCT && (0..3).random() == 0) {
            return listOf(7, 11, 14, 15, 16, 17).filter { rules.target % it != 0 }.randomOrNull() ?: rules.values.random()
        }
        return rules.values.random()
    }

    /**
     * The board must always hold a way to the target (NumberCrushView.ensureSolvable):
     * re-roll the NEW blocks a few times; failing that, turn one block into the
     * partner of another; failing that, rebuild two blocks from scratch.
     * `cols[c][0]` is the bottom block of column c.
     */
    fun <B> ensureSolvable(
        cols0: List<List<B>>, fresh0: Set<Long>, rules: CrushRules,
        id: (B) -> Long, value: (B) -> Int, remake: (B, Int) -> B,
    ): List<List<B>> {
        val cols = cols0.map { it.toMutableList() }
        val fresh = fresh0.toMutableSet()
        fun solvable() = isSolvable(cols.flatten().map(value), rules)
        var tries = 0
        while (!solvable() && tries < 8 && fresh.isNotEmpty()) {
            tries++
            for (c in cols.indices) for (r in cols[c].indices) {
                val old = cols[c][r]
                if (id(old) in fresh) {
                    val b = remake(old, randomValue(rules))
                    fresh.remove(id(old)); fresh.add(id(b))
                    cols[c][r] = b
                }
            }
        }
        if (solvable()) return cols
        // Plant a guaranteed pair: a block with a partner value, and another block turned into that partner.
        val positions = cols.indices.flatMap { c -> cols[c].indices.map { c to it } }.shuffled()
        for (p in positions) {
            val partner = rules.complement(value(cols[p.first][p.second])) ?: continue
            val others = positions.filter { it != p }
            val q = others.firstOrNull { id(cols[it.first][it.second]) in fresh } ?: others.firstOrNull() ?: continue
            cols[q.first][q.second] = remake(cols[q.first][q.second], partner)
            return cols
        }
        // Nothing has a partner (a × round full of odd blocks): rebuild two blocks.
        val v = rules.values.shuffled().firstOrNull { rules.complement(it) != null }
        if (positions.size >= 2 && v != null) {
            val partner = rules.complement(v)!!
            val (p, q) = positions[0] to positions[1]
            cols[p.first][p.second] = remake(cols[p.first][p.second], v)
            cols[q.first][q.second] = remake(cols[q.first][q.second], partner)
        }
        return cols
    }

    /** Is there at least one pair or triple on the board that hits the target? */
    fun isSolvable(board: List<Int>, rules: CrushRules): Boolean {
        val n = board.size
        for (i in 0 until n) for (j in i + 1 until n) {
            if (rules.hits(listOf(board[i], board[j]))) return true
            for (k in j + 1 until n) if (rules.hits(listOf(board[i], board[j], board[k]))) return true
        }
        return false
    }
}

// MARK: - ⚡ True / false statements

/** One card of "נָכוֹן אוֹ לֹא נָכוֹן?": an optional question line, the claim, and whether it is true. */
data class LightningStatement(val prompt: String?, val claim: String, val isTrue: Boolean, val topic: Topic)

object LightningStatements {
    /** Half the cards are true. Math is computed; everything else is a short bank question. */
    fun make(topic: Topic?, grade: Int, seen: MutableSet<String>): LightningStatement {
        val mathShare = when (topic) { Topic.MATH -> 1.0; null -> 0.5; else -> 0.2 }
        if (kotlin.random.Random.nextDouble() >= mathShare) fromBank(topic, grade, seen)?.let { return it }
        return math(grade, seen)
    }

    fun math(grade: Int, seen: MutableSet<String>): LightningStatement {
        var fact = MathFacts.fact(grade)
        var tries = 0
        while (fact.expression in seen && tries < 20) { fact = MathFacts.fact(grade); tries++ }
        seen += fact.expression
        val isTrue = kotlin.random.Random.nextBoolean()
        var shown = fact.answer
        if (!isTrue) {
            var offsets = MiniGameDistractors.numericOffsets(fact.answer, grade)
            if (grade < 7) offsets = offsets.filter { fact.answer + it >= 0 }
            offsets = offsets.filter { it != 0 }
            shown = fact.answer + (offsets.randomOrNull() ?: 1)
        }
        return LightningStatement(null, CurriculumMath.ltr("${fact.expression} = ${MathFacts.show(shown)}"), shown == fact.answer, Topic.MATH)
    }

    private fun fromBank(topic: Topic?, grade: Int, seen: MutableSet<String>): LightningStatement? {
        val pool: List<Topic> = if (topic != null && topic != Topic.MATH && topic != Topic.READING) listOf(topic)
        else GameEnv.source.playableTopics.filter { it != Topic.MATH && it != Topic.READING && ContentAvailability.hasContent(it, GameEnv.lang) }
        if (pool.isEmpty()) return null
        repeat(4) {
            val t = pool.randomOrNull() ?: return null
            val items = GameContent.items(t, grade, maxPrompt = 70, maxAnswer = 28)
            val q = items.firstOrNull { it.prompt !in seen } ?: return@repeat
            seen += q.prompt
            if (kotlin.random.Random.nextBoolean() || q.distractors.isEmpty()) return LightningStatement(q.prompt, q.answer, true, t)
            // ה׳+ gets the "near miss", not the throwaway.
            val wrong = MiniGameDistractors.pick(q.answer, q.distractors, grade) ?: q.distractors[0]
            return LightningStatement(q.prompt, wrong, false, t)
        }
        return null
    }
}

// MARK: - ⚡ Surprise round

/** What the runner launches: a game, themed on a world kids love. */
data class SurprisePlan(val topic: Topic, val game: MiniGameKind, val id: String = UUID.randomUUID().toString())

/**
 * ⚡ "סִבּוּב הַפְתָּעָה" — after every 12–15 regular questions (twice a session
 * at most) the runner stops for one quick arcade game, themed on ⚽ 🌍 🚀 🐾 🦖 🌊,
 * paying ⭐ and 💎 twice over and never a minute.
 */
object SurpriseRound {
    const val MAX_PER_SESSION = 2
    const val REWARD_MULTIPLIER = 2

    /** Regular questions between rounds. */
    fun nextGap(): Int = (12..15).random()

    /**
     * QuestionRunnerView.surpriseRoundDue, pure: after the gap (twice a session
     * at most) — never in the bonus arena, never for a pre-reader, never in the
     * middle of a reading passage or on a 💫 bonus question.
     * Runner bookkeeping (iOS): on start `surprises = 0; nextAt = nextGap()`;
     * when due, `nextAt = questionIndex + nextGap()` and, if [plan] returns a
     * plan, `surprises += 1` and show [SurpriseRoundOverlay] before the next question.
     */
    fun shouldTrigger(
        questionIndex: Int, nextSurpriseAt: Int, surprisesThisSession: Int,
        isBonusArena: Boolean, isPreReader: Boolean,
        readingQueueEmpty: Boolean, currentHasPassage: Boolean, isBonusQuestion: Boolean,
        gamesAvailable: Boolean = MiniGameKind.availableForActiveChild,
    ): Boolean = questionIndex >= nextSurpriseAt &&
        surprisesThisSession < MAX_PER_SESSION &&
        !isBonusArena && !isPreReader &&
        readingQueueEmpty && !currentHasPassage &&
        !isBonusQuestion && gamesAvailable

    /** The "things kids love" worlds — a free taste of the packs for every child. */
    val interestTopics: List<Topic> = listOf(Topic.SOCCER, Topic.FLAGS, Topic.SPACE, Topic.ANIMALS, Topic.DINOSAURS, Topic.SEA)

    private val suffix: String get() = GameEnv.childKey

    /** Worlds that can serve a fair round now: content in the language, ≥ 8 items near the grade. */
    fun eligibleTopics(grade: Int): List<Topic> {
        val withContent = interestTopics.filter { t ->
            ContentAvailability.hasContent(t, GameEnv.lang) && nearGrade(t, grade).size >= 8
        }
        val visible = runCatching { QuestionPacks.visiblePacks(GameEnv.lang).toSet() }.getOrDefault(emptySet())
        val live = withContent.filter { !it.isPack || it in visible }
        return if (live.size >= 2) live else withContent
    }

    internal fun nearGrade(topic: Topic, grade: Int): List<BankQuestion> {
        val reach = if (grade > 6) 2 else 1
        return (QuestionBanks.bank(topic, GameEnv.lang) ?: emptyList()).filter { it.gradeDistance(grade) <= reach }
    }

    /** Weighted by what the child likes, never the same world twice in a row. */
    fun pickTopic(grade: Int): Topic? {
        val pool = eligibleTopics(grade).toMutableList()
        val last = Topic.of(GameEnv.prefs.getString("surprise.lastTopic.$suffix"))
        if (pool.size > 1 && last != null) pool.remove(last)
        if (pool.isEmpty()) return null
        val interests = GameEnv.source.interests.toSet()
        fun liked(t: Topic) = when (t) {
            Topic.SOCCER -> "sports" in interests
            Topic.FLAGS -> "flags" in interests || "geography" in interests
            Topic.SPACE -> "space" in interests
            Topic.ANIMALS, Topic.SEA -> "animals" in interests
            Topic.DINOSAURS -> "animals" in interests || "science" in interests
            else -> false
        }
        val weights = pool.map { t ->
            val answered = min(GameEnv.source.topicAnswered(t), 60).toDouble() / 60
            1 + GameEnv.source.affinity(t) * 1.5 + answered + (if (liked(t)) 1.5 else 0.0)
        }
        var roll = kotlin.random.Random.nextDouble() * max(weights.sum(), 0.0001)
        for ((t, w) in pool.zip(weights)) {
            if (roll < w) return t
            roll -= w
        }
        return pool.last()
    }

    /** The games that can be themed on `topic` at this grade, in the session it interrupts (`context`). */
    fun games(topic: Topic, grade: Int, context: Topic? = null): List<MiniGameKind> {
        if (PreReaderGames.isPreReader(grade)) return MiniGameGradeFit.preReaderRoster
        var out = mutableListOf(MiniGameKind.BALLOON)
        if (WordSets.spellingAvailable(grade)) out += listOf(MiniGameKind.WORD, MiniGameKind.WORD_SEARCH)
        val short = nearGrade(topic, grade).filter { q ->
            val p = Question.stripNiqqud(q.prompt)
            p.graphemes() <= 60 && !p.contains("לא שיך") && !p.contains("לא שייך") &&
                Question.stripNiqqud(q.correctAnswer).graphemes() <= 24 &&
                q.distractors.all { Question.stripNiqqud(it).graphemes() <= 24 }
        }
        if ((topic == Topic.FLAGS && grade >= 2) || short.size >= 12) out += MiniGameKind.PAIRS
        if (short.size >= 12) out += MiniGameKind.LIGHTNING
        if (context == null || context == Topic.MATH) out += MiniGameKind.CRUSH
        if (SortSets.make(topic, grade) != null) out += MiniGameKind.SORT
        out += MiniGameKind.PATTERN
        if (context == null || context in listOf(Topic.MATH, Topic.LOGIC, Topic.GIFTED)) {
            out += listOf(MiniGameKind.GAME2048, MiniGameKind.BALANCE)
            if (short.size >= 6 || context == Topic.MATH) out += MiniGameKind.VAULT
        }
        if (context == Topic.MONEY) out += MiniGameKind.GROCERY
        // In the English / Hebrew world, the spelling games come first (listed twice — iOS weights them).
        if (context == Topic.ENGLISH || context == Topic.HEBREW) {
            val spelling = out.filter { it == MiniGameKind.WORD || it == MiniGameKind.WORD_SEARCH }
            if (spelling.isNotEmpty()) out += spelling
        }
        // 🎚️ Nothing that is a freebie at this grade.
        val script = WordSets.script(topic, grade)
        out = out.filter { kind ->
            val board: SpellScript? = when (kind) {
                MiniGameKind.WORD, MiniGameKind.WORD_SEARCH -> script
                MiniGameKind.GROCERY -> if (topic == Topic.ENGLISH) SpellScript.ENGLISH else if (topic == Topic.HEBREW) SpellScript.HEBREW else null
                else -> null
            }
            MiniGameGradeFit.offered(kind, grade, board, context ?: topic)
        }.toMutableList()
        return out
    }

    /** The next round for this child, or null when nothing fits. */
    fun plan(grade: Int, context: Topic? = null): SurprisePlan? {
        val topic = pickTopic(grade) ?: return null
        val games = games(topic, grade, context).toMutableList()
        val gameKey = "surprise.lastGame.$suffix"
        val last = MiniGameKind.of(GameEnv.prefs.getString(gameKey))
        if (games.size > 1 && last != null) games.removeAll { it == last }
        val game = games.randomOrNull() ?: return null
        GameEnv.prefs.putString("surprise.lastTopic.$suffix", topic.raw)
        GameEnv.prefs.putString(gameKey, game.raw)
        return SurprisePlan(topic, game)
    }

    /** "⚽ כַּדּוּרֶגֶל" — the theme line on the interstitial. */
    fun themeName(topic: Topic): String = when (topic) {
        Topic.SOCCER -> tr("כַּדּוּרֶגֶל")
        Topic.FLAGS -> tr("דְּגָלִים וּבִירוֹת")
        Topic.SPACE -> tr("חָלָל")
        Topic.ANIMALS -> tr("חַיּוֹת")
        Topic.DINOSAURS -> tr("דִּינוֹזָאוּרִים")
        Topic.SEA -> tr("הַיָּם")
        else -> topic.displayName
    }
}

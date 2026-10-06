package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.kid.content.Question
import com.rani.tofy.ui.child.Topic
import kotlin.math.abs

// 🎚️ MiniGameGrading.swift — how hard a mini-game is for THIS child.
//
//   1️⃣ [MiniGameBand] — the five rungs every game scales on.
//   2️⃣ [MiniGameGradeFit] — the game × grade table: a board that is trivially
//      easy for a grade is not offered in that grade's chooser at all.
//
// 🗣️ A mother tongue and a foreign language are not the same subject: Hebrew
// boards scale hard, English (a second language from ג׳) stays gentle.

/** The five rungs. Ordinal order = iOS rawValue order (preReader 0 … top 4). */
enum class MiniGameBand(val hebrewName: String) {
    PRE_READER("גן"), LOWER("א׳–ב׳"), MIDDLE("ג׳–ד׳"), UPPER("ה׳–ו׳"), TOP("ז׳–ח׳");

    companion object {
        fun of(grade: Int): MiniGameBand = when {
            grade < 1 -> PRE_READER
            grade <= 2 -> LOWER
            grade <= 4 -> MIDDLE
            grade <= 6 -> UPPER
            else -> TOP
        }
    }
}

/** SpellScript (MiniGameContent.swift): the alphabet a spelling board uses. */
enum class SpellScript {
    HEBREW, ENGLISH, CYRILLIC, ARABIC;

    /** Hebrew and Arabic fill right-to-left, English and Russian left-to-right. */
    val rtl: Boolean get() = this == HEBREW || this == ARABIC
    val topic: Topic get() = if (this == HEBREW) Topic.HEBREW else Topic.ENGLISH
    /** Latin and Cyrillic are shown in capitals. */
    val uppercased: Boolean get() = this == ENGLISH || this == CYRILLIC
    val alphabet: List<Char>
        get() = when (this) {
            ENGLISH -> "ABCDEFGHIKLMNOPRSTUWY".toList()
            HEBREW -> "אבגדהוזחטיכלמנסעפצקרשת".toList()
            CYRILLIC -> "АБВГДЕЖЗИКЛМНОПРСТУФХЦЧШЫЭЮЯ".toList()
            ARABIC -> "ابتثجحخدذرزسشصضطظعغفقكلمنهوي".toList()
        }

    fun display(word: String): String = if (uppercased) word.uppercase() else word

    /**
     * A language the child reads at SCHOOL level — their own tongue, or the one
     * their school teaches them to write in (Hebrew for ru/ar children in Israel).
     */
    val isMotherTongue: Boolean
        get() {
            val l = GameEnv.lang
            return when (this) {
                HEBREW -> GameEnv.isIsraeli
                ENGLISH -> l == AppLanguage.EN
                CYRILLIC -> l == AppLanguage.RU
                ARABIC -> l == AppLanguage.AR
            }
        }
    val isSecondLanguage: Boolean get() = !isMotherTongue
}

/** The grade band each game is worth offering in. */
object MiniGameGradeFit {
    /** 👶 The גן roster: the five games whose mechanic survives with NO text. */
    val preReaderRoster: List<MiniGameKind> =
        listOf(MiniGameKind.BALLOON, MiniGameKind.SORT, MiniGameKind.PAIRS, MiniGameKind.PATTERN, MiniGameKind.CRUSH)

    fun roster(grade: Int): List<MiniGameKind> =
        if (MiniGameBand.of(grade) != MiniGameBand.PRE_READER) MiniGameKind.entries.filter { offered(it, grade) }
        else preReaderRoster

    /** Is this game worth putting in front of this child at all? `script` = the board's alphabet (🧩 🔤 🛒). */
    fun offered(kind: MiniGameKind, grade: Int, script: SpellScript? = null, topic: Topic? = null): Boolean {
        val band = MiniGameBand.of(grade)
        if (band <= MiniGameBand.PRE_READER) return kind in preReaderRoster
        return when (kind) {
            MiniGameKind.WORD -> if (script == null || !script.isSecondLanguage) true else grade >= 3 && band <= MiniGameBand.UPPER
            MiniGameKind.WORD_SEARCH -> if (script == null || !script.isSecondLanguage) true else grade >= 3
            MiniGameKind.GAME2048 -> band >= MiniGameBand.MIDDLE
            MiniGameKind.VAULT -> grade >= 2
            MiniGameKind.PATTERN -> if (topic == Topic.ENGLISH || topic == Topic.HEBREW) grade <= 5 else true
            MiniGameKind.GROCERY -> if (script == null || !script.isSecondLanguage) true else grade >= 3
            MiniGameKind.PAIRS, MiniGameKind.BALLOON, MiniGameKind.CRUSH, MiniGameKind.LIGHTNING,
            MiniGameKind.SORT, MiniGameKind.BALANCE -> true
        }
    }

    /** Every grade this game is offered in (0 = גן … 8). */
    fun grades(kind: MiniGameKind, script: SpellScript? = null, topic: Topic? = null): List<Int> =
        (0..8).filter { offered(kind, it, script, topic) }
}

/** One rung of a spelling ladder: the picture (the whole clue) and the word (no niqqud). */
data class LadderWord(val band: MiniGameBand, val emoji: String, val word: String)

private fun L(b: MiniGameBand, e: String, w: String) = LadderWord(b, e, w)

private fun pickRung(list: List<LadderWord>, b: MiniGameBand, maxLetters: Int): List<SpellWord> =
    list.filter { it.band == b && it.word.length <= maxLetters }.shuffled().map { SpellWord(it.emoji, it.word) }

/** 🇮🇱 Hebrew spelling, rung by rung — the mother tongue, so it climbs steeply. */
object HebrewLadder {
val general: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "🐶", "כלב"),
        L(MiniGameBand.LOWER, "🐱", "חתול"),
        L(MiniGameBand.LOWER, "🏠", "בית"),
        L(MiniGameBand.LOWER, "📖", "ספר"),
        L(MiniGameBand.LOWER, "🌳", "עץ"),
        L(MiniGameBand.LOWER, "☀️", "שמש"),
        L(MiniGameBand.LOWER, "🌸", "פרח"),
        L(MiniGameBand.LOWER, "🍎", "תפוח"),
        L(MiniGameBand.LOWER, "⚽", "כדור"),
        L(MiniGameBand.LOWER, "💧", "מים"),
        L(MiniGameBand.LOWER, "🍞", "לחם"),
        L(MiniGameBand.LOWER, "🥛", "חלב"),
        L(MiniGameBand.LOWER, "🐟", "דג"),
        L(MiniGameBand.LOWER, "🐴", "סוס"),
        L(MiniGameBand.LOWER, "🐄", "פרה"),
        L(MiniGameBand.LOWER, "🥚", "ביצה"),
        L(MiniGameBand.LOWER, "🌙", "ירח"),
        L(MiniGameBand.LOWER, "⭐", "כוכב"),
        L(MiniGameBand.LOWER, "☁️", "ענן"),
        L(MiniGameBand.LOWER, "❄️", "שלג"),
        L(MiniGameBand.LOWER, "🥕", "גזר"),
        L(MiniGameBand.LOWER, "👟", "נעל"),
        L(MiniGameBand.LOWER, "🚪", "דלת"),
        L(MiniGameBand.LOWER, "🎩", "כובע"),
        L(MiniGameBand.LOWER, "🍌", "בננה"),
        L(MiniGameBand.LOWER, "🍃", "עלה"),
        L(MiniGameBand.MIDDLE, "📒", "מחברת"),
        L(MiniGameBand.MIDDLE, "✏️", "עיפרון"),
        L(MiniGameBand.MIDDLE, "🚗", "מכונית"),
        L(MiniGameBand.MIDDLE, "☂️", "מטרייה"),
        L(MiniGameBand.MIDDLE, "🐸", "צפרדע"),
        L(MiniGameBand.MIDDLE, "🐓", "תרנגול"),
        L(MiniGameBand.MIDDLE, "🥾", "מגפיים"),
        L(MiniGameBand.MIDDLE, "🧦", "גרביים"),
        L(MiniGameBand.MIDDLE, "👕", "חולצה"),
        L(MiniGameBand.MIDDLE, "🧳", "מזוודה"),
        L(MiniGameBand.MIDDLE, "📷", "מצלמה"),
        L(MiniGameBand.MIDDLE, "🪥", "מברשת"),
        L(MiniGameBand.MIDDLE, "🚿", "מקלחת"),
        L(MiniGameBand.MIDDLE, "🛁", "אמבטיה"),
        L(MiniGameBand.MIDDLE, "💡", "מנורה"),
        L(MiniGameBand.MIDDLE, "🍉", "אבטיח"),
        L(MiniGameBand.MIDDLE, "🍑", "אפרסק"),
        L(MiniGameBand.MIDDLE, "🍄", "פטרייה"),
        L(MiniGameBand.MIDDLE, "🍦", "גלידה"),
        L(MiniGameBand.MIDDLE, "🍪", "עוגייה"),
        L(MiniGameBand.MIDDLE, "🍫", "שוקולד"),
        L(MiniGameBand.MIDDLE, "⛲", "מזרקה"),
        L(MiniGameBand.MIDDLE, "🚦", "רמזור"),
        L(MiniGameBand.MIDDLE, "🚢", "אונייה"),
        L(MiniGameBand.MIDDLE, "🍒", "דובדבן"),
        L(MiniGameBand.MIDDLE, "🥒", "מלפפון"),
        L(MiniGameBand.MIDDLE, "🐙", "תמנון"),
        L(MiniGameBand.MIDDLE, "🐬", "דולפין"),
        L(MiniGameBand.MIDDLE, "🦉", "ינשוף"),
        L(MiniGameBand.MIDDLE, "🦘", "קנגורו"),
        L(MiniGameBand.MIDDLE, "🐌", "חילזון"),
        L(MiniGameBand.MIDDLE, "🦗", "חרגול"),
        L(MiniGameBand.MIDDLE, "🐝", "כוורת"),
        L(MiniGameBand.MIDDLE, "🍓", "תותים"),
        L(MiniGameBand.UPPER, "✂️", "מספריים"),
        L(MiniGameBand.UPPER, "🚲", "אופניים"),
        L(MiniGameBand.UPPER, "👖", "מכנסיים"),
        L(MiniGameBand.UPPER, "👓", "משקפיים"),
        L(MiniGameBand.UPPER, "🚌", "אוטובוס"),
        L(MiniGameBand.UPPER, "🍅", "עגבנייה"),
        L(MiniGameBand.UPPER, "🔭", "טלסקופ"),
        L(MiniGameBand.UPPER, "🚑", "אמבולנס"),
        L(MiniGameBand.UPPER, "🎹", "פסנתר"),
        L(MiniGameBand.UPPER, "🎺", "חצוצרה"),
        L(MiniGameBand.UPPER, "🎷", "סקסופון"),
        L(MiniGameBand.UPPER, "🎤", "מיקרופון"),
        L(MiniGameBand.UPPER, "📺", "טלוויזיה"),
        L(MiniGameBand.UPPER, "🎧", "אוזניות"),
        L(MiniGameBand.UPPER, "🧮", "מחשבון"),
        L(MiniGameBand.UPPER, "🚜", "טרקטור"),
        L(MiniGameBand.UPPER, "🗼", "מגדלור"),
        L(MiniGameBand.UPPER, "🎡", "קרוסלה"),
        L(MiniGameBand.UPPER, "🛼", "גלגיליות"),
        L(MiniGameBand.UPPER, "🎿", "מגלשיים"),
        L(MiniGameBand.UPPER, "🐳", "לווייתן"),
        L(MiniGameBand.UPPER, "🐧", "פינגווין"),
        L(MiniGameBand.UPPER, "🦩", "פלמינגו"),
        L(MiniGameBand.UPPER, "🐵", "שימפנזה"),
        L(MiniGameBand.UPPER, "🎻", "תזמורת"),
        L(MiniGameBand.UPPER, "🥦", "ברוקולי"),
        L(MiniGameBand.UPPER, "🍔", "המבורגר"),
        L(MiniGameBand.UPPER, "🥐", "קרואסון"),
        L(MiniGameBand.UPPER, "🍩", "סופגנייה"),
        L(MiniGameBand.UPPER, "🥞", "פנקייק"),
        L(MiniGameBand.UPPER, "🌻", "חמניות"),
        L(MiniGameBand.UPPER, "🫖", "קומקום"),
        L(MiniGameBand.UPPER, "🪸", "אלמוגים"),
        L(MiniGameBand.UPPER, "☄️", "מטאוריט"),
        L(MiniGameBand.UPPER, "🌌", "גלקסיה"),
        L(MiniGameBand.UPPER, "🛰️", "לוויין"),
        L(MiniGameBand.UPPER, "🪗", "אקורדיון"),
        L(MiniGameBand.TOP, "🔬", "מיקרוסקופ"),
        L(MiniGameBand.TOP, "👨‍🚀", "אסטרונאוט"),
        L(MiniGameBand.TOP, "🚁", "הליקופטר"),
        L(MiniGameBand.TOP, "🐠", "אקווריום"),
        L(MiniGameBand.TOP, "🩺", "סטטוסקופ"),
        L(MiniGameBand.TOP, "🎶", "קסילופון"),
        L(MiniGameBand.TOP, "🛹", "סקייטבורד"),
        L(MiniGameBand.TOP, "🦛", "היפופוטם"),
        L(MiniGameBand.TOP, "🐊", "קרוקודיל"),
        L(MiniGameBand.TOP, "🌊", "אוקיינוס"),
        L(MiniGameBand.TOP, "🚋", "חשמלית"),
        L(MiniGameBand.TOP, "🦎", "סלמנדרה"),
        L(MiniGameBand.TOP, "🦕", "דינוזאור"),
        L(MiniGameBand.TOP, "🥑", "אבוקדו"),
        L(MiniGameBand.TOP, "🩰", "בלרינה"),
        L(MiniGameBand.TOP, "🎆", "זיקוקים"),
        L(MiniGameBand.TOP, "🦧", "אורנגאוטן"),
        L(MiniGameBand.TOP, "🛴", "קורקינט"),
        L(MiniGameBand.TOP, "🌺", "אורכידאה"),
        L(MiniGameBand.TOP, "🎭", "תיאטרון"),
        L(MiniGameBand.TOP, "🍬", "סוכרייה"),
        L(MiniGameBand.TOP, "🧁", "קאפקייק"),
        L(MiniGameBand.TOP, "🥤", "מילקשייק"),
        L(MiniGameBand.TOP, "🍋", "לימונדה"),
        L(MiniGameBand.TOP, "🥜", "בוטנים"),
        L(MiniGameBand.TOP, "🐯", "טיגריס"),
        L(MiniGameBand.TOP, "🪂", "מצנחים"),
    )
    val soccer: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "⚽", "כדור"),
        L(MiniGameBand.LOWER, "🥅", "שער"),
        L(MiniGameBand.LOWER, "👟", "נעל"),
        L(MiniGameBand.LOWER, "🚩", "דגל"),
        L(MiniGameBand.LOWER, "🏆", "גביע"),
        L(MiniGameBand.MIDDLE, "📣", "אוהדים"),
        L(MiniGameBand.MIDDLE, "👥", "קבוצה"),
        L(MiniGameBand.MIDDLE, "🦵", "בעיטה"),
        L(MiniGameBand.MIDDLE, "🟨", "כרטיס"),
        L(MiniGameBand.MIDDLE, "⏱️", "מחצית"),
        L(MiniGameBand.MIDDLE, "🧤", "כפפות"),
        L(MiniGameBand.UPPER, "🏟️", "אצטדיון"),
        L(MiniGameBand.UPPER, "🏅", "אליפות"),
        L(MiniGameBand.UPPER, "🌍", "מונדיאל"),
        L(MiniGameBand.UPPER, "🥈", "מדליה"),
        L(MiniGameBand.UPPER, "🥇", "תחרות"),
        L(MiniGameBand.TOP, "🧑‍⚖️", "שופטים"),
        L(MiniGameBand.TOP, "🏃", "ספורטאי"),
    )
    val sea: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "🐟", "דג"),
        L(MiniGameBand.LOWER, "🌊", "ים"),
        L(MiniGameBand.LOWER, "🦀", "סרטן"),
        L(MiniGameBand.LOWER, "🦈", "כריש"),
        L(MiniGameBand.LOWER, "🐚", "צדף"),
        L(MiniGameBand.MIDDLE, "🐙", "תמנון"),
        L(MiniGameBand.MIDDLE, "🐬", "דולפין"),
        L(MiniGameBand.MIDDLE, "🪼", "מדוזה"),
        L(MiniGameBand.MIDDLE, "🦑", "דיונון"),
        L(MiniGameBand.MIDDLE, "🦭", "כלבים"),
        L(MiniGameBand.UPPER, "🐳", "לווייתן"),
        L(MiniGameBand.UPPER, "🪸", "אלמוגים"),
        L(MiniGameBand.UPPER, "🐧", "פינגווין"),
        L(MiniGameBand.UPPER, "⛵", "מפרשית"),
        L(MiniGameBand.UPPER, "🤿", "צוללן"),
        L(MiniGameBand.TOP, "🌊", "אוקיינוס"),
        L(MiniGameBand.TOP, "🐠", "אקווריום"),
        L(MiniGameBand.TOP, "🐊", "קרוקודיל"),
        L(MiniGameBand.TOP, "🦛", "היפופוטם"),
    )
    val space: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "☀️", "שמש"),
        L(MiniGameBand.LOWER, "🌙", "ירח"),
        L(MiniGameBand.LOWER, "⭐", "כוכב"),
        L(MiniGameBand.LOWER, "🚀", "חללית"),
        L(MiniGameBand.LOWER, "👽", "חייזר"),
        L(MiniGameBand.MIDDLE, "🔴", "מאדים"),
        L(MiniGameBand.MIDDLE, "🪐", "שבתאי"),
        L(MiniGameBand.MIDDLE, "🛰️", "לוויין"),
        L(MiniGameBand.MIDDLE, "☄️", "מטאור"),
        L(MiniGameBand.MIDDLE, "🔵", "נפטון"),
        L(MiniGameBand.UPPER, "🔭", "טלסקופ"),
        L(MiniGameBand.UPPER, "🌌", "גלקסיה"),
        L(MiniGameBand.UPPER, "☄️", "מטאוריט"),
        L(MiniGameBand.UPPER, "🟢", "אורנוס"),
        L(MiniGameBand.TOP, "👨‍🚀", "אסטרונאוט"),
        L(MiniGameBand.TOP, "🔭", "טלסקופים"),
        L(MiniGameBand.TOP, "☄️", "מטאוריטים"),
    )
    val animals: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "🐶", "כלב"),
        L(MiniGameBand.LOWER, "🐱", "חתול"),
        L(MiniGameBand.LOWER, "🐴", "סוס"),
        L(MiniGameBand.LOWER, "🐘", "פיל"),
        L(MiniGameBand.LOWER, "🦁", "אריה"),
        L(MiniGameBand.LOWER, "🐒", "קוף"),
        L(MiniGameBand.LOWER, "🐄", "פרה"),
        L(MiniGameBand.MIDDLE, "🐸", "צפרדע"),
        L(MiniGameBand.MIDDLE, "🐓", "תרנגול"),
        L(MiniGameBand.MIDDLE, "🦉", "ינשוף"),
        L(MiniGameBand.MIDDLE, "🦘", "קנגורו"),
        L(MiniGameBand.MIDDLE, "🐌", "חילזון"),
        L(MiniGameBand.MIDDLE, "🦗", "חרגול"),
        L(MiniGameBand.MIDDLE, "🐬", "דולפין"),
        L(MiniGameBand.UPPER, "🐧", "פינגווין"),
        L(MiniGameBand.UPPER, "🦩", "פלמינגו"),
        L(MiniGameBand.UPPER, "🐵", "שימפנזה"),
        L(MiniGameBand.UPPER, "🐳", "לווייתן"),
        L(MiniGameBand.UPPER, "🦇", "עטלפים"),
        L(MiniGameBand.TOP, "🦛", "היפופוטם"),
        L(MiniGameBand.TOP, "🐊", "קרוקודיל"),
        L(MiniGameBand.TOP, "🦧", "אורנגאוטן"),
        L(MiniGameBand.TOP, "🦎", "סלמנדרה"),
        L(MiniGameBand.TOP, "🐯", "טיגריס"),
    )
    val dinosaurs: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "🦴", "עצם"),
        L(MiniGameBand.LOWER, "🥚", "ביצה"),
        L(MiniGameBand.LOWER, "🦷", "שן"),
        L(MiniGameBand.LOWER, "🍃", "עלה"),
        L(MiniGameBand.LOWER, "🪨", "סלע"),
        L(MiniGameBand.MIDDLE, "🦎", "זוחלים"),
        L(MiniGameBand.MIDDLE, "🌿", "צמחים"),
        L(MiniGameBand.MIDDLE, "🧊", "קרחון"),
        L(MiniGameBand.MIDDLE, "🦌", "קרניים"),
        L(MiniGameBand.UPPER, "🦕", "דינוזאור"),
        L(MiniGameBand.UPPER, "🦴", "מאובנים"),
        L(MiniGameBand.UPPER, "🐊", "תנינים"),
        L(MiniGameBand.TOP, "🦖", "סטגוזאור"),
        L(MiniGameBand.TOP, "🦕", "טריצרטופס"),
    )
    val flags: List<LadderWord> = listOf(
        L(MiniGameBand.LOWER, "🚩", "דגל"),
        L(MiniGameBand.LOWER, "🗺️", "מפה"),
        L(MiniGameBand.LOWER, "🏙️", "עיר"),
        L(MiniGameBand.LOWER, "🏝️", "אי"),
        L(MiniGameBand.LOWER, "✈️", "מטוס"),
        L(MiniGameBand.MIDDLE, "🚢", "אונייה"),
        L(MiniGameBand.MIDDLE, "🏳️", "מדינה"),
        L(MiniGameBand.MIDDLE, "🧳", "מזוודה"),
        L(MiniGameBand.MIDDLE, "🌐", "גלובוס"),
        L(MiniGameBand.UPPER, "🌏", "יבשות"),
        L(MiniGameBand.UPPER, "🚌", "אוטובוס"),
        L(MiniGameBand.UPPER, "🗼", "מגדלור"),
        L(MiniGameBand.UPPER, "🏜️", "מדבריות"),
        L(MiniGameBand.TOP, "🌊", "אוקיינוס"),
        L(MiniGameBand.TOP, "🏛️", "אקרופוליס"),
    )

    fun themed(topic: Topic?): List<LadderWord>? = when (topic) {
        Topic.SOCCER -> soccer
        Topic.SEA -> sea
        Topic.SPACE -> space
        Topic.ANIMALS -> animals
        Topic.DINOSAURS -> dinosaurs
        Topic.FLAGS -> flags
        else -> null
    }

    /** The child's rung first; the rung below only as filler (a ה׳ child never meets כלב). */
    fun words(topic: Topic?, grade: Int, maxLetters: Int, minimum: Int): List<SpellWord> {
        val band = MiniGameBand.of(grade)
        val source = themed(topic) ?: general
        val out = pickRung(source, band, maxLetters).toMutableList()
        if (out.size < minimum && themed(topic) != null) {
            out += pickRung(general, band, maxLetters).filter { w -> out.none { it.word == w.word } }
        }
        val below = MiniGameBand.entries.getOrNull(band.ordinal - 1)
        if (out.size < minimum && below != null && below > MiniGameBand.PRE_READER) {
            val filler = pickRung(source, below, maxLetters) + pickRung(general, below, maxLetters)
            for (w in filler) if (out.none { it.word == w.word }) out += w
        }
        return out
    }
}

/** 🇺🇸 English spelling — a foreign language from ג׳, so the curve is deliberately flat. */
object EnglishLadder {
    val firstWords: List<LadderWord> = listOf(
        L(MiniGameBand.MIDDLE, "🐱", "cat"),
        L(MiniGameBand.MIDDLE, "🐶", "dog"),
        L(MiniGameBand.MIDDLE, "☀️", "sun"),
        L(MiniGameBand.MIDDLE, "🎩", "hat"),
        L(MiniGameBand.MIDDLE, "🛏️", "bed"),
        L(MiniGameBand.MIDDLE, "🚌", "bus"),
        L(MiniGameBand.MIDDLE, "🥚", "egg"),
        L(MiniGameBand.MIDDLE, "🦊", "fox"),
        L(MiniGameBand.MIDDLE, "📦", "box"),
        L(MiniGameBand.MIDDLE, "🐟", "fish"),
        L(MiniGameBand.MIDDLE, "⭐", "star"),
        L(MiniGameBand.MIDDLE, "🌳", "tree"),
        L(MiniGameBand.MIDDLE, "🐦", "bird"),
        L(MiniGameBand.MIDDLE, "✋", "hand"),
        L(MiniGameBand.MIDDLE, "🧢", "cap"),
        L(MiniGameBand.MIDDLE, "🗝️", "key"),
    )
    val everyday: List<LadderWord> = listOf(
        L(MiniGameBand.UPPER, "🍎", "apple"),
        L(MiniGameBand.UPPER, "🏠", "house"),
        L(MiniGameBand.UPPER, "🪑", "chair"),
        L(MiniGameBand.UPPER, "🚆", "train"),
        L(MiniGameBand.UPPER, "💧", "water"),
        L(MiniGameBand.UPPER, "🍞", "bread"),
        L(MiniGameBand.UPPER, "🕐", "clock"),
        L(MiniGameBand.UPPER, "🐍", "snake"),
        L(MiniGameBand.UPPER, "🐯", "tiger"),
        L(MiniGameBand.UPPER, "🍕", "pizza"),
        L(MiniGameBand.UPPER, "🌸", "flower"),
        L(MiniGameBand.UPPER, "🦓", "zebra"),
        L(MiniGameBand.UPPER, "🪟", "window"),
        L(MiniGameBand.UPPER, "🍌", "banana"),
        L(MiniGameBand.UPPER, "🧑‍🏫", "teacher"),
        L(MiniGameBand.UPPER, "🐒", "monkey"),
        L(MiniGameBand.UPPER, "🐰", "rabbit"),
        L(MiniGameBand.UPPER, "🧺", "basket"),
        L(MiniGameBand.UPPER, "✏️", "pencil"),
        L(MiniGameBand.UPPER, "🏔️", "mountain"),
        L(MiniGameBand.UPPER, "🦋", "butterfly"),
        L(MiniGameBand.UPPER, "🚲", "bicycle"),
    )
    val nativeUpper: List<LadderWord> = listOf(
        L(MiniGameBand.UPPER, "✂️", "scissors"),
        L(MiniGameBand.UPPER, "🚲", "bicycle"),
        L(MiniGameBand.UPPER, "👖", "trousers"),
        L(MiniGameBand.UPPER, "👓", "glasses"),
        L(MiniGameBand.UPPER, "🍅", "tomato"),
        L(MiniGameBand.UPPER, "🔭", "telescope"),
        L(MiniGameBand.UPPER, "🚑", "ambulance"),
        L(MiniGameBand.UPPER, "🎹", "piano"),
        L(MiniGameBand.UPPER, "🎺", "trumpet"),
        L(MiniGameBand.UPPER, "🎧", "headphones"),
        L(MiniGameBand.UPPER, "🚜", "tractor"),
        L(MiniGameBand.UPPER, "🗼", "lighthouse"),
        L(MiniGameBand.UPPER, "🎡", "carousel"),
        L(MiniGameBand.UPPER, "🐳", "whale"),
        L(MiniGameBand.UPPER, "🐧", "penguin"),
        L(MiniGameBand.UPPER, "🦩", "flamingo"),
        L(MiniGameBand.UPPER, "🎻", "orchestra"),
        L(MiniGameBand.UPPER, "🥦", "broccoli"),
        L(MiniGameBand.UPPER, "🍔", "hamburger"),
        L(MiniGameBand.UPPER, "🥐", "croissant"),
        L(MiniGameBand.UPPER, "🍩", "doughnut"),
        L(MiniGameBand.UPPER, "🥞", "pancake"),
        L(MiniGameBand.UPPER, "🌻", "sunflower"),
        L(MiniGameBand.UPPER, "🫖", "kettle"),
        L(MiniGameBand.UPPER, "🪸", "coral"),
        L(MiniGameBand.UPPER, "🌌", "galaxy"),
        L(MiniGameBand.UPPER, "🛰️", "satellite"),
        L(MiniGameBand.UPPER, "🪗", "accordion"),
        L(MiniGameBand.UPPER, "🎷", "saxophone"),
        L(MiniGameBand.UPPER, "🍍", "pineapple"),
    )
    val nativeTop: List<LadderWord> = listOf(
        L(MiniGameBand.TOP, "🔬", "microscope"),
        L(MiniGameBand.TOP, "👨‍🚀", "astronaut"),
        L(MiniGameBand.TOP, "🚁", "helicopter"),
        L(MiniGameBand.TOP, "🐠", "aquarium"),
        L(MiniGameBand.TOP, "🩺", "stethoscope"),
        L(MiniGameBand.TOP, "🛹", "skateboard"),
        L(MiniGameBand.TOP, "🐊", "crocodile"),
        L(MiniGameBand.TOP, "🦧", "orangutan"),
        L(MiniGameBand.TOP, "🦎", "salamander"),
        L(MiniGameBand.TOP, "🦕", "dinosaur"),
        L(MiniGameBand.TOP, "🥑", "avocado"),
        L(MiniGameBand.TOP, "🩰", "ballerina"),
        L(MiniGameBand.TOP, "🎆", "fireworks"),
        L(MiniGameBand.TOP, "🛴", "scooter"),
        L(MiniGameBand.TOP, "🌺", "orchid"),
        L(MiniGameBand.TOP, "🎭", "theatre"),
        L(MiniGameBand.TOP, "🍬", "lollipop"),
        L(MiniGameBand.TOP, "🧁", "cupcake"),
        L(MiniGameBand.TOP, "🥤", "milkshake"),
        L(MiniGameBand.TOP, "🍋", "lemonade"),
        L(MiniGameBand.TOP, "🥜", "peanuts"),
        L(MiniGameBand.TOP, "☂️", "umbrella"),
        L(MiniGameBand.TOP, "🧮", "calculator"),
        L(MiniGameBand.TOP, "🎤", "microphone"),
        L(MiniGameBand.TOP, "📺", "television"),
        L(MiniGameBand.TOP, "🦋", "butterfly"),
        L(MiniGameBand.TOP, "🐛", "caterpillar"),
        L(MiniGameBand.TOP, "🌊", "waterfall"),
        L(MiniGameBand.TOP, "🧳", "suitcase"),
        L(MiniGameBand.TOP, "🥁", "percussion"),
    )

    /** Second language: two rungs on purpose. Mother tongue: the full four. */
    fun words(grade: Int, maxLetters: Int, minimum: Int, motherTongue: Boolean = false): List<SpellWord> {
        val band = MiniGameBand.of(grade)
        val rungs: List<List<LadderWord>> = if (motherTongue) when (band) {
            MiniGameBand.PRE_READER, MiniGameBand.LOWER -> listOf(firstWords, everyday)
            MiniGameBand.MIDDLE -> listOf(everyday, firstWords)
            MiniGameBand.UPPER -> listOf(nativeUpper, everyday)
            MiniGameBand.TOP -> listOf(nativeTop, nativeUpper)
        } else if (grade <= 4) listOf(firstWords, everyday) else listOf(everyday, firstWords)
        val out = mutableListOf<SpellWord>()
        for (rung in rungs) {
            val fresh = rung.filter { it.word.length <= maxLetters }.shuffled().map { SpellWord(it.emoji, it.word) }
            for (w in fresh) if (out.none { it.word == w.word }) out += w
            if (out.size >= minimum) break
        }
        return out
    }
}

/** 🔤 The word search's grid size and directions — the mother tongue grows much faster. */
object WordSearchShape {
    fun size(grade: Int, script: SpellScript, roomy: Boolean): Int {
        val band = MiniGameBand.of(grade)
        if (script.isSecondLanguage) {
            val compact = if (band >= MiniGameBand.UPPER) 7 else 6
            return if (roomy) compact + 1 else compact
        }
        return when (band) {
            MiniGameBand.PRE_READER, MiniGameBand.LOWER -> if (roomy) 7 else 6
            MiniGameBand.MIDDLE -> if (roomy) 8 else 7
            MiniGameBand.UPPER -> if (roomy) 10 else 8
            MiniGameBand.TOP -> if (roomy) 10 else 9
        }
    }

    /** Diagonals: from ג׳ in the mother tongue, from ה׳ in a second language. */
    fun diagonals(grade: Int, script: SpellScript): Boolean {
        val band = MiniGameBand.of(grade)
        return if (script.isMotherTongue) band >= MiniGameBand.MIDDLE else band >= MiniGameBand.UPPER
    }

    /** Backwards words — ה׳ and up, mother tongue only. */
    fun backwards(grade: Int, script: SpellScript): Boolean =
        script.isMotherTongue && MiniGameBand.of(grade) >= MiniGameBand.UPPER
}

/** 🎯 How close the wrong answers sit. */
object MiniGameDistractors {
    /**
     * From ה׳ a "near miss"; before that, any. NOTE: iOS sorts with
     * `min { closeness(a) < closeness(b) }`, i.e. it returns the LEAST alike —
     * mirrored exactly so both apps deal the same boards.
     */
    fun pick(answer: String, from: List<String>, grade: Int): String? {
        if (from.isEmpty()) return null
        if (MiniGameBand.of(grade) < MiniGameBand.UPPER) return from.random()
        val target = Question.stripNiqqud(answer)
        return from.minByOrNull { closeness(target, Question.stripNiqqud(it)) }
    }

    /** Bigger = more alike: a shared opening, a shared ending, a similar length. */
    internal fun closeness(a: String, b: String): Int {
        if (a == b) return -1
        val x = a.toList(); val y = b.toList()
        var head = 0
        while (head < minOf(x.size, y.size) && x[head] == y[head]) head++
        var tail = 0
        while (tail < minOf(x.size, y.size) - head && x[x.size - 1 - tail] == y[y.size - 1 - tail]) tail++
        return head * 3 + tail * 2 - abs(x.size - y.size)
    }

    /** How far a wrong number may sit from the right one. */
    fun numericOffsets(answer: Int, grade: Int): List<Int> = when (MiniGameBand.of(grade)) {
        MiniGameBand.PRE_READER, MiniGameBand.LOWER -> listOf(-2, -1, 1, 2)
        MiniGameBand.MIDDLE -> listOf(-2, -1, 1, 2) + (if (abs(answer) >= 20) listOf(-10, 10) else emptyList())
        MiniGameBand.UPPER -> listOf(-1, 1, -2, 2) + (if (abs(answer) >= 20) listOf(-9, 9, 10, -10) else emptyList())
        MiniGameBand.TOP -> listOf(-1, 1, -2, 2) + (if (abs(answer) >= 20) listOf(-9, 9, 11, -11) else emptyList()) +
            (if (answer != 0) listOf(-2 * answer) else emptyList())
    }
}

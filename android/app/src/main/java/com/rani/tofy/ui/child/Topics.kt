package com.rani.tofy.ui.child

import com.rani.tofy.data.Child
import com.rani.tofy.data.Progress
import com.rani.tofy.data.dbl
import com.rani.tofy.data.int
import com.rani.tofy.data.map
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.str
import com.rani.tofy.data.strList
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr

/** Topic.swift — raw values are the Firestore keys (difficultyByTopic, enabledTopics, perTopic…). */
enum class Topic(val raw: String, private val nameKey: String, private val emojiRaw: String, val isPack: Boolean = false) {
    MATH("math", "מָתֵמָטִיקָה", "🧮"),
    ENGLISH("english", "אַנְגְּלִית", "🇬🇧"),
    HEBREW("hebrew", "עִבְרִית", "✍️"),
    LOGIC("logic", "לוֹגִיקָה", "🧩"),
    SCIENCE("science", "מַדָּעִים", "🔬"),
    HISTORY("history", "הִיסְטוֹרְיָה", "🏛️"),
    GEOGRAPHY("geography", "גֵּאוֹגְרַפְיָה", "🌍"),
    MONEY("money", "חִנּוּךְ פִּינַנְסִי", "💰"),
    READING("reading", "הֲבָנַת הַנִּקְרָא", "📖"),
    HOLIDAYS("holidays", "הַחַגִּים", "🎊"),
    // Paid packs — QuestionPack.id == topic raw value.
    SOCCER("soccer", "עוֹלַם הַכַּדּוּרֶגֶל", "⚽", true),
    DINOSAURS("dinosaurs", "דִּינוֹזָאוּרִים", "🦖", true),
    SPACE("space", "חָלָל וְכוֹכָבִים", "🚀", true),
    ANIMALS("animals", "עוֹלַם הַחַיּוֹת", "🐾", true),
    SEA("sea", "מַעֲמַקֵּי הַיָּם", "🌊", true),
    GIFTED("gifted", "הֲכָנָה לִמְחוֹנָנִים", "🧠", true),
    FOOD("food", "מִטְבָּח וּמַדָּע שֶׁל אֹכֶל", "🍳", true),
    ISRAEL("israel", "יִשְׂרָאֵל שֶׁלִּי", "🏛️", true),
    MUSIC("music", "מוּזִיקָה", "🎵", true),
    BODY("body", "גּוּף הָאָדָם", "🧍", true),
    VEHICLES("vehicles", "כְּלֵי רֶכֶב וְתַחְבּוּרָה", "🚗", true),
    FLAGS("flags", "דְּגָלִים וּמְדִינוֹת", "🌍", true),
    TISHREI("tishrei", "חַגֵּי תִּשְׁרֵי", "🍎", true);

    val displayName: String get() = tr(nameKey)

    /** A US child's English class is their own language — 📝, not a foreign flag. */
    val emoji: String get() = if (this == ENGLISH && I18n.language == AppLanguage.EN) "📝" else emojiRaw

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw }
        /** Topic.core: every topic that is not a paid pack. */
        val core: List<Topic> = entries.filter { !it.isPack }
    }
}

/** Difficulty.swift */
enum class Difficulty(val raw: String, private val key: String) {
    EASY("easy", "קַל"), MEDIUM("medium", "בֵּינוֹנִי"), HARD("hard", "קָשֶׁה");
    val displayName: String get() = tr(key)
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

/** LearningLevel (ChildRecord.swift) — seeds the base difficulty. */
enum class LearningLevel(val raw: String, private val key: String, val emoji: String, val seed: Difficulty) {
    BEGINNER("beginner", "מַתְחִיל", "🌱", Difficulty.EASY),
    DEVELOPING("developing", "מִתְפַּתֵּחַ", "🌿", Difficulty.EASY),
    PROFICIENT("proficient", "שׁוֹלֵט", "🌳", Difficulty.MEDIUM),
    ADVANCED("advanced", "מִתְקַדֵּם", "🚀", Difficulty.HARD);
    val displayName: String get() = tr(key)
    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } ?: DEVELOPING }
}

/** ChildAge.swift — the stored `age` is the bracket's raw value. */
enum class AgeBracket(val raw: Int, val label: String, val emoji: String) {
    PRE_K(4, "4-5", "🧒"), GRADE1(6, "6-7", "👦"), GRADE3(8, "8-9", "👧"), OLDER(10, "10+", "🧑");
    companion object {
        fun of(raw: Int) = entries.firstOrNull { it.raw == raw } ?: GRADE1
        fun forGrade(g: Int) = when { g < 1 -> PRE_K; g <= 2 -> GRADE1; g <= 4 -> GRADE3; else -> OLDER }
    }
}

/** InterestCatalog (ChildRecord.swift). */
data class Interest(val id: String, private val key: String, val emoji: String) { val label: String get() = tr(key) }

val Interests = listOf(
    Interest("sports", "סְפּוֹרְט", "⚽️"), Interest("space", "חָלָל", "🚀"),
    Interest("animals", "בַּעֲלֵי חַיִּים", "🦁"), Interest("flags", "דְּגָלִים", "🚩"),
    Interest("music", "מוּזִיקָה", "🎵"), Interest("art", "אָמָנוּת", "🎨"),
    Interest("history", "הִיסְטוֹרְיָה", "🏛️"), Interest("science", "מַדָּע", "🔬"),
    Interest("english", "אַנְגְּלִית", "🔤"), Interest("numbers", "מִסְפָּרִים", "🔢"),
    Interest("puzzles", "חִידוֹת", "🧩"), Interest("geography", "מְדִינוֹת", "🌍"),
)

/** A world card (World.swift) — the base worlds; the 💫 bonus arena has no toggle. */
data class World(val id: String, private val key: String, val emoji: String, val topic: Topic) {
    val name: String get() = if (topic.isPack) topic.displayName else tr(key)
}

val BaseWorlds = listOf(
    World("math_kingdom", "מַמְלֶכֶת הַמָּתֵמָטִיקָה", "🧮", Topic.MATH),
    World("english_land", "אֶרֶץ אַנְגְּלִית", "🔤", Topic.ENGLISH),
    World("hebrew_land", "אֶרֶץ הָעִבְרִית", "✍️", Topic.HEBREW),
    World("logic_lab", "חִידוֹת הַלּוֹגִיקָה", "🧩", Topic.LOGIC),
    World("science_lab", "מַעְבְּדַת הַמַּדָּעִים", "🔬", Topic.SCIENCE),
    World("history_museum", "מוּזֵיאוֹן הַהִיסְטוֹרְיָה", "🏛️", Topic.HISTORY),
    World("geo_journey", "מַסָּע סְבִיב הָעוֹלָם", "🌍", Topic.GEOGRAPHY),
    World("money_market", "שׁוּק הַכֶּסֶף", "💰", Topic.MONEY),
    World("story_forest", "יַעַר הַסִּפּוּרִים", "📖", Topic.READING),
    World("holidays", "הַחַגִּים", "🎊", Topic.HOLIDAYS),
)

/**
 * ContentAvailability.hasContent for the parent's app language. Hebrew is the
 * full catalog; 🎊 is Arabic-only; the Hebrew world exists for ru/ar children
 * (Israeli school) but not en. Bank sizes per language can't be measured here,
 * so every other topic counts as available.
 */
fun Topic.hasContent(lang: AppLanguage = I18n.language): Boolean = when {
    this == Topic.HOLIDAYS -> lang == AppLanguage.AR
    lang == AppLanguage.HE -> true
    this == Topic.HEBREW -> lang == AppLanguage.RU || lang == AppLanguage.AR
    else -> true
}

// MARK: - Child helpers (Profile.swift semantics on the raw ChildRecord)

val Child.learningLevel: LearningLevel get() = LearningLevel.of(raw.str("learningLevel"))
val Child.interests: List<String> get() = raw.strList("interests") ?: emptyList()
val Child.disabledPacks: Set<String> get() = (raw.strList("disabledPacks") ?: emptyList()).toSet()
val Child.gradeSetByChild: Boolean get() = raw["gradeSetByChild"] == true
val Child.hasPlayPIN: Boolean get() = !playPIN.isNullOrEmpty()

/** Profile.difficulty(for:): the parent's per-topic choice, else the learning level's seed. */
fun Child.difficultyFor(t: Topic): Difficulty = Difficulty.of(difficultyByTopic[t.raw]) ?: learningLevel.seed

/**
 * ChildRecord.toProfile(): nil = all core; a pre-v2 record gets 📖 (not preK),
 * a pre-v3 record gets 🎊 — a stored set can't tell "turned off" from "didn't exist yet".
 */
val Child.enabledTopicSet: Set<Topic>
    get() {
        val set = enabledTopics?.mapNotNull { Topic.of(it) }?.toMutableSet() ?: Topic.core.toMutableSet()
        val v = raw.int("topicsVersion") ?: 1
        if (v < 2 && age != AgeBracket.PRE_K.raw) set += Topic.READING
        if (v < 3) set += Topic.HOLIDAYS
        return set
    }

/** Profile.owns: bought for this child, and a pass still in date. */
fun Child.ownsPack(t: Topic): Boolean {
    if (!packs.contains(t.raw)) return false
    val exp = raw.map("packExpiry")?.dbl(t.raw) ?: return true
    return exp > nowSecs()
}

/**
 * Profile.allows. Packs: only those bought for this child (the founder's
 * pack visibility is a cloud config the Android app doesn't read, so Tofy+
 * access to every pack isn't listed here).
 */
fun Child.allows(t: Topic): Boolean {
    if (!t.hasContent()) return false
    if (t.isPack) return ownsPack(t) && !disabledPacks.contains(t.raw)
    return enabledTopicSet.contains(t)
}

val Child.playableTopics: Set<Topic> get() = Topic.entries.filter { allows(it) }.toSet()

/** ChildWorldsView.listedWorlds: base worlds with content + pack worlds this child owns. */
fun Child.listedWorlds(): List<World> =
    BaseWorlds.filter { it.topic.hasContent() } +
        Topic.entries.filter { it.isPack && ownsPack(it) && it.hasContent() }.map { World("${it.raw}_world", "", it.emoji, it) }

/** The fields to write for a new enabled-topic set — ChildRecord(profile:): nil (deleted) when all core are on. */
fun enabledTopicsFields(set: Set<Topic>): Map<String, Any?> {
    val base = set.filter { !it.isPack }
    return mapOf(
        "enabledTopics" to (if (base.size >= Topic.core.size) com.google.firebase.firestore.FieldValue.delete() else base.map { it.raw }.sorted()),
        "topicsVersion" to 3,
    )
}

/** Profile.resolvedDailyCap with the iOS ParentSettings default (on, 60 min). */
fun Child.resolvedCap(): Pair<Boolean, Int> {
    val m = dailyCapMinutes ?: return true to DEFAULT_CAP
    return if (m <= 0) false to 0 else true to m
}

const val DEFAULT_CAP = 60

// MARK: - AdaptiveTopicLevel (ChildSettingsView.swift)

enum class Direction { RAISED, EASED }
data class AdaptiveState(val served: Difficulty, val direction: Direction?)

private fun levelOf(d: Difficulty) = when (d) { Difficulty.EASY -> 0.0; Difficulty.MEDIUM -> 1.0; Difficulty.HARD -> 2.0 }
private fun difficultyAt(level: Double) = when (Math.round(level).toInt()) { in Int.MIN_VALUE..0 -> Difficulty.EASY; 1 -> Difficulty.MEDIUM; else -> Difficulty.HARD }

fun adaptiveState(t: Topic, child: Child, adaptive: Map<String, Double>): AdaptiveState {
    val base = levelOf(child.difficultyFor(t))
    val level = adaptive[t.raw] ?: base
    val dir = if (level > base + 0.35) Direction.RAISED else if (level < base - 0.35) Direction.EASED else null
    return AdaptiveState(difficultyAt(level), dir)
}

fun hasAdaptiveSignal(p: Progress) = p.totalAnswered >= 4

fun practicedTopics(child: Child, p: Progress, limit: Int = 6): List<Topic> =
    child.playableTopics.filter { (p.topicAnswered[it.raw] ?: 0) >= 1 }
        .sortedByDescending { p.topicAnswered[it.raw] ?: 0 }.take(limit)

package com.rani.tofy.kid.ui.play

import androidx.compose.ui.graphics.Color
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ContentMode
import com.rani.tofy.kid.content.QuestionPacks
import com.rani.tofy.kid.core.ChestKind
import com.rani.tofy.ui.child.BaseWorlds
import com.rani.tofy.ui.child.Topic

/** AppColor (DesignSystem/Colors.swift) — the kid palette the runner uses. */
object KidColor {
    val starGold = Color(0xFFFFD23F)
    val gemPurple = Color(0xFF9B5DE5)
    val diamondBlue = Color(0xFF4CC9F0)
    val companionGlow = Color(0xFFFFB84D)
    val successMint = Color(0xFF06D6A0)
    val almostWarm = Color(0xFFFF9F1C)
    val flameOrange = Color(0xFFF25C54)
    val dreamyTeal = Color(0xFF48BFE3)
}

/** The bits of World.swift the round needs: id (room progress / unlocks), emoji, name, glow. */
data class PlayWorld(val id: String, val emoji: String, val name: String, val topic: Topic, val glow: Color, val isBonus: Boolean = false)

object PlayWorlds {
    private val glows = mapOf(
        "math_kingdom" to KidColor.flameOrange, "english_land" to Color(0xFFFF5252), "hebrew_land" to Color(0xFFFF8FAB),
        "logic_lab" to Color(0xFF7C4DFF), "science_lab" to Color(0xFF00C853), "history_museum" to Color(0xFFFFC107),
        "geo_journey" to Color(0xFF00ACC1), "money_market" to Color(0xFF43A047), "story_forest" to Color(0xFFAB47BC),
        "holidays" to Color(0xFFFFB300),
    )

    val arena: PlayWorld get() = PlayWorld("bonus_arena", "💫", tr("זִירַת הָעֲנָקִים"), Topic.LOGIC, KidColor.flameOrange, isBonus = true)

    /** Worlds.all: base worlds + one per pack + the arena last. */
    val all: List<PlayWorld>
        get() = BaseWorlds.map { PlayWorld(it.id, it.emoji, it.name, it.topic, glows[it.id] ?: KidColor.flameOrange) } +
            QuestionPacks.all.map { PlayWorld("${it.raw}_world", it.emoji, it.displayName, it, Color(0xFF2ECC71)) } +
            arena

    /** Worlds.forTopic — the world that themes a topic (the feed follows each question). */
    fun forTopic(t: Topic): PlayWorld = all.firstOrNull { it.topic == t && !it.isBonus } ?: all.first()

    fun forMode(mode: ContentMode, currentTopic: Topic): PlayWorld = when (mode) {
        is ContentMode.World -> forTopic(mode.topic)
        ContentMode.BonusArena -> arena
        ContentMode.SmartFeed -> forTopic(currentTopic)
    }
}

/** ChestKind.label (RewardEngine.swift). */
val ChestKind.label: String
    get() = when (this) {
        ChestKind.WOOD -> tr("קוּפְסַת עֵץ")
        ChestKind.GOLD -> tr("קוּפְסַת זָהָב")
        ChestKind.MAGIC -> tr("קוּפְסַת קֶסֶם")
        ChestKind.LEGENDARY -> tr("קוּפְסַת אַגָּדָה")
    }

/** Character3D.HelpLevel — the equipped character is the "smart helper"; pricier tiers help more. */
enum class HelpLevel { ENCOURAGE, HINT, EXPLAIN }

object CharacterHelp {
    // Character3DCatalog prices > 2400⭐ (rare and up). Free/common → encourage.
    private val prices = mapOf(
        "tiger" to 2900, "zebra" to 3200, "zebra_b" to 3450, "crocodile" to 3750, "elephant" to 4200,
        "elephant_b" to 4500, "elephant_c" to 4800, "hedgehog_c" to 2650, "lemur" to 3100, "camel" to 3600,
        "quokka" to 4300, "panda" to 6000, "panda_b" to 6600, "octopus" to 7200, "lion" to 8000,
        "octopus_b" to 7400, "lion_b" to 8400, "dragon" to 12000, "redpanda" to 13000, "unicorn" to 16000, "owl" to 22000,
    )

    /** CharacterTier.help: rare/epic (2401…8800) → hint, legendary/mythic (> 8800) → explain. */
    fun level(characterID: String?): HelpLevel {
        val p = prices[characterID] ?: 0
        return when { p > 8800 -> HelpLevel.EXPLAIN; p > 2400 -> HelpLevel.HINT; else -> HelpLevel.ENCOURAGE }
    }
}

/** HintContent.swift — never the answer, only how to think. */
object HintContent {
    fun hint(t: Topic, girl: Boolean): String = when (t) {
        Topic.MATH -> (if (girl) tr("סִפְרִי לְאַט, אֶחָד-אֶחָד 🔢") else tr("סְפוֹר לְאַט, אֶחָד-אֶחָד 🔢"))
        Topic.ENGLISH -> (if (girl) tr("תַּגִּידִי אֶת הַמִּלָּה בְּקוֹל 🔊") else tr("תַּגִּיד אֶת הַמִּלָּה בְּקוֹל 🔊"))
        Topic.HEBREW -> (if (girl) tr("אִמְרִי אֶת הַמִּלָּה לְאַט 🗣️") else tr("אֱמוֹר אֶת הַמִּלָּה לְאַט 🗣️"))
        Topic.LOGIC -> (if (girl) tr("חַפְּשִׂי מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩") else tr("חַפֵּשׂ מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה 🧩"))
        Topic.SCIENCE -> (if (girl) tr("חִשְׁבִי עַל הַטֶּבַע סְבִיבֵךְ 🔬") else tr("חֲשׁוֹב עַל הַטֶּבַע סְבִיבְךָ 🔬"))
        Topic.HISTORY -> (if (girl) tr("חִשְׁבִי מָה קָרָה קוֹדֶם 🏛️") else tr("חֲשׁוֹב מָה קָרָה קוֹדֶם 🏛️"))
        Topic.GEOGRAPHY -> (if (girl) tr("דַּמְיְנִי אֶת הַמַּפָּה 🌍") else tr("דַּמְיֵן אֶת הַמַּפָּה 🌍"))
        Topic.MONEY -> (if (girl) tr("חִשְׁבִי כַּמָּה זֶה עוֹלֶה 💰") else tr("חֲשׁוֹב כַּמָּה זֶה עוֹלֶה 💰"))
        Topic.READING -> (if (girl) tr("קִרְאִי שׁוּב אֶת הַקֶּטַע לְאַט 📖") else tr("קְרָא שׁוּב אֶת הַקֶּטַע לְאַט 📖"))
        Topic.SOCCER -> (if (girl) tr("תַּחְשְׁבִי עַל מִשְׂחָק שֶׁרָאִית ⚽") else tr("תַּחְשֹׁב עַל מִשְׂחָק שֶׁרָאִיתָ ⚽"))
        Topic.GIFTED -> (if (girl) tr("חַפְּשִׂי אֶת הַחֹק שֶׁחוֹזֵר 🧠") else tr("חַפֵּשׂ אֶת הַחֹק שֶׁחוֹזֵר 🧠"))
        else -> (if (girl) tr("תַּחְשְׁבִי עַל מַה שֶּׁרָאִית אוֹ שָׁמַעַתְּ עַל זֶה 💡") else tr("תַּחְשֹׁב עַל מַה שֶּׁרָאִיתָ אוֹ שָׁמַעְתָּ עַל זֶה 💡"))
    }

    fun explain(t: Topic, girl: Boolean): String = when (t) {
        Topic.MATH -> tr("אֶפְשָׁר לִסְפּוֹר עַל הָאֶצְבָּעוֹת אוֹ לְצַיֵּר נְקוּדּוֹת וְאָז לִסְפּוֹר אֶת הַכֹּל.")
        Topic.ENGLISH -> (if (girl) tr("חִשְׁבִי אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפְּשִׂי אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל.") else tr("חֲשׁוֹב אֵיךְ הַמִּלָּה נִשְׁמַעַת, וְחַפֵּשׂ אֶת הָאוֹתִיּוֹת שֶׁעוֹשׂוֹת אֶת הַצְּלִיל."))
        Topic.HEBREW -> (if (girl) tr("פָּרְקִי אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמְעִי אֵיךְ כָּל חֵלֶק נִכְתָּב.") else tr("פָּרֵק אֶת הַמִּלָּה לַהֲבָרוֹת וְתִשְׁמַע אֵיךְ כָּל חֵלֶק נִכְתָּב."))
        Topic.LOGIC -> (if (girl) tr("בִּדְקִי מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשִׁיכִי אֶת הַסֵּדֶר.") else tr("בְּדוֹק מָה חוֹזֵר אוֹ מִשְׁתַּנֶּה כָּל פַּעַם, וְהַמְשֵׁךְ אֶת הַסֵּדֶר."))
        Topic.SCIENCE -> (if (girl) tr("נַסִּי לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִית בָּעוֹלָם הָאֲמִתִּי.") else tr("נַסֵּה לְהִזָּכֵר בְּמַשֶּׁהוּ דּוֹמֶה שֶׁרָאִיתָ בָּעוֹלָם הָאֲמִתִּי."))
        Topic.HISTORY -> (if (girl) tr("סַדְּרִי אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו.") else tr("סַדֵּר אֶת הַדְּבָרִים לְפִי הַזְּמַן — מָה הָיָה רִאשׁוֹן וּמָה אַחֲרָיו."))
        Topic.GEOGRAPHY -> (if (girl) tr("חִשְׁבִי עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ.") else tr("חֲשׁוֹב עַל הַמָּקוֹם — אֵיפֹה הוּא וּמָה יֵשׁ לְיָדוֹ."))
        Topic.MONEY -> (if (girl) tr("סִפְרִי אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבִדְקִי כַּמָּה יֵשׁ סַךְ הַכֹּל.") else tr("סְפוֹר אֶת הַמַּטְבְּעוֹת בְּיַחַד וּבְדוֹק כַּמָּה יֵשׁ סַךְ הַכֹּל."))
        Topic.READING -> (if (girl) tr("הַתְּשׁוּבָה מִתְחַבֵּאת בַּקֶּטַע — חַפְּשִׂי בּוֹ אֶת הַמִּלִּים מֵהַשְּׁאֵלָה.") else tr("הַתְּשׁוּבָה מִתְחַבֵּאת בַּקֶּטַע — חַפֵּשׂ בּוֹ אֶת הַמִּלִּים מֵהַשְּׁאֵלָה."))
        Topic.SOCCER -> (if (girl) tr("דַּמְיְנִי אֶת הַמִּגְרָשׁ: אֵיפֹה עוֹמֵד כָּל שַׂחְקָן וּמָה מֻתָּר לוֹ לַעֲשׂוֹת.") else tr("דַּמְיֵן אֶת הַמִּגְרָשׁ: אֵיפֹה עוֹמֵד כָּל שַׂחְקָן וּמָה מֻתָּר לוֹ לַעֲשׂוֹת."))
        Topic.GIFTED -> (if (girl) tr("קִרְאִי שׁוּב לְאַט, וּבִדְקִי אֵיזֶה חֹק מַתְאִים לְכָל הָאֵיבָרִים בַּסִּדְרָה.") else tr("קְרָא שׁוּב לְאַט, וּבְדֹק אֵיזֶה חֹק מַתְאִים לְכָל הָאֵיבָרִים בַּסִּדְרָה."))
        else -> tr("הוֹרִידוּ קֹדֶם אֶת הַתְּשׁוּבוֹת שֶׁבֶּטַח לֹא נְכוֹנוֹת — וּבַחֲרוּ מִמַּה שֶּׁנִּשְׁאַר.")
    }
}

/** WorldMapView.clockLabel — "1:36", the build-198 exact time. */
fun clockLabel(seconds: Int): String = "${seconds / 60}:" + "%02d".format(seconds % 60)

/** Int.currencyShort (StarCounter.swift): 1284 → "1.2K". */
fun Int.currencyShort(): String {
    val a = kotlin.math.abs(this.toLong())
    if (a < 1_000) return "$this"
    val sign = if (this < 0) "-" else ""
    fun fmt(v: Double, suffix: String): String {
        if (v < 10) {
            val t = kotlin.math.floor(v * 10) / 10
            val s = String.format(java.util.Locale.US, "%.1f", t)
            return sign + (if (s.endsWith(".0")) s.dropLast(2) else s) + suffix
        }
        return sign + v.toLong() + suffix
    }
    return when {
        a < 1_000_000 -> fmt(a / 1_000.0, "K")
        a < 1_000_000_000 -> fmt(a / 1_000_000.0, "M")
        else -> fmt(a / 1_000_000_000.0, "B")
    }
}

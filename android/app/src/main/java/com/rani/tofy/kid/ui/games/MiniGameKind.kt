package com.rani.tofy.kid.ui.games

import com.rani.tofy.i18n.tr

/**
 * 🎮 MiniGameKind (MiniGameKit.swift) — the twelve mini-games that break up
 * the question loop. Each opens from a world's chooser, and the runner
 * launches one as a ⚡ surprise round. `raw` = the iOS rawValue (prefs keys,
 * the surprise round's "last game").
 */
enum class MiniGameKind(val raw: String, val emoji: String) {
    PAIRS("pairs", "🔗"),
    BALLOON("balloon", "🎈"),
    WORD("word", "🧩"),
    CRUSH("crush", "🧱"),
    WORD_SEARCH("wordSearch", "🔤"),
    LIGHTNING("lightning", "⚡"),
    SORT("sort", "🧺"),
    PATTERN("pattern", "🧠"),
    GAME2048("game2048", "🔢"),
    VAULT("vault", "🔐"),
    GROCERY("grocery", "🛒"),
    BALANCE("balance", "⚖️");

    val title: String
        get() = when (this) {
            PAIRS -> tr("חַבְּרוּ אֶת הַזּוּגוֹת")
            BALLOON -> tr("פּוֹצְצוּ אֶת הַבַּלּוֹנִים")
            WORD -> tr("בְּנוּ אֶת הַמִּלָּה")
            CRUSH -> tr("מְפַצְּחִים")
            WORD_SEARCH -> tr("תַּפְזֹרֶת")
            LIGHTNING -> tr("נָכוֹן אוֹ לֹא נָכוֹן?")
            SORT -> tr("מִיּוּן לַסַּלִּים")
            PATTERN -> tr("הַתַּבְנִית")
            GAME2048 -> tr("2048 שֶׁל טוֹפִּי")
            VAULT -> tr("הַכַּסֶּפֶת")
            GROCERY -> tr("הַמַּכֹּלֶת")
            BALANCE -> tr("מֹאזְנַיִם")
        }

    /** Seconds on the clock for the timed games (a surprise round is shorter). */
    fun seconds(surprise: Boolean): Int = when (this) {
        BALLOON -> 30
        CRUSH, LIGHTNING -> if (surprise) 45 else 60
        SORT -> if (surprise) 30 else 40
        GAME2048 -> if (surprise) 90 else 150
        else -> 0
    }

    fun subtitle(surprise: Boolean): String = when (this) {
        PAIRS -> tr("5 זוּגוֹת — מִצְאוּ לְכָל אֶחָד אֶת הַבֶּן־זוּג שֶׁלּוֹ")
        BALLOON -> tr("%lld שְׁנִיּוֹת — פּוֹצְצוּ רַק אֶת הַנְּכוֹנִים!", seconds(surprise))
        WORD -> tr("5 מִלִּים — לְפִי הַתְּמוּנָה, אוֹת אַחַר אוֹת")
        CRUSH -> tr("%lld שְׁנִיּוֹת — בַּחֲרוּ קֻבִּיּוֹת שֶׁמַּגִּיעוֹת בְּדִיּוּק לַיַּעַד!", seconds(surprise))
        WORD_SEARCH -> tr("5 מִלִּים מִסְתַּתְּרוֹת — גִּרְרוּ אֶצְבַּע עַל כָּל מִלָּה")
        LIGHTNING -> tr("%lld שְׁנִיּוֹת — כַּמָּה שֶׁיּוֹתֵר תְּשׁוּבוֹת נְכוֹנוֹת!", seconds(surprise))
        SORT -> tr("%lld שְׁנִיּוֹת — גִּרְרוּ כָּל פְּרִיט לַסַּל הַמַּתְאִים", seconds(surprise))
        PATTERN -> tr("6 סְדָרוֹת — מָה מַשְׁלִים אֶת הַתַּבְנִית?")
        GAME2048 -> tr("חַבְּרוּ אֲרִיחִים זֵהִים — וְכָל כַּמָּה מַהֲלָכִים מַגִּיעָה שְׁאֵלַת בּוֹנוּס")
        VAULT -> tr("כָּל תְּשׁוּבָה נְכוֹנָה פּוֹתַחַת רֶמֶז — וְהָרְמָזִים מְגַלִּים אֶת הַקּוֹד הַסּוֹדִי")
        GROCERY -> if (surprise) tr("2 קְנִיּוֹת — קוֹנִים לְפִי הָרְשִׁימָה וּמְחַשְּׁבִים עֹדֶף")
        else tr("3 קְנִיּוֹת — קוֹנִים לְפִי הָרְשִׁימָה וּמְחַשְּׁבִים עֹדֶף")
        BALANCE -> tr("5 מֹאזְנַיִם — מָה מֵבִיא אוֹתָם לְאִזּוּן?")
    }

    /** The short name on a world screen's game tile. */
    val shortName: String
        get() = when (this) {
            PAIRS -> tr("זוּגוֹת")
            BALLOON -> tr("בַּלּוֹנִים")
            WORD -> tr("בְּנוּ מִלָּה")
            CRUSH -> tr("מְפַצְּחִים")
            WORD_SEARCH -> tr("תַּפְזֹרֶת")
            LIGHTNING -> tr("נָכוֹן אוֹ לֹא")
            SORT -> tr("מִיּוּן לַסַּלִּים")
            PATTERN -> tr("הַתַּבְנִית")
            GAME2048 -> tr("2048 שֶׁל טוֹפִּי")
            VAULT -> tr("הַכַּסֶּפֶת")
            GROCERY -> tr("הַמַּכֹּלֶת")
            BALANCE -> tr("מֹאזְנַיִם")
        }

    /** The name on the PARENT's side (no niqqud, spelled out — never stripped). */
    val parentName: String
        get() = when (this) {
            PAIRS -> tr("זוגות")
            BALLOON -> tr("בלונים")
            WORD -> tr("בנו מילה")
            CRUSH -> tr("מפצחים")
            WORD_SEARCH -> tr("תפזורת")
            LIGHTNING -> tr("נכון או לא")
            SORT -> tr("מיון לסלים")
            PATTERN -> tr("התבנית")
            GAME2048 -> tr("2048 של טופי")
            VAULT -> tr("הכספת")
            GROCERY -> tr("המכולת")
            BALANCE -> tr("מאזניים")
        }

    /** One line under the game's card in the world's chooser. */
    val blurb: String
        get() = when (this) {
            PAIRS -> tr("מְחַבְּרִים כָּל שְׁאֵלָה לַתְּשׁוּבָה שֶׁלָּהּ")
            BALLOON -> tr("מְפוֹצְצִים רַק אֶת הַנְּכוֹנִים")
            WORD -> tr("בּוֹנִים מִלָּה אוֹת אַחַר אוֹת")
            CRUSH -> tr("קֻבִּיּוֹת שֶׁמַּגִּיעוֹת בְּדִיּוּק לַיַּעַד")
            WORD_SEARCH -> tr("מוֹצְאִים מִלִּים מִסְתַּתְּרוֹת")
            LIGHTNING -> tr("נָכוֹן אוֹ לֹא — מַהֵר!")
            SORT -> tr("כָּל פְּרִיט לַסַּל הַמַּתְאִים")
            PATTERN -> tr("מָה מַמְשִׁיךְ אֶת הַסִּדְרָה?")
            GAME2048 -> tr("מְחַבְּרִים אֲרִיחִים עַד 2048")
            VAULT -> tr("רְמָזִים שֶׁמְּגַלִּים קוֹד סוֹדִי")
            GROCERY -> tr("קוֹנִים, מְחַשְּׁבִים וּמְקַבְּלִים עֹדֶף")
            BALANCE -> tr("מְאַזְּנִים אֶת שְׁתֵּי הַכַּפּוֹת")
        }

    /** 👶 Does this game have a גן form (no words, spoken rule, PreReaderGames content)? */
    val hasPreReaderForm: Boolean get() = this in MiniGameGradeFit.preReaderRoster

    companion object {
        fun of(raw: String?) = entries.firstOrNull { it.raw == raw }

        /** Is there any game at all for the active child (every grade has a roster now). */
        val availableForActiveChild: Boolean
            get() = MiniGameGradeFit.roster(GameEnv.grade(1)).isNotEmpty()
    }
}

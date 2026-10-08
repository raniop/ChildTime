package com.rani.tofy.ui.child

import androidx.compose.ui.graphics.Color
import com.rani.tofy.i18n.tr

/**
 * 🏆 WorldTiers.swift — how a world tier READS, shared by the kid's home tiles,
 * the world chooser, the boss and the parent's child page. The numbers live in
 * `kid.core.WorldStage` (stage = tier × 10 + room).
 */
object WorldTiers {
    /** Card/badge colours: bronze, silver, gold, champion. */
    fun color(tier: Int): Color = when (tier) {
        0 -> Color(0xFFD08A4E)
        1 -> Color(0xFFDDE5F2)
        2 -> Color(0xFFFFD25A)
        else -> Color(0xFF38D18C)
    }

    /** The kid's badge for a tier — the mockup: every played world wears one. */
    fun kidBadge(tier: Int, girl: Boolean): String? = when (tier) {
        0 -> tr("⭐ דַּרְגָּה 1")
        1 -> tr("⭐⭐ דַּרְגָּה 2")
        2 -> tr("⭐⭐⭐ דַּרְגָּה 3")
        else -> if (girl) tr("👑 אַלּוּפָה") else tr("👑 אַלּוּף")
    }

    /** The crowns line under a world's name once a tier is done (null before the first). */
    fun crownsLine(tier: Int): String? = when {
        tier == 1 -> tr("👑 דַּרְגָּה 1 הֻשְׁלְמָה")
        tier == 2 -> tr("👑👑 2 דַּרְגּוֹת הֻשְׁלְמוּ")
        tier >= 3 -> tr("👑👑👑 כָּל הַדַּרְגּוֹת הֻשְׁלְמוּ")
        else -> null
    }

    /** The parent's line for a world: tier, then room or "boss waiting". */
    fun parentLabel(tier: Int, room: Int): String {
        val where = if (room >= 9) tr("הבוס מחכה") else tr("חדר %lld/10", room + 1)
        return when (tier) {
            0 -> tr("⭐ ארד") + " · " + where
            1 -> tr("⭐⭐ כסף") + " · " + where
            2 -> tr("⭐⭐⭐ זהב") + " · " + where
            else -> tr("👑 השלם")
        }
    }
}

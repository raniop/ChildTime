package com.rani.tofy.kid.ui.shop

import androidx.compose.ui.graphics.Color
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.ChestReward
import com.rani.tofy.kid.core.ProgressEngine
import kotlin.random.Random
import com.rani.tofy.kid.ui.social.SocialMe

/** WheelPrize.Kind (LuckyWheel.swift). */
sealed class WheelPrizeKind {
    data class Stars(val n: Int) : WheelPrizeKind()
    data class Diamonds(val n: Int) : WheelPrizeKind()
    data class Minutes(val n: Int) : WheelPrizeKind()
    data class RareItem(val cosmeticID: String) : WheelPrizeKind()
    /** A gentle family chore — never on the wheel today (every wedge is a win). */
    data class FunMission(val task: String) : WheelPrizeKind()
}

data class WheelPrize(val key: String, val kind: WheelPrizeKind, val label: String, val emoji: String, val argb: Long) {
    val color: Color get() = Color(argb)
    val isPenalty: Boolean get() = kind is WheelPrizeKind.FunMission
}

/**
 * LuckyWheelCatalog + the spin maths of LuckyWheelView.
 *
 * EXACT ODDS (iOS): the pool is every non-penalty prize (13; 11 when minute
 * prizes are excluded), shuffled, first 8 become the wedges, and the winner is
 * a uniform pick among the 8. So every pool prize wins with probability
 * 8/N × 1/8 = 1/N — 1/13 each (1/11 with minutes excluded).
 */
object LuckyWheel {
    const val WEDGES = 8
    const val EXTRA_TURNS = 5

    fun prizes(): List<WheelPrize> = listOf(
        WheelPrize("stars15", WheelPrizeKind.Stars(15), tr("15 כּוֹכָבִים"), "⭐", 0xFF9B5DE5),
        WheelPrize("stars45", WheelPrizeKind.Stars(45), tr("45 כּוֹכָבִים"), "⭐", 0xFF5E60CE),
        WheelPrize("stars90", WheelPrizeKind.Stars(90), tr("90 כּוֹכָבִים!"), "🌟", 0xFFF15BB5),
        WheelPrize("stars30", WheelPrizeKind.Stars(30), tr("30 כּוֹכָבִים"), "⭐", 0xFFFFD166),
        WheelPrize("min5", WheelPrizeKind.Minutes(5), tr("+5 דַּק' מִשְׂחָק"), "⏰", 0xFF06D6A0),
        WheelPrize("min10", WheelPrizeKind.Minutes(10), tr("+10 דַּק' מִשְׂחָק"), "⏱", 0xFF118AB2),
        WheelPrize("stars60", WheelPrizeKind.Stars(60), tr("+60 כּוֹכָבִים"), "🌟", 0xFFFFB84D),
        WheelPrize("stars150", WheelPrizeKind.Stars(150), tr("+150 כּוֹכָבִים!"), "🌟", 0xFFF59E0B),
        WheelPrize("crown", WheelPrizeKind.RareItem("hat_crown"), tr("כֶּתֶר זָהָב!"), "👑", 0xFFFFD166),
        WheelPrize("dia100", WheelPrizeKind.Diamonds(100), tr("100 יַהֲלוֹמִים!"), "💎", 0xFF9B5DE5),
        WheelPrize("dia10", WheelPrizeKind.Diamonds(10), tr("10 יַהֲלוֹמִים"), "💎", 0xFF4CC9F0),
        WheelPrize("dia25", WheelPrizeKind.Diamonds(25), tr("25 יַהֲלוֹמִים"), "💎", 0xFF4895EF),
        WheelPrize("dia50", WheelPrizeKind.Diamonds(50), tr("50 יַהֲלוֹמִים!"), "💎", 0xFF3A86FF),
        WheelPrize("room", WheelPrizeKind.FunMission(tr("לְסַדֵּר אֶת הַחֶדֶר 🧸")), tr("מְסַדְּרִים חֶדֶר"), "🧹", 0xFFFF6B6B),
        WheelPrize("bag", WheelPrizeKind.FunMission(tr("לְהָכִין תִּיק לַגַּן/בֵּית סֵפֶר 🎒")), tr("מְכִינִים תִּיק"), "🎒", 0xFFFF6B9D),
        WheelPrize("table", WheelPrizeKind.FunMission(tr("לַעֲזוֹר לַעֲרוֹךְ שׁוּלְחָן 🍽")), tr("עוֹרְכִים שׁוּלְחָן"), "🍽", 0xFFFFB84D),
        WheelPrize("socks", WheelPrizeKind.FunMission(tr("לְקַפֵּל גַּרְבַּיִם קְטַנִּים 🧦")), tr("מְקַפְּלִים גַּרְבַּיִם"), "🧦", 0xFF5B9BFF),
    )

    /** The pool one spin draws from: every win (no chores), minus minutes when there's no room for them. */
    fun pool(excludeMinutes: Boolean): List<WheelPrize> =
        prizes().filter { !it.isPenalty && !(excludeMinutes && it.kind is WheelPrizeKind.Minutes) }

    /** wedgesForSpin: a fresh 8-wedge layout each time. */
    fun wedgesForSpin(excludeMinutes: Boolean = false, random: Random = Random.Default): List<WheelPrize> =
        pool(excludeMinutes).shuffled(random).take(WEDGES)

    /** The winning wedge is picked FIRST (uniform), then the wheel spins to land on it. */
    fun winnerIndex(wedgeCount: Int, random: Random = Random.Default): Int = random.nextInt(wedgeCount)

    /** Probability that [prize] wins one spin (see the header). */
    fun odds(excludeMinutes: Boolean): Double = 1.0 / pool(excludeMinutes).size

    /** Wedge i's centre, in degrees clockwise from 12 o'clock. */
    fun wedgeCenter(index: Int, count: Int): Double { val per = 360.0 / count; return index * per + per / 2 }

    /** The final rotation that brings wedge [index]'s centre under the top pointer. */
    fun landingRotation(index: Int, count: Int): Double = EXTRA_TURNS * 360.0 + (360 - wedgeCenter(index, count))

    /** Which wedge sits under the pointer at [rotation] (the inverse of [landingRotation]). */
    fun wedgeUnderPointer(rotation: Double, count: Int): Int {
        val a = ((360 - rotation % 360) % 360 + 360) % 360
        return (a / (360.0 / count)).toInt().coerceIn(0, count - 1)
    }

    /**
     * WheelPrize.apply — grant the prize (inside KidSession.edit) and return
     * the kid-facing line. [unlockCosmetic] records a cosmetic prize; returns
     * false when it was already owned (then a 💎 consolation instead).
     */
    fun apply(prize: WheelPrize, e: ProgressEngine, unlockCosmetic: (CosmeticItem) -> Boolean): String = when (val k = prize.kind) {
        is WheelPrizeKind.Stars -> {
            e.applyChestReward(ChestReward(k.n, 0, 0))
            tr("+%lld כּוֹכָבִים נוֹסְפוּ!", k.n)
        }
        is WheelPrizeKind.Diamonds -> {
            e.applyChestReward(ChestReward(0, k.n, 0))
            tr("+%lld יַהֲלוֹמִים נוֹסְפוּ! 💎", k.n)
        }
        is WheelPrizeKind.Minutes -> {
            val g = e.grantBonusMinutes(k.n)
            when {
                g.addedToday > 0 && g.bankedForTomorrow > 0 ->
                    tr("+%lld דַּקּוֹת עַכְשָׁיו · עוֹד %lld נִשְׁמְרוּ לְמָחָר 🎁", g.addedToday, g.bankedForTomorrow)
                g.bankedForTomorrow > 0 ->
                    com.rani.tofy.kid.ui.BankedNote.capReached(g.bankedForTomorrow, e.snapshot.carryOverMinutes ?: 0, ProgressEngine.MAX_CARRY_OVER, SocialMe.isGirl)
                else -> tr("+%lld דַּקּוֹת נוֹסְפוּ לִזְמַן הַמִּשְׂחָק", g.addedToday)
            }
        }
        is WheelPrizeKind.RareItem -> {
            val item = CosmeticCatalog.item(k.cosmeticID)
            if (item != null && unlockCosmetic(item)) SocialMe.g(tr("פָּתַחְתָּ פְּרִיט נָדִיר: %@!", item.name), tr("פָּתַחַתְּ פְּרִיט נָדִיר: %@!", item.name))
            else {
                // Already owned → a diamond consolation the kid can spend, never a loss.
                e.applyChestReward(ChestReward(45, 15, 0))
                SocialMe.g(tr("כְּבָר יֵשׁ לְךָ אֶת הַפְּרִיט הַזֶּה — קַבֵּל 15 יַהֲלוֹמִים בִּמְקוֹם 💎"), tr("כְּבָר יֵשׁ לָךְ אֶת הַפְּרִיט הַזֶּה — קַבְּלִי 15 יַהֲלוֹמִים בִּמְקוֹם 💎"))
            }
        }
        is WheelPrizeKind.FunMission -> tr("משימה: %@", k.task)
    }
}

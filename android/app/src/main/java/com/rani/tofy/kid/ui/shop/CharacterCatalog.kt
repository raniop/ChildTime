package com.rani.tofy.kid.ui.shop

import androidx.compose.ui.graphics.Color
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.RewardEngine

/**
 * One collectible character — ChildTime/Models/Character3DCatalog.swift
 * (Character3D). Every roster entry is a flat 2D PNG on both platforms
 * (R.drawable.char_<id>), so `id` is also the image name.
 */
data class ShopCharacter(val id: String, val name: String, val priceStars: Int) {
    val isFree: Boolean get() = priceStars == 0
    /** 💎 cost — the legacy ⭐ price re-denominated (RewardEngine.diamondPrice). */
    val priceDiamonds: Int get() = RewardEngine.diamondPrice(priceStars)
    val tier: CharacterTier get() = CharacterTier.of(priceStars)
}

/** CharacterTier: rarity derived from price — drives the card colour and how smart a helper the character is. */
enum class CharacterTier(val argb: Long) {
    FREE(0xFF9EA8B8), COMMON(0xFF4DC773), RARE(0xFF4099FA), EPIC(0xFFAD66F2), LEGENDARY(0xFFFFC72E), MYTHIC(0xFFFA599E);

    val color: Color get() = Color(argb)

    val label: String
        get() = when (this) {
            FREE -> tr("חִנָּם")
            COMMON -> tr("רָגִיל")
            RARE -> tr("נָדִיר")
            EPIC -> tr("מְיוּחָד")
            LEGENDARY -> tr("אַגָּדִי")
            MYTHIC -> tr("מִיתִי")
        }

    /** CharacterTier.help — free/common encourage, rare/epic hint, legendary/mythic explain (never the answer). */
    val help: Help
        get() = when (this) {
            FREE, COMMON -> Help.ENCOURAGE
            RARE, EPIC -> Help.HINT
            LEGENDARY, MYTHIC -> Help.EXPLAIN
        }

    enum class Help { ENCOURAGE, HINT, EXPLAIN }

    companion object {
        /** The exact iOS price bands. */
        fun of(priceStars: Int): CharacterTier = when {
            priceStars <= 0 -> FREE
            priceStars <= 2400 -> COMMON
            priceStars <= 5200 -> RARE
            priceStars <= 8800 -> EPIC
            priceStars <= 20000 -> LEGENDARY
            else -> MYTHIC
        }
    }
}

/** Character3DCatalog.all — same ids, names, prices and display order as iOS. */
object CharacterCatalog {
    const val DEFAULT_ID = "fox"

    /** id → ⭐ price, in display order (no tr(): safe for tests and hot paths). */
    val prices: LinkedHashMap<String, Int> = linkedMapOf(
        // 🆓 Free
        "fox" to 0, "bunny" to 0, "penguin" to 0, "bear" to 0,
        // 🟢 Common (≤2400)
        "hamster" to 950, "hamster_b" to 1050, "squirrel" to 1050, "squirrel_b" to 1100, "turtle" to 1150,
        "hedgehog" to 1200, "hedgehog_b" to 1250, "fennec" to 1300, "monkey" to 1350, "gazelle" to 1450,
        "ibex" to 1550, "pig" to 1600, "pig_b" to 1700, "koala" to 1800, "koala_b" to 1850, "koala_c" to 1950,
        "otter" to 2000, "fox_b" to 2100, "crocodile_b" to 2250, "mouse" to 1500, "chinchilla" to 1650,
        "koala_d" to 1900, "koala_e" to 2300,
        // 🔵 Rare (2401–5200)
        "tiger" to 2900, "zebra" to 3200, "zebra_b" to 3450, "crocodile" to 3750, "elephant" to 4200,
        "elephant_b" to 4500, "elephant_c" to 4800, "hedgehog_c" to 2650, "lemur" to 3100, "camel" to 3600,
        "quokka" to 4300,
        // 🟣 Epic (5201–8800)
        "panda" to 6000, "panda_b" to 6600, "octopus" to 7200, "lion" to 8000, "octopus_b" to 7400, "lion_b" to 8400,
        // 👑 Legendary (8801–20000)
        "dragon" to 12000, "redpanda" to 13000, "unicorn" to 16000,
        // 🩷 Mythic (20001+)
        "owl" to 22000,
    )

    /** The localized display name (Character3D.name). */
    fun name(id: String): String = when (id.substringBefore('_')) {   // alternate-art variants (koala_c…) share the name
        "fox" -> tr("שׁוּעָל")
        "bunny" -> tr("אַרְנָב")
        "penguin" -> tr("פִּינְגְּוִין")
        "bear" -> tr("דּוֹב")
        "hamster" -> tr("אוֹגֵר")
        "squirrel" -> tr("סְנָאִי")
        "turtle" -> tr("צָב")
        "hedgehog" -> tr("קִיפּוֹד")
        "fennec" -> tr("פֶנֶק")
        "monkey" -> tr("קוֹף")
        "gazelle" -> tr("צְבִי")
        "ibex" -> tr("יָעֵל")
        "pig" -> tr("חֲזַרְזִיר")
        "koala" -> tr("קוֹאָלָה")
        "otter" -> tr("לוּטְרָה")
        "crocodile" -> tr("תַּנִּין")
        "mouse" -> tr("עַכְבָּר")
        "chinchilla" -> tr("צִ'ינְצִ'ילָה")
        "tiger" -> tr("נָמֵר")
        "zebra" -> tr("זֶבְּרָה")
        "elephant" -> tr("פִּיל")
        "lemur" -> tr("לֶמוּר")
        "camel" -> tr("גָּמָל")
        "quokka" -> tr("קְווֹקָה")
        "panda" -> tr("פַּנְדָּה")
        "octopus" -> tr("תַּמְנוּן")
        "lion" -> tr("אַרְיֵה")
        "dragon" -> tr("דְּרָקוֹן")
        "redpanda" -> tr("פַּנְדָּה אֲדוּמָּה")
        "unicorn" -> tr("חַד-קֶרֶן")
        "owl" -> tr("יַנְשׁוּף")
        else -> tr("שׁוּעָל")
    }

    /** The whole roster in display order (names resolved in the current language). */
    fun all(): List<ShopCharacter> = prices.map { (id, p) -> ShopCharacter(id, name(id), p) }

    /** Character3DCatalog.find: nil / unknown → the default character. */
    fun find(id: String?): ShopCharacter {
        val key = id?.takeIf { it in prices } ?: DEFAULT_ID
        return ShopCharacter(key, name(key), prices.getValue(key))
    }

    /** The runner's helper level for the equipped character (legendary/mythic explain, rare/epic hint). */
    fun help(id: String?): CharacterTier.Help = CharacterTier.of(prices[id] ?: 0).help
}

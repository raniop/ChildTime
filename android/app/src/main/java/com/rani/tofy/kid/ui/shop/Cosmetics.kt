package com.rani.tofy.kid.ui.shop

import android.content.Context
import android.content.SharedPreferences
import androidx.compose.ui.graphics.Color
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.RewardEngine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONObject

/** CosmeticCategory (CosmeticItem.swift) — at most one equipped item per category. */
enum class CosmeticCategory(val raw: String, val icon: String, val sortOrder: Int, val zIndex: Int) {
    HAT("hat", "🎩", 0, 7), GLASSES("glasses", "👓", 1, 6), SHIRT("shirt", "👕", 2, 4), PANTS("pants", "👖", 3, 3),
    SHOES("shoes", "👟", 4, 2), ACCESSORY("accessory", "💎", 5, 5), BACKPACK("backpack", "🎒", 6, 1), VEHICLE("vehicle", "🛹", 7, 0);

    val displayName: String
        get() = when (this) {
            HAT -> tr("כּוֹבָעִים")
            GLASSES -> tr("מִשְׁקָפַיִם")
            SHIRT -> tr("חוּלְצוֹת")
            PANTS -> tr("מִכְנָסַיִם")
            SHOES -> tr("נַעֲלַיִם")
            ACCESSORY -> tr("אַקְסֶסוֹרִיז")
            BACKPACK -> tr("תִּיקִים")
            VEHICLE -> tr("גַּלְגַּלִּים")
        }

    /**
     * ProfileAvatarView.position(for:) — offset in units of the avatar size and
     * the item's scale, so a hat sits on the crown and glasses on the eyes.
     */
    val anchor: Triple<Float, Float, Float>
        get() = when (this) {
            HAT -> Triple(0f, -0.40f, 0.54f)
            GLASSES -> Triple(0f, -0.05f, 0.52f)
            SHIRT -> Triple(0f, 0.34f, 0.32f)
            PANTS -> Triple(0f, 0.46f, 0.24f)
            SHOES -> Triple(0f, 0.52f, 0.22f)
            ACCESSORY -> Triple(0.34f, -0.30f, 0.26f)
            BACKPACK -> Triple(-0.36f, 0.08f, 0.28f)
            VEHICLE -> Triple(0.36f, 0.38f, 0.30f)
        }

    companion object { fun of(raw: String?) = entries.firstOrNull { it.raw == raw } }
}

/** CosmeticRarity — card border colour and shop sort priority. */
enum class CosmeticRarity(val argb: Long) {
    COMMON(0xFF9CA3AF), RARE(0xFF5B9BFF), EPIC(0xFF9B5DE5), LEGENDARY(0xFFF59E0B);

    val color: Color get() = Color(argb)
    val label: String
        get() = when (this) {
            COMMON -> tr("רָגִיל")
            RARE -> tr("נָדִיר")
            EPIC -> tr("אַגָּדִי")
            LEGENDARY -> tr("נָדִיר בִּמְיוּחָד")
        }
}

/** CosmeticItem — stable string ids so a kid's inventory survives renames. Rendered as its emoji. */
data class CosmeticItem(
    val id: String, val category: CosmeticCategory, val name: String, val emoji: String,
    val rarity: CosmeticRarity, val price: Int,
) {
    /** 💎 cost — the legacy ⭐ `price` re-denominated into diamonds. */
    val priceDiamonds: Int get() = RewardEngine.diamondPrice(price)
}

/** CosmeticCatalog.swift — the master list, same ids/prices as iOS. */
object CosmeticCatalog {
    /** Every kid starts owning these (keeps the avatar editable from minute zero). */
    val starterFreeIDs: Set<String> = setOf("shirt_tee", "pants_jeans", "shoes_sneakers", "hat_cap")

    fun all(): List<CosmeticItem> {
        val h = CosmeticCategory.HAT; val g = CosmeticCategory.GLASSES; val s = CosmeticCategory.SHIRT; val p = CosmeticCategory.PANTS
        val sh = CosmeticCategory.SHOES; val a = CosmeticCategory.ACCESSORY; val b = CosmeticCategory.BACKPACK; val v = CosmeticCategory.VEHICLE
        val c = CosmeticRarity.COMMON; val r = CosmeticRarity.RARE; val e = CosmeticRarity.EPIC; val l = CosmeticRarity.LEGENDARY
        return listOf(
            CosmeticItem("hat_party", h, tr("כּוֹבַע מְסִיבָּה"), "🎉", c, 30),
            CosmeticItem("hat_cap", h, tr("כּוֹבַע מִצְחִיָּה"), "🧢", c, 30),
            CosmeticItem("hat_top", h, tr("כּוֹבַע צִילִינְדֶּר"), "🎩", r, 75),
            CosmeticItem("hat_graduate", h, tr("כּוֹבַע סְטוּדֶנְט"), "🎓", r, 90),
            CosmeticItem("hat_cowboy", h, tr("כּוֹבַע בּוֹקְרִים"), "🤠", e, 165),
            CosmeticItem("hat_crown", h, tr("כֶּתֶר זָהָב"), "👑", l, 360),
            CosmeticItem("hat_helmet", h, tr("קַסְדָּה"), "⛑", r, 75),
            CosmeticItem("hat_unicorn", h, tr("קֶרֶן חַד-קֶרֶן"), "🦄", l, 390),
            CosmeticItem("hat_pirate", h, tr("כּוֹבַע פִּירָאט"), "🏴‍☠️", e, 180),
            CosmeticItem("hat_santa", h, tr("כּוֹבַע חוֹרֶף"), "🎄", c, 36),

            CosmeticItem("glasses_round", g, tr("מִשְׁקָפַיִם עֲגוּלִים"), "🤓", c, 36),
            CosmeticItem("glasses_shade", g, tr("מִשְׁקְפֵי שֶׁמֶשׁ"), "😎", r, 66),
            CosmeticItem("glasses_3d", g, tr("מִשְׁקְפֵי 3D"), "🥽", e, 150),
            CosmeticItem("glasses_vr", g, tr("מִשְׁקְפֵי VR"), "🕶", e, 210),
            CosmeticItem("glasses_heart", g, tr("מִשְׁקְפֵי לֵב"), "💖", l, 330),
            CosmeticItem("glasses_star", g, tr("מִשְׁקְפֵי כּוֹכָבִים"), "⭐", l, 345),

            CosmeticItem("shirt_tee", s, tr("חוּלְצַת טְרִיקוֹ"), "👕", c, 24),
            CosmeticItem("shirt_hoodie", s, tr("קַפּוּצ׳וֹן"), "🧥", r, 75),
            CosmeticItem("shirt_kimono", s, tr("קִימוֹנוֹ"), "🥋", r, 90),
            CosmeticItem("shirt_lab", s, tr("חָלוּק מַדְעָן"), "🥼", e, 165),
            CosmeticItem("shirt_tuxedo", s, tr("סְמוֹקִינְג"), "🤵", e, 195),
            CosmeticItem("shirt_jersey", s, tr("חוּלְצַת סְפּוֹרְט"), "🎽", c, 36),
            CosmeticItem("shirt_kingrobe", s, tr("גְּלִימַת מֶלֶךְ"), "👘", l, 390),
            CosmeticItem("shirt_jacket", s, tr("זָ'קֵט"), "🧥", r, 84),

            CosmeticItem("pants_jeans", p, tr("גִּ'ינְס"), "👖", c, 30),
            CosmeticItem("pants_shorts", p, tr("מִכְנָסַיִם קְצָרִים"), "🩳", c, 24),
            CosmeticItem("pants_skirt", p, tr("חֲצָאִית"), "👗", r, 75),
            CosmeticItem("pants_sweats", p, tr("מִכְנְסֵי טְרֶנִינְג"), "🩲", c, 27),
            CosmeticItem("pants_overalls", p, tr("אוֹבֵרוֹל"), "👨‍🌾", e, 165),

            CosmeticItem("shoes_sneakers", sh, tr("סְנִיקֶרְס"), "👟", c, 30),
            CosmeticItem("shoes_boots", sh, tr("מַגָּפַיִים"), "🥾", r, 75),
            CosmeticItem("shoes_heels", sh, tr("עֲקֵבִים"), "👠", r, 84),
            CosmeticItem("shoes_runners", sh, tr("נַעֲלֵי רִיצָה"), "🏃", e, 165),
            CosmeticItem("shoes_ballet", sh, tr("נַעֲלֵי בָּלֵט"), "🩰", e, 180),
            CosmeticItem("shoes_magic", sh, tr("נַעֲלֵי קֶסֶם"), "✨", l, 360),

            CosmeticItem("acc_watch", a, tr("שָׁעוֹן"), "⌚", c, 36),
            CosmeticItem("acc_medal", a, tr("מֶדַלְיָה"), "🏅", r, 75),
            CosmeticItem("acc_trophy", a, tr("גָּבִיעַ"), "🏆", e, 180),
            CosmeticItem("acc_wand", a, tr("שַׁרְבִיט קֶסֶם"), "🪄", e, 195),
            CosmeticItem("acc_balloon", a, tr("בַּלּוֹן"), "🎈", c, 30),
            CosmeticItem("acc_butterfly", a, tr("פַּרְפַּר"), "🦋", r, 66),
            CosmeticItem("acc_lightning", a, tr("בָּרָק קֶסֶם"), "⚡", l, 345),

            CosmeticItem("bag_school", b, tr("תִּיק בֵּית סֵפֶר"), "🎒", c, 36),
            CosmeticItem("bag_briefcase", b, tr("תִּיק עֲבוֹדָה"), "💼", r, 75),
            CosmeticItem("bag_purse", b, tr("אַרְנָק"), "👛", c, 30),
            CosmeticItem("bag_pouch", b, tr("תִּיק קָטָן"), "👝", r, 66),

            CosmeticItem("ride_skateboard", v, tr("סְקֵייטְבּוֹרְד"), "🛹", r, 90),
            CosmeticItem("ride_scooter", v, tr("קוֹרְקִינֶט"), "🛴", r, 84),
            CosmeticItem("ride_bike", v, tr("אוֹפַנַּיִים"), "🚲", e, 180),
            CosmeticItem("ride_surfboard", v, tr("גַּלְשָׁן"), "🏄", e, 195),
            CosmeticItem("ride_basketball", v, tr("כַּדּוּרְסַל"), "🏀", c, 36),
        )
    }

    fun item(id: String?): CosmeticItem? = id?.let { k -> all().firstOrNull { it.id == k } }

    /** items(in:) — rarity ascending, then price. */
    fun items(category: CosmeticCategory): List<CosmeticItem> =
        all().filter { it.category == category }.sortedWith(compareBy({ it.rarity.ordinal }, { it.price }))
}

/**
 * CosmeticStore.swift — DEVICE-LOCAL on iOS too (UserDefaults, never synced):
 * ownership is family-wide on this device, equipping is per child. Purchases
 * burn 💎 through the engine (see ShopOps.purchaseCosmetic). Items granted by a
 * chest (LocalPlayState.ownedCosmetics) count as owned as well.
 */
object CosmeticStore {
    private const val PREFS = "tofy.cosmetics"
    private const val KEY_OWNED = "cosmetics.ownedIDs"
    private const val KEY_EQUIPPED = "cosmetics.equippedByProfile"   // {childID: {category: itemID}}
    private const val KEY_SEEDED = "cosmetics.didSeedStarter"

    private var prefs: SharedPreferences? = null
    private val _owned = MutableStateFlow<Set<String>>(emptySet())
    val owned: StateFlow<Set<String>> = _owned
    private val _equipped = MutableStateFlow<Map<String, Map<String, String>>>(emptyMap())
    val equipped: StateFlow<Map<String, Map<String, String>>> = _equipped

    fun init(context: Context) {
        if (prefs != null) return
        val p = context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs = p
        var owned = p.getStringSet(KEY_OWNED, emptySet())?.toSet() ?: emptySet()
        if (!p.getBoolean(KEY_SEEDED, false)) {
            owned = owned + CosmeticCatalog.starterFreeIDs
            p.edit().putBoolean(KEY_SEEDED, true).putStringSet(KEY_OWNED, owned).apply()
        }
        _owned.value = owned
        _equipped.value = runCatching {
            val j = JSONObject(p.getString(KEY_EQUIPPED, "{}") ?: "{}")
            j.keys().asSequence().associateWith { cid ->
                val m = j.getJSONObject(cid); m.keys().asSequence().associateWith { m.getString(it) }
            }
        }.getOrDefault(emptyMap())
    }

    /** Owned on this device, plus anything a chest put in the child's local state. */
    fun owns(id: String, chestOwned: Set<String> = emptySet()): Boolean = id in _owned.value || id in chestOwned

    /** unlockFree — a prize (Lucky Wheel crown). No-op when already owned. */
    fun unlockFree(id: String) {
        if (id in _owned.value) return
        val next = _owned.value + id
        _owned.value = next
        prefs?.edit()?.putStringSet(KEY_OWNED, next)?.apply()
    }

    fun equippedItems(childID: String): List<CosmeticItem> =
        (_equipped.value[childID] ?: emptyMap()).values.mapNotNull { CosmeticCatalog.item(it) }.sortedBy { it.category.sortOrder }

    /** Put [item] on [childID] (replacing that category), or remove the category when null / not owned. */
    fun equip(item: CosmeticItem?, category: CosmeticCategory, childID: String, chestOwned: Set<String> = emptySet()) {
        val map = (_equipped.value[childID] ?: emptyMap()).toMutableMap()
        if (item != null && owns(item.id, chestOwned)) map[category.raw] = item.id else map.remove(category.raw)
        val all = _equipped.value.toMutableMap().also { it[childID] = map }
        _equipped.value = all
        val j = JSONObject(); all.forEach { (cid, m) -> j.put(cid, JSONObject(m as Map<*, *>)) }
        prefs?.edit()?.putString(KEY_EQUIPPED, j.toString())?.apply()
    }
}

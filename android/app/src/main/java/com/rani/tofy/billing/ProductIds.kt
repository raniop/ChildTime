package com.rani.tofy.billing

import com.rani.tofy.data.Child
import com.rani.tofy.data.dbl
import com.rani.tofy.data.map
import com.rani.tofy.data.nowSecs
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.child.hasContent

/**
 * Google Play product ids — the SAME catalog as iOS, renamed to what Play
 * accepts (lowercase letters, digits, `_` and `.`; must start with a letter or
 * digit). Create exactly these in Play Console (docs/PLAY_BILLING_SETUP.md) and
 * keep functions/index.js PLAY_SUBSCRIPTION_IDS / PLAY_INAPP_ID in sync.
 *
 *  iOS (App Store Connect)                         Play Console
 *  com.rani.ChildTime.premium.monthly         →   tofy_plus_monthly   (subscription, base plan "monthly", P1M)
 *  com.rani.ChildTime.premium.yearly          →   tofy_plus_yearly    (subscription, base plan "yearly", P1Y)
 *  com.rani.ChildTime.stars.small|medium|large →  stars_small|medium|large       (consumable one-time)
 *  com.rani.ChildTime.pack.<id>               →   pack_<id>           (consumable one-time)
 *  com.rani.ChildTime.pack.<id>.sibling       →   pack_<id>_sibling
 *  com.rani.ChildTime.world.<topic>.30d       →   pass_<topic>
 *  com.rani.ChildTime.world.<topic>.30d.sibling → pass_<topic>_sibling
 *
 * Packs and passes are CONSUMABLE on Play too (iOS: consumable), so a family can
 * buy the same pack for a second child and renew a pass; the entitlement lives
 * in OUR data (children.packs / packExpiry, households.ownedPacks).
 */
object ProductIds {
    const val MONTHLY = "tofy_plus_monthly"
    const val YEARLY = "tofy_plus_yearly"
    val SUBSCRIPTIONS = listOf(MONTHLY, YEARLY)

    const val STARS_SMALL = "stars_small"     // 60 💎
    const val STARS_MEDIUM = "stars_medium"   // 200 💎
    const val STARS_LARGE = "stars_large"     // 500 💎
    val STARS = listOf(STARS_SMALL, STARS_MEDIUM, STARS_LARGE)

    /** StarPackStore.diamonds(for:) */
    fun diamonds(productId: String): Int = when (productId) {
        STARS_SMALL -> 60
        STARS_MEDIUM -> 200
        STARS_LARGE -> 500
        else -> 0
    }

    fun isSubscription(id: String) = id in SUBSCRIPTIONS
    fun isStars(id: String) = id in STARS
    fun isPackOrPass(id: String) = id.startsWith("pack_") || id.startsWith("pass_")
}

/**
 * QuestionPack.swift (packs + WorldPasses), the part billing needs. A pack is
 * bought once per child forever; a pass opens one base world for one child for
 * 30 days, no auto-renew. The id is the Topic raw value, as on iOS.
 */
data class PlayPack(val topic: Topic, val isPass: Boolean) {
    val id: String get() = topic.raw
    val durationDays: Int? get() = if (isPass) 30 else null
    val productId: String get() = if (isPass) "pass_$id" else "pack_$id"
    val siblingProductId: String get() = "${productId}_sibling"
    val emoji: String get() = topic.emoji
    val name: String get() = topic.displayName

    companion object {
        /** QuestionPacks.all — every paid pack (catalog order = Topic order). */
        val packs: List<PlayPack> get() = Topic.entries.filter { it.isPack }.map { PlayPack(it, false) }

        /** WorldPasses.all — the base worlds sold for 30 days (not the 🎊/💫 bonus worlds). */
        val passes: List<PlayPack> get() = PASS_TOPICS.map { PlayPack(it, true) }

        /** WorldPasses.available — passes with questions in the app's language. */
        val availablePasses: List<PlayPack> get() = passes.filter { it.topic.hasContent() }

        val all: List<PlayPack> get() = packs + passes
        val allProductIds: List<String> get() = all.flatMap { listOf(it.productId, it.siblingProductId) }

        fun forProduct(productId: String): PlayPack? = all.firstOrNull { it.productId == productId || it.siblingProductId == productId }

        private val PASS_TOPICS = listOf(
            Topic.MATH, Topic.ENGLISH, Topic.HEBREW, Topic.LOGIC, Topic.SCIENCE,
            Topic.HISTORY, Topic.GEOGRAPHY, Topic.MONEY, Topic.READING,
        )
    }
}

/** Profile.ownedPacks contains the pack (iOS childOwnsPack — no expiry check). */
fun Child.hasPackRecord(pack: PlayPack): Boolean = packs.contains(pack.id)

/** Profile.packExpiry[pack] — unix seconds, passes only. */
fun Child.packExpiry(pack: PlayPack): Double? = raw.map("packExpiry")?.dbl(pack.id)

/** Profile.passDaysLeft: whole days left on a pass (nil when not a pass / no expiry). */
fun Child.passDaysLeft(pack: PlayPack): Int? {
    if (!pack.isPass) return null
    val exp = packExpiry(pack) ?: return null
    return maxOf(0, Math.ceil((exp - nowSecs()) / 86_400).toInt())
}

/** Profile.owns: bought for this child, and a pass still in date. */
fun Child.ownsPlayPack(pack: PlayPack): Boolean {
    if (!hasPackRecord(pack)) return false
    if (!pack.isPass) return true
    return (packExpiry(pack) ?: 0.0) > nowSecs()
}

/** Profile.passExpired: a pass this child HAD and lost. */
fun Child.passExpired(pack: PlayPack): Boolean = pack.isPass && hasPackRecord(pack) && !ownsPlayPack(pack)

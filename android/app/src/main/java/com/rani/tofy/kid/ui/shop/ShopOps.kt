package com.rani.tofy.kid.ui.shop

import com.rani.tofy.kid.core.ChestReward
import com.rani.tofy.kid.core.ProgressEngine

/** CharacterStore / CosmeticStore.PurchaseError, as a value. */
sealed class Purchase {
    data class Ok(val price: Int, val balanceAfter: Int) : Purchase()
    data object AlreadyOwned : Purchase()
    data class NotEnoughDiamonds(val short: Int) : Purchase()
}

/** The buy rules, IO-free (unit-tested): owned first, then the 💎 balance. */
object ShopMath {
    fun evaluate(owned: Boolean, priceDiamonds: Int, balance: Int): Purchase = when {
        owned -> Purchase.AlreadyOwned
        balance < priceDiamonds -> Purchase.NotEnoughDiamonds(priceDiamonds - balance)
        else -> Purchase.Ok(priceDiamonds, balance - priceDiamonds)
    }

    /** CharacterStore.owns: free characters are always owned; the rest live in the synced snapshot. */
    fun ownsCharacter(c: ShopCharacter, ownedIDs: Collection<String>): Boolean = c.isFree || c.id in ownedIDs
}

// ── engine ops the shop needs (kid/core stays untouched) ────────────────────

fun ProgressEngine.ownsCharacter(c: ShopCharacter): Boolean = ShopMath.ownsCharacter(c, snapshot.ownedCharacterIDs)

/**
 * CharacterStore.purchase: spend 💎 and add the id to the snapshot's
 * ownedCharacterIDs (a synced, union-merged field). Run inside KidSession.edit.
 */
fun ProgressEngine.purchaseCharacter(c: ShopCharacter): Purchase {
    val r = ShopMath.evaluate(ownsCharacter(c), c.priceDiamonds, snapshot.diamonds)
    if (r is Purchase.Ok) {
        spendDiamonds(c.priceDiamonds)
        addOwnedCharacter(c.id)
    }
    return r
}

/** CharacterStore.unlockFree — a prize; no-op when owned. */
fun ProgressEngine.unlockCharacterFree(c: ShopCharacter) { if (!ownsCharacter(c)) addOwnedCharacter(c.id) }

/** CosmeticStore.purchase — burns 💎 here; the caller records ownership + equips in [CosmeticStore]. */
fun ProgressEngine.purchaseCosmetic(item: CosmeticItem, owned: Boolean): Purchase {
    val r = ShopMath.evaluate(owned, item.priceDiamonds, snapshot.diamonds)
    if (r is Purchase.Ok) spendDiamonds(item.priceDiamonds)
    return r
}

/**
 * DailyChestView.onAppear: the magic chest, and when there's no room left for
 * play-minutes (today's cap full AND tomorrow's bank full) +5⭐ +5💎 instead of minutes.
 */
fun ProgressEngine.dailyChestReward(base: ChestReward): ChestReward =
    if (bonusMinutesRoom() <= 0) ChestReward(base.stars + 5, base.diamonds + 5, 0, base.cosmeticID) else base

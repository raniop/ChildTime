package com.rani.tofy.kid.ui.shop

import com.rani.tofy.kid.core.KidClock
import com.rani.tofy.kid.core.KidSettings
import com.rani.tofy.kid.core.ProgressEngine
import com.rani.tofy.kid.core.ProgressSnapshot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId
import kotlin.math.abs
import kotlin.random.Random

/** The wheel's odds + landing maths and the shop's purchase rules (LuckyWheel.swift, CharacterStore, CosmeticStore). */
class ShopEconomyTest {

    private class FakeClock(override val zone: ZoneId = ZoneId.of("Asia/Jerusalem")) : KidClock {
        var unix = LocalDateTime.of(2026, 10, 7, 10, 0).atZone(zone).toEpochSecond().toDouble()
        override fun nowUnix() = unix
        override fun uptimeSecs() = 1000.0
    }
    private fun engine(diamonds: Int = 0, owned: List<String> = emptyList(), settings: KidSettings = KidSettings()): ProgressEngine {
        val e = ProgressEngine(settings, FakeClock(), "DEV-A")
        if (diamonds > 0) e.addDiamonds(diamonds)
        owned.forEach { e.addOwnedCharacter(it) }
        return e
    }

    // ── 🎡 wheel odds ────────────────────────────────────────────────────────
    @Test fun poolIsAllWinsNoChores() {
        val pool = LuckyWheel.pool(excludeMinutes = false)
        assertEquals(13, pool.size)
        assertTrue(pool.none { it.isPenalty })
        assertEquals(17, LuckyWheel.prizes().size)
        assertEquals(4, LuckyWheel.prizes().count { it.isPenalty })
    }

    @Test fun excludingMinutesDropsBothMinuteWedges() {
        val pool = LuckyWheel.pool(excludeMinutes = true)
        assertEquals(11, pool.size)
        assertTrue(pool.none { it.kind is WheelPrizeKind.Minutes })
        repeat(200) { assertTrue(LuckyWheel.wedgesForSpin(true, Random(it)).none { w -> w.kind is WheelPrizeKind.Minutes }) }
    }

    @Test fun eightDistinctWedgesEverySpin() {
        repeat(500) {
            val w = LuckyWheel.wedgesForSpin(false, Random(it))
            assertEquals(8, w.size)
            assertEquals(8, w.map { p -> p.key }.toSet().size)
        }
    }

    @Test fun exactOddsAreUniformOverThePool() {
        assertEquals(1.0 / 13, LuckyWheel.odds(false), 1e-12)
        assertEquals(1.0 / 11, LuckyWheel.odds(true), 1e-12)
    }

    @Test fun simulatedOddsMatchOneInThirteen() {
        val rnd = Random(20261007)
        val n = 260_000
        val hits = HashMap<String, Int>()
        repeat(n) {
            val w = LuckyWheel.wedgesForSpin(false, rnd)
            val k = w[LuckyWheel.winnerIndex(w.size, rnd)].key
            hits[k] = (hits[k] ?: 0) + 1
        }
        assertEquals(13, hits.size)
        hits.values.forEach { assertTrue("got ${it.toDouble() / n}", abs(it.toDouble() / n - 1.0 / 13) < 0.004) }
        // 💎 jackpot (100) is as likely as any other wedge; diamonds as a group = 4/13.
        val dia = hits.filterKeys { it.startsWith("dia") }.values.sum().toDouble() / n
        assertEquals(4.0 / 13, dia, 0.006)
    }

    // ── 🎯 landing maths: the pointer always ends on the winning wedge ───────
    @Test fun landingPutsWinnerUnderThePointer() {
        for (count in listOf(8, 6, 1)) for (i in 0 until count) {
            val r = LuckyWheel.landingRotation(i, count)
            assertEquals(0.0, (r + LuckyWheel.wedgeCenter(i, count)) % 360.0, 1e-9)
            assertEquals(i, LuckyWheel.wedgeUnderPointer(r, count))
            assertTrue(r >= LuckyWheel.EXTRA_TURNS * 360.0)
        }
    }

    // ── 🎁 wheel prizes land in the right pocket ────────────────────────────
    @Test fun applyStarsDiamondsAndCrown() {
        val e = engine()
        val pr = LuckyWheel.prizes().associateBy { it.key }
        LuckyWheel.apply(pr.getValue("stars150"), e) { true }
        LuckyWheel.apply(pr.getValue("dia100"), e) { true }
        assertEquals(150, e.snapshot.stars); assertEquals(100, e.snapshot.diamonds)
        // Crown already owned → 45⭐ + 15💎 consolation, never a loss.
        LuckyWheel.apply(pr.getValue("crown"), e) { false }
        assertEquals(195, e.snapshot.stars); assertEquals(115, e.snapshot.diamonds)
        var unlocked: String? = null
        LuckyWheel.apply(pr.getValue("crown"), e) { unlocked = it.id; true }
        assertEquals("hat_crown", unlocked)
        assertEquals(115, e.snapshot.diamonds)
    }

    @Test fun minutePrizeFillsTodayThenBanks() {
        val e = engine(settings = KidSettings(childDailyCapMinutes = 60))
        e.grantBonusMinutes(55)
        val before = e.pendingMinutes
        LuckyWheel.apply(LuckyWheel.prizes().first { it.key == "min10" }, e) { true }
        assertEquals(before + 5, e.pendingMinutes)
        assertEquals(5, e.snapshot.carryOverMinutes)
    }

    // ── 💎 purchase math ────────────────────────────────────────────────────
    @Test fun diamondPricesAreStarsOverFive() {
        assertEquals(190, CharacterCatalog.find("hamster").priceDiamonds)       // 950⭐
        assertEquals(4400, CharacterCatalog.find("owl").priceDiamonds)          // 22000⭐
        assertEquals(0, CharacterCatalog.find("fox").priceDiamonds)
        assertEquals(72, CosmeticCatalog.item("hat_crown")!!.priceDiamonds)    // 360⭐
        assertEquals(5, CosmeticCatalog.item("shirt_tee")!!.priceDiamonds)     // 24⭐ → 4.8 → 5
        assertEquals(7, CosmeticCatalog.item("hat_santa")!!.priceDiamonds)     // 36⭐ → 7.2 → 7
    }

    @Test fun evaluateOrder() {
        assertEquals(Purchase.AlreadyOwned, ShopMath.evaluate(owned = true, priceDiamonds = 10, balance = 0))
        assertEquals(Purchase.NotEnoughDiamonds(7), ShopMath.evaluate(false, 190, 183))
        assertEquals(Purchase.Ok(190, 0), ShopMath.evaluate(false, 190, 190))
    }

    @Test fun buyingSpendsAndAddsOwnership() {
        val e = engine(diamonds = 250)
        val tiger = CharacterCatalog.find("tiger")   // 2900⭐ → 580💎
        assertEquals(Purchase.NotEnoughDiamonds(330), e.purchaseCharacter(tiger))
        assertEquals(250, e.snapshot.diamonds)
        val hamster = CharacterCatalog.find("hamster")
        assertEquals(Purchase.Ok(190, 60), e.purchaseCharacter(hamster))
        assertEquals(60, e.snapshot.diamonds)
        assertEquals(listOf("hamster"), e.snapshot.ownedCharacterIDs)
        assertEquals(Purchase.AlreadyOwned, e.purchaseCharacter(hamster))
        assertEquals(60, e.snapshot.diamonds)
    }

    @Test fun freeCharactersAreAlwaysOwnedAndNeverWritten() {
        val e = engine()
        assertEquals(Purchase.AlreadyOwned, e.purchaseCharacter(CharacterCatalog.find("bunny")))
        assertTrue(e.snapshot.ownedCharacterIDs.isEmpty())
    }

    @Test fun ownershipSurvivesAMergeWithAnOlderDevice() {
        val e = engine(diamonds = 500)
        e.purchaseCharacter(CharacterCatalog.find("hamster"))
        val other = ProgressSnapshot.blank().apply { ownedCharacterIDs = listOf("koala") }
        e.mergeRemote(other)
        assertTrue(e.snapshot.ownedCharacterIDs.containsAll(listOf("hamster", "koala")))
    }

    @Test fun cosmeticPurchaseSpendsOnlyWhenNew() {
        val e = engine(diamonds = 100)
        val crown = CosmeticCatalog.item("hat_crown")!!
        assertEquals(Purchase.Ok(72, 28), e.purchaseCosmetic(crown, owned = false))
        assertEquals(Purchase.AlreadyOwned, e.purchaseCosmetic(crown, owned = true))
        assertEquals(28, e.snapshot.diamonds)
    }

    // ── 🏷 tiers and helper levels ──────────────────────────────────────────
    @Test fun tiersFollowThePriceBands() {
        assertEquals(CharacterTier.FREE, CharacterTier.of(0))
        assertEquals(CharacterTier.COMMON, CharacterTier.of(2400))
        assertEquals(CharacterTier.RARE, CharacterTier.of(2401))
        assertEquals(CharacterTier.EPIC, CharacterTier.of(8800))
        assertEquals(CharacterTier.LEGENDARY, CharacterTier.of(8801))
        assertEquals(CharacterTier.MYTHIC, CharacterTier.of(20001))
        assertEquals(CharacterTier.Help.EXPLAIN, CharacterCatalog.help("dragon"))
        assertEquals(CharacterTier.Help.EXPLAIN, CharacterCatalog.help("owl"))
        assertEquals(CharacterTier.Help.HINT, CharacterCatalog.help("tiger"))
        assertEquals(CharacterTier.Help.ENCOURAGE, CharacterCatalog.help("fox"))
        assertEquals(48, CharacterCatalog.prices.size)   // = the 48 char_*.png
        assertEquals("fox", CharacterCatalog.find("nope").id)
    }

    @Test fun dailyChestTradesMinutesForGemsWhenFull() {
        val e = engine(settings = KidSettings(childDailyCapMinutes = 60))
        val base = com.rani.tofy.kid.core.RewardEngine.chestContents(com.rani.tofy.kid.core.ChestKind.MAGIC)
        assertEquals(base, e.dailyChestReward(base))
        e.grantBonusMinutes(60 + 30)   // today full + tomorrow's bank full
        val r = e.dailyChestReward(base)
        assertEquals(0, r.minutes); assertEquals(base.stars + 5, r.stars); assertEquals(base.diamonds + 5, r.diamonds)
        assertTrue(e.dailyChestAvailable)
        e.openDailyChest()
        assertFalse(e.dailyChestAvailable)
    }
}

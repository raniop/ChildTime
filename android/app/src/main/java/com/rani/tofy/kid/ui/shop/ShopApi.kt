package com.rani.tofy.kid.ui.shop

import androidx.compose.runtime.Composable
import com.rani.tofy.kid.core.KidSession

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  Kid ECONOMY screens — the entry points the kid home wires
 * ════════════════════════════════════════════════════════════════════════════
 *
 * Every screen is full-bleed (GlassBackdrop + systemBarsPadding), handles the
 * system back itself, and works on the child bound in [KidSession]. All wallet
 * changes go through KidSession.edit { … } (engine ops + ShopOps.kt), so they
 * persist, count as LWW edits and upload like every other progress change.
 *
 * SCREENS
 *   ShopScreen(onExit)                ShopView — the equipped character big + the
 *                                     collectible grid: tap owned → equip, locked →
 *                                     buy-and-equip with 💎 (or "not enough 💎").
 *                                     The 💎 pill opens the diamond packs behind the
 *                                     parent gate (Android: "בְּקָרוֹב בְּאַנְדְּרוֹאִיד",
 *                                     disabled — no Play Billing, nothing charges).
 *   CharacterCollectionScreen(onExit) Character3DPickerView — same grid, "בְּחַר דְּמוּת",
 *                                     closes itself a beat after a pick.
 *   WheelScreen(onExit)               LuckyWheelView. Show it when wheelSpinsAvailable() > 0
 *                                     (iOS auto-presents it on the home after a round /
 *                                     on appear). Entering SPENDS the spin (like iOS's
 *                                     resetWheelProgress before presenting); entered
 *                                     without one, it can't spin.
 *   DailyChestScreen(onExit)          DailyChestView. Show it when dailyChestReady()
 *                                     (the home's 🎁 button). Once a calendar day.
 *   HatchingScreen(onContinue)        HatchingView — the onboarding egg (no economy).
 *   CosmeticAvatar(characterID, childID, size)   portrait + equipped cosmetics.
 *
 * QUERIES / HOOKS
 *   wheelSpinsAvailable(): Int        1 when a free spin is earned (questionsPerWheel
 *                                     correct answers, a 5/10 hot streak, or the comeback
 *                                     spin), else 0 — iOS holds at most one pending spin.
 *   dailyChestReady(): Boolean        today's chest not opened yet (lastDailyChestDate).
 *   grantComebackWheelIfReturning()   call when the home appears (WorldMapView.onAppear):
 *                                     ≥20 h away → a "welcome back" spin, once a day.
 *
 * SYNC FORMAT (exactly iOS)
 *   • owned characters → ProgressSnapshot.ownedCharacterIDs (state/current, union-merged);
 *     free characters are always owned and never written.
 *   • the equipped character → children/{id}.character3DID + characterUpdatedAt
 *     (epoch seconds; the fresher pick wins every merge) — a confirmed merge-write
 *     (JoinRepository.childWrite: DENIED → heal membership, retry once).
 *   • wheel → wheelProgressCount (snapshot) + pendingBonusWheel (device-local),
 *     lastComebackWheelAt; chest → lastDailyChestDate (rides along with the next edit).
 *   • cosmetics are DEVICE-LOCAL on iOS too (CosmeticStore, UserDefaults) — never synced.
 */

@Composable fun ShopScreen(onExit: () -> Unit) = ShopScreenImpl(onExit)

@Composable fun CharacterCollectionScreen(onExit: () -> Unit) = CharacterCollectionScreenImpl(onExit)

@Composable fun WheelScreen(onExit: () -> Unit) = WheelScreenImpl(onExit)

@Composable fun DailyChestScreen(onExit: () -> Unit) = DailyChestScreenImpl(onExit)

/** ProgressStore.freeWheelAvailable → 0 / 1. */
fun wheelSpinsAvailable(): Int = if (KidSession.engine()?.freeWheelAvailable == true) 1 else 0

/** ProgressStore.dailyChestAvailable. */
fun dailyChestReady(): Boolean = KidSession.engine()?.dailyChestAvailable == true

/** ProgressStore.grantComebackWheelIfReturning — on the home's appear. */
fun grantComebackWheelIfReturning() { KidSession.edit { it.grantComebackWheelIfReturning() } }

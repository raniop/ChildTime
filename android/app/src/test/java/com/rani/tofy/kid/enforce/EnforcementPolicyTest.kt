package com.rani.tofy.kid.enforce

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** EnforcementPolicy — the ShieldPolicy.swift twin. */
class EnforcementPolicyTest {
    private val now = 1_800_000_000.0
    private val sys = SystemApps(
        own = "com.rani.tofy",
        launchers = setOf("com.android.launcher3"),
        alwaysAllowed = setOf("com.google.android.dialer", "com.google.android.inputmethod.latin"),
        parentOnly = setOf("com.android.settings", "com.google.android.packageinstaller"),
    )
    private val locked = GuardState(managed = true)
    private val game = "com.supercell.brawlstars"

    @Test fun parentPhoneIsNeverLocked() {
        assertEquals(Verdict.NOT_MANAGED, EnforcementPolicy.decide(game, now, GuardState(managed = false), sys))
        // Defaults: a caller that forgets `managed` locks NOTHING (ShieldInputs.isChildDevice).
        assertFalse(EnforcementPolicy.shouldBlock(game, now, GuardState(), sys))
        assertFalse(EnforcementPolicy.shouldBlock("com.android.settings", now, GuardState(), sys))
    }

    @Test fun lockedByDefaultIncludingAppsInstalledLater() {
        assertEquals(Verdict.LOCKED, EnforcementPolicy.decide(game, now, locked, sys))
        assertTrue(EnforcementPolicy.shouldBlock("com.never.seen.before", now, locked, sys))
    }

    @Test fun tofyHomePhoneKeyboardAlwaysOpen() {
        for (p in listOf("com.rani.tofy", "com.android.launcher3", "com.google.android.dialer", "com.google.android.inputmethod.latin"))
            assertEquals(p, Verdict.ALWAYS_OPEN, EnforcementPolicy.decide(p, now, locked, sys))
        assertFalse(EnforcementPolicy.shouldBlock(null, now, locked, sys))
    }

    @Test fun openWindowOpensEverythingButSettings() {
        val open = locked.copy(windowOpen = true)
        assertEquals(Verdict.WINDOW_OPEN, EnforcementPolicy.decide(game, now, open, sys))
        assertEquals(Verdict.PARENT_ONLY, EnforcementPolicy.decide("com.android.settings", now, open, sys))
        assertEquals(Verdict.PARENT_ONLY, EnforcementPolicy.decide("com.google.android.packageinstaller", now, open, sys))
    }

    @Test fun windowEndedOrRemoteLockReLocks() {
        // KidSession closes the window on WindowEnded / RemoteLock → windowOpen=false.
        val open = locked.copy(windowOpen = true)
        assertFalse(EnforcementPolicy.shouldBlock(game, now, open, sys))
        assertTrue(EnforcementPolicy.shouldBlock(game, now, open.copy(windowOpen = false), sys))
    }

    @Test fun openByDesignStaysOpenWhenLocked() {
        val s = locked.copy(openByDesign = setOf("com.whatsapp"))
        assertEquals(Verdict.OPEN_BY_DESIGN, EnforcementPolicy.decide("com.whatsapp", now, s, sys))
        assertTrue(EnforcementPolicy.shouldBlock(game, now, s, sys))
    }

    @Test fun openByDesignCannotOpenSettings() {
        val s = locked.copy(openByDesign = setOf("com.android.settings"))
        assertEquals(Verdict.PARENT_ONLY, EnforcementPolicy.decide("com.android.settings", now, s, sys))
    }

    @Test fun temporaryAllowanceOnlyWhileUnexpired() {
        val live = locked.copy(temporaryAllowed = setOf("com.android.settings", game), temporaryEndsAt = now + 60)
        assertEquals(Verdict.TEMPORARY, EnforcementPolicy.decide("com.android.settings", now, live, sys))
        assertEquals(Verdict.TEMPORARY, EnforcementPolicy.decide(game, now, live, sys))
        val expired = live.copy(temporaryEndsAt = now - 1)
        assertEquals(Verdict.PARENT_ONLY, EnforcementPolicy.decide("com.android.settings", now, expired, sys))
        assertEquals(Verdict.LOCKED, EnforcementPolicy.decide(game, now, expired, sys))
        assertEquals(Verdict.LOCKED, EnforcementPolicy.decide(game, now, live.copy(temporaryEndsAt = null), sys))
    }

    @Test fun lockModeOrderMatchesShieldBridge() {
        // Cap outranks everything — but only when nothing is waiting.
        assertEquals(LockMode.DAILY_CAP_REACHED, EnforcementPolicy.lockMode(Verdict.LOCKED, true, 60, 60, 0))
        assertEquals(LockMode.HAS_MINUTES, EnforcementPolicy.lockMode(Verdict.LOCKED, true, 60, 60, 5))
        assertEquals(LockMode.HAS_MINUTES, EnforcementPolicy.lockMode(Verdict.LOCKED, true, 60, 10, 5))
        assertEquals(LockMode.NEEDS_QUESTIONS, EnforcementPolicy.lockMode(Verdict.LOCKED, true, 60, 10, 0))
        assertEquals(LockMode.NEEDS_QUESTIONS, EnforcementPolicy.lockMode(Verdict.LOCKED, false, 60, 90, 0))
        assertEquals(LockMode.NEEDS_QUESTIONS, EnforcementPolicy.lockMode(Verdict.LOCKED, true, 0, 90, 0))   // ≤0 = unlimited
        assertEquals(LockMode.PARENT_ONLY, EnforcementPolicy.lockMode(Verdict.PARENT_ONLY, true, 60, 60, 0))
    }

    @Test fun overlayStaysOnHomeScreenAndLeavesWhenAllowed() {
        // We send the child home ourselves: the launcher must not dismiss the card.
        assertFalse(EnforcementPolicy.shouldDismissOverlay(game, "com.android.launcher3", now, locked, sys))
        assertFalse(EnforcementPolicy.shouldDismissOverlay(game, game, now, locked, sys))
        assertFalse(EnforcementPolicy.shouldDismissOverlay(game, "com.other.game", now, locked, sys))
        // Tofy / the phone came to the front.
        assertTrue(EnforcementPolicy.shouldDismissOverlay(game, "com.rani.tofy", now, locked, sys))
        assertTrue(EnforcementPolicy.shouldDismissOverlay(game, "com.google.android.dialer", now, locked, sys))
        // A window opened (here, by a parent, by a gift) — the covered app is allowed now.
        assertTrue(EnforcementPolicy.shouldDismissOverlay(game, "com.android.launcher3", now, locked.copy(windowOpen = true), sys))
        // The device stopped being managed (removed by the parent).
        assertTrue(EnforcementPolicy.shouldDismissOverlay(game, null, now, GuardState(), sys))
    }
}

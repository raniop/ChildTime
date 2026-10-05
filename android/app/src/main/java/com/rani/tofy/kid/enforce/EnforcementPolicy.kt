package com.rani.tofy.kid.enforce

/*
 * 🔒 The ONE place that decides whether an app may be on screen on a child's
 * Android device — the twin of iOS ShieldCore/ShieldPolicy.swift. Pure Kotlin
 * (no Android types) so every rule is unit-tested in EnforcementPolicyTest.
 *
 * iOS writes a SHIELD PLAN once and the OS enforces it; Android has no
 * FamilyControls, so TofyGuardService asks this file on every foreground
 * change instead. The model is iOS's strong baseline (`lockEverythingNew`,
 * armed on every child device with no setup): EVERYTHING is locked — an app
 * installed tomorrow included — except
 *   • what must always work (Tofy itself, the home screen, phone/emergency,
 *     the keyboard, the system permission dialog)  ≈ iOS "Tofy is never shielded"
 *   • the parent's "what stays open" list            = iOS openByDesignApps
 *   • an unexpired temporary allowance               = iOS temporaryAllowedApps
 * and, while a play window is open, everything else too.
 *
 * Android-only: the device's own SETTINGS (and the uninstall dialog) are
 * parent-only — blocked even inside an open window — because on Android
 * Settings is where the guard is switched off, and there is no Screen Time
 * passcode to protect it (iOS's ChildLockSetupView step ②).
 *
 * Defaults are the SAFE ones, like ShieldInputs: a caller that forgets a field
 * gets a locked device, never an open one — EXCEPT [GuardState.managed], which
 * defaults to false so a parent's own phone is never locked by mistake
 * (ShieldInputs.isChildDevice).
 */

/** Packages the device itself needs; resolved on-device by [SystemApps.resolve]. */
data class SystemApps(
    /** Tofy's own package — never blocked (iOS: the app that owns the store is never shielded). */
    val own: String,
    /** Every HOME activity — the child must always be able to get back to the home screen. */
    val launchers: Set<String> = emptySet(),
    /** Phone, in-call UI, emergency, keyboards, permission dialog, system UI. */
    val alwaysAllowed: Set<String> = emptySet(),
    /** Settings and the uninstall dialog — parent-only, even in an open window. */
    val parentOnly: Set<String> = emptySet(),
)

/** Everything the decision depends on, as plain values. */
data class GuardState(
    /** A CHILD device bound to a child (not Kid Mode on a parent phone, not disconnected). */
    val managed: Boolean = false,
    /** A play window is open right now (KidSession: isUnlocked && !unlockBudgetExhausted). */
    val windowOpen: Boolean = false,
    /** The parent's "what stays open" list (iOS openByDesignApps). */
    val openByDesign: Set<String> = emptySet(),
    /** A per-app allowance — honored only while [temporaryEndsAt] is in the future. */
    val temporaryAllowed: Set<String> = emptySet(),
    /** Unix seconds; null = no allowance. */
    val temporaryEndsAt: Double? = null,
)

enum class Verdict(val block: Boolean) {
    /** Not a managed child device — the guard stands down entirely. */
    NOT_MANAGED(false),
    /** Tofy, the home screen, phone/emergency, keyboard, permission dialog. */
    ALWAYS_OPEN(false),
    /** A parent's short allowance (also the setup-time Settings grace). */
    TEMPORARY(false),
    /** The parent's "what stays open" list. */
    OPEN_BY_DESIGN(false),
    /** Earned / gift / parent-granted time is running. */
    WINDOW_OPEN(false),
    /** No window: the app waits until the child earns time. */
    LOCKED(true),
    /** Device settings / uninstall — only a parent can open them (via Tofy's parent code). */
    PARENT_ONLY(true),
}

/** What the lock screen says — iOS ShieldState.Mode, decided like ShieldBridge.refresh(). */
enum class LockMode { NEEDS_QUESTIONS, HAS_MINUTES, DAILY_CAP_REACHED, PARENT_ONLY }

object EnforcementPolicy {

    fun decide(pkg: String?, now: Double, state: GuardState, sys: SystemApps): Verdict {
        if (!state.managed) return Verdict.NOT_MANAGED
        // Unknown foreground (nothing seen yet): nothing to block.
        if (pkg.isNullOrEmpty()) return Verdict.ALWAYS_OPEN
        if (pkg == sys.own || pkg in sys.launchers || pkg in sys.alwaysAllowed) return Verdict.ALWAYS_OPEN
        // Only an UNEXPIRED allowance exempts anything (TofyShield.inputs).
        val tempLive = state.temporaryEndsAt?.let { it > now } == true
        if (tempLive && pkg in state.temporaryAllowed) return Verdict.TEMPORARY
        // Before the open window: an open window must not open the way to
        // switching the guard off.
        if (pkg in sys.parentOnly) return Verdict.PARENT_ONLY
        if (pkg in state.openByDesign) return Verdict.OPEN_BY_DESIGN
        if (state.windowOpen) return Verdict.WINDOW_OPEN
        return Verdict.LOCKED
    }

    /** The task's one-liner: should [pkg] be covered by the lock screen right now? */
    fun shouldBlock(pkg: String?, now: Double, state: GuardState, sys: SystemApps): Boolean =
        decide(pkg, now, state, sys).block

    /**
     * ShieldBridge.refresh(): the daily cap outranks everything (there is nothing
     * the child can do about it), then minutes already waiting, then the ask.
     */
    fun lockMode(
        verdict: Verdict,
        dailyCapEnabled: Boolean, dailyCapMinutes: Int, minutesEarnedToday: Int, pendingMinutes: Int,
    ): LockMode = when {
        verdict == Verdict.PARENT_ONLY -> LockMode.PARENT_ONLY
        dailyCapEnabled && dailyCapMinutes > 0 && minutesEarnedToday >= dailyCapMinutes && pendingMinutes <= 0 -> LockMode.DAILY_CAP_REACHED
        pendingMinutes > 0 -> LockMode.HAS_MINUTES
        else -> LockMode.NEEDS_QUESTIONS
    }

    /**
     * Should the lock screen that is up for [blockedPkg] go away now that
     * [foreground] is in front? Not for the home screen — we send the child home
     * ourselves when we cover an app, so "home appeared" is our own doing, and
     * the card stays until the child taps it (iOS shield: one deliberate button).
     * Yes when the blocked app is now allowed (a window opened) or another
     * allowed, non-home app came to the front (Tofy, the phone ringing).
     */
    fun shouldDismissOverlay(blockedPkg: String, foreground: String?, now: Double, state: GuardState, sys: SystemApps): Boolean {
        if (!decide(blockedPkg, now, state, sys).block) return true
        val fg = foreground ?: return false
        if (fg == blockedPkg || fg in sys.launchers) return false
        return !decide(fg, now, state, sys).block
    }
}

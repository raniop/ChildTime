package com.rani.tofy.kid.enforce

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * The guard's local settings — the twin of what iOS keeps in the app group
 * (TofyShield.Key): what stays open (`allowedAppsData`), a temporary allowance
 * (`allowExceptionData` / `allowExceptionEndsAt`) and whether setup was done.
 * Device-local on purpose, like iOS: shielding is a property of THIS device.
 */
object EnforcementStore {
    private const val PREFS = "tofy.enforce"
    private const val OPEN = "openByDesign"
    private const val TEMP = "temporaryAllowed"
    private const val TEMP_ENDS = "temporaryEndsAt"
    private const val DISCLOSURE = "disclosureAcceptedAt"
    private const val SETUP_DONE = "setupDone"

    private fun prefs(ctx: Context): SharedPreferences =
        ctx.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /** Bumped on every write so the running guard re-checks at once. */
    private val _version = MutableStateFlow(0)
    val version: StateFlow<Int> = _version
    private fun bump() { _version.value += 1 }

    // ── what stays open (iOS openByDesignApps) ──────────────────────────────
    fun openByDesign(ctx: Context): Set<String> = prefs(ctx).getStringSet(OPEN, emptySet())?.toSet() ?: emptySet()
    fun setOpenByDesign(ctx: Context, pkgs: Set<String>) { prefs(ctx).edit().putStringSet(OPEN, pkgs.toSet()).apply(); bump() }

    // ── temporary allowance (iOS allowExceptionData + allowExceptionEndsAt) ──
    fun temporaryAllowed(ctx: Context): Set<String> = prefs(ctx).getStringSet(TEMP, emptySet())?.toSet() ?: emptySet()
    fun temporaryEndsAt(ctx: Context): Double? =
        prefs(ctx).getLong(TEMP_ENDS, 0L).takeIf { it > 0 }?.let { it / 1000.0 }

    /** Open [pkgs] (on top of anything already allowed) for [minutes] from now. */
    fun allowTemporarily(ctx: Context, pkgs: Set<String>, minutes: Int) {
        val now = System.currentTimeMillis()
        val live = (temporaryEndsAt(ctx)?.let { it * 1000 > now } == true)
        val merged = if (live) temporaryAllowed(ctx) + pkgs else pkgs
        val ends = maxOf(now + minutes * 60_000L, if (live) prefs(ctx).getLong(TEMP_ENDS, 0L) else 0L)
        prefs(ctx).edit().putStringSet(TEMP, merged).putLong(TEMP_ENDS, ends).apply()
        bump()
    }

    fun clearTemporary(ctx: Context) { prefs(ctx).edit().remove(TEMP).remove(TEMP_ENDS).apply(); bump() }

    // ── setup bookkeeping ───────────────────────────────────────────────────
    /** Play's prominent disclosure was accepted (unix ms; 0 = never). */
    fun disclosureAccepted(ctx: Context): Boolean = prefs(ctx).getLong(DISCLOSURE, 0L) > 0
    fun markDisclosureAccepted(ctx: Context) { prefs(ctx).edit().putLong(DISCLOSURE, System.currentTimeMillis()).apply() }

    fun setupDone(ctx: Context): Boolean = prefs(ctx).getBoolean(SETUP_DONE, false)
    fun markSetupDone(ctx: Context) { prefs(ctx).edit().putBoolean(SETUP_DONE, true).apply() }
}

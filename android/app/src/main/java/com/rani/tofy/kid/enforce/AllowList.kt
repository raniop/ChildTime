package com.rani.tofy.kid.enforce

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.inputmethod.InputMethodManager

/**
 * What must always work on a locked child device, resolved on THIS device
 * (OEMs ship their own launcher, dialer and settings), plus the list of
 * launchable apps for the "what stays open" picker.
 *
 * Package visibility (Android 11+): every intent resolved here has a matching
 * <queries> entry in AndroidManifest.xml — no QUERY_ALL_PACKAGES.
 */
object AllowList {
    /**
     * Guard the uninstall dialog like Settings (parent-only). The Android twin of
     * iOS `denyAppRemoval` on a child device: deleting Tofy drops the lock. A
     * parent opens it from Tofy with the parent code. Flip to false if Play
     * review objects — see EnforceApi.kt.
     */
    const val GUARD_UNINSTALL = true

    /** Present on (almost) every device; resolved packages are added on top. */
    private val KNOWN_ALWAYS = setOf(
        "com.android.systemui",
        "com.android.phone", "com.android.server.telecom", "com.android.emergency",
        "com.google.android.dialer", "com.android.dialer", "com.samsung.android.dialer",
        "com.android.incallui", "com.samsung.android.incallui",
        "com.google.android.apps.safetyhub",
        "com.android.permissioncontroller", "com.google.android.permissioncontroller",
        "com.android.cellbroadcastreceiver", "com.google.android.cellbroadcastreceiver",
    )

    /** Where the guard (or the app itself) can be switched off. */
    private val KNOWN_SETTINGS = setOf(
        "com.android.settings", "com.samsung.accessibility", "com.google.android.settings.intelligence",
        "com.android.settings.intelligence", "com.miui.securitycenter", "com.huawei.systemmanager",
        "com.coloros.safecenter", "com.oplus.safecenter",
    )

    private val KNOWN_INSTALLERS = setOf("com.android.packageinstaller", "com.google.android.packageinstaller")

    @Volatile private var cached: SystemApps? = null
    @Volatile private var cachedAt = 0L

    /** Cached for 10 minutes — a new launcher or keyboard is picked up soon enough. */
    fun system(ctx: Context): SystemApps {
        val now = System.currentTimeMillis()
        cached?.takeIf { now - cachedAt < 10 * 60_000 }?.let { return it }
        return resolve(ctx).also { cached = it; cachedAt = now }
    }

    fun invalidate() { cached = null }

    fun resolve(ctx: Context): SystemApps {
        val pm = ctx.packageManager
        fun pkgsFor(i: Intent): Set<String> = runCatching {
            pm.queryIntentActivities(i, PackageManager.MATCH_DEFAULT_ONLY or PackageManager.MATCH_ALL)
                .mapNotNull { it.activityInfo?.packageName }.toSet()
        }.getOrDefault(emptySet())

        val launchers = pkgsFor(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME))
        val telecom = runCatching {
            val tm = ctx.getSystemService(TelecomManager::class.java)
            setOfNotNull(tm?.defaultDialerPackage, tm?.systemDialerPackage)
        }.getOrDefault(emptySet())
        val keyboards = runCatching {
            ctx.getSystemService(InputMethodManager::class.java)?.enabledInputMethodList?.map { it.packageName }?.toSet()
        }.getOrNull() ?: emptySet()
        val settings = pkgsFor(Intent(Settings.ACTION_SETTINGS)) + pkgsFor(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
        val installers = if (GUARD_UNINSTALL)
            KNOWN_INSTALLERS + pkgsFor(Intent(Intent.ACTION_DELETE, Uri.parse("package:${ctx.packageName}")))
        else emptySet()

        // The phone app comes from Telecom, not from every app that answers tel:
        // (VoIP apps register for it too and would slip out of the lock).
        // Keyboards / dialers are never parent-only, whatever an OEM bundles them with.
        val always = KNOWN_ALWAYS + telecom + keyboards
        val parentOnly = (KNOWN_SETTINGS + settings + installers) - always - launchers - ctx.packageName
        return SystemApps(own = ctx.packageName, launchers = launchers, alwaysAllowed = always, parentOnly = parentOnly)
    }

    /** The uninstall dialog(s) — what the parent's remote "allow deleting apps (5 min)" opens. */
    fun installerPackages(ctx: Context): Set<String> = KNOWN_INSTALLERS + runCatching {
        ctx.packageManager.queryIntentActivities(Intent(Intent.ACTION_DELETE, Uri.parse("package:${ctx.packageName}")),
            PackageManager.MATCH_DEFAULT_ONLY or PackageManager.MATCH_ALL).mapNotNull { it.activityInfo?.packageName }.toSet()
    }.getOrDefault(emptySet())

    /** The device's Settings app(s) — what a parent's "open settings" allowance opens. */
    fun settingsPackages(ctx: Context): Set<String> = system(ctx).parentOnly

    // ── the picker ───────────────────────────────────────────────────────────
    data class App(val pkg: String, val label: String, val icon: Drawable?)

    /**
     * Launchable apps a parent can keep open — minus Tofy, the home screen and
     * the always-open system apps (they are open anyway) and Settings (never
     * the child's). Sorted by label. Call off the main thread.
     */
    fun launchableApps(ctx: Context): List<App> {
        val pm = ctx.packageManager
        val sys = system(ctx)
        val skip = setOf(sys.own) + sys.launchers + sys.alwaysAllowed + sys.parentOnly
        val infos = runCatching {
            pm.queryIntentActivities(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER), 0)
        }.getOrDefault(emptyList())
        return infos.asSequence()
            .mapNotNull { ri -> ri.activityInfo?.let { ai -> ai.packageName to ri } }
            .filter { (pkg, _) -> pkg !in skip }
            .distinctBy { it.first }
            .map { (pkg, ri) -> App(pkg, ri.loadLabel(pm)?.toString() ?: pkg, runCatching { ri.loadIcon(pm) }.getOrNull()) }
            .sortedBy { it.label.lowercase() }
            .toList()
    }
}

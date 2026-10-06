package com.rani.tofy.kid.enforce

import android.app.AppOpsManager
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper

/**
 * Brings Tofy back by itself once a permission is granted in system Settings.
 *
 * Rani, on the real tablet, standing on the "Tofy ✓ On" page: "מה אני צריך
 * לפתוח? איך מישהו אחר יבין?" — Settings never says "now go back", and a
 * parent who has just flipped the switch has no reason to look for Tofy again.
 * So we arm a short-lived flag before sending them to Settings and return the
 * moment the grant lands: the accessibility service's own connect for the lock,
 * an AppOps watcher for usage access.
 */
internal object SetupReturn {
    private const val KEY = "lockSetup.returnArmedAt"
    private const val WINDOW_MS = 10 * 60_000L

    private fun prefs(ctx: Context) = ctx.getSharedPreferences("tofy", Context.MODE_PRIVATE)

    fun arm(ctx: Context) { prefs(ctx).edit().putLong(KEY, System.currentTimeMillis()).apply() }

    /** True once if a Settings trip was armed in the last few minutes. */
    fun consume(ctx: Context): Boolean {
        val at = prefs(ctx).getLong(KEY, 0L)
        if (at == 0L || System.currentTimeMillis() - at > WINDOW_MS) return false
        prefs(ctx).edit().remove(KEY).apply()
        return true
    }

    fun bringTofyBack(ctx: Context, delayMs: Long = 700) {
        val app = ctx.applicationContext
        Handler(Looper.getMainLooper()).postDelayed({
            app.packageManager.getLaunchIntentForPackage(app.packageName)?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                runCatching { app.startActivity(it) }
            }
        }, delayMs)
    }

    private var usageWatcher: AppOpsManager.OnOpChangedListener? = null

    /** Usage access has no callback of its own — watch the app-op until it flips to allowed. */
    fun watchUsageAccess(ctx: Context) {
        val app = ctx.applicationContext
        val ops = app.getSystemService(AppOpsManager::class.java) ?: return
        usageWatcher?.let { runCatching { ops.stopWatchingMode(it) } }
        val listener = AppOpsManager.OnOpChangedListener { _, pkg ->
            if (pkg != app.packageName || !UsageAccess.isGranted(app)) return@OnOpChangedListener
            usageWatcher?.let { runCatching { ops.stopWatchingMode(it) } }
            usageWatcher = null
            if (consume(app)) bringTofyBack(app)
        }
        usageWatcher = listener
        runCatching { ops.startWatchingMode(AppOpsManager.OPSTR_GET_USAGE_STATS, app.packageName, listener) }
    }
}

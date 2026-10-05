package com.rani.tofy.kid.enforce

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings

/**
 * "Usage access" (PACKAGE_USAGE_STATS) — the FALLBACK, not the guard.
 *
 * TofyGuardService learns the foreground app from accessibility events, which
 * only fire on a CHANGE. Right after the service (re)connects — a reboot, an
 * update, the parent just switching it on — the child may already be inside an
 * app and no event has come yet. With usage access we read the last app that
 * came to the front and cover it at once; without it we wait for the next
 * switch. That is the whole job: no history is kept, nothing leaves the device.
 */
object UsageAccess {

    fun isGranted(ctx: Context): Boolean = runCatching {
        val ops = ctx.getSystemService(AppOpsManager::class.java) ?: return false
        val mode = if (Build.VERSION.SDK_INT >= 29)
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        else @Suppress("DEPRECATION") ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        mode == AppOpsManager.MODE_ALLOWED
    }.getOrDefault(false)

    /** Settings → Usage access (straight to Tofy's row where the OEM supports it). */
    fun settingsIntent(ctx: Context): Intent {
        val direct = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS, Uri.parse("package:${ctx.packageName}"))
        val i = if (direct.resolveActivity(ctx.packageManager) != null) direct else Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        return i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    /** The app that most recently came to the front in the last [windowMs], or null. */
    fun foregroundPackage(ctx: Context, windowMs: Long = 6 * 60 * 60_000L): String? {
        if (!isGranted(ctx)) return null
        return runCatching {
            val usm = ctx.getSystemService(UsageStatsManager::class.java) ?: return null
            val now = System.currentTimeMillis()
            val events = usm.queryEvents(now - windowMs, now)
            val e = UsageEvents.Event()
            var last: String? = null
            val resumed = if (Build.VERSION.SDK_INT >= 29) UsageEvents.Event.ACTIVITY_RESUMED
                          else @Suppress("DEPRECATION") UsageEvents.Event.MOVE_TO_FOREGROUND
            while (events.hasNextEvent()) {
                events.getNextEvent(e)
                if (e.eventType == resumed) last = e.packageName
            }
            last
        }.getOrNull()
    }
}

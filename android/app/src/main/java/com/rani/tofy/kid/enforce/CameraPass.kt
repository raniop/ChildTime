package com.rani.tofy.kid.enforce

import android.content.Context
import android.content.Intent
import android.provider.MediaStore

/**
 * 📸 A short pass for the camera app while the child photographs a finished
 * chore. The lock blocks every other app — the camera included — so "צלמו את
 * המטלה" opened a camera the guard sent straight back home (Rani, on the tablet).
 *
 * Armed right before the capture intent, for [WINDOW_SECS] at most, and
 * disarmed the moment the photo (or a cancel) comes back to Tofy — so it can't
 * become a way into the gallery or anything else.
 */
object CameraPass {
    private const val PREFS = "tofy.cameraPass"
    private const val UNTIL = "until"
    private const val PKGS = "pkgs"
    private const val WINDOW_SECS = 120L

    fun arm(ctx: Context) {
        val pm = ctx.packageManager
        val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)
        val pkgs = buildSet {
            pm.resolveActivity(intent, 0)?.activityInfo?.packageName?.let { add(it) }
            pm.queryIntentActivities(intent, 0).forEach { add(it.activityInfo.packageName) }
        }.filter { it != "android" && it != ctx.packageName }.toSet()
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong(UNTIL, System.currentTimeMillis() + WINDOW_SECS * 1000).putStringSet(PKGS, pkgs).apply()
    }

    fun disarm(ctx: Context) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    /** The camera packages the guard lets through right now (empty when no pass is live). */
    fun packages(ctx: Context): Set<String> {
        val p = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (System.currentTimeMillis() > p.getLong(UNTIL, 0)) return emptySet()
        return p.getStringSet(PKGS, emptySet()) ?: emptySet()
    }
}

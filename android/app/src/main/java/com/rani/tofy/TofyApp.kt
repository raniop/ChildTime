package com.rani.tofy

import android.app.Application
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import android.app.NotificationChannel
import android.app.NotificationManager
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr

/** The application context for code without one (prefs read from a composable). */
object TofyAppRef {
    lateinit var app: android.content.Context
    fun prefs(name: String): android.content.SharedPreferences = app.getSharedPreferences(name, android.content.Context.MODE_PRIVATE)
}

class TofyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        TofyAppRef.app = this
        // 📍 The family map is OpenStreetMap (osmdroid): its tile requests must name the app.
        org.osmdroid.config.Configuration.getInstance().apply {
            load(this@TofyApp, getSharedPreferences("osmdroid", MODE_PRIVATE)); userAgentValue = packageName
        }
        if (BuildConfig.DEBUG && BuildConfig.USE_EMULATORS) useLocalEmulators()
        else if (FirebaseApp.getApps(this).isEmpty()) FirebaseApp.initializeApp(this)
        I18n.init(this)
        // 🔄 "There is a newer Tofy" (config/appUpdate) — cached numbers now, the listener once signed in.
        com.rani.tofy.update.AppUpdateConfig.init(this)
        DeviceRole.init(this)
        createChannels()
        // Kid side: content assets/cache + the progress session (both idempotent).
        com.rani.tofy.kid.content.QuestionSource.init(this)
        com.rani.tofy.kid.core.KidSession.init(this)
        com.rani.tofy.kid.location.KidLocation.init(this)
    }

    /**
     * Debug-only: re-initialise Firebase as project "demo-tofy" (a demo- project
     * id can never reach production) and point Auth + Firestore at the local
     * emulators on the host (10.0.2.2 from the Android emulator).
     */
    private fun useLocalEmulators() {
        val opts = FirebaseOptions.fromResource(this) ?: return
        FirebaseApp.initializeApp(this, FirebaseOptions.Builder(opts).setProjectId("demo-tofy").build())
        FirebaseAuth.getInstance().useEmulator(BuildConfig.EMULATOR_HOST, 9099)
        FirebaseFirestore.getInstance().useEmulator(BuildConfig.EMULATOR_HOST, 8080)
    }

    /** One channel per kind, so a parent can mute marketing without losing approvals. */
    fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("family", tr("עדכונים"), NotificationManager.IMPORTANCE_HIGH))
        nm.createNotificationChannel(NotificationChannel("requests", tr("בקשות לאישור"), NotificationManager.IMPORTANCE_HIGH))
        nm.createNotificationChannel(NotificationChannel("reports", tr("דוחות ותובנות"), NotificationManager.IMPORTANCE_DEFAULT))
        // 📍 The child's "location is shared" notice (quiet, always there while
        // sharing — Google Play requires it) and the 🔔 beep (loud, on top).
        nm.createNotificationChannel(NotificationChannel("location", tr("שיתוף מיקום"), NotificationManager.IMPORTANCE_LOW))
        nm.createNotificationChannel(NotificationChannel("beep", tr("🔔 צפצוף"), NotificationManager.IMPORTANCE_HIGH).apply { setSound(null, null) })
    }
}

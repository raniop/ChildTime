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

class TofyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG && BuildConfig.USE_EMULATORS) useLocalEmulators()
        I18n.init(this)
        createChannels()
    }

    /**
     * Debug-only: re-initialise Firebase as project "demo-tofy" (a demo- project
     * id can never reach production) and point Auth + Firestore at the local
     * emulators on the host (10.0.2.2 from the Android emulator).
     */
    private fun useLocalEmulators() {
        val opts = FirebaseOptions.fromResource(this) ?: return
        FirebaseApp.getApps(this).forEach { it.delete() }
        FirebaseApp.initializeApp(this, FirebaseOptions.Builder(opts).setProjectId("demo-tofy").build())
        FirebaseAuth.getInstance().useEmulator("10.0.2.2", 9099)
        FirebaseFirestore.getInstance().useEmulator("10.0.2.2", 8080)
    }

    /** One channel per kind, so a parent can mute marketing without losing approvals. */
    fun createChannels() {
        val nm = getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(NotificationChannel("family", tr("עדכונים"), NotificationManager.IMPORTANCE_HIGH))
        nm.createNotificationChannel(NotificationChannel("requests", tr("בקשות לאישור"), NotificationManager.IMPORTANCE_HIGH))
        nm.createNotificationChannel(NotificationChannel("reports", tr("דוחות ותובנות"), NotificationManager.IMPORTANCE_DEFAULT))
    }
}

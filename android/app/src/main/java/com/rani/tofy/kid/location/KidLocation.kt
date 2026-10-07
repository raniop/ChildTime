package com.rani.tofy.kid.location

import android.Manifest
import android.annotation.SuppressLint
import android.app.Notification
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.location.Location
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.BatteryManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingEvent
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.MainActivity
import com.rani.tofy.R
import com.rani.tofy.data.FamilyPlace
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidIdentity
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONArray
import org.json.JSONObject

/**
 * 📍 Location on a CHILD's Android device — the twin of iOS LocationSharing
 * (child side). Shares only while a parent switched it on for this child
 * (children/{id}.locationSharing.enabled) and the phone allows it:
 *   • the last fix → children/{id}/location/fix_<installID> (no route, ever);
 *   • crossings of the family's places → children/{id}/placeEvents/… (the
 *     server pushes them to the parents and deletes them);
 *   • 🔔 a loud beep the parent can trigger, at alarm volume, silent mode or not.
 * Battery: balanced-power updates every ~10 minutes / 100 m plus geofences —
 * no GPS running. Google Play requires a notice while a child is tracked: a
 * quiet ongoing notification says so for as long as sharing is on.
 *
 * Works with the app closed: the receivers below wake a cold process, so the
 * child ID and the places are kept in prefs, not only in memory.
 */
object KidLocation {
    private const val PREFS = "tofy.location"
    private const val NOTICE_ID = 4207
    private const val BEEP_ID = 4208

    private lateinit var app: Context
    private val prefs: SharedPreferences by lazy { app.getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
    private val db get() = FirebaseFirestore.getInstance()
    private val regs = mutableListOf<ListenerRegistration>()

    private val _enabled = MutableStateFlow(false)
    /** A parent switched sharing on for the child on this device. */
    val enabled: StateFlow<Boolean> = _enabled
    private val _beeping = MutableStateFlow(false)
    /** 🔔 Ringing now — the kid screen shows "מָצָאתִי!". */
    val beeping: StateFlow<Boolean> = _beeping

    fun init(ctx: Context) { app = ctx.applicationContext }

    private val childID: String? get() = prefs.getString("childID", null)
    private val places: List<FamilyPlace>
        get() = runCatching {
            val arr = JSONArray(prefs.getString("places", "[]"))
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.getJSONObject(i)
                FamilyPlace(id = o.getString("id"), name = o.optString("name"), emoji = o.optString("emoji", "📍"),
                    lat = o.getDouble("lat"), lng = o.getDouble("lng"), radius = o.optDouble("radius", 200.0))
            }
        }.getOrDefault(emptyList())

    fun hasFine(ctx: Context = app) =
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
    fun hasBackground(ctx: Context = app) = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
        ContextCompat.checkSelfPermission(ctx, Manifest.permission.ACCESS_BACKGROUND_LOCATION) == PackageManager.PERMISSION_GRANTED
    /** The kid's one-time explanation is due (sharing on, the phone not yet allowing it) —
     *  at most 3 times in all, so a child who declined is not nagged. */
    val needsPermission: Boolean
        get() = _enabled.value && (!hasFine() || !hasBackground()) && prefs.getInt("promptCount", 0) < 3
    fun countPrompt() { prefs.edit().putInt("promptCount", prefs.getInt("promptCount", 0) + 1).apply() }

    // ── binding (KidSession) ────────────────────────────────────────────────

    private var bound: Pair<String?, String?>? = null

    /** The child on this device (null = none / Kid Mode on a parent phone). */
    fun bind(cid: String?, householdID: String?) {
        if (bound == (cid to householdID)) return
        bound = cid to householdID
        regs.forEach { it.remove() }; regs.clear()
        if (cid == null) { prefs.edit().remove("childID").apply(); setEnabled(false); return }
        prefs.edit().putString("childID", cid).apply()
        val child = db.collection("children").document(cid)
        regs += child.addSnapshotListener { d, _ ->
            @Suppress("UNCHECKED_CAST")
            val on = ((d?.get("locationSharing") as? Map<String, Any?>)?.get("enabled") as? Boolean) ?: false
            setEnabled(on)
        }
        if (householdID != null) regs += db.collection("households").document(householdID).addSnapshotListener { d, _ ->
            val list = FamilyPlace.list(d?.get("places"))
            prefs.edit().putString("places", JSONArray(list.map { p ->
                JSONObject().put("id", p.id).put("name", p.name).put("emoji", p.emoji)
                    .put("lat", p.lat).put("lng", p.lng).put("radius", p.radius)
            }).toString()).apply()
            if (_enabled.value) syncGeofences()
        }
        // While Tofy runs, a parent's refresh / beep also arrives here directly.
        regs += child.collection("location").document("request").addSnapshotListener { d, _ ->
            if (d != null && d.exists() && !d.metadata.hasPendingWrites()) freshFixAsync()
        }
        regs += child.collection("location").document("beep").addSnapshotListener { d, _ ->
            val m = d?.data ?: return@addSnapshotListener
            if (d.metadata.hasPendingWrites()) return@addSnapshotListener
            val target = m["deviceID"] as? String
            if (!target.isNullOrEmpty() && target != KidIdentity.installID) return@addSnapshotListener
            if (m["stop"] == true) { stopBeep(false); return@addSnapshotListener }
            val at = (m["at"] as? Timestamp)?.toDate()?.time ?: 0
            if (System.currentTimeMillis() - at < 60_000 && m["foundAt"] == null) startBeep()
        }
    }

    private fun setEnabled(on: Boolean) {
        _enabled.value = on
        prefs.edit().putBoolean("enabled", on).apply()
        if (on) start() else stop()
    }

    /** Called after the kid granted permission (and at bind). */
    @SuppressLint("MissingPermission")
    fun start() {
        if (!_enabled.value || !hasFine()) { reportPermission(); return }
        val req = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, 10 * 60_000L)
            .setMinUpdateDistanceMeters(100f).build()
        runCatching { LocationServices.getFusedLocationProviderClient(app).requestLocationUpdates(req, updatesIntent()) }
        syncGeofences()
        showNotice()
        freshFixAsync()
    }

    /** Tofy came to the front: a fresh fix (a "while using" phone can share ONLY now) + fences. */
    fun appBecameActive() {
        if (!_enabled.value) return
        reportPermission()
        if (!hasFine()) return
        prefs.edit().putLong("lastWrite", 0).apply()
        syncGeofences()
        freshFixAsync()
    }

    private fun stop() {
        runCatching { LocationServices.getFusedLocationProviderClient(app).removeLocationUpdates(updatesIntent()) }
        runCatching { LocationServices.getGeofencingClient(app).removeGeofences(fenceIntent()) }
        NotificationManagerCompat.from(app).cancel(NOTICE_ID)
    }

    @SuppressLint("MissingPermission")
    private fun syncGeofences() {
        if (!hasFine() || !hasBackground()) return
        val client = LocationServices.getGeofencingClient(app)
        runCatching { client.removeGeofences(fenceIntent()) }
        val fences = places.take(90).map { p ->
            Geofence.Builder().setRequestId(p.id)
                .setCircularRegion(p.lat, p.lng, maxOf(100.0, p.radius).toFloat())
                .setExpirationDuration(Geofence.NEVER_EXPIRE)
                .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER or Geofence.GEOFENCE_TRANSITION_EXIT)
                .build()
        }
        if (fences.isEmpty()) return
        val req = GeofencingRequest.Builder().setInitialTrigger(0).addGeofences(fences).build()
        runCatching { client.addGeofences(req, fenceIntent()) }
    }

    private fun updatesIntent(): PendingIntent = PendingIntent.getBroadcast(app, 1,
        Intent(app, LocationUpdatesReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
    private fun fenceIntent(): PendingIntent = PendingIntent.getBroadcast(app, 2,
        Intent(app, GeofenceReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)

    /** "📍 Tofy shares this phone's location with your parents" — while sharing. */
    private fun showNotice() {
        val open = PendingIntent.getActivity(app, 3, Intent(app, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(app, "location").setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(tr("📍 טופי משתף את המיקום עם ההורים"))
            .setContentText(tr("ההורים במשפחה רואים איפה הטלפון. רק הם."))
            .setOngoing(true).setSilent(true).setContentIntent(open).build()
        runCatching { NotificationManagerCompat.from(app).notify(NOTICE_ID, n) }
    }

    // ── fixes ───────────────────────────────────────────────────────────────

    fun freshFixAsync() { CoroutineScope(Dispatchers.Main).launch { freshFix() } }

    /** The parent asked: one fresh fix, written now (≤ 9 s — the push's window). */
    @SuppressLint("MissingPermission")
    suspend fun freshFix() {
        if (!prefs.getBoolean("enabled", false) || !hasFine()) { reportPermission(); return }
        val loc = withTimeoutOrNull(9_000) {
            runCatching {
                LocationServices.getFusedLocationProviderClient(app)
                    .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null).await()
            }.getOrNull()
        } ?: return
        write(loc, force = true)
    }

    fun write(loc: Location, force: Boolean = false) {
        val cid = childID ?: return
        if (!prefs.getBoolean("enabled", false)) return
        val now = System.currentTimeMillis()
        if (!force && now - prefs.getLong("lastWrite", 0) < 60_000) return
        prefs.edit().putLong("lastWrite", now).apply()
        val place = FamilyPlace.at(loc.latitude, loc.longitude, places, loc.accuracy.toDouble())
        if (prefs.getString("placeID", null) != place?.id) {
            prefs.edit().putString("placeID", place?.id).putLong("placeSince", now / 1000).apply()
        }
        val battery = runCatching {
            (app.getSystemService(Context.BATTERY_SERVICE) as BatteryManager)
                .getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) / 100.0
        }.getOrNull()?.takeIf { it in 0.0..1.0 }
        db.collection("children").document(cid).collection("location").document("fix_${KidIdentity.installID}").set(mapOf(
            "lat" to loc.latitude, "lng" to loc.longitude, "accuracy" to loc.accuracy.toDouble(),
            "clientAt" to loc.time / 1000.0, "at" to FieldValue.serverTimestamp(),
            "platform" to "android", "kind" to "android", "deviceID" to KidIdentity.installID,
            "permission" to permissionName(), "battery" to battery,
            "placeID" to place?.id, "placeSince" to place?.let { prefs.getLong("placeSince", now / 1000).toDouble() },
        ))
    }

    private fun permissionName() = when {
        !hasFine() -> "denied"
        !hasBackground() -> "whenInUse"
        else -> "always"
    }

    private fun reportPermission() {
        val cid = childID ?: return
        if (!prefs.getBoolean("enabled", false)) return
        db.collection("children").document(cid).collection("location").document("fix_${KidIdentity.installID}")
            .set(mapOf("permission" to permissionName(), "platform" to "android", "kind" to "android",
                "deviceID" to KidIdentity.installID), SetOptions.merge())
    }

    fun crossed(placeID: String, arrive: Boolean) {
        val cid = childID ?: return
        if (!prefs.getBoolean("enabled", false)) return
        db.collection("children").document(cid).collection("placeEvents").add(mapOf(
            "placeID" to placeID, "kind" to if (arrive) "arrive" else "leave",
            "clientAt" to System.currentTimeMillis() / 1000.0, "deviceID" to KidIdentity.installID,
        ))
        prefs.edit().putLong("lastWrite", 0).apply()
        freshFixAsync()
    }

    // ── 🔔 beep ──────────────────────────────────────────────────────────────

    private var player: MediaPlayer? = null
    private var savedAlarmVolume = -1
    private val main = Handler(Looper.getMainLooper())

    /** At ALARM volume for 30 s (silent mode does not mute the alarm stream). */
    fun startBeep() = main.post {
        if (_beeping.value) return@post
        val am = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        savedAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
        am.setStreamVolume(AudioManager.STREAM_ALARM, am.getStreamMaxVolume(AudioManager.STREAM_ALARM), 0)
        player = MediaPlayer().apply {
            setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
            app.resources.openRawResourceFd(R.raw.tofy_beep).use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            isLooping = true
            prepare(); start()
        }
        _beeping.value = true
        val found = PendingIntent.getBroadcast(app, 4, Intent(app, BeepStopReceiver::class.java), PendingIntent.FLAG_IMMUTABLE)
        val open = PendingIntent.getActivity(app, 5, Intent(app, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE)
        val n = NotificationCompat.Builder(app, "beep").setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(tr("מְחַפְּשִׂים אֶת הַטֵּלֵפוֹן!"))
            .setContentText(tr("אַבָּא אוֹ אִמָּא בִּקְּשׁוּ לְצַפְצֵף כְּדֵי לִמְצֹא אוֹתוֹ"))
            .setPriority(NotificationCompat.PRIORITY_MAX).setCategory(Notification.CATEGORY_ALARM)
            .setContentIntent(open).setDeleteIntent(found)
            .addAction(0, tr("מָצָאתִי! 👋"), found).build()
        runCatching { NotificationManagerCompat.from(app).notify(BEEP_ID, n) }
        main.postDelayed({ stopBeep(false) }, 30_000)
    }

    /** [report]: the child pressed "מָצָאתִי" — the parents see "found". */
    fun stopBeep(report: Boolean) = main.post {
        main.removeCallbacksAndMessages(null)
        player?.runCatching { stop(); release() }
        player = null
        if (savedAlarmVolume >= 0) {
            (app.getSystemService(Context.AUDIO_SERVICE) as AudioManager)
                .setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmVolume, 0)
            savedAlarmVolume = -1
        }
        _beeping.value = false
        NotificationManagerCompat.from(app).cancel(BEEP_ID)
        val cid = childID
        if (report && cid != null) db.collection("children").document(cid).collection("location").document("beep")
            .set(mapOf("foundAt" to FieldValue.serverTimestamp()), SetOptions.merge())
    }
}

/** Background fixes (~10 min / 100 m) while Tofy is closed. */
class LocationUpdatesReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        KidLocation.init(context)
        LocationResult.extractResult(intent)?.lastLocation?.let { KidLocation.write(it) }
    }
}

/** Arrive / leave a family place. */
class GeofenceReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        KidLocation.init(context)
        val e = GeofencingEvent.fromIntent(intent) ?: return
        if (e.hasError()) return
        val arrive = when (e.geofenceTransition) {
            Geofence.GEOFENCE_TRANSITION_ENTER -> true
            Geofence.GEOFENCE_TRANSITION_EXIT -> false
            else -> return
        }
        e.triggeringGeofences?.forEach { KidLocation.crossed(it.requestId, arrive) }
    }
}

/** "מָצָאתִי! 👋" on the beep notification (or swiping it away). */
class BeepStopReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        KidLocation.init(context)
        KidLocation.stopBeep(true)
    }
}

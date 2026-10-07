package com.rani.tofy.ui.location

import android.content.Context
import android.location.Geocoder
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.rani.tofy.data.Child
import com.rani.tofy.data.ChildLocationFix
import com.rani.tofy.data.FamilyPlace
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.bool
import com.rani.tofy.data.confirmedMerge
import com.rani.tofy.data.map
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.Locale

/**
 * 📍 The PARENT side of location — iOS LocationSharing (parent side). Follows
 * each child's devices' last fixes and beep state, sends the two commands
 * (refresh, beep), and switches sharing / saves places. Firestore shape: see
 * kid/location/KidLocation.kt and iOS LocationSharing.swift.
 */
object LocationRepository {
    data class Beep(val at: Double, val found: Double?, val stop: Boolean)

    private val db get() = FirebaseFirestore.getInstance()
    private val regs = mutableListOf<ListenerRegistration>()
    private var following: List<String> = emptyList()

    private val _fixes = MutableStateFlow<Map<String, List<ChildLocationFix>>>(emptyMap())
    /** childID → each device's last fix, freshest first. */
    val fixes: StateFlow<Map<String, List<ChildLocationFix>>> = _fixes
    private val _beeps = MutableStateFlow<Map<String, Beep>>(emptyMap())
    val beeps: StateFlow<Map<String, Beep>> = _beeps
    private val _addresses = MutableStateFlow<Map<String, String>>(emptyMap())
    val addresses: StateFlow<Map<String, String>> = _addresses
    /** A tapped "🏫 נוני הגיעה" push → the map, on that child. */
    val openMapFor = MutableStateFlow<String?>(null)

    fun sharingOn(child: Child): Boolean = child.raw.map("locationSharing")?.bool("enabled") == true

    /** Listeners only — nothing is sent to the children's phones. */
    fun follow(childIDs: List<String>) {
        val ids = childIDs.sorted()
        if (ids == following) return
        following = ids
        regs.forEach { it.remove() }; regs.clear()
        for (cid in ids) {
            regs += db.collection("children").document(cid).collection("location").addSnapshotListener { snap, _ ->
                snap ?: return@addSnapshotListener
                val list = snap.documents.filter { it.id.startsWith("fix_") }.map { d ->
                    val at = (d.get("at") as? Timestamp)?.seconds?.toDouble() ?: (d.get("clientAt") as? Number)?.toDouble() ?: 0.0
                    ChildLocationFix(
                        lat = (d.get("lat") as? Number)?.toDouble(), lng = (d.get("lng") as? Number)?.toDouble(),
                        accuracy = (d.get("accuracy") as? Number)?.toDouble() ?: 0.0, at = at,
                        battery = (d.get("battery") as? Number)?.toDouble(), placeID = d.getString("placeID"),
                        placeSince = (d.get("placeSince") as? Number)?.toDouble(), permission = d.getString("permission"),
                    ).also { it.deviceID = d.getString("deviceID") ?: d.id.removePrefix("fix_"); it.kind = d.getString("kind") ?: "" }
                }.sortedByDescending { it.at }
                _fixes.value = _fixes.value + (cid to list)
                val b = snap.documents.firstOrNull { it.id == "beep" }
                if (b != null) {
                    val at = (b.get("at") as? Timestamp)?.seconds?.toDouble() ?: 0.0
                    _beeps.value = _beeps.value + (cid to Beep(at, (b.get("foundAt") as? Timestamp)?.seconds?.toDouble(), b.getBoolean("stop") == true))
                }
            }
        }
    }

    /** The map opened / "רענון": ask each child's phone for a fresh fix. */
    /** childID → when the parent last asked (unix s) — "מרענן…", then why nothing came. */
    val refreshedAt = MutableStateFlow<Map<String, Double>>(emptyMap())

    fun refresh(childIDs: List<String>) {
        refreshedAt.value = refreshedAt.value + childIDs.associateWith { System.currentTimeMillis() / 1000.0 }
        val me = FirebaseAuth.getInstance().currentUser?.uid ?: ""
        childIDs.forEach { cid ->
            db.collection("children").document(cid).collection("location").document("request")
                .set(mapOf("at" to FieldValue.serverTimestamp(), "by" to me))
        }
    }

    fun beep(childID: String, deviceID: String? = null, stop: Boolean = false) {
        val me = FirebaseAuth.getInstance().currentUser?.uid ?: ""
        db.collection("children").document(childID).collection("location").document("beep")
            .set(mapOf("at" to FieldValue.serverTimestamp(), "by" to me, "stop" to stop, "deviceID" to (deviceID ?: "")))
    }

    /** The parent's consent switch; off deletes every stored fix. */
    suspend fun setSharing(childID: String, on: Boolean): Boolean {
        val me = FirebaseAuth.getInstance().currentUser?.uid ?: ""
        val ref = db.collection("children").document(childID)
        val f = mapOf("locationSharing" to if (on) mapOf("enabled" to true, "consentAt" to System.currentTimeMillis() / 1000.0, "consentBy" to me)
                                               else mapOf("enabled" to false, "consentAt" to null, "consentBy" to null))
        var out = confirmedMerge(ref, f)
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(ref, f) }
        if (!on) runCatching {
            ref.collection("location").get().await().documents.filter { it.id.startsWith("fix_") }.forEach { it.reference.delete() }
        }
        return out == WriteOutcome.OK || out == WriteOutcome.QUEUED
    }

    suspend fun savePlaces(places: List<FamilyPlace>): Boolean {
        val hid = FamilyRepository.householdID ?: return false
        val out = confirmedMerge(db.collection("households").document(hid), mapOf("places" to places.map { it.toMap() }))
        return out == WriteOutcome.OK || out == WriteOutcome.QUEUED
    }

    /** The device shown for a child: the parent's pick, else the phone, else the freshest. */
    fun shownFix(child: Child, picked: String? = null): ChildLocationFix? {
        if (!sharingOn(child)) return null
        val all = (_fixes.value[child.id] ?: emptyList()).filter { it.hasFix }
        picked?.let { id -> all.firstOrNull { it.deviceID == id }?.let { return it } }
        return all.firstOrNull { it.kind != "ipad" } ?: all.firstOrNull()
    }

    /** "🏫 בית הספר · מאז 08:02", or the street address outside every place. */
    fun whereLine(ctx: Context, f: ChildLocationFix, places: List<FamilyPlace>): String {
        // The child's phone names the place; the parent also checks, so a place added after
        // the phone last moved (or a fix a little off indoors) still reads as the place.
        val reported = f.placeID?.let { id -> places.firstOrNull { it.id == id } }
        val place = reported ?: FamilyPlace.at(f.lat!!, f.lng!!, places, f.accuracy)
        if (place != null) {
            val since = if (reported != null) f.placeSince?.let { clock(it) } else null
            return if (since != null) tr("%@ %@ · מאז %@", place.emoji, place.name, since) else "${place.emoji} ${place.name}"
        }
        val key = String.format(Locale.ROOT, "%.4f,%.4f", Math.round(f.lat!! * 2000) / 2000.0, Math.round(f.lng!! * 2000) / 2000.0)
        _addresses.value[key]?.let { return "📍 $it" }
        geocode(ctx, key, f.lat, f.lng!!)
        return tr("📍 מחפשים כתובת…")
    }

    private val geocoding = mutableSetOf<String>()
    @Suppress("DEPRECATION")
    private fun geocode(ctx: Context, key: String, lat: Double, lng: Double) {
        if (!geocoding.add(key)) return
        CoroutineScope(Dispatchers.IO).launch {
            val line = runCatching {
                Geocoder(ctx, Locale(I18n.language.code)).getFromLocation(lat, lng, 1)?.firstOrNull()?.let { a ->
                    listOfNotNull(listOfNotNull(a.thoroughfare, a.subThoroughfare).joinToString(" ").ifEmpty { null }, a.locality)
                        .joinToString(", ").ifEmpty { null }
                }
            }.getOrNull()
            if (line != null) _addresses.value = _addresses.value + (key to line)
        }
    }

    fun clock(unix: Double): String {
        val t = java.time.Instant.ofEpochSecond(unix.toLong()).atZone(java.time.ZoneId.systemDefault())
        return String.format(Locale.ROOT, "%02d:%02d", t.hour, t.minute)
    }

    /** "עכשיו" / "לפני 3 דק׳" / "לפני 2 שע׳" / the date — iOS ParentLocationView.relative. */
    fun relative(at: Double): String {
        val secs = (System.currentTimeMillis() / 1000.0 - at).toLong()
        return when {
            secs < 60 -> tr("עכשיו")
            secs < 3600 -> tr("לפני %lld דק׳", secs / 60)
            secs < 86_400 -> tr("לפני %lld שע׳", secs / 3600)
            else -> java.time.format.DateTimeFormatter.ofPattern("d/M HH:mm")
                .format(java.time.Instant.ofEpochSecond(at.toLong()).atZone(java.time.ZoneId.systemDefault()))
        }
    }

    fun deviceName(kind: String): String = when (kind) {
        "iphone" -> tr("📱 אייפון"); "ipad" -> tr("📲 אייפד"); "android" -> tr("📱 אנדרואיד"); else -> tr("📱 טלפון")
    }
}

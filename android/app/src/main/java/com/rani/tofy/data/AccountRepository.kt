package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.DeviceRole
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.firestore.Source
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.tasks.await
import java.util.TimeZone
import java.util.UUID

/** Where a signed-in parent lands — HouseholdManager.bootstrap's routing. */
sealed interface Bootstrap {
    data object Loading : Bootstrap
    data object NeedsFamilyChoice : Bootstrap
    data class EmailInvite(val householdID: String, val familyName: String?) : Bootstrap
    data class Ready(val householdID: String) : Bootstrap
    data class Failed(val message: String) : Bootstrap
}

/**
 * The parent account + household lifecycle, field-for-field compatible with
 * HouseholdManager.swift (ensureParentDoc / createOwnHousehold / acceptEmailInvite).
 * NOBODY gets a silently created household: no membership → explicit choice.
 */
object AccountRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val auth get() = FirebaseAuth.getInstance()
    private val _boot = MutableStateFlow<Bootstrap>(Bootstrap.Loading)
    val boot: StateFlow<Bootstrap> = _boot

    private fun parentRef(uid: String) = db.collection("parents").document(uid)

    // 🔌 A failed family load used to sit on "Failed" with the raw error until
    // the app was killed. Now it retries by itself (3s → a minute), and on
    // "נסו שוב" / returning to the app (HouseholdManager.swift, Eli 9.10).
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var retryJob: Job? = null
    private var attempts = 0
    /** A load is being retried after a failure (MainActivity keeps the connecting screen up). */
    val retrying: Boolean get() = attempts > 0
    private fun retryDelayMs(attempt: Int): Long = (minOf(60.0, 3.0 * Math.pow(2.0, (minOf(maxOf(attempt, 1) - 1, 5)).toDouble())) * 1000).toLong()

    /** Try again now — the connecting screen's button, and app resume. */
    fun retryNow() {
        if (_boot.value !is Bootstrap.Failed) return
        _boot.value = Bootstrap.Loading   // at once — a second tap/onResume now finds "Loading" and stops
        retryJob?.cancel()
        // Tracked, and only one at a time: a double tap / rotation used to start
        // two bootstraps, and both attached the family's listeners.
        retryJob = scope.launch { bootstrap() }
    }

    /** The account the current "no family yet" answer (choice / email invite) is for. */
    private var answeredFor: String? = null

    suspend fun bootstrap() {
        val user = auth.currentUser ?: return
        // Cancel a pending retry — but never the job we are running INSIDE: the
        // auto-retry called bootstrap(), which cancelled itself, and every later
        // await threw CancellationException → "Failed" → retry → cancel… forever.
        // Rotation / dark mode / locale recreate the activity and run this again:
        // a family already loaded for this account stays — the dashboard used to
        // turn into a spinner (and offline, stay one).
        if (_boot.value is Bootstrap.Ready && FamilyRepository.isRunningFor(user.uid)) return
        // Same for "no family yet": the answer for THIS account stands. Loading
        // again on a rotation threw the parent off the name / code screen, back
        // to the fork, with what they typed gone.
        if ((_boot.value is Bootstrap.NeedsFamilyChoice || _boot.value is Bootstrap.EmailInvite) && answeredFor == user.uid) return
        val me = kotlin.coroutines.coroutineContext[Job]
        if (retryJob != me) retryJob?.cancel()
        _boot.value = Bootstrap.Loading
        try {
            ensureParentDoc(user.uid, user.email, user.displayName)
            val hid = findMembership(user.uid)
            if (hid != null) {
                if (finish(hid)) { attempts = 0; return }
                throw IllegalStateException("family not loaded")
            }
            val mail = user.email?.lowercase()
            if (!mail.isNullOrBlank()) {
                val inv = db.collection("households").whereArrayContains("invitedParentEmails", mail).limit(1).get().await()
                inv.documents.firstOrNull()?.let {
                    attempts = 0; answeredFor = user.uid
                    _boot.value = Bootstrap.EmailInvite(it.id, it.getString("familyName")); return
                }
            }
            attempts = 0; answeredFor = user.uid
            _boot.value = Bootstrap.NeedsFamilyChoice
        } catch (e: CancellationException) {
            throw e   // a cancelled launch (rotation) is not a failed load
        } catch (e: Exception) {
            _boot.value = Bootstrap.Failed(e.message ?: "error")
            attempts += 1
            val wait = retryDelayMs(attempts)
            retryJob = scope.launch { delay(wait); if (_boot.value is Bootstrap.Failed) bootstrap() }
        }
    }

    /** "לא המשפחה שלי" — go to the explicit new-vs-join choice instead. */
    fun declineEmailInvite() { _boot.value = Bootstrap.NeedsFamilyChoice }

    private suspend fun ensureParentDoc(uid: String, email: String?, displayName: String?) {
        val snap = parentRef(uid).get().await()
        if (snap.exists()) return
        parentRef(uid).set(mapOf(
            "id" to uid, "email" to email, "displayName" to displayName,
            "householdIDs" to emptyList<String>(), "fcmTokens" to emptyList<String>(),
            "twoFactorEnabled" to false, "consentVersion" to 0,
        ), SetOptions.merge()).await()
    }

    private suspend fun findMembership(uid: String): String? {
        val query = db.collection("households").whereArrayContains("parentUIDs", uid)
        var q = query.get().await()
        // "No family" from the CACHE is not an answer — ask the server (offline
        // that throws → retry), or a cached empty result leads to a SECOND family.
        if (q.isEmpty && q.metadata.isFromCache) q = query.get(Source.SERVER).await()
        val ids = q.documents.map { it.id }
        val me = parentRef(uid).get().await()
        val preferred = (me.get("householdIDs") as? List<*>)?.filterIsInstance<String>().orEmpty()
        if (ids.isEmpty()) return rejoinOwnFamily(uid, preferred)
        // Several families (one opened by accident before joining the partner's):
        // the same order as the iPhone — the one this account CHOSE
        // (`activeHouseholdID` on its own doc), then the one with children, then
        // the first one listed. Each platform used to pick by a rule of its own.
        val chosen = me.getString("activeHouseholdID")
        return q.documents.sortedWith(compareBy<com.google.firebase.firestore.DocumentSnapshot>(
            { if (it.id == chosen) 0 else 1 },
            { if (((it.get("childIDs") as? List<*>)?.size ?: 0) > 0) 0 else 1 },
            { preferred.indexOf(it.id).let { i -> if (i < 0) Int.MAX_VALUE else i } },
        )).first().id
    }

    /**
     * 🛡 The server says "no family", but this account's OWN parent doc still
     * names one — it was dropped from that family's parentUIDs (a server
     * clean-up on 30.8). Rejoin it (the self-add the rules allow) instead of
     * starting a SECOND family (HouseholdManager.rejoinOwnFamily).
     */
    private suspend fun rejoinOwnFamily(uid: String, listed: List<String>): String? {
        for (hid in listed) {
            val ref = db.collection("households").document(hid)
            try {
                ref.update("parentUIDs", FieldValue.arrayUnion(uid)).await()   // a deleted family throws
                val doc = ref.get(Source.SERVER).await()
                if ((doc.get("parentUIDs") as? List<*>)?.contains(uid) == true) return hid
            } catch (e: com.google.firebase.firestore.FirebaseFirestoreException) {
                // Gone / not ours → the next one. Anything else (offline mid-way)
                // is NOT "no family": rethrow, and the load retries.
                if (e.code != com.google.firebase.firestore.FirebaseFirestoreException.Code.NOT_FOUND &&
                    e.code != com.google.firebase.firestore.FirebaseFirestoreException.Code.PERMISSION_DENIED) throw e
            }
        }
        return null
    }

    /** False when the family's listeners could not start — the caller retries. */
    private suspend fun finish(hid: String): Boolean {
        val user = auth.currentUser ?: return false
        if (!FamilyRepository.start(user.uid)) return false
        // NOT awaited: offline a write never completes, and awaiting these two
        // left the parent on a bare spinner with no way out (HouseholdManager.swift).
        scope.launch { recordMyParentName(hid); recordTimeZone(hid); registerParentDevice(hid) }
        _boot.value = Bootstrap.Ready(hid)
        return true
    }

    /** "צרו משפחה חדשה" — the ONLY way a household is minted. */
    suspend fun createOwnHousehold(familyName: String?) {
        val uid = auth.currentUser?.uid ?: return
        // 🛡 Never a SECOND family: if this account already belongs to one, load
        // it. If that check can't reach the server, this throws — no guessing.
        findMembership(uid)?.let { if (!finish(it)) error("family not loaded"); return }
        val id = UUID.randomUUID().toString().uppercase()
        val data = mutableMapOf<String, Any?>(
            "id" to id, "parentUIDs" to listOf(uid), "childIDs" to emptyList<String>(),
            "createdBy" to uid, "createdAt" to nowSecs(),
        )
        familyName?.trim()?.takeIf { it.isNotEmpty() }?.let { data["familyName"] = it }
        db.collection("households").document(id).set(data).await()
        parentRef(uid).update(mapOf("householdIDs" to FieldValue.arrayUnion(id), "activeHouseholdID" to id)).await()
        if (!finish(id)) error("family not loaded")
    }

    suspend fun acceptEmailInvite(hid: String) {
        val user = auth.currentUser ?: return
        db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(user.uid)).await()
        parentRef(user.uid).update(mapOf("householdIDs" to FieldValue.arrayUnion(hid), "activeHouseholdID" to hid)).await()
        user.email?.lowercase()?.let {
            runCatching { db.collection("households").document(hid).update("invitedParentEmails", FieldValue.arrayRemove(it)).await() }
        }
        if (!finish(hid)) error("family not loaded")   // the screen shows its error, not an endless spinner
    }

    /** Join a co-parent's family by the 6-char code (redeemInvite, bringLocalChildren=false). */
    suspend fun redeemInvite(rawCode: String): Result<Unit> = runCatching {
        val user = auth.currentUser ?: error("not signed in")
        val code = rawCode.trim().uppercase()
        val inv = db.collection("invites").document(code).get().await()
        if (!inv.exists()) error("code")
        val d = inv.data!!
        val exp = d.secs("expiresAt") ?: 0.0
        if (exp < nowSecs()) error("expired")
        val hid = d.str("householdID") ?: error("code")
        db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(user.uid)).await()
        parentRef(user.uid).update(mapOf("householdIDs" to FieldValue.arrayUnion(hid), "activeHouseholdID" to hid)).await()
        db.collection("invites").document(code).update("redeemedBy", user.uid).await()
        if (!finish(hid)) error("family not loaded")
    }

    private suspend fun recordMyParentName(hid: String) {
        val user = auth.currentUser ?: return
        val name = user.displayName?.takeIf { it.isNotBlank() } ?: user.email ?: return
        runCatching { db.collection("households").document(hid).update("parentNames.${user.uid}", name).await() }
    }

    /** Written ONCE, when the family has none (HouseholdManager.recordTimeZone): every
     *  phone used to write its own, and with one parent abroad the two kept replacing
     *  each other's value. A parent moves it on purpose in Settings. */
    private suspend fun recordTimeZone(hid: String) {
        runCatching {
            val ref = db.collection("households").document(hid)
            if (!ref.get().await().getString("timeZone").isNullOrBlank()) return
            ref.update("timeZone", TimeZone.getDefault().id).await()
        }
    }

    // ── 📱 this phone as a PARENT device (HouseholdManager.registerParentDevice) ──

    /**
     * `childDevices/parent_<install>` — the row that says "this install is a parent's
     * phone". Without it a parent's Android in Kid Mode looked exactly like the child's
     * own device: a reset waited for it instead of applying, and the iPhone offered to
     * "remove" it. Same doc id, fields and liveness rule as the iPhone (the parent row's
     * `lastSeenAt` must be at least the Kid Mode row's `joinedAt`).
     */
    suspend fun registerParentDevice(hid: String) {
        if (DeviceRole.role != DeviceRole.Role.PARENT) return
        val me = com.rani.tofy.kid.core.KidIdentity
        runCatching {
            val ref = db.collection("childDevices").document("parent_${me.installID}")
            val now = nowSecs()
            val joinedAt = (kotlinx.coroutines.withTimeoutOrNull(5000) { ref.get().await() }?.get("joinedAt") as? Number)?.toDouble() ?: now
            ref.set(mapOf(
                "id" to "parent_${me.installID}", "childID" to "", "householdID" to hid,
                "platform" to "android", "deviceID" to me.installID,
                "name" to me.friendlyName, "kind" to me.kind, "systemVersion" to me.systemVersion,
                "joinedAt" to joinedAt, "lastSeenAt" to now,
                "role" to "parent", "appVersion" to me.appVersion,
                "kidModeChildID" to (DeviceRole.kidModeChildID ?: FieldValue.delete()),
            ), SetOptions.merge()).await()
        }
    }

    suspend fun recordConsent(version: Int = 1) {
        val uid = auth.currentUser?.uid ?: return
        parentRef(uid).set(mapOf("consentVersion" to version, "consentAt" to nowSecs()), SetOptions.merge()).await()
    }

    suspend fun consentVersion(): Int {
        val uid = auth.currentUser?.uid ?: return 0
        return (parentRef(uid).get().await().getLong("consentVersion") ?: 0L).toInt()
    }

    fun signOut() {
        retryJob?.cancel(); attempts = 0; answeredFor = null
        // This phone is no longer a parent's (not awaited — offline it never completes).
        runCatching { db.collection("childDevices").document("parent_${com.rani.tofy.kid.core.KidIdentity.installID}").delete() }
        FamilyRepository.stop()
        auth.signOut()
        _boot.value = Bootstrap.Loading
    }
}

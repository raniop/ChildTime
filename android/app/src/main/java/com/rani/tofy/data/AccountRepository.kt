package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
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
    private fun retryDelayMs(attempt: Int): Long = (minOf(60.0, 3.0 * Math.pow(2.0, (minOf(maxOf(attempt, 1) - 1, 5)).toDouble())) * 1000).toLong()

    /** Try again now — the connecting screen's button, and app resume. */
    fun retryNow() {
        if (_boot.value !is Bootstrap.Failed) return
        retryJob?.cancel()
        scope.launch { bootstrap() }
    }

    suspend fun bootstrap() {
        val user = auth.currentUser ?: return
        // Cancel a pending retry — but never the job we are running INSIDE: the
        // auto-retry called bootstrap(), which cancelled itself, and every later
        // await threw CancellationException → "Failed" → retry → cancel… forever.
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
                    _boot.value = Bootstrap.EmailInvite(it.id, it.getString("familyName")); return
                }
            }
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
        if (ids.isEmpty()) return null
        val preferred = (parentRef(uid).get().await().get("householdIDs") as? List<*>)?.filterIsInstance<String>().orEmpty()
        return preferred.firstOrNull { it in ids } ?: ids.first()
    }

    /** False when the family's listeners could not start — the caller retries. */
    private suspend fun finish(hid: String): Boolean {
        val user = auth.currentUser ?: return false
        if (!FamilyRepository.start(user.uid)) return false
        recordMyParentName(hid)
        recordTimeZone(hid)
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
        parentRef(uid).update("householdIDs", FieldValue.arrayUnion(id)).await()
        if (!finish(id)) error("family not loaded")
    }

    suspend fun acceptEmailInvite(hid: String) {
        val user = auth.currentUser ?: return
        db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(user.uid)).await()
        parentRef(user.uid).update("householdIDs", FieldValue.arrayUnion(hid)).await()
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
        parentRef(user.uid).update("householdIDs", FieldValue.arrayUnion(hid)).await()
        db.collection("invites").document(code).update("redeemedBy", user.uid).await()
        if (!finish(hid)) error("family not loaded")
    }

    private suspend fun recordMyParentName(hid: String) {
        val user = auth.currentUser ?: return
        val name = user.displayName?.takeIf { it.isNotBlank() } ?: user.email ?: return
        runCatching { db.collection("households").document(hid).update("parentNames.${user.uid}", name).await() }
    }

    private suspend fun recordTimeZone(hid: String) {
        runCatching { db.collection("households").document(hid).update("timeZone", TimeZone.getDefault().id).await() }
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
        FamilyRepository.stop()
        auth.signOut()
        _boot.value = Bootstrap.Loading
    }
}

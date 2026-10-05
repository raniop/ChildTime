package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
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

    suspend fun bootstrap() {
        val user = auth.currentUser ?: return
        _boot.value = Bootstrap.Loading
        try {
            ensureParentDoc(user.uid, user.email, user.displayName)
            val hid = findMembership(user.uid)
            if (hid != null) { finish(hid); return }
            val mail = user.email?.lowercase()
            if (!mail.isNullOrBlank()) {
                val inv = db.collection("households").whereArrayContains("invitedParentEmails", mail).limit(1).get().await()
                inv.documents.firstOrNull()?.let {
                    _boot.value = Bootstrap.EmailInvite(it.id, it.getString("familyName")); return
                }
            }
            _boot.value = Bootstrap.NeedsFamilyChoice
        } catch (e: Exception) {
            _boot.value = Bootstrap.Failed(e.message ?: "error")
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
        val q = db.collection("households").whereArrayContains("parentUIDs", uid).get().await()
        val ids = q.documents.map { it.id }
        if (ids.isEmpty()) return null
        val preferred = (parentRef(uid).get().await().get("householdIDs") as? List<*>)?.filterIsInstance<String>().orEmpty()
        return preferred.firstOrNull { it in ids } ?: ids.first()
    }

    private suspend fun finish(hid: String) {
        val user = auth.currentUser ?: return
        FamilyRepository.start(user.uid)
        recordMyParentName(hid)
        recordTimeZone(hid)
        _boot.value = Bootstrap.Ready(hid)
    }

    /** "צרו משפחה חדשה" — the ONLY way a household is minted. */
    suspend fun createOwnHousehold(familyName: String?) {
        val uid = auth.currentUser?.uid ?: return
        val id = UUID.randomUUID().toString().uppercase()
        val data = mutableMapOf<String, Any?>(
            "id" to id, "parentUIDs" to listOf(uid), "childIDs" to emptyList<String>(),
            "createdBy" to uid, "createdAt" to nowSecs(),
        )
        familyName?.trim()?.takeIf { it.isNotEmpty() }?.let { data["familyName"] = it }
        db.collection("households").document(id).set(data).await()
        parentRef(uid).update("householdIDs", FieldValue.arrayUnion(id)).await()
        finish(id)
    }

    suspend fun acceptEmailInvite(hid: String) {
        val user = auth.currentUser ?: return
        db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(user.uid)).await()
        parentRef(user.uid).update("householdIDs", FieldValue.arrayUnion(hid)).await()
        user.email?.lowercase()?.let {
            runCatching { db.collection("households").document(hid).update("invitedParentEmails", FieldValue.arrayRemove(it)).await() }
        }
        finish(hid)
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
        finish(hid)
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

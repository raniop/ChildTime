package com.rani.tofy.data

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.SetOptions
import kotlinx.coroutines.tasks.await
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.UUID

/** Children and household edits — HouseholdManager.swift's parent-side writes. */
object ChildRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private fun hid() = FamilyRepository.householdID ?: error("no household")

    /**
     * A new child, shaped like ChildRecord(profile:) so every iOS device decodes it.
     * Returns the new child id (UUID string, uppercase like Swift's uuidString).
     */
    suspend fun createChild(name: String, gender: String?, grade: Int, dailyCapMinutes: Int?, character: String = "fox"): String {
        val id = UUID.randomUUID().toString().uppercase()
        val h = hid()
        val age = when { grade <= 0 -> 4; grade <= 2 -> 6; grade <= 4 -> 8; else -> 10 }
        val rec = mutableMapOf<String, Any?>(
            "id" to id, "householdID" to h, "name" to name.trim(), "age" to age,
            "avatarPresetID" to "fox", "character3DID" to character, "characterUpdatedAt" to nowSecs(),
            "grade" to grade, "gradeSchoolYear" to schoolYear(),
            "interests" to emptyList<String>(), "learningLevel" to "developing", "createdAt" to nowSecs(),
            "topicsVersion" to 2, "onlyRegularQuestions" to false,
        )
        gender?.let { rec["gender"] = it }
        dailyCapMinutes?.let { rec["dailyCapMinutes"] = it }
        db.collection("children").document(id).set(rec, SetOptions.merge()).await()
        db.collection("households").document(h).update("childIDs", FieldValue.arrayUnion(id)).await()
        return id
    }

    /** Merge only the fields the parent changed — never a stale full record. */
    suspend fun update(childID: String, fields: Map<String, Any?>): WriteOutcome {
        val ref = db.collection("children").document(childID)
        var out = confirmedMerge(ref, fields)
        if (out == WriteOutcome.DENIED) { FamilyRepository.reassertMembership(); out = confirmedMerge(ref, fields) }
        return out
    }

    /** Tombstone FIRST, then the subcollection + leaderboard card, then the doc (rules gate on it). */
    suspend fun deleteChild(childID: String) {
        val h = hid()
        db.collection("deletedChildren").document(childID).set(mapOf("householdID" to h, "deletedAt" to nowSecs())).await()
        db.collection("households").document(h).update("childIDs", FieldValue.arrayRemove(childID)).await()
        runCatching { db.collection("children").document(childID).collection("state").document("current").delete().await() }
        runCatching { db.collection("friendCards").document(childID).delete().await() }
        db.collection("children").document(childID).delete().await()
    }

    // MARK: invites

    private const val ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    private fun makeCode(): String { val r = SecureRandom(); return (1..6).map { ALPHABET[r.nextInt(ALPHABET.length)] }.joinToString("") }

    /** invites/{CODE}, valid 7 days. childID → a per-child device join code. */
    suspend fun createInvite(childID: String? = null): String {
        val uid = FirebaseAuth.getInstance().currentUser!!.uid
        val code = makeCode()
        val d = mutableMapOf<String, Any?>("id" to code, "householdID" to hid(), "createdBy" to uid, "createdAt" to nowSecs(), "expiresAt" to nowSecs() + 7 * 86400)
        childID?.let { d["childID"] = it }
        db.collection("invites").document(code).set(d).await()
        return code
    }

    /** The QR a child's iPad scans (JoinLink.swift). */
    fun joinURL(code: String, childID: String) = "https://tofyapp.com/join?c=$code&k=$childID"

    fun watchRedemption(code: String, onRedeemed: () -> Unit): ListenerRegistration =
        db.collection("invites").document(code).addSnapshotListener { s, _ -> if (s?.get("redeemedBy") != null) onRedeemed() }

    // MARK: household

    suspend fun setFamilyName(name: String) {
        db.collection("households").document(hid()).update("familyName", name.trim()).await()
    }

    /** 🌍 A parent moves the family to another time zone (HouseholdManager.setFamilyTimeZone). */
    suspend fun setFamilyTimeZone(identifier: String) {
        db.collection("households").document(hid()).update("timeZone", identifier).await()
    }

    suspend fun setChildOrder(ids: List<String>) {
        db.collection("households").document(hid()).update("childOrder", ids).await()
    }

    suspend fun setChoresMoneyEnabled(on: Boolean) {
        db.collection("households").document(hid()).update("choresMoneyEnabled", on).await()
    }

    suspend fun inviteParentByEmail(raw: String): Boolean {
        val mail = raw.trim().lowercase()
        if (!mail.contains("@") || !mail.contains(".")) return false
        db.collection("households").document(hid()).update("invitedParentEmails", FieldValue.arrayUnion(mail)).await()
        return true
    }

    /**
     * The family parent code, as ParentGateView stores it: "salt:hash" where salt
     * is 16 random bytes in hex and hash = hex(SHA-256(salt + pin)). The child's
     * iPad verifies the same blob at its parental gate.
     */
    fun pinBlob(pin: String): String {
        val salt = ByteArray(16).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it) }
        return "$salt:${sha256Hex(salt + pin)}"
    }

    fun verifyPin(blob: String?, pin: String): Boolean {
        val parts = blob?.split(":") ?: return false
        if (parts.size != 2) return false
        return sha256Hex(parts[0] + pin) == parts[1]
    }

    private fun sha256Hex(s: String) = MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }

    suspend fun setHouseholdPIN(pin: String) {
        db.collection("households").document(hid()).update("parentPinHash", pinBlob(pin)).await()
    }
}

package com.rani.tofy.kid.ui

import android.net.Uri
import com.google.firebase.FirebaseNetworkException
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FirebaseFirestoreException
import com.google.firebase.firestore.SetOptions
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.confirmedMerge
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.secs
import com.rani.tofy.data.str
import com.rani.tofy.data.strList
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.delay
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeoutOrNull

/**
 * The child device's side of joining a family (HouseholdManager.redeemInvite
 * with bringLocalChildren = false + JoinLink.swift). A child device has NO
 * sign-in screen: it gets an anonymous uid, then joins the household as a
 * member (that uid in parentUIDs — the rules let a non-member add ONLY itself)
 * and binds to ONE existing child. It never uploads children of its own.
 */
object JoinRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val auth get() = FirebaseAuth.getInstance()

    /** JoinLink.payload(from:) → (CODE, childID?). Accepts the join link or a raw "CODE|childID". */
    fun parse(scanned: String): Pair<String, String?> {
        val s = scanned.trim()
        if (s.lowercase().startsWith("http")) {
            val u = runCatching { Uri.parse(s) }.getOrNull()
            if (u != null && (u.path ?: "").startsWith("/join")) {
                val code = u.getQueryParameter("c").orEmpty()
                val child = u.getQueryParameter("k")?.takeIf { it.isNotBlank() }
                if (code.isNotEmpty()) return code.trim().uppercase() to child
            }
        }
        val parts = s.split("|", limit = 2)
        return parts[0].trim().uppercase() to parts.getOrNull(1)?.trim()?.takeIf { it.isNotEmpty() }
    }

    /** AuthManager.signInAnonymouslyIfNeeded — the uid joining needs. Null on failure. */
    suspend fun ensureAnonymous(timeoutMs: Long = 8000): String? {
        auth.currentUser?.let { return it.uid }
        return withTimeoutOrNull(timeoutMs) { runCatching { auth.signInAnonymously().await().user?.uid }.getOrNull() }
    }

    sealed class Result {
        /** Joined. [childID] is resolved (link k / invite childID / only child) or null when ambiguous. */
        data class Joined(val householdID: String, val childID: String?) : Result()
        data class Failed(val message: String) : Result()
    }

    suspend fun redeem(rawPayload: String): Result {
        val (code, linkChild) = parse(rawPayload)
        if (code.length < 6) return Result.Failed(tr("קוֹד לֹא תָּקִין"))
        val uid = ensureAnonymous() ?: return Result.Failed(tr("בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב."))
        return try {
            val inv = db.collection("invites").document(code).get().await()
            val d = inv.data ?: return Result.Failed(tr("קוד לא נמצא"))
            if ((d.secs("expiresAt") ?: 0.0) < nowSecs()) return Result.Failed(tr("הקוד פג תוקף"))
            val hid = d.str("householdID") ?: return Result.Failed(tr("קוד לא נמצא"))
            val inviteChild = d.str("childID")
            // Same three writes, same order as iOS: membership, my parents doc, the invite.
            db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(uid)).await()
            ensureParentDoc(uid)
            db.collection("parents").document(uid).update("householdIDs", FieldValue.arrayUnion(hid)).await()
            db.collection("invites").document(code).update("redeemedBy", uid).await()
            // The join is done. Reading the household right after a fresh anonymous
            // session was refused for a moment on iOS — retry, never fail over it.
            var childIDs: List<String> = emptyList()
            for (attempt in 1..4) {
                val ok = runCatching { db.collection("households").document(hid).get().await() }.getOrNull()
                if (ok?.exists() == true) { childIDs = ok.data?.strList("childIDs").orEmpty(); break }
                delay(700)
            }
            // Which child is THIS device for? The link's k, the invite's childID, else the only child.
            val resolved = linkChild ?: inviteChild ?: childIDs.singleOrNull()
            Result.Joined(hid, resolved)
        } catch (e: Exception) {
            val offline = e is FirebaseNetworkException ||
                (e as? FirebaseFirestoreException)?.code == FirebaseFirestoreException.Code.UNAVAILABLE
            Result.Failed(if (offline) tr("בִּדְקוּ אֶת חִבּוּר הָאִינְטֶרְנֶט וְנַסּוּ שׁוּב.") else tr("קוֹד לֹא תָּקִין"))
        }
    }

    /** HouseholdManager.ensureParentDoc — the anonymous account's parents/{uid}, same fields as iOS ParentAccount. */
    private suspend fun ensureParentDoc(uid: String) {
        val ref = db.collection("parents").document(uid)
        if (runCatching { ref.get().await().exists() }.getOrDefault(false)) return
        ref.set(mapOf(
            "id" to uid, "householdIDs" to emptyList<String>(), "fcmTokens" to emptyList<String>(),
            "twoFactorEnabled" to false, "consentVersion" to 0,
        ), SetOptions.merge()).await()
    }

    /** Re-add this device's uid to parentUIDs (a no-op when already a member) — the DENIED self-heal. */
    suspend fun reassertMembership(householdID: String?) {
        val uid = auth.currentUser?.uid ?: return
        val hid = householdID ?: return
        runCatching { db.collection("households").document(hid).update("parentUIDs", FieldValue.arrayUnion(uid)).await() }
    }

    /**
     * A confirmed merge-write to children/{id} from the kid side (grade pick,
     * "ask a parent", play-code reset) — on DENIED heal membership and retry once.
     */
    suspend fun childWrite(childID: String, householdID: String?, fields: Map<String, Any?>): WriteOutcome {
        val ref = db.collection("children").document(childID)
        var out = confirmedMerge(ref, fields)
        if (out == WriteOutcome.DENIED) { reassertMembership(householdID); out = confirmedMerge(ref, fields) }
        return out
    }
}

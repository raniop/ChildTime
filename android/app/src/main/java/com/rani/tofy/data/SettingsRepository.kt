package com.rani.tofy.data

import android.content.Context
import android.widget.Toast
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.EmailAuthProvider
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.FirebaseFirestore
import com.rani.tofy.BuildConfig
import com.rani.tofy.R
import com.rani.tofy.auth.AuthRepository
import com.rani.tofy.i18n.tr
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.Locale

/**
 * Parent-settings writes that have no home in ChildRepository — the Android side
 * of ParentSettingsView.swift / ParentFeedbackView.swift / PushManager.sendTestPush
 * and HouseholdManager.deleteAllData().
 */
object SettingsRepository {
    private val db get() = FirebaseFirestore.getInstance()
    private val auth get() = FirebaseAuth.getInstance()

    /**
     * A household write (family name, child order, parent code): on a permission
     * error re-add ourselves to parentUIDs and try once more — the
     * command-delivery rule. Returns true when the write landed.
     */
    suspend fun householdWrite(block: suspend () -> Unit): Boolean =
        runCatching { block() }.isSuccess || run {
            FamilyRepository.reassertMembership()
            runCatching { block() }.isSuccess
        }

    /** The sign-in providers of this account ("google.com", "password", "apple.com"). */
    val providers: List<String>
        get() = auth.currentUser?.providerData?.map { it.providerId }?.filter { it != "firebase" }.orEmpty()

    // MARK: test push

    /** PushManager.sendTestPush: functions' sendTestPush pushes to this uid's tokens. */
    suspend fun sendTestPush(): String {
        val uid = auth.currentUser?.uid ?: return tr("אין משתמש מחובר")
        return try {
            db.collection("pushTests").add(mapOf("uid" to uid, "createdAt" to nowSecs())).await()
            tr("נשלחה בקשת בדיקה — ההתראה אמורה להגיע תוך כמה שניות")
        } catch (e: Exception) {
            tr("שגיאה: %@", e.localizedMessage ?: "")
        }
    }

    // MARK: feedback

    /**
     * ParentFeedbackView.submit — the same fields, fire-and-forget exactly like
     * iOS (the thank-you shows at once and the write queues offline).
     */
    fun submitFeedback(message: String) {
        val payload = mutableMapOf<String, Any>(
            "message" to message,
            "createdAt" to nowSecs(),
            "appVersion" to "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})",
            "locale" to Locale.getDefault().toString(),
            "fromUID" to (auth.currentUser?.uid ?: "anonymous"),
        )
        FamilyRepository.householdID?.let { payload["householdID"] = it }
        db.collection("parentFeedback").add(payload)
    }

    // MARK: account deletion

    /**
     * Firebase refuses `user.delete()` unless the sign-in is fresh (~5 minutes).
     * Checked BEFORE the cascade so the family's data is never wiped while the
     * account itself survives.
     */
    fun needsRecentLogin(): Boolean {
        val last = auth.currentUser?.metadata?.lastSignInTimestamp ?: return true
        return System.currentTimeMillis() - last > 4 * 60 * 1000
    }

    /** Re-auth with Google (Credential Manager). null on success, "cancel", or a message. */
    suspend fun reauthWithGoogle(activity: Context): String? = try {
        val user = auth.currentUser ?: error("no user")
        val option = GetSignInWithGoogleOption.Builder(activity.getString(R.string.default_web_client_id)).build()
        val cred = CredentialManager.create(activity).getCredential(activity, GetCredentialRequest(listOf(option))).credential
        if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            val token = GoogleIdTokenCredential.createFrom(cred.data).idToken
            user.reauthenticate(GoogleAuthProvider.getCredential(token, null)).await()
            null
        } else "unsupported credential"
    } catch (e: androidx.credentials.exceptions.GetCredentialCancellationException) { "cancel" } catch (e: Exception) { e.localizedMessage ?: "error" }

    /** Re-auth with the account's email + the password the parent types. */
    suspend fun reauthWithPassword(password: String): Boolean = try {
        val user = auth.currentUser ?: error("no user")
        user.reauthenticate(EmailAuthProvider.getCredential(user.email ?: "", password)).await()
        true
    } catch (e: Exception) { false }

    /**
     * Outlives the settings screen: the cascade deletes the children, so AppNav
     * swaps the screen away mid-way — a composable scope would be cancelled.
     */
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /**
     * ParentSettingsView.deleteEverything: the cloud data first (rules need a
     * live session), THEN the auth account (Google Play's in-app deletion), then
     * sign out. A failure is reported as a toast — by then the screen is gone.
     */
    fun deleteEverything(context: Context) {
        val app = context.applicationContext
        val hh = FamilyRepository.state.value.household
        appScope.launch {
            deleteAllData(hh)
            val err = AuthRepository.deleteAccount()
            if (err != null) {
                val recent = err.contains("recent", ignoreCase = true) || err.contains("17014")
                val msg = if (recent) tr("כדי למחוק את החשבון לצמיתות יש להתחבר מחדש ואז לנסות שוב. שאר הנתונים כבר נמחקו.")
                else tr("מחיקת החשבון נכשלה: %@", err)
                Toast.makeText(app, msg, Toast.LENGTH_LONG).show()
            }
            app.getSharedPreferences("tofy", Context.MODE_PRIVATE).edit().remove("parentPinBlob").apply()
            AccountRepository.signOut()
        }
    }

    /** HouseholdManager.deleteAllData() (~line 2007), step for step, every step best-effort. */
    private suspend fun deleteAllData(hh: Household?) {
        val uid = auth.currentUser?.uid ?: return
        if (hh == null) { runCatching { db.collection("parents").document(uid).delete().await() }; return }
        for (childID in hh.childIDs) {
            val child = db.collection("children").document(childID)
            runCatching { child.collection("state").document("current").delete().await() }
            runCatching { deleteCollection("children/$childID/dailyStats") }
            // The public leaderboard card carries the child's name — BEFORE the
            // child doc, since its delete rule gates on the child's householdID.
            runCatching { db.collection("friendCards").document(childID).delete().await() }
            runCatching { child.delete().await() }
            runCatching {
                db.collection("childDevices").whereEqualTo("childID", childID).get().await()
                    .documents.forEach { runCatching { it.reference.delete().await() } }
            }
        }
        runCatching { deleteCollection("households/${hh.id}/chores") }
        runCatching { deleteCollection("households/${hh.id}/choreStats") }
        runCatching { db.collection("households").document(hh.id).delete().await() }
        runCatching { db.collection("parents").document(uid).delete().await() }
    }

    private suspend fun deleteCollection(path: String) {
        db.collection(path).get().await().documents.forEach { runCatching { it.reference.delete().await() } }
    }

    /** AppInfo.versionLine: "גרסה 2026.10.6 (1)". */
    val versionLine: String get() = tr("גרסה %@ (%@)", BuildConfig.VERSION_NAME, BuildConfig.VERSION_CODE.toString())
}

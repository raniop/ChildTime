package com.rani.tofy.auth

import android.content.Context
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.auth.UserProfileChangeRequest
import com.rani.tofy.R
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.tasks.await

/**
 * Parent sign-in: Google (Credential Manager) and email/password — the same
 * Firebase Auth accounts as iOS, so a parent who registered with Google or email
 * on an iPhone lands in the same family here. Anonymous sessions are child
 * devices only and are never offered.
 */
object AuthRepository {
    private val auth get() = FirebaseAuth.getInstance()

    val user: Flow<FirebaseUser?> = callbackFlow {
        val l = FirebaseAuth.AuthStateListener { trySend(it.currentUser) }
        auth.addAuthStateListener(l)
        awaitClose { auth.removeAuthStateListener(l) }
    }

    /** A parent account — anything but an anonymous (child-device) session. */
    val isRealAccount: Boolean get() = auth.currentUser?.let { !it.isAnonymous } ?: false

    /** Returns null on success, "cancel" when the parent backed out, else an error message. */
    suspend fun signInWithGoogle(activity: Context): String? = try {
        val option = GetSignInWithGoogleOption.Builder(activity.getString(R.string.default_web_client_id)).build()
        val result = CredentialManager.create(activity).getCredential(activity, GetCredentialRequest(listOf(option)))
        val cred = result.credential
        if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
            val token = GoogleIdTokenCredential.createFrom(cred.data).idToken
            auth.signInWithCredential(GoogleAuthProvider.getCredential(token, null)).await()
            null
        } else "unsupported credential"
    } catch (e: GetCredentialCancellationException) { "cancel" } catch (e: Exception) { e.localizedMessage ?: "error" }

    suspend fun signInWithEmail(email: String, password: String): String? = try {
        auth.signInWithEmailAndPassword(email.trim(), password).await(); null
    } catch (e: Exception) { e.localizedMessage ?: "error" }

    suspend fun register(name: String, email: String, password: String): String? = try {
        val r = auth.createUserWithEmailAndPassword(email.trim(), password).await()
        if (name.isNotBlank()) r.user?.updateProfile(UserProfileChangeRequest.Builder().setDisplayName(name.trim()).build())?.await()
        null
    } catch (e: Exception) { e.localizedMessage ?: "error" }

    suspend fun resetPassword(email: String): String? = try {
        auth.sendPasswordResetEmail(email.trim()).await(); null
    } catch (e: Exception) { e.localizedMessage ?: "error" }

    /** Google Play requires in-app account deletion. Caller deletes Firestore data first. */
    suspend fun deleteAccount(): String? = try {
        auth.currentUser?.delete()?.await(); null
    } catch (e: Exception) { e.localizedMessage ?: "error" }
}

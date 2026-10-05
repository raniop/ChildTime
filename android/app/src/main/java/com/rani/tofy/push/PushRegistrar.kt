package com.rani.tofy.push

import android.content.Context
import android.app.PendingIntent
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.RemoteMessage
import com.rani.tofy.MainActivity
import com.rani.tofy.R
import com.rani.tofy.i18n.I18n
import kotlinx.coroutines.tasks.await

/**
 * The parent's FCM token goes where iOS puts it — parents/{uid}.fcmTokens plus
 * tokenLanguages[token] — so every server push (chores, help, live events,
 * weekly report) reaches this phone in the parent's language.
 */
object PushRegistrar {
    fun register(token: String? = null) {
        val uid = FirebaseAuth.getInstance().currentUser?.takeIf { !it.isAnonymous }?.uid ?: return
        if (token != null) write(uid, token)
        else FirebaseMessaging.getInstance().token.addOnSuccessListener { write(uid, it) }
    }

    private fun write(uid: String, token: String) {
        FirebaseFirestore.getInstance().collection("parents").document(uid).set(mapOf(
            "fcmTokens" to FieldValue.arrayUnion(token),
            "tokenLanguages" to mapOf(token to I18n.language.code),
            "language" to I18n.language.code,
        ), SetOptions.merge())
    }

    /** On sign-out: this phone stops receiving the family's pushes. */
    suspend fun unregister() {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return
        val token = runCatching { FirebaseMessaging.getInstance().token.await() }.getOrNull() ?: return
        runCatching {
            FirebaseFirestore.getInstance().collection("parents").document(uid)
                .update(mapOf("fcmTokens" to FieldValue.arrayRemove(token), "tokenLanguages.$token" to FieldValue.delete())).await()
        }
    }
}

object Notifier {
    fun show(ctx: Context, m: RemoteMessage) {
        val title = m.notification?.title ?: m.data["title"] ?: return
        val body = m.notification?.body ?: m.data["body"] ?: ""
        val channel = m.notification?.channelId ?: m.data["channel"] ?: "family"
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java).apply {
            m.data.forEach { (k, v) -> putExtra(k, v) }
        }, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, channel).setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title).setContentText(body).setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true).setContentIntent(open).build()
        runCatching { NotificationManagerCompat.from(ctx).notify(m.messageId.hashCode(), n) }
    }
}

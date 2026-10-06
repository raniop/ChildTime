package com.rani.tofy.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/** Notifications with a `notification` block are shown by the system; data-only ones land here. */
class TofyMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) { PushRegistrar.register(token) }
    override fun onMessageReceived(message: RemoteMessage) {
        // 🔔 Every VISIBLE push also lands in the activity feed, like iOS's PushManager.
        // A silent data message (the server's "wake" to a child device after a parent
        // command) has nothing to say — it used to add an empty "עדכון חדש" row (Rani).
        val body = message.notification?.body ?: message.data["body"]
        val title = message.notification?.title ?: message.data["title"]
        if (title != null || body != null)
            com.rani.tofy.data.ActivityStore.recordNotification(message.data["type"], message.messageId ?: "${System.currentTimeMillis()}", body)
        Notifier.show(this, message)
    }
}

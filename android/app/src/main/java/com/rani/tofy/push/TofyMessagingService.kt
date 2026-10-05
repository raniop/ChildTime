package com.rani.tofy.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/** Notifications with a `notification` block are shown by the system; data-only ones land here. */
class TofyMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) { PushRegistrar.register(token) }
    override fun onMessageReceived(message: RemoteMessage) {
        // 🔔 Every push also lands in the activity feed, like iOS's PushManager.
        com.rani.tofy.data.ActivityStore.recordNotification(message.data["type"], message.messageId ?: "${System.currentTimeMillis()}",
            message.notification?.body ?: message.data["body"])
        Notifier.show(this, message)
    }
}

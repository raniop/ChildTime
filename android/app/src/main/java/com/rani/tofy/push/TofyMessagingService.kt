package com.rani.tofy.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

/** Notifications with a `notification` block are shown by the system; data-only ones land here. */
class TofyMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) { PushRegistrar.register(token) }
    override fun onMessageReceived(message: RemoteMessage) { Notifier.show(this, message) }
}

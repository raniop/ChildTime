package com.rani.tofy.kid.ui.home

import android.content.Intent
import android.net.Uri
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.rani.tofy.kid.ui.social.FriendLink
import com.rani.tofy.kid.ui.social.FriendsRepository

/**
 * Where a tapped push or an opened link wants the kid side to go — the twin of
 * ChildTimeApp.onOpenURL / onContinueUserActivity + PushManager's tap handler:
 *
 *   push data.type == "liveGameInvite" + data.gameID → [pendingGameID] (the home joins it)
 *   https://tofyapp.com/friend?f=CODE, tofy://friend?f=  → FriendsRepository.pendingFriendCode (the board adds it)
 *   https://tofyapp.com/game?g=ID, tofy://game?g=ID     → [pendingGameID]
 *   https://tofyapp.com/join?c=&k=                       → [pendingJoinLink] (ChildJoin redeems it when unbound)
 *
 * Compose state, so the kid home / join screen react the moment a value lands.
 */
object KidDeepLinks {
    /** LiveGameManager.pendingGameID — consumed by the kid home (opens the live quiz). */
    var pendingGameID by mutableStateOf<String?>(null)
    /** A join link waiting for an unbound child device's join screen. */
    var pendingJoinLink by mutableStateOf<String?>(null)

    /** MainActivity.onCreate / onNewIntent. */
    fun handle(intent: Intent?) {
        intent ?: return
        // FCM puts the push's data keys on the launch intent as string extras (tray tap or Notifier).
        if (intent.getStringExtra("type") == "liveGameInvite") {
            intent.getStringExtra("gameID")?.takeIf { it.isNotBlank() }?.let { pendingGameID = it }
        }
        intent.data?.let { handle(it) }
    }

    fun handle(uri: Uri) {
        val scheme = uri.scheme?.lowercase()
        val kind = when {
            (scheme == "https" || scheme == "http") && uri.host?.lowercase()?.removePrefix("www.") == FriendLink.HOST ->
                uri.path.orEmpty().trim('/').substringBefore('/').lowercase()
            scheme == "tofy" -> uri.host?.lowercase()
            else -> null
        }
        when (kind) {
            "friend" -> FriendLink.code(uri.toString()).takeIf { it.isNotBlank() && it != uri.toString() }
                ?.let { FriendsRepository.pendingFriendCode = it }
            "game" -> uri.getQueryParameter("g")?.takeIf { it.isNotBlank() }?.let { pendingGameID = it }
            // JoinRepository.parse reads the https form (path /join, c + k).
            "join" -> if (!uri.getQueryParameter("c").isNullOrBlank())
                pendingJoinLink = "https://${FriendLink.HOST}/join?${uri.encodedQuery.orEmpty()}"
        }
    }
}

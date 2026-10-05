package com.rani.tofy.kid.ui.social

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.launch

/*
 * ════════════════════════════════════════════════════════════════════════════
 *  Kid SOCIAL + CHORES — the public entry points (port of FriendsViews.swift,
 *  LiveGameViews.swift, ChoresKidView.swift and their managers)
 * ════════════════════════════════════════════════════════════════════════════
 *
 * All of these act as the child bound in KidSession (KidSession.boundChildID)
 * and the signed-in Firebase uid (anonymous on a child device). Each screen is
 * full-bleed, handles system Back, and calls its exit lambda when done.
 *
 *  FriendsScreen(onExit)
 *      LeaderboardView: the 🎮 live-tournament block (invites + "start a game"),
 *      friends / all-players tabs (podium + ranks, my global rank), add a friend
 *      by QR / code (ZXing scanner + my QR; no share sheet — Kids Category 1.3),
 *      the friend-requests inbox, and a friend's mini-profile (send / accept a
 *      request). Starting or joining a tournament opens the live quiz IN PLACE;
 *      leaving the quiz returns home (onExit) like iOS, which dismisses the board.
 *
 *  LiveQuizScreen(gameID, onExit)
 *      gameID == null → the topic pick, then the lobby (host invites friends by
 *      push), countdown, questions, reveals, round breaks, final (rewards land
 *      in KidSession: ⭐ + 💎, each device credits itself once). gameID != null
 *      → join that game (from LiveInviteBanner / a push with data.gameID / a
 *      tofy://game?g=ID link). Leaving mid-match: host → cancelled for all.
 *
 *  KidChoresScreen(onExit)
 *      ChoresKidView: the catalog + family chores, "עשיתי!" with an optional
 *      proof photo (camera or gallery → ≤900 px JPEG 0.55 → photoData Blob),
 *      confirmed write with membership self-heal, waiting / approved states.
 *
 *  LiveInviteBanner(onJoin)
 *      Put it at the TOP of the kid home (overlay). Listens for games I'm
 *      invited to, drops in for 5 s when a new invite arrives; "join" →
 *      onJoin(gameID) → open LiveQuizScreen(gameID). It also keeps my public
 *      friend card's ⭐ live while the home is up (iOS beginScoreSync).
 *
 *  pendingChoresCount(): Int
 *      Chores of the bound child waiting for a parent's approval (the iOS
 *      home chores card's "מחכות" count). Backed by Compose state, so reading
 *      it inside a composable recomposes when it changes; starts the chores
 *      listener on first use. Also: choresDoneTodayCount(), choresTotalCount().
 *
 *  ChildFriendsList(childID, childName, onClose)   — PARENT side
 *      ChildFriendsView: a child's friends with a remove action (bottom sheet).
 *
 *  FriendsRepository.pendingFriendCode = code    — an incoming friend link
 *      (https://tofyapp.com/friend?f=CODE); the board adds it on open.
 */

@Composable
fun FriendsScreen(onExit: () -> Unit) {
    // null = the board; "" = new game (topic pick); else = join that game id.
    var quiz by remember { mutableStateOf<String?>(null) }
    val q = quiz
    if (q == null) LeaderboardScreen(onExit = onExit, onStartGame = { quiz = "" }, onJoinGame = { quiz = it })
    else LiveQuizFlow(gameID = q.ifEmpty { null }, onExit = onExit)
}

@Composable
fun LiveQuizScreen(gameID: String?, onExit: () -> Unit) = LiveQuizFlow(gameID, onExit)

@Composable
fun KidChoresScreen(onExit: () -> Unit) = KidChoresContent(onExit)

@Composable
fun LiveInviteBanner(onJoin: (String) -> Unit) = InviteBanner(onJoin)

/** Chores waiting for a parent's approval (bound child). */
fun pendingChoresCount(): Int {
    KidChoresStore.startIfNeeded()
    val id = SocialMe.id ?: return 0
    return KidChoresStore.choresFor(id).count { it.isPendingApproval }
}

/** Chores approved today (the home card's "%lld הֻשְׁלְמוּ הַיּוֹם! 💪"). */
fun choresDoneTodayCount(): Int {
    KidChoresStore.startIfNeeded()
    val id = SocialMe.id ?: return 0
    return KidChoresStore.choresFor(id).count { it.approvedToday }
}

/** All chores on the child's list (for the home card's progress track). */
fun choresTotalCount(): Int {
    KidChoresStore.startIfNeeded()
    val id = SocialMe.id ?: return 0
    return KidChoresStore.choresFor(id).size
}

/** ChildFriendsView (parent dashboard): see + remove a child's friends. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChildFriendsList(childID: String, childName: String, onClose: () -> Unit) {
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    var friends by remember { mutableStateOf<List<FriendCard>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    suspend fun reload() { loading = true; friends = FriendsRepository.friendsOf(childID); loading = false }
    LaunchedEffect(childID) { FriendsRepository.init(ctx); reload() }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = Ink.sheet) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp).padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("הַחֲבֵרִים שֶׁל %@", childName), Modifier.fillMaxWidth().padding(bottom = 8.dp), color = Color.White,
                fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
            when {
                loading -> Box(Modifier.fillMaxWidth().padding(20.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) }
                friends.isEmpty() -> Text(tr("עֲדַיִן אֵין חֲבֵרִים."), color = Ink.secondary, fontFamily = Rounded, fontSize = 15.sp)
                else -> friends.forEach { f ->
                    FriendListRow(f) {
                        Text(tr("הָסֵר"), Modifier.clickable { scope.launch { FriendsRepository.removeFriend(f.id, forChild = childID); reload() } }
                            .padding(horizontal = 10.dp, vertical = 6.dp), color = Color(0xFFFF9AA0), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    }
                }
            }
        }
    }
}

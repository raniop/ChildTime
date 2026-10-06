package com.rani.tofy.kid.ui.social

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.KidCenterCard
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.ui.settings.QrImage
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * LeaderboardView (FriendsViews.swift): the live tournament block, the
 * friends / all-players tabs, a top-3 podium + ranked rows. Long-press a
 * friend to remove; tap anyone for their mini-profile.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun LeaderboardScreen(onExit: () -> Unit, onStartGame: () -> Unit, onJoinGame: (String) -> Unit) {
    val f = FriendsRepository
    val lg = LiveGameRepository
    val ctx = LocalContext.current
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var showAdd by remember { mutableStateOf(false) }
    var showRequests by remember { mutableStateOf(false) }
    var selected by remember { mutableStateOf<FriendCard?>(null) }
    var toRemove by remember { mutableStateOf<FriendCard?>(null) }
    var global by remember { mutableStateOf(false) }
    val meID = SocialMe.id

    LaunchedEffect(Unit) {
        f.init(ctx); KidSounds.init(ctx)
        f.startLive()   // real-time: new friends + live stars
        f.pendingFriendCode?.let { code -> f.pendingFriendCode = null; f.addFriend(code) }
    }
    DisposableEffect(Unit) {
        lg.startInvitesListener()
        onDispose { f.stopLive(); lg.stopInvitesListener() }
    }
    BackHandler(onBack = onExit)

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            // Header — ✕ on one side, inbox + add on the other (iOS .appMirrored order).
            Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    HeaderCircle("➕") { showAdd = true }
                    HeaderCircle("📥", badge = f.incomingRequests.size) { showRequests = true }
                    Spacer(Modifier.weight(1f))
                    HeaderCircle("✕", onClick = onExit)
                }
                Text(tr("הַחֲבֵרִים"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 26.sp)
                TournamentBlock(lg.invites, onJoin = { haptics.success(); onJoinGame(it) }, onStart = { haptics.light(); onStartGame() })
            }
            // Tabs: my friends vs. everyone in the app.
            Row(Modifier.padding(horizontal = 16.dp).padding(bottom = 8.dp).fillMaxWidth().glassInset(14.dp).padding(4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                TabButton(tr("הַחֲבֵרִים שֶׁלִּי"), !global, Modifier.weight(1f)) { global = false }
                TabButton(tr("כָּל הַשַּׂחְקָנִים"), global, Modifier.weight(1f)) { global = true; scope.launch { f.loadGlobal() } }
            }
            var refreshing by remember { mutableStateOf(false) }
            // "All players" are strangers: show them by an initial only (Families policy) —
            // full first names stay for friends the child actually added.
            val board = if (global) f.globalBoard.map { if (it.id == meID) it else it.copy(name = initialOnly(it.name)) } else f.leaderboard
            when {
                !global && f.leaderboard.size <= 1 -> FriendsEmptyState { showAdd = true }
                global && f.globalBoard.isEmpty() -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) }
                else -> PullToRefreshBox(refreshing, onRefresh = {
                    scope.launch { refreshing = true; if (global) f.loadGlobal() else f.refresh(); refreshing = false }
                }, Modifier.fillMaxSize()) {
                    Column(
                        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 40.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
                    ) {
                        Column(Modifier.widthIn(max = 560.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            if (global) MyRankBanner(f.myGlobalRank)
                            Podium(board, meID, onTap = { haptics.light(); selected = it },
                                onLong = if (global) null else { c -> if (c.id != meID) toRemove = c })
                            board.drop(3).forEachIndexed { i, c ->
                                BoardRow(i + 4, c, c.id == meID, onTap = { haptics.light(); selected = c },
                                    onLong = if (global || c.id == meID) null else { { toRemove = c } })
                            }
                            // Outside the top 100 → my own row at the bottom with my real rank.
                            val rank = f.myGlobalRank
                            if (global && rank != null && meID != null && board.none { it.id == meID }) {
                                Text("• • •", Modifier.align(Alignment.CenterHorizontally), color = Color.White.copy(alpha = 0.45f), fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
                                val me = FriendCard(meID, SocialMe.name.ifEmpty { tr("אֲנִי") }, SocialMe.character3DID, SocialMe.stars, f.myCode)
                                BoardRow(rank, me, true, onTap = { selected = me }, onLong = null)
                            }
                        }
                    }
                }
            }
        }

        // Remove a friend — gentle, always reversible.
        toRemove?.let { c ->
            KidCenterCard(onDismiss = { toRemove = null }) {
                Text(tr("לְהָסִיר חָבֵר?"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 20.sp)
                Text(SocialMe.g(tr("%@ יֵצֵא מִלּוּחַ הַחֲבֵרִים שֶׁלְּךָ. תָּמִיד אֶפְשָׁר לְהוֹסִיף שׁוּב.", c.displayName), tr("%@ יֵצֵא מִלּוּחַ הַחֲבֵרִים שֶׁלָּךְ. תָּמִיד אֶפְשָׁר לְהוֹסִיף שׁוּב.", c.displayName)),
                    color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontSize = 15.sp, textAlign = TextAlign.Center)
                BrushCapsule(tr("הָסִירוּ אֶת %@", c.displayName), SolidColor(Color(0xFFEF4655)), Modifier.fillMaxWidth()) {
                    scope.launch { f.removeFriend(c.id); toRemove = null }
                }
                WhiteCapsule(tr("בִּטּוּל"), Modifier.fillMaxWidth()) { toRemove = null }
            }
        }
        if (showAdd) AddFriendCover { showAdd = false }
        if (showRequests) FriendRequestsCover { showRequests = false }
        selected?.let { c -> FriendProfileSheet(c) { selected = null } }
    }
}

/** 🎮 The live tournament lives inside the friends screen: invites to join + one big "start". */
@Composable
private fun TournamentBlock(invites: List<LiveGameInvite>, onJoin: (String) -> Unit, onStart: () -> Unit) {
    Column(Modifier.fillMaxWidth().widthIn(max = 560.dp).padding(top = 2.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        invites.forEach { inv ->
            Row(
                Modifier.fillMaxWidth().glassPane(18.dp, 0.18f).background(Ink.live.copy(alpha = 0.12f))
                    .clickable { onJoin(inv.id) }.padding(12.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Text("🔔", fontSize = 24.sp)
                Column(Modifier.weight(1f)) {
                    // No verb — we don't know the HOST's gender.
                    Text(tr("הַזְמָנָה לְטוּרְנִיר מֵ%@!", inv.hostName), color = Ink.primary, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp, maxLines = 2)
                    Text(tr("הַמִּשְׂחָק מַתְחִיל עַכְשָׁו — לַחֲצוּ לְהִצְטָרֵף"), color = Ink.secondary, fontFamily = Rounded,
                        fontWeight = FontWeight.SemiBold, fontSize = 12.sp, maxLines = 2)
                }
                Text(tr("הִצְטָרְפוּ"), Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.92f))
                    .padding(horizontal = 12.dp, vertical = 8.dp),
                    color = SocialColor.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, maxLines = 1)
            }
        }
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(22.dp))
                .background(Brush.horizontalGradient(listOf(Color(0xFFEF476F).copy(alpha = 0.55f), Color(0xFF9B5DE5).copy(alpha = 0.55f))))
                .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(22.dp))
                .clickable(onClick = onStart).padding(12.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text("🎮", fontSize = 26.sp)
            Column(Modifier.weight(1f)) {
                Text(tr("טוּרְנִיר חַי עִם חֲבֵרִים"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, maxLines = 2)
                Text(tr("מַזְמִינִים, כֻּלָּם עוֹנִים בְּאוֹתוֹ זְמַן — מִי הֲכִי מָהִיר?"), color = Ink.secondary, fontFamily = Rounded,
                    fontWeight = FontWeight.SemiBold, fontSize = 12.sp, maxLines = 2)
            }
            Text(if (LocalLayoutDirection.current == LayoutDirection.Rtl) "‹" else "›", color = Color.White, fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun TabButton(title: String, active: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(11.dp)).background(if (active) Color.White.copy(alpha = 0.92f) else Color.Transparent)
            .clickable(onClick = onClick).padding(vertical = 9.dp),
        contentAlignment = Alignment.Center,
    ) { Text(title, color = if (active) SocialColor.indigo else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1) }
}

/** My place among ALL players — always positive, never failure language. */
@Composable
private fun MyRankBanner(rank: Int?) {
    rank ?: return
    Column(
        Modifier.fillMaxWidth().padding(top = 8.dp).glassPane(22.dp).background(SocialColor.starGold.copy(alpha = 0.14f)).padding(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(SocialMe.g(tr("הַמָּקוֹם שֶׁלְּךָ בְּכָל הָעוֹלָם"), tr("הַמָּקוֹם שֶׁלָּךְ בְּכָל הָעוֹלָם")), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        Text("#${"%,d".format(rank)}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 34.sp)
        Text(SocialMe.g(tr("כָּל כּוֹכָב מְקַדֵּם אוֹתְךָ לְמַעְלָה! ⭐"), tr("כָּל כּוֹכָב מְקַדֵּם אוֹתָךְ לְמַעְלָה! ⭐")), color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp)
    }
}

/** Top 3: #1 center & tallest (order 2·1·3 in the layout direction, like the iOS HStack). */
@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun Podium(board: List<FriendCard>, meID: String?, onTap: (FriendCard) -> Unit, onLong: ((FriendCard) -> Unit)?) {
    val top = board.take(3)
    val ordered = buildList {
        if (top.size > 1) add(2 to top[1])
        if (top.isNotEmpty()) add(1 to top[0])
        if (top.size > 2) add(3 to top[2])
    }
    Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        ordered.forEach { (rank, card) ->
            val isMe = card.id == meID
            Column(
                Modifier.weight(1f).combinedClickable(onClick = { onTap(card) }, onLongClick = onLong?.let { { it(card) } }),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                if (rank == 1) Text("👑", fontSize = 26.sp)
                Portrait(card.character3DID, if (rank == 1) 96.dp else 76.dp, glow = isMe)
                Text(card.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1)
                StarsPill(card.stars)
                // Glass steps — gold glows through the winner's, softer for 2 and 3.
                Box(
                    Modifier.fillMaxWidth().height(if (rank == 1) 96.dp else if (rank == 2) 70.dp else 54.dp)
                        .clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.14f))
                        .background(Brush.verticalGradient(listOf(SocialColor.starGold.copy(alpha = if (rank == 1) 0.55f else 0.25f), Color.Transparent)))
                        .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(14.dp)),
                    contentAlignment = Alignment.TopCenter,
                ) { Text(if (rank == 1) "🥇" else if (rank == 2) "🥈" else "🥉", Modifier.padding(top = 6.dp), fontSize = 26.sp) }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BoardRow(rank: Int, card: FriendCard, isMe: Boolean, onTap: () -> Unit, onLong: (() -> Unit)?) {
    Row(
        Modifier.fillMaxWidth().glassPane(20.dp)
            .then(if (isMe) Modifier.background(SocialColor.starGold.copy(alpha = 0.16f)).border(1.5.dp, SocialColor.starGold.copy(alpha = 0.8f), RoundedCornerShape(20.dp)) else Modifier)
            .combinedClickable(onClick = onTap, onLongClick = onLong).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("$rank", Modifier.width(28.dp), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center)
        Portrait(card.character3DID, 46.dp)
        Text(card.displayName, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, maxLines = 1)
        StarsPill(card.stars)
    }
}

@Composable
private fun FriendsEmptyState(onAdd: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
        Text("🏆", fontSize = 72.sp)
        Text(tr("עוֹד אֵין חֲבֵרִים"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
        Text(tr("הוֹסִיפוּ אֶת הֶחָבֵר הָרִאשׁוֹן וְתִרְאוּ מִי אָסַף הֲכִי הַרְבֵּה כּוֹכָבִים!"), color = Color.White.copy(alpha = 0.8f),
            fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.sp, textAlign = TextAlign.Center)
        WhiteCapsule("➕ " + tr("הוֹסִיפוּ חָבֵר"), Modifier.padding(top = 6.dp), onClick = onAdd)
        Spacer(Modifier.height(80.dp))
    }
}

// MARK: - Add friend

/** AddFriendView: my QR + code, scan a friend, or type their code. No share button (Kids Category 1.3). */
@Composable
private fun AddFriendCover(onClose: () -> Unit) {
    val f = FriendsRepository
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var scanner by remember { mutableStateOf(false) }
    var typed by remember { mutableStateOf("") }
    var message by remember { mutableStateOf<String?>(null) }
    var added by remember { mutableStateOf(false) }
    var celebrate by remember { mutableStateOf<FriendCard?>(null) }
    var confetti by remember { mutableIntStateOf(0) }
    var known by remember { mutableStateOf(f.leaderboard.map { it.id }.toSet()) }

    fun celebrateThenClose(card: FriendCard?) {
        added = true; message = tr("הִתְחַבַּרְתֶּם! 🎉")
        haptics.success(); KidSounds.play(AppSound.CHEST_OPEN)
        celebrate = card; confetti++
        scope.launch { delay(2000); onClose() }
    }
    fun add(raw: String) {
        scope.launch {
            val ok = f.addFriend(raw)
            if (ok) { typed = ""; known = known + (f.lastAddedFriend?.id ?: ""); celebrateThenClose(f.lastAddedFriend) }
            else { added = false; message = f.lastError ?: tr("לֹא הִצְלַחְנוּ"); haptics.warning() }
        }
    }

    // Live so the inbound listener fires the instant someone scans MY code → celebrate + close here too.
    LaunchedEffect(Unit) { f.startLive() }
    DisposableEffect(Unit) { onDispose { f.stopLive() } }
    LaunchedEffect(f.leaderboard.map { it.id }) {
        val ids = f.leaderboard.map { it.id }.toSet()
        val fresh = ids - known
        known = ids
        val newID = fresh.firstOrNull { it != SocialMe.id } ?: return@LaunchedEffect
        if (celebrate != null) return@LaunchedEffect
        celebrateThenClose(f.leaderboard.firstOrNull { it.id == newID })
    }
    BackHandler(onBack = onClose)

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                Text(tr("הוֹסָפַת חָבֵר"), Modifier.align(Alignment.Center), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
                Box(Modifier.align(Alignment.CenterStart)) { HeaderCircle("✕", onClick = onClose) }
            }
            Column(
                Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Column(Modifier.widthIn(max = 460.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    // My code — always LTR (a Latin code + QR).
                    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                        Column(
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Color.White.copy(alpha = 0.10f)).padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            Text(tr("הַקּוֹד שֶׁלִּי"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                            if (f.myCode.isNotEmpty()) {
                                QrImage(FriendLink.url(f.myCode), 170.dp)
                                Text(f.myCode, color = Color.White, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.ExtraBold, fontSize = 28.sp, letterSpacing = 5.sp)
                            } else CircularProgressIndicator(color = Color.White)
                            Text(tr("חֲבֵרִים סוֹרְקִים אֶת הַקּוֹד אוֹ פּוֹתְחִים אֶת הַקִּישּׁוּר — וְאַתֶּם מְחוּבָּרִים!"), color = Color.White.copy(alpha = 0.7f),
                                fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp, textAlign = TextAlign.Center)
                        }
                    }
                    Column(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Color.White.copy(alpha = 0.10f)).padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        BrushCapsule("📷 " + tr("סִרְקוּ חָבֵר"), SocialColor.purpleDream, Modifier.fillMaxWidth()) { scanner = true }
                        Text(tr("אוֹ הַקְלִידוּ קוֹד שֶׁל חָבֵר"), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp)
                        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.12f)).padding(vertical = 12.dp),
                                contentAlignment = Alignment.Center) {
                                if (typed.isEmpty()) Text(tr("קוֹד"), color = Color.White.copy(alpha = 0.5f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp)
                                BasicTextField(
                                    typed, { typed = it.uppercase().filter { ch -> ch.isLetterOrDigit() && ch.code < 128 }.take(12) },
                                    Modifier.fillMaxWidth(), singleLine = true,
                                    textStyle = TextStyle(color = Color.White, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.ExtraBold,
                                        fontSize = 24.sp, letterSpacing = 5.sp, textAlign = TextAlign.Center),
                                    cursorBrush = SolidColor(Color.White),
                                    // Latin code even on a Hebrew keyboard (ChildJoinView's .asciiCapable).
                                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters, autoCorrectEnabled = false, keyboardType = KeyboardType.Ascii),
                                )
                            }
                        }
                        val ready = typed.trim().length >= 4
                        BrushCapsule(tr("הוֹסִיפוּ"), SocialColor.gold, Modifier.fillMaxWidth(), enabled = ready) { add(typed) }
                    }
                    message?.let {
                        Text(it, Modifier.fillMaxWidth(), color = if (added) SocialColor.successMint else SocialColor.almostWarm,
                            fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, textAlign = TextAlign.Center)
                    }
                }
            }
        }
        FriendCelebration(celebrate)
        ConfettiOverlay(confetti)
        if (scanner) FriendQrScanner(tr("סְרִיקַת חָבֵר"), onScanned = { scanner = false; add(it) }, onCancel = { scanner = false })
    }
}

// MARK: - Friend profile

/** FriendProfileView: the public card + a friend-request action (or a one-tap accept if they asked first). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FriendProfileSheet(card: FriendCard, onClose: () -> Unit) {
    val f = FriendsRepository
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var sending by remember { mutableStateOf(false) }
    var sent by remember { mutableStateOf(false) }
    val isMe = card.id == SocialMe.id
    val incoming = f.incomingRequests.firstOrNull { it.fromID == card.id }
    LaunchedEffect(card.id) { sent = f.hasOutgoingRequest(card.id) }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = Ink.sheet, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Portrait(card.character3DID, 140.dp, glow = true)
            Text(card.displayName.ifEmpty { tr("שַׂחְקָן") }, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 32.sp)
            Text("⭐ " + tr("%lld כּוֹכָבִים", card.stars), Modifier.clip(RoundedCornerShape(50)).background(SocialColor.gold).padding(horizontal = 18.dp, vertical = 9.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            Box(Modifier.fillMaxWidth().padding(top = 8.dp), contentAlignment = Alignment.Center) {
                when {
                    isMe -> Text("👤 " + SocialMe.g(tr("זֶה אַתָּה 🙂"), tr("זוֹ אַתְּ 🙂")), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                    f.isFriend(card.id) -> Text("✅ " + SocialMe.g(tr("חָבֵר שֶׁלְּךָ"), tr("חָבֵר שֶׁלָּךְ")), color = SocialColor.successMint, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                    incoming != null -> BrushCapsule("✓ " + tr("אַשְּׁרוּ בַּקָּשַׁת חֲבֵרוּת"), SocialColor.gold, Modifier.fillMaxWidth(), size = 18) {
                        scope.launch { f.acceptRequest(incoming); haptics.success(); onClose() }
                    }
                    sent -> Text("📨 " + tr("בַּקָּשָׁה נִשְׁלְחָה ⏳"), Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.12f)).padding(vertical = 14.dp),
                        color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center)
                    else -> BrushCapsule("➕ " + tr("שִׁלְחוּ בַּקָּשַׁת חֲבֵרוּת"), SocialColor.purpleDream, Modifier.fillMaxWidth(), size = 18, busy = sending) {
                        sending = true
                        scope.launch {
                            val ok = f.sendRequest(card)
                            sending = false
                            if (ok) { sent = true; haptics.success() } else haptics.warning()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Requests inbox

/** FriendRequestsView: who asked (character, name, ⭐) with accept / "not now" — declining tells no one. */
@Composable
private fun FriendRequestsCover(onClose: () -> Unit) {
    val f = FriendsRepository
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var celebrate by remember { mutableStateOf<FriendCard?>(null) }
    var confetti by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { f.startLive() }
    DisposableEffect(Unit) { onDispose { f.stopLive() } }
    BackHandler(onBack = onClose)

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                Text(tr("בַּקָּשׁוֹת חֲבֵרוּת"), Modifier.align(Alignment.Center), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
                Box(Modifier.align(Alignment.CenterStart)) { HeaderCircle("✕", onClick = onClose) }
            }
            if (f.incomingRequests.isEmpty()) {
                Column(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
                    Text("📭", fontSize = 64.sp)
                    Text(tr("אֵין בַּקָּשׁוֹת חֲדָשׁוֹת"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                    Text(SocialMe.g(tr("כְּשֶׁמִּישֶׁהוּ יְבַקֵּשׁ לִהְיוֹת חָבֵר שֶׁלְּךָ — זֶה יוֹפִיעַ כָּאן."), tr("כְּשֶׁמִּישֶׁהוּ יְבַקֵּשׁ לִהְיוֹת חָבֵר שֶׁלָּךְ — זֶה יוֹפִיעַ כָּאן.")), color = Color.White.copy(alpha = 0.8f),
                        fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 14.sp, textAlign = TextAlign.Center)
                    Spacer(Modifier.height(80.dp))
                }
            } else {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally) {
                    Column(Modifier.widthIn(max = 460.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        f.incomingRequests.forEach { req ->
                            Row(
                                Modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Color.White.copy(alpha = 0.10f))
                                    .padding(horizontal = 14.dp, vertical = 10.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
                            ) {
                                Portrait(req.character3DID, 54.dp)
                                Column(Modifier.weight(1f)) {
                                    Text(req.displayName.ifEmpty { tr("שַׂחְקָן") }, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, maxLines = 1)
                                    Text("${req.stars} ⭐", color = Color.White.copy(alpha = 0.75f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                                }
                                Text(tr("לֹא עַכְשָׁו"), Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.12f))
                                    .clickable { haptics.light(); scope.launch { f.declineRequest(req) } }.padding(horizontal = 12.dp, vertical = 9.dp),
                                    color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, maxLines = 1)
                                Text("✓ " + tr("אַשְּׁרוּ"), Modifier.clip(RoundedCornerShape(50)).background(SocialColor.gold)
                                    .clickable {
                                        scope.launch {
                                            f.acceptRequest(req)
                                            haptics.success(); KidSounds.play(AppSound.CHEST_OPEN)
                                            celebrate = FriendCard(req.fromID, req.displayName, req.character3DID, req.stars, "")
                                            confetti++
                                            delay(1600)
                                            celebrate = null
                                            if (f.incomingRequests.isEmpty()) onClose()
                                        }
                                    }.padding(horizontal = 14.dp, vertical = 9.dp),
                                    color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 14.sp, maxLines = 1)
                            }
                        }
                    }
                }
            }
        }
        FriendCelebration(celebrate)
        ConfettiOverlay(confetti)
    }
}

/** ChildFriendsView's row look, reused by the parent-visible list in [ChildFriendsList]. */
@Composable
internal fun FriendListRow(card: FriendCard, trailing: @Composable () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.size(40.dp).clip(androidx.compose.foundation.shape.CircleShape)) { CharacterImage(card.character3DID ?: "fox", Modifier.size(40.dp)) }
        Text(card.displayName, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        Text("${card.stars} ⭐", color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
        trailing()
    }
}

/** "דָּנָה" → "ד׳" — the first letter, niqqud dropped, with a geresh. */
internal fun initialOnly(name: String): String {
    val first = name.replace(Regex("[\u0591-\u05C7]"), "").trim().firstOrNull() ?: return "?"
    return if (first in '\u05D0'..'\u05EA') "$first׳" else "$first."
}

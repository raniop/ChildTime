package com.rani.tofy.kid.ui.social

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ContentAvailability
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.KidCenterCard
import com.rani.tofy.kid.ui.home.allWorlds
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.ceil

/** Leaving must finish even after the screen is gone (iOS `.onDisappear { leaveGame }`). */
private val leaveScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

/**
 * LiveGameFlowView: ONE full-screen flow — the topic pick until a game exists
 * (or joining [gameID]), then the lobby / game itself. Play again → back to the
 * topic pick; every other way out leaves the game and calls [onExit].
 */
@Composable
internal fun LiveQuizFlow(gameID: String?, onExit: () -> Unit) {
    val lg = LiveGameRepository
    val ctx = LocalContext.current
    var settingUp by remember { mutableStateOf(gameID == null) }
    var joining by remember { mutableStateOf(gameID != null) }
    var hadGame by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        KidSounds.init(ctx); FriendsRepository.init(ctx)
        lg.lastError = null
        if (gameID != null) { lg.joinGame(gameID); joining = false }
    }
    DisposableEffect(Unit) { onDispose { leaveScope.launch { lg.leaveGame() } } }
    // The game went away (we left it) → close the flow, unless "play again" reopened the topic pick.
    LaunchedEffect(lg.game == null) {
        if (lg.game != null) hadGame = true
        else if (hadGame && !settingUp) onExit()
    }
    val exit: () -> Unit = { leaveScope.launch { lg.leaveGame(); onExit() } }

    when {
        lg.game != null -> LiveGameView(onExit = exit, onPlayAgain = { settingUp = true; hadGame = false; leaveScope.launch { lg.leaveGame() } })
        settingUp -> LiveGameSetup(onClose = onExit)
        joining -> GlassBackdrop { Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) } }
        // Couldn't join (already started / another language) — gentle, never "failed".
        else -> GlassBackdrop {
            BackHandler(onBack = onExit)
            EndedView(lg.lastError ?: tr("הַמִּשְׂחָק הִסְתַּיֵּם 🎈"), tr("תָּמִיד אֶפְשָׁר לְהַתְחִיל מִשְׂחָק חָדָשׁ!"), onExit)
        }
    }
}

// MARK: - Setup

/** LiveGameSetupSheet: ONE decision — tap a topic and the game starts at the child's own level. */
@Composable
private fun LiveGameSetup(onClose: () -> Unit) {
    val lg = LiveGameRepository
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var creating by remember { mutableStateOf(false) }
    val lang = I18n.language
    // No reading: the live game syncs prompt+options only, so a passage question would arrive without its passage.
    val topics = remember(lang) { Topic.core.filter { it != Topic.READING && ContentAvailability.hasContent(it, lang) } }
    val worlds = remember(lang) { allWorlds() }
    BackHandler(onBack = onClose)

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Text(tr("בְּמָה מְשַׂחֲקִים? 🎮"), Modifier.padding(horizontal = 60.dp).padding(top = 40.dp), color = Ink.primary,
                fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 26.sp, maxLines = 1, textAlign = TextAlign.Center)
            Text(tr("בַּחֲרוּ נוֹשֵׂא וְהַמִּשְׂחָק מַתְחִיל!"), Modifier.padding(top = 8.dp), color = Color.White.copy(alpha = 0.85f),
                fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            Column(Modifier.weight(1f).widthIn(max = 520.dp).verticalScroll(rememberScrollState()).padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(14.dp)) {
                topics.chunked(2).forEach { pair ->
                    Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        pair.forEach { t ->
                            val glow = worlds.firstOrNull { it.topic == t }?.glow
                            Column(
                                Modifier.weight(1f).height(130.dp).glassPane(16.dp)
                                    .then(if (glow != null) Modifier.background(glow.copy(alpha = 0.16f)) else Modifier)
                                    .clickable(enabled = !creating) {
                                        haptics.medium(); KidSounds.play(AppSound.UI_TAP)
                                        creating = true
                                        scope.launch {
                                            val raw = KidSession.engine()?.settings?.difficulty(t.raw)?.raw
                                            lg.createGame(t, Difficulty.of(raw) ?: Difficulty.EASY)
                                            creating = false
                                        }
                                    },
                                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterVertically),
                            ) {
                                Text(t.emoji, fontSize = 52.sp)
                                Text(t.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, maxLines = 1)
                            }
                        }
                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }
            val err = lg.lastError
            if (err != null && !creating) Text(err, Modifier.padding(bottom = 8.dp, start = 16.dp, end = 16.dp), color = SocialColor.almostWarm,
                fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp, textAlign = TextAlign.Center)
        }
        Box(Modifier.systemBarsPadding().padding(16.dp)) { HeaderCircle("✕", onClick = onClose) }
        if (creating) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)), contentAlignment = Alignment.Center) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("🚀", fontSize = 52.sp)
                Text(tr("מְכִינִים אֶת הַמִּשְׂחָק…"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            }
        }
    }
}

// MARK: - Game

private val answerColors = listOf(Color(0xFFF25C54), Color(0xFF4CC9F0), Color(0xFF06D6A0), Color(0xFF9B5DE5))

/** LiveGameView: switches on the state — lobby → countdown → question → reveal → round break → final. */
@Composable
private fun LiveGameView(onExit: () -> Unit, onPlayAgain: () -> Unit) {
    val lg = LiveGameRepository
    val g = lg.game ?: return
    val meID = SocialMe.id
    val amHost = g.hostID == meID
    var showQuit by remember { mutableStateOf(false) }
    var peek by remember { mutableStateOf<LiveGamePlayer?>(null) }
    var confetti by remember { mutableIntStateOf(0) }
    val live = g.state in setOf(LiveGameState.COUNTDOWN, LiveGameState.QUESTION, LiveGameState.REVEAL, LiveGameState.ROUND_BREAK)
    BackHandler { if (live) showQuit = true else onExit() }

    GlassBackdrop {
        Box(Modifier.fillMaxSize().systemBarsPadding()) {
            when (g.state) {
                LiveGameState.LOBBY -> Lobby(g, meID, onExit) { peek = it }
                LiveGameState.COUNTDOWN -> Countdown()
                LiveGameState.QUESTION -> QuestionView(g, meID)
                LiveGameState.REVEAL -> RevealView(g, meID) { peek = it }
                LiveGameState.ROUND_BREAK -> RoundBreakView(g, meID) { peek = it }
                LiveGameState.FINAL -> FinalView(g, meID, onExit, onPlayAgain, onCelebrate = { confetti++ }) { peek = it }
                LiveGameState.CANCELLED -> EndedView(tr("הַמִּשְׂחָק הִסְתַּיֵּם 🎈"), tr("תָּמִיד אֶפְשָׁר לְהַתְחִיל מִשְׂחָק חָדָשׁ!"), onExit)
            }
            // A persistent "leave" during live play, so anyone can bow out mid-match.
            if (live) Box(Modifier.padding(16.dp)) {
                Box(Modifier.size(48.dp).clip(CircleShape).background(Color.Black.copy(alpha = 0.3f)).border(1.dp, Color.White.copy(alpha = 0.25f), CircleShape)
                    .clickable { showQuit = true }, contentAlignment = Alignment.Center) { Text("✕", color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold) }
            }
        }
        ConfettiOverlay(confetti)
        if (showQuit) KidCenterCard(onDismiss = { showQuit = false }) {
            Text(tr("לָצֵאת מֵהַמִּשְׂחָק?"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 20.sp)
            Text(if (amHost) SocialMe.g(tr("אַתָּה הַמַּנְהִיג — הַמִּשְׂחָק יִסְתַּיֵּם לְכָל הַחֲבֵרִים."), tr("אַתְּ הַמַּנְהִיגָה — הַמִּשְׂחָק יִסְתַּיֵּם לְכָל הַחֲבֵרִים.")) else tr("אֶפְשָׁר תָּמִיד לְהִצְטָרֵף לְמִשְׂחָק חָדָשׁ אַחַר כָּךְ."),
                color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontSize = 15.sp, textAlign = TextAlign.Center)
            BrushCapsule(if (amHost) tr("כֵּן, לְסַיֵּם לְכוּלָּם") else tr("כֵּן, לָצֵאת"), androidx.compose.ui.graphics.SolidColor(Color(0xFFEF4655)), Modifier.fillMaxWidth()) {
                showQuit = false; onExit()
            }
            WhiteCapsule(tr("נִשְׁאָרִים בַּמִּשְׂחָק"), Modifier.fillMaxWidth()) { showQuit = false }
        }
        peek?.let { PlayerPeekSheet(it) { peek = null } }
    }
}

@Composable
private fun BoxScope.CloseButton(onClick: () -> Unit) {
    Box(Modifier.align(Alignment.TopStart).padding(16.dp)) { HeaderCircle("✕", onClick = onClick) }
}

@Composable
private fun Lobby(g: LiveGame, meID: String?, onExit: () -> Unit, onPeek: (LiveGamePlayer) -> Unit) {
    val lg = LiveGameRepository
    val isHost = g.hostID == meID
    val canStart = lg.players.size >= LiveGameRules.MIN_PLAYERS
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var nudged by remember { mutableStateOf(setOf<String>()) }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(top = 64.dp, bottom = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text("🎮", fontSize = 56.sp)
            Text(if (isHost) tr("מִי מִצְטָרֵף?") else tr("מִשְׂחָק חָדָשׁ שֶׁל %@!", g.hostName), Modifier.padding(horizontal = 16.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp, textAlign = TextAlign.Center)
            Text(tr("%@ %@ · הַטּוֹב מִ-%lld סִבּוּבִים", g.topicEmoji, g.topicName, g.totalRounds), color = Color.White.copy(alpha = 0.85f),
                fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp, textAlign = TextAlign.Center)
            // Players — tap for a peek.
            Column(Modifier.weight(1f).widthIn(max = 560.dp).verticalScroll(rememberScrollState()).padding(16.dp)) {
                BoxWithConstraints(Modifier.fillMaxWidth()) {
                    val cols = maxOf(1, (maxWidth / 106.dp).toInt())
                    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
                        lg.players.chunked(cols).forEach { row ->
                            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                                row.forEach { p ->
                                    Column(Modifier.weight(1f).clickable { haptics.light(); onPeek(p) }.padding(top = 8.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                        Portrait(p.character3DID, 64.dp, glow = p.id == meID)
                                        Text(p.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, maxLines = 1)
                                    }
                                }
                                repeat(cols - row.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                }
                // The host's friends with join status + a direct push invite.
                val joined = lg.players.map { it.id }.toSet()
                val friends = FriendsRepository.leaderboard.filter { it.id != meID }
                if (isHost && friends.isNotEmpty()) {
                    Text(tr("הַחֲבֵרִים שֶׁלִּי"), Modifier.fillMaxWidth().padding(top = 18.dp, bottom = 8.dp), color = Color.White.copy(alpha = 0.85f),
                        fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        friends.forEach { f ->
                            Row(Modifier.fillMaxWidth().glassInset(16.dp).padding(horizontal = 14.dp, vertical = 6.dp),
                                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                Portrait(f.character3DID, 36.dp)
                                Text(f.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
                                if (f.id in joined) {
                                    Text("✅ " + tr("הִצְטָרֵף"), color = SocialColor.successMint, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                                } else {
                                    val sent = f.id in nudged
                                    Text((if (sent) "📨 " else "🔔 ") + (if (sent) tr("נִשְׁלַח") else tr("הַזְמִינוּ")),
                                        Modifier.clip(RoundedCornerShape(16.dp)).background(if (sent) SocialColor.successMint.copy(alpha = 0.6f) else SocialColor.gemPurple)
                                            .clickable(enabled = !sent) { haptics.light(); nudged = nudged + f.id; scope.launch { lg.invite(f.id) } }
                                            .padding(horizontal = 12.dp, vertical = 6.dp),
                                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                                }
                            }
                        }
                    }
                }
            }
            if (isHost) {
                // NO share button: a share sheet leaves the app (Kids Category 1.3) — invites go in-app above.
                Box(Modifier.padding(horizontal = 24.dp).fillMaxWidth().widthIn(max = 520.dp).clip(RoundedCornerShape(16.dp))
                    .background(Brush.horizontalGradient(listOf(Color(0xFF5E60CE), Color(0xFF3E8BF0))))
                    .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
                    .clickable(enabled = canStart) { lg.startGame() }.padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
                    Text(if (canStart) tr("מַתְחִילִים! 🚀") else tr("מְחַכִּים לְעוֹד שַׂחְקָן אֶחָד לְפָחוֹת…"),
                        color = Color.White.copy(alpha = if (canStart) 1f else 0.55f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp, textAlign = TextAlign.Center)
                }
            } else {
                Text(tr("מְחַכִּים שֶׁ%@ יַתְחִיל… ⏳", g.hostName), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded,
                    fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            }
        }
        CloseButton(onExit)
    }
}

@Composable
private fun Countdown() {
    var value by remember { mutableIntStateOf(LiveGameRules.COUNTDOWN_SECONDS) }
    LaunchedEffect(Unit) { while (value > 0) { delay(1000); value-- } }
    val s by animateFloatAsState(if (value % 2 == 0) 1f else 1.08f, label = "cd")
    Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically)) {
        Text(if (value > 0) "$value" else "🚀", Modifier.scale(s), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 120.sp)
        Text(tr("מִתְכּוֹנְנִים…"), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
    }
}

@Composable
private fun QuestionView(g: LiveGame, meID: String?) {
    val lg = LiveGameRepository
    val q = g.currentQuestion
    val scope = rememberCoroutineScope()
    val haptics = KidHaptics(LocalView.current)
    Column(Modifier.fillMaxSize().padding(bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Column(Modifier.widthIn(max = 680.dp).fillMaxSize(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 64.dp), verticalAlignment = Alignment.CenterVertically) {
                TimerRing(g)
                Spacer(Modifier.weight(1f))
                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Pill(tr("סִבּוּב %lld/%lld", g.currentRound + 1, g.totalRounds), SocialColor.starGold, 17)
                    Pill(tr("שְׁאֵלָה %lld/%lld", g.questionInRound + 1, g.roundQuestions), Color.White.copy(alpha = 0.9f), 16)
                }
            }
            HeadToHead(lg.players, meID)
            Spacer(Modifier.weight(1f))
            Text(q?.prompt ?: "", Modifier.padding(horizontal = 16.dp).fillMaxWidth().glassPane(16.dp).padding(horizontal = 26.dp, vertical = 40.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp, textAlign = TextAlign.Center, lineHeight = 42.sp)
            Spacer(Modifier.weight(1f))
            val answered = lg.myChoiceIndex != null
            (q?.options ?: emptyList()).withIndex().chunked(2).forEach { pair ->
                Row(Modifier.padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    pair.forEach { (idx, text) ->
                        val mine = lg.myChoiceIndex == idx
                        val color = answerColors[idx % answerColors.size]
                        val scale by animateFloatAsState(if (mine) 1.04f else 1f, label = "ans")
                        Box(
                            Modifier.weight(1f).heightIn(min = 118.dp).scale(scale).clip(RoundedCornerShape(16.dp))
                                .background(Color.White.copy(alpha = 0.14f)).background(color.copy(alpha = if (answered && !mine) 0.15f else 0.5f))
                                .border(if (mine) 3.dp else 1.dp, Color.White.copy(alpha = if (mine) 1f else 0.4f), RoundedCornerShape(16.dp))
                                .clickable(enabled = !answered) { haptics.light(); scope.launch { lg.submitAnswer(idx) } }.padding(horizontal = 12.dp),
                            contentAlignment = Alignment.Center,
                        ) { Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 26.sp, maxLines = 2, textAlign = TextAlign.Center) }
                    }
                    if (pair.size == 1) Spacer(Modifier.weight(1f))
                }
            }
            if (answered) Text("✅ " + SocialMe.g(tr("עָנִיתָ! מְחַכִּים לַשְּׁאָר…"), tr("עָנִית! מְחַכִּים לַשְּׁאָר…")), Modifier.fillMaxWidth().padding(top = 6.dp), color = SocialColor.starGold,
                fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun Pill(text: String, color: Color, size: Int) {
    Text(text, Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f)).border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
        .padding(horizontal = 14.dp, vertical = 6.dp), color = color, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = size.sp)
}

/** The big countdown ring — mint, turning warm under 30 %. */
@Composable
private fun TimerRing(g: LiveGame) {
    var now by remember { mutableLongStateOf(System.currentTimeMillis()) }
    LaunchedEffect(g.currentIndex) { while (true) { now = System.currentTimeMillis(); delay(100) } }
    val total = g.questionDurationMs / 1000.0
    val elapsed = g.questionStartedAt?.let { maxOf(0.0, now / 1000.0 - it) } ?: 0.0
    val remaining = maxOf(0.0, total - elapsed)
    val frac = if (total > 0) (remaining / total).toFloat() else 0f
    val tint = if (frac > 0.3f) SocialColor.successMint else SocialColor.almostWarm
    Box(Modifier.size(72.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.fillMaxSize().padding(4.dp)) {
            drawCircle(Color.White.copy(alpha = 0.18f), style = Stroke(8.dp.toPx()))
            drawArc(tint, -90f, 360f * frac, false, Offset.Zero, Size(size.width, size.height), style = Stroke(8.dp.toPx(), cap = StrokeCap.Round))
        }
        Text("${ceil(remaining).toInt()}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 28.sp)
    }
}

/** The live "כמה–כמה": a VS for a duel, a chip row for 3+. Display-only mid-play. */
@Composable
private fun HeadToHead(ps: List<LiveGamePlayer>, meID: String?) {
    if (ps.size == 2) {
        // Me on the start side (RTL: right) when I'm playing.
        val ordered = if (ps.any { it.id == meID }) ps.sortedByDescending { if (it.id == meID) 1 else 0 } else ps
        val a = ordered[0]; val b = ordered[1]
        Row(Modifier.padding(horizontal = 16.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).padding(vertical = 10.dp, horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            VsSide(a, meID, Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("${a.roundWins} — ${b.roundWins}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 30.sp)
                Text(tr("🏆 סִבּוּבִים"), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 10.sp)
            }
            VsSide(b, meID, Modifier.weight(1f))
        }
    } else if (ps.size > 2) {
        Row(Modifier.padding(horizontal = 16.dp).horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ps.forEach { p ->
                Row(Modifier.clip(RoundedCornerShape(16.dp)).background(if (p.id == meID) SocialColor.starGold.copy(alpha = 0.22f) else Color.White.copy(alpha = 0.10f))
                    .padding(horizontal = 10.dp, vertical = 6.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Portrait(p.character3DID, 30.dp)
                    Column {
                        Text(p.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp, maxLines = 1)
                        Text("🏆${p.roundWins} · ${p.score}", color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 11.sp)
                    }
                }
            }
        }
    }
}

@Composable
private fun VsSide(p: LiveGamePlayer, meID: String?, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp)) {
        Portrait(p.character3DID, 50.dp, glow = p.id == meID)
        Text(p.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, maxLines = 1)
        Text("${p.score}", color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp)
    }
}

@Composable
private fun RevealView(g: LiveGame, meID: String?, onPeek: (LiveGamePlayer) -> Unit) {
    val lg = LiveGameRepository
    val correct = g.revealCorrectIndex
    val mine = lg.myChoiceIndex
    val gotIt = mine != null && mine == correct
    val haptics = KidHaptics(LocalView.current)
    // Celebrate a right answer; otherwise stay gentle (no "wrong" sound).
    LaunchedEffect(g.currentIndex) { if (gotIt) { KidSounds.play(AppSound.CORRECT_BIG); haptics.success() } else haptics.soft() }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(top = 72.dp, bottom = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text(if (gotIt) tr("נֶהֱדָר! 🎉") else if (mine == null) tr("הַשְּׁאֵלָה הַבָּאָה תַּגִּיעַ 💫") else tr("כִּמְעַט! 🌟"),
            color = if (gotIt) SocialColor.successMint else Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp, textAlign = TextAlign.Center)
        Column(Modifier.widthIn(max = 600.dp).padding(horizontal = 16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            (g.currentQuestion?.options ?: emptyList()).forEachIndexed { idx, text ->
                val isCorrect = idx == correct; val isMine = idx == mine
                Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
                    .background(if (isCorrect) SocialColor.successMint.copy(alpha = 0.9f) else if (isMine) SocialColor.almostWarm.copy(alpha = 0.5f) else Color.White.copy(alpha = 0.10f))
                    .padding(horizontal = 18.dp, vertical = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(text, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, maxLines = 2)
                    if (isCorrect) Text("✓", color = Color.White, fontSize = 26.sp, fontWeight = FontWeight.Black)
                    else if (isMine) Text(SocialMe.g(tr("בָּחַרְתָּ"), tr("בָּחַרְתְּ")), color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp, fontWeight = FontWeight.Bold, fontFamily = Rounded)
                }
            }
        }
        // Compact standings between questions.
        Column(Modifier.widthIn(max = 560.dp).padding(horizontal = 16.dp).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Text(tr("הַנִּקּוּד"), color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
            lg.players.take(6).forEachIndexed { i, p ->
                Row(Modifier.fillMaxWidth().glassPane(16.dp, 0.10f).then(if (p.id == meID) Modifier.background(SocialColor.starGold.copy(alpha = 0.16f)) else Modifier)
                    .clickable { onPeek(p) }.padding(horizontal = 14.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("${i + 1}", Modifier.width(20.dp), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                    Portrait(p.character3DID, 34.dp)
                    Text(p.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
                    Text("${p.score}", color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                }
            }
        }
    }
}

@Composable
private fun RoundBreakView(g: LiveGame, meID: String?, onPeek: (LiveGamePlayer) -> Unit) {
    val lg = LiveGameRepository
    val winner = lg.players.firstOrNull { it.id == g.lastRoundWinnerID }
    val haptics = KidHaptics(LocalView.current)
    LaunchedEffect(g.currentRound) { KidSounds.play(AppSound.STREAK_UP); haptics.medium() }
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(vertical = 72.dp, horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
        Text("🏁", fontSize = 56.sp)
        Text(tr("סִיַּמְנוּ סִבּוּב %lld!", g.currentRound + 1), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp)
        if (winner != null) Text(tr("הַסִּבּוּב שַׁיָּךְ לְ%@! 🎉", winner.name), color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center)
        else Text(tr("תֵּיקוּ בַּסִּבּוּב! 🤝"), color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
        RoundWinsTally(lg.players, meID, onPeek)
        Text(tr("הַסִּבּוּב הַבָּא מַתְחִיל… ⏳"), color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    }
}

private fun byWins(ps: List<LiveGamePlayer>) = ps.sortedWith(compareByDescending<LiveGamePlayer> { it.roundWins }.thenByDescending { it.score })

@Composable
private fun RoundWinsTally(ps: List<LiveGamePlayer>, meID: String?, onPeek: (LiveGamePlayer) -> Unit) {
    Column(Modifier.widthIn(max = 520.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        byWins(ps).forEach { p ->
            Row(Modifier.fillMaxWidth().glassPane(16.dp, 0.10f).then(if (p.id == meID) Modifier.background(SocialColor.starGold.copy(alpha = 0.16f)) else Modifier)
                .clickable { onPeek(p) }.padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Portrait(p.character3DID, 36.dp)
                Text(p.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
                Text("🏆".repeat(p.roundWins).ifEmpty { "—" }, color = Color.White, fontSize = 15.sp)
            }
        }
    }
}

@Composable
private fun FinalView(g: LiveGame, meID: String?, onExit: () -> Unit, onPlayAgain: () -> Unit, onCelebrate: () -> Unit, onPeek: (LiveGamePlayer) -> Unit) {
    val lg = LiveGameRepository
    val iWon = g.matchWinnerID == meID
    val haptics = KidHaptics(LocalView.current)
    // One clean confetti burst per appearance.
    LaunchedEffect(Unit) { onCelebrate(); KidSounds.play(AppSound.LEVEL_UP); haptics.success() }
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(top = 56.dp, bottom = 16.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(if (iWon) "🏆" else "🎉", fontSize = 76.sp)
            Text(if (iWon) SocialMe.g(tr("וָואו, נִצַּחְתָּ! 🤩"), tr("וָואו, נִצַּחַתְּ! 🤩")) else tr("כָּל הַכָּבוֹד! 🎉"), Modifier.padding(horizontal = 16.dp),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 32.sp, textAlign = TextAlign.Center)
            Text(SocialMe.g(tr("הַפְּרָסִים שֶׁלְּךָ:"), tr("הַפְּרָסִים שֶׁלָּךְ:")), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                PrizePill("⭐", if (iWon) LiveGameRules.WINNER_STARS else LiveGameRules.PARTICIPATION_STARS, SocialColor.starGold)
                PrizePill("💎", if (iWon) LiveGameRules.WINNER_DIAMONDS else LiveGameRules.PARTICIPATION_DIAMONDS, SocialColor.diamondBlue)
            }
            Column(Modifier.weight(1f).widthIn(max = 560.dp).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)) {
                byWins(lg.players).forEachIndexed { idx, p ->
                    Row(Modifier.fillMaxWidth().glassPane(16.dp).then(if (p.id == meID) Modifier.background(SocialColor.starGold.copy(alpha = 0.16f)) else Modifier)
                        .clickable { onPeek(p) }.padding(horizontal = 14.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(when (idx) { 0 -> "🥇"; 1 -> "🥈"; 2 -> "🥉"; else -> "${idx + 1}" }, Modifier.width(32.dp), color = Color.White,
                            fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp, textAlign = TextAlign.Center)
                        Portrait(p.character3DID, 44.dp)
                        Text(p.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, maxLines = 1)
                        Column(horizontalAlignment = Alignment.End) {
                            Text("🏆".repeat(p.roundWins), fontSize = 14.sp)
                            Text(tr("%lld נְקוּדּוֹת", p.score), color = SocialColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                        }
                    }
                }
            }
            Column(Modifier.widthIn(max = 520.dp).padding(horizontal = 24.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                WhiteCapsule(SocialMe.g(tr("שַׂחֵק שׁוּב 🔄"), tr("שַׂחֲקִי שׁוּב 🔄")), Modifier.fillMaxWidth(), size = 19) { haptics.light(); onPlayAgain() }
                Text(tr("סִיּוּם"), Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).clickable(onClick = onExit).padding(vertical = 13.dp),
                    color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center)
            }
        }
        CloseButton(onExit)
    }
}

@Composable
private fun PrizePill(emoji: String, amount: Int, tint: Color) {
    Column(Modifier.size(96.dp).glassPane(16.dp).background(tint.copy(alpha = 0.14f)), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(3.dp, Alignment.CenterVertically)) {
        Text(emoji, fontSize = 36.sp)
        Text("+$amount", color = tint, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
    }
}

@Composable
private fun EndedView(title: String, subtitle: String, onClose: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp, Alignment.CenterVertically)) {
        Text("🎈", fontSize = 64.sp)
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp, textAlign = TextAlign.Center)
        Text(subtitle, color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.sp, textAlign = TextAlign.Center)
        WhiteCapsule(tr("סְגִירָה"), Modifier.padding(top = 6.dp), onClick = onClose)
        Spacer(Modifier.height(80.dp))
    }
}

// MARK: - Player peek

/** PlayerPeekView: their character, name, ⭐, this-match stats, and an "add friend" shortcut. Public data only. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlayerPeekSheet(player: LiveGamePlayer, onClose: () -> Unit) {
    val f = FriendsRepository
    val haptics = KidHaptics(LocalView.current)
    val scope = rememberCoroutineScope()
    var card by remember { mutableStateOf<FriendCard?>(null) }
    var loading by remember { mutableStateOf(true) }
    var adding by remember { mutableStateOf(false) }
    var added by remember { mutableStateOf(false) }
    val isMe = player.id == SocialMe.id
    LaunchedEffect(player.id) { card = f.card(player.id); loading = false }

    ModalBottomSheet(onDismissRequest = onClose, containerColor = Ink.sheet) {
        Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp).padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Portrait(player.character3DID, 140.dp, glow = true)
            Text(player.name.ifEmpty { tr("שַׂחְקָן") }, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp)
            val stars = card?.stars
            if (stars != null) Text("⭐ " + tr("%lld כּוֹכָבִים", stars), Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.92f))
                .padding(horizontal = 18.dp, vertical = 9.dp), color = SocialColor.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
            else if (loading) CircularProgressIndicator(color = Color.White)
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                StatTile("🏆", "${player.roundWins}", tr("סִבּוּבִים"), Modifier.weight(1f))
                StatTile("⚡️", "${player.score}", tr("נְקוּדּוֹת"), Modifier.weight(1f))
            }
            Text(tr("בַּמִּשְׂחָק הַזֶּה"), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
            when {
                isMe -> Text("👤 " + SocialMe.g(tr("זֶה אַתָּה 🙂"), tr("זוֹ אַתְּ 🙂")), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                added || f.isFriend(player.id) -> Text("✅ " + SocialMe.g(tr("חָבֵר שֶׁלְּךָ"), tr("חָבֵר שֶׁלָּךְ")), color = SocialColor.successMint, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                !card?.code.isNullOrEmpty() -> WhiteCapsule(if (adding) "…" else "➕ " + tr("הוֹסִיפוּ לַחֲבֵרִים"), Modifier.fillMaxWidth(), size = 18, enabled = !adding) {
                    adding = true
                    scope.launch {
                        val ok = f.addFriend(card?.code ?: "")
                        adding = false
                        if (ok) { added = true; haptics.success() } else haptics.warning()
                    }
                }
            }
        }
    }
}

@Composable
private fun StatTile(emoji: String, value: String, label: String, modifier: Modifier) {
    Column(modifier.glassPane(16.dp).padding(vertical = 14.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(emoji, fontSize = 26.sp)
        Text(value, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 24.sp)
        Text(label, color = Color.White.copy(alpha = 0.75f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp)
    }
}

/**
 * WorldMapView.gameInviteBanner: drops in at the top when a NEW invite arrives,
 * auto-hides after 5 s. Also keeps my friend card's stars live while the home
 * is up (WorldMapView.onAppear → FriendsManager.beginScoreSync).
 */
@Composable
internal fun InviteBanner(onJoin: (String) -> Unit) {
    val lg = LiveGameRepository
    val ctx = LocalContext.current
    val haptics = KidHaptics(LocalView.current)
    var visible by remember { mutableStateOf(false) }
    var lastCount by remember { mutableIntStateOf(0) }
    DisposableEffect(Unit) {
        FriendsRepository.init(ctx); KidSounds.init(ctx)
        FriendsRepository.beginScoreSync()
        lg.startInvitesListener()
        onDispose { lg.stopInvitesListener() }
    }
    val count = lg.invites.size
    LaunchedEffect(count) {
        val grew = count > lastCount
        lastCount = count
        if (!grew) { if (count == 0) visible = false; return@LaunchedEffect }
        haptics.success(); KidSounds.play(AppSound.PORTAL_APPEAR)
        visible = true
        delay(5000)
        visible = false
    }
    val invite = lg.invites.firstOrNull()
    androidx.compose.animation.AnimatedVisibility(visible && invite != null && lg.game == null,
        enter = androidx.compose.animation.slideInVertically { -it } + androidx.compose.animation.fadeIn(),
        exit = androidx.compose.animation.slideOutVertically { -it } + androidx.compose.animation.fadeOut()) {
        Row(Modifier.padding(horizontal = 12.dp, vertical = 4.dp).widthIn(max = 520.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp))
            .background(SocialColor.gemPurple).border(1.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(16.dp)).padding(14.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("🎮", fontSize = 30.sp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(tr("הַזְמָנָה מִ%@!", invite?.hostName ?: ""), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 2)
                Text(tr("מִשְׂחָק חִידוֹן נֶגֶד חֲבֵרִים"), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            }
            Text(tr("הִצְטָרְפוּ"), Modifier.clip(RoundedCornerShape(16.dp)).background(SocialColor.starGold)
                .clickable { haptics.medium(); visible = false; invite?.let { onJoin(it.id) } }.padding(horizontal = 18.dp, vertical = 9.dp),
                color = Color(0xFF2B2D42), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1)
        }
    }
}

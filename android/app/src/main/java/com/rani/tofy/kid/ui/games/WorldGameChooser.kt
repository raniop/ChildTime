package com.rani.tofy.kid.ui.games

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.WorldStage
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.ui.child.WorldTiers
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.PlayWorld
import com.rani.tofy.kid.ui.play.currencyShort
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** World.rooms (World.swift default). The boss waits in the final room. */
internal const val WORLD_ROOMS = 10

internal fun bossUnlocked(world: PlayWorld): Boolean = (KidSession.engine()?.progress(world.id) ?: 0) >= WORLD_ROOMS - 1

/** The bank the games play from (reading → the language the child reads; the arena → none). */
internal fun contentTopic(world: PlayWorld) = if (world.isBonus) null else (GameContent.sourceTopic(world.topic) ?: world.topic)

internal fun worldGames(world: PlayWorld): List<MiniGameKind> =
    WorldGameFit.games(if (world.isBonus) null else world.topic, GameEnv.grade(1))

/**
 * WorldGameChooserView.swift — "אֵיךְ בָּא לְךָ לְשַׂחֵק?": what a world opens to.
 * 📝 regular questions, the games that make a real round from THIS world's
 * content (WorldGameFit, best fit first; the last one played outlined in gold),
 * 🐉 the boss once unlocked, and 🎲 "surprise me". Every game here earns screen
 * time like the questions do (MiniGameEarnSession).
 */
@Composable
internal fun WorldGameChooserScreen(world: PlayWorld, onPlayQuestions: () -> Unit, onExit: () -> Unit) {
    val ready = rememberGamesReady()
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val state by KidSession.state.collectAsState()
    val snap = state?.snapshot
    val girl = GameEnv.source.isGirl
    fun g(m: String, f: String) = if (girl) f else m
    val preReader = PreReaderGames.isPreReader(GameEnv.grade(1))
    val lastKey = "chooser.last.${GameEnv.childKey}.${world.id}"
    val ctopic = contentTopic(world)

    var games by remember { mutableStateOf<List<MiniGameKind>?>(null) }
    var lastPick by remember { mutableStateOf(GameEnv.prefs.getString(lastKey)) }
    var launch by remember { mutableStateOf<String?>(null) }   // "questions" · "boss" · a game raw
    var appeared by remember { mutableStateOf(false) }
    /** 💎 paid for the first visit to this world (shown once, then gone). */
    var firstVisitPaid by remember { mutableStateOf(0) }

    // 🏆 First time in this world: the 💎 nudge for trying something new.
    LaunchedEffect(world.id) {
        if (world.isBonus) return@LaunchedEffect
        val paid = KidSession.edit { it.markVisited(world.id) } ?: 0
        if (paid > 0) {
            delay(400)
            firstVisitPaid = paid
            play(AppSound.CORRECT_SMALL)
        }
    }

    LaunchedEffect(ready) {
        if (!ready) return@LaunchedEffect
        games = withContext(Dispatchers.Default) { worldGames(world) }
        // 👶 A גן child can't read "אֵיךְ בָּא לְךָ לְשַׂחֵק?", so they hear it.
        if (preReader) GameEnv.speak(g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?")))
        appeared = true
    }

    fun pick(id: String) {
        h.light()
        GameEnv.prefs.putString(lastKey, id)
        scope.launch {
            delay(200)
            if (id == "questions") onPlayQuestions() else launch = id
            lastPick = id
        }
    }

    // A launched game / boss covers the chooser; closing it comes back here.
    when (val l = launch) {
        "boss" -> { BossBattle(world) { launch = null }; return }
        null, "questions" -> Unit
        else -> {
            val kind = MiniGameKind.of(l)
            if (kind != null) {
                val earn = remember(l) { MiniGameEarnSession(scope) }
                MiniGameScreen(kind, ctopic, surprise = false, earn = earn) { launch = null }
                return
            }
        }
    }

    BackHandler(onBack = onExit)
    GlassBackdrop {
        SparkleField(14, 12f)
        val list = games
        if (!ready || list == null) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Color.White) }
            return@GlassBackdrop
        }
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState())
                .padding(horizontal = if (m.compact) 16.dp else 32.dp).padding(top = 8.dp, bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.compact) 16.dp else 24.dp),
        ) {
            val inner = Modifier.widthIn(max = 1000.dp).fillMaxWidth()
            // ── Header ──
            Column(inner.glassPane(16.dp).padding(if (m.compact) 14.dp else 20.dp), verticalArrangement = Arrangement.spacedBy(if (m.compact) 10.dp else 14.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    MiniGameChip(onClick = onExit) { Text("✕", color = Color.White, fontWeight = FontWeight.Black, fontSize = 13.sp) }
                    Spacer(Modifier.weight(1f))
                    MiniGameChip { ChipText("💎 ${(snap?.diamonds ?: 0).currencyShort()}", KidColor.diamondBlue) }
                    MiniGameChip { ChipText("⭐ ${(snap?.stars ?: 0).currencyShort()}", KidColor.starGold) }
                    // "⏱ 12/90 דַּק' הַיּוֹם" — today's minutes against the child's daily cap.
                    val cap = KidSession.engine()?.settings?.dailyCap
                    val earned = snap?.minutesEarnedToday ?: 0
                    MiniGameChip { ChipText("⏱ " + if (cap?.enabled == true) tr("%lld/%lld דַּק' הַיּוֹם", earned, cap.max) else tr("%lld דַּקּוֹת", earned)) }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (m.compact) 12.dp else 18.dp)) {
                    val s by animateFloatAsState(if (appeared) 1f else 0.5f, spring(dampingRatio = 0.7f), label = "emoji")
                    Text(world.emoji, fontSize = (if (m.compact) 54 else 72).sp, modifier = Modifier.floating(5f).graphicsLayer { scaleX = s; scaleY = s })
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        FitText(world.name, (if (m.compact) 24 else 32).sp, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.6f,
                            align = TextAlign.Start)
                        val room = KidSession.engine()?.progress(world.id) ?: 0
                        val frac = minOf(room, WORLD_ROOMS).toFloat() / WORLD_ROOMS
                        Box(Modifier.width(if (m.compact) 150.dp else 220.dp).height(7.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.2f))) {
                            Box(Modifier.fillMaxWidth(maxOf(0.04f, frac)).height(7.dp).clip(RoundedCornerShape(16.dp)).background(GoldBrush))
                        }
                        // "חֶדֶר 3 מִתּוֹךְ 10", with the 🏆 tier in front from silver on.
                        val tier = KidSession.engine()?.worldTier(world.id) ?: 0
                        val roomLine = if (tier >= WorldStage.TIER_COUNT) tr("👑 הָעוֹלָם הֻשְׁלַם") else {
                            val r = tr("חֶדֶר %lld מִתּוֹךְ %lld", minOf(room + 1, WORLD_ROOMS), WORLD_ROOMS)
                            WorldTiers.kidBadge(tier, girl)?.let { "$it · $r" } ?: r
                        }
                        Text(roomLine, color = Ink.secondary, fontFamily = Rounded,
                            fontWeight = FontWeight.SemiBold, fontSize = (if (m.compact) 13 else 15).sp)
                        androidx.compose.animation.AnimatedVisibility(firstVisitPaid > 0,
                            enter = androidx.compose.animation.scaleIn(spring(dampingRatio = 0.6f)) + androidx.compose.animation.fadeIn()) {
                            Text(tr("✨ בִּקּוּר רִאשׁוֹן: +%lld 💎", firstVisitPaid), color = KidColor.diamondBlue, fontFamily = Rounded,
                                fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 13 else 15).sp,
                                modifier = Modifier.clip(RoundedCornerShape(16.dp))
                                    .background(Color.White.copy(alpha = 0.9f)).padding(horizontal = 10.dp, vertical = 4.dp))
                        }
                    }
                }
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)) {
                    val q = g(tr("אֵיךְ בָּא לְךָ לְשַׂחֵק?"), tr("אֵיךְ בָּא לָךְ לְשַׂחֵק?"))
                    FitText(q, (if (m.compact) 22 else 30).sp, Modifier.weight(1f, fill = false), weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f)
                    // 👶 גן: the same question, out loud, as often as asked for.
                    if (preReader) PreReaderSpeakButton(q, if (m.compact) 44.dp else 54.dp)
                }
            }
            // ── 🧠 The questions are a TILE like every game — first in the grid —
            // and "surprise me" the last one (Rani, 2026-10-12; same as iOS). They
            // used to be a wide strip of text above the picture tiles and read as
            // the screen's heading: a tester and her daughter never found out it
            // could be tapped, and played only the games under it.
            val quizBlurb = when {
                world.isBonus -> tr("שְׁאֵלוֹת עֲנָק, וְדַקּוֹת כְּפוּלוֹת")
                preReader -> tr("שׁוֹמְעִים שְׁאֵלָה וּבוֹחֲרִים תְּמוּנָה")
                else -> tr("עוֹנִים עַל שְׁאֵלוֹת וּמַרְוִיחִים דַּקּוֹת")
            }
            if (list.isEmpty()) {
                // Nothing to sit beside (a world with only its boss): the whole row,
                // with the picture and a button that says what to do.
                ChooserCard(inner, KidColor.starGold, lastPick == "questions", girl) {
                    Row(Modifier.juicyClick { pick("questions") }.padding(if (m.compact) 14.dp else 20.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(if (m.compact) 12.dp else 20.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            FitText(tr("🧠 חִידוֹן"), (if (m.compact) 21 else 27).sp, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f, align = TextAlign.Start)
                            Text(quizBlurb, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = (if (m.compact) 13 else 16).sp)
                            Text(tr("▶ לְשַׂחֵק"), color = Color(0xFF2A1E5C), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 17 else 21).sp,
                                modifier = Modifier.clip(RoundedCornerShape(16.dp)).background(KidColor.starGold)
                                    .padding(horizontal = if (m.compact) 22.dp else 30.dp, vertical = if (m.compact) 9.dp else 12.dp))
                        }
                        QuizTilePreview(preReader, Modifier.width(if (m.compact) 130.dp else 230.dp).height(if (m.compact) 92.dp else 132.dp))
                    }
                }
            } else {
                val cols = if (m.compact) 2 else 4
                val tiles = listOf("questions") + list.map { it.raw } + "surprise"
                Column(inner, verticalArrangement = Arrangement.spacedBy(if (m.compact) 12.dp else 16.dp)) {
                    tiles.chunked(cols).forEachIndexed { row, chunk ->
                        Row(horizontalArrangement = Arrangement.spacedBy(if (m.compact) 12.dp else 16.dp)) {
                            chunk.forEachIndexed { k, id ->
                                val i = row * cols + k
                                val kind = list.firstOrNull { it.raw == id }
                                val rise by animateFloatAsState(if (appeared) 0f else 14f, tween(400, delayMillis = 30 * i), label = "rise")
                                val tint = when (id) { "questions" -> KidColor.starGold; "surprise" -> hexColor("9B5DE5"); else -> TileTints[i % 4] }
                                Box(Modifier.weight(1f).graphicsLayer { translationY = rise * density; alpha = 1f - rise / 14f }) {
                                    ChooserCard(Modifier.fillMaxWidth(), tint, lastPick == id && id != "surprise", girl) {
                                        Column(Modifier.juicyClick {
                                            if (id == "surprise") {
                                                val pool = list.toMutableList()
                                                if (pool.size > 1) pool.removeAll { it.raw == lastPick }
                                                pool.randomOrNull()?.let { pick(it.raw) }
                                            } else pick(id)
                                        }.padding(10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                            val art = Modifier.fillMaxWidth().height(if (m.compact) 92.dp else 124.dp)
                                            when {
                                                kind != null -> MiniGamePreview(kind, art)
                                                id == "questions" -> QuizTilePreview(preReader, art)
                                                else -> Box(art.glassInset(16.dp), contentAlignment = Alignment.Center) { Text("🎲", fontSize = (if (m.compact) 56 else 78).sp) }
                                            }
                                            FitText(when {
                                                kind != null -> kind.emoji + " " + kind.shortName
                                                id == "questions" -> tr("🧠 חִידוֹן")
                                                else -> tr("🎲 הַפְתָּעָה")
                                            }, (if (m.compact) 16 else 20).sp, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.6f)
                                            Text(when {
                                                kind != null -> kind.blurb
                                                id == "questions" -> quizBlurb
                                                else -> tr("מִשְׂחָק אַקְרָאִי מֵהָעוֹלָם הַזֶּה")
                                            }, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = (if (m.compact) 12 else 14).sp,
                                                textAlign = TextAlign.Center, maxLines = 2, modifier = Modifier.heightIn(min = if (m.compact) 30.dp else 36.dp))
                                        }
                                    }
                                }
                            }
                            repeat(cols - chunk.size) { Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
            }
            // ── 🐉 the boss (once its last room is reached) ──
            if (bossUnlocked(world)) WideCard(inner, "🐉", tr("קְרַב בּוֹס"), tr("הָאֶתְגָּר הַגָּדוֹל שֶׁל הָעוֹלָם הַזֶּה"), hexColor("EF476F"),
                lastPick == "boss", girl) { pick("boss") }
        }
    }
}

/** A chooser tile + its gold "last played" outline and tag. */
@Composable
private fun ChooserCard(modifier: Modifier, tint: Color, last: Boolean, girl: Boolean, content: @Composable () -> Unit) {
    Box(modifier) {
        Box(Modifier.fillMaxWidth().miniGameTile(TileState.NORMAL, tint, 24.dp).then(if (last) Modifier.border(2.5.dp, KidColor.starGold, RoundedCornerShape(16.dp)) else Modifier)) {
            content()
        }
        // The tag sits ON the gold outline, in the corner away from the title —
        // inside the card it covered the heading (Rani, 2026-10-06). Outside the
        // tile's clip, so the half above the border isn't cut off.
        if (last) Text(if (girl) tr("שִׂחַקְתְּ לָאַחֲרוֹנָה") else tr("שִׂחַקְתָּ לָאַחֲרוֹנָה"), color = Color(0xFF4B3FBF), fontFamily = Rounded,
            fontWeight = FontWeight.ExtraBold, fontSize = 10.5.sp,
            modifier = Modifier.align(Alignment.TopEnd).padding(end = 16.dp).offset(y = (-11).dp)
                .clip(RoundedCornerShape(16.dp)).background(KidColor.starGold).padding(horizontal = 9.dp, vertical = 4.dp))
    }
}

@Composable
private fun WideCard(modifier: Modifier, emoji: String, title: String, subtitle: String, tint: Color, last: Boolean, girl: Boolean, onClick: () -> Unit) {
    val m = gameMetrics()
    ChooserCard(modifier, tint, last, girl) {
        Row(Modifier.fillMaxWidth().juicyClick(onClick = onClick).padding(if (m.compact) 14.dp else 18.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(emoji, fontSize = (if (m.compact) 40 else 52).sp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 20 else 26).sp)
                Text(subtitle, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = (if (m.compact) 13 else 16).sp)
            }
        }
    }
}

/** The questions' tile art: a question as the child meets it — pictures to
 *  choose from for a pre-reader, a sum with number answers for a reader. */
@Composable
private fun QuizTilePreview(pictures: Boolean, modifier: Modifier) {
    val answers = if (pictures) listOf("🦴", "🚗", "🍎", "⚽") else listOf("10", "12", "13", "11")
    val right = if (pictures) 0 else 1
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(modifier.glassInset(16.dp).padding(horizontal = 14.dp, vertical = 5.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically)) {
            Text(if (pictures) "🔊 🐶 ❓" else "7 + 5 = ?", color = Color(0xFF2A1E5C), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp,
                modifier = Modifier.clip(RoundedCornerShape(8.dp)).background(Color.White.copy(alpha = 0.92f)).padding(horizontal = 10.dp, vertical = 1.dp))
            repeat(2) { r ->
                Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                    repeat(2) { c ->
                        val i = r * 2 + c
                        Box(Modifier.width(46.dp).height(21.dp).clip(RoundedCornerShape(8.dp))
                            .background(if (i == right) Color(0xFF2ECC71) else TileTints[i % 4].copy(alpha = 0.85f))
                            .border(if (i == right) 2.dp else 1.dp, Color.White.copy(alpha = if (i == right) 0.9f else 0.35f), RoundedCornerShape(8.dp)),
                            contentAlignment = Alignment.Center) {
                            Text(answers[i], color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = if (pictures) 15.sp else 13.sp)
                        }
                    }
                }
            }
        }
    }
}

/**
 * A still miniature of each game (MiniGamePreview.swift draws a live, inert
 * copy of the real screen; Android shows a static sketch of the same board).
 */
@Composable
internal fun MiniGamePreview(kind: MiniGameKind, modifier: Modifier) {
    when (kind) {
        MiniGameKind.SEQUENCE -> { PreSequence(modifier); return }
        MiniGameKind.BASKET -> { PreBasket(modifier); return }
        else -> Unit
    }
    val cells: List<String> = when (kind) {
        MiniGameKind.PAIRS -> listOf("🇫🇷", tr("פָּרִיז"), "🇯🇵", tr("טוֹקְיוֹ"))
        MiniGameKind.BALLOON -> listOf("🎈", "🎈", "🎈")
        MiniGameKind.WORD -> listOf("🐶", "_", "_", "_")
        MiniGameKind.CRUSH -> listOf("3", "7", "5", "2", "8", "4")
        MiniGameKind.WORD_SEARCH -> (if (GameEnv.lang == com.rani.tofy.i18n.AppLanguage.HE) "כלבשמג" else "CATSUN").map { it.toString() }
        MiniGameKind.LIGHTNING -> listOf("7 × 8 = 56", "✓", "✗")
        MiniGameKind.SORT -> listOf("🐟", "🌊", "🌳")
        MiniGameKind.PATTERN -> listOf("2", "4", "6", "?")
        MiniGameKind.GAME2048 -> listOf("2", "4", "8", "16")
        MiniGameKind.VAULT -> listOf("?", "?", "?")
        MiniGameKind.GROCERY -> listOf("🥛", "🍞", "🍎")
        MiniGameKind.BALANCE -> listOf("7 + ?", "⚖️", "10")
        MiniGameKind.SEQUENCE, MiniGameKind.BASKET -> emptyList()   // drawn above
    }
    Box(modifier.glassInset(16.dp).padding(8.dp), contentAlignment = Alignment.Center) {
        Ltr {
            Row(horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
                cells.take(6).forEachIndexed { i, c ->
                    Box(Modifier.weight(1f, fill = false).widthIn(min = 22.dp).height(36.dp).miniGameTile(if (c == "?") TileState.PICKED else TileState.NORMAL, TileTints[i % 4], 8.dp)
                        .padding(horizontal = 4.dp), contentAlignment = Alignment.Center) {
                        FitText(c, 16.sp, weight = FontWeight.Black, maxLines = 1, minScale = 0.4f)
                    }
                }
            }
        }
    }
}

/** 🎞️ Three numbered frames — the first two filled, the third waiting — and the picture that belongs in it. */
@Composable
private fun PreSequence(modifier: Modifier) {
    val steps = listOf("seed", "sprout", "flower")
    BoxWithConstraints(modifier.glassInset(16.dp).padding(horizontal = 6.dp, vertical = 5.dp), contentAlignment = Alignment.Center) {
        val w = minOf(maxWidth * 0.26f, maxHeight * 0.47f)
        val badge = w * 0.42f
        Ltr {   // numbers run left to right
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(w * 0.1f)) {
                Row(horizontalArrangement = Arrangement.spacedBy(w * 0.2f)) {
                    steps.forEachIndexed { i, key ->
                        Box {
                            Box(Modifier.size(w).miniGameTile(if (i < 2) TileState.CORRECT else TileState.NORMAL, KidColor.starGold, 10.dp)
                                .padding(w * 0.08f), contentAlignment = Alignment.Center) {
                                if (i < 2) com.rani.tofy.ui.chores.ChoreDrawing(key, Modifier.fillMaxSize())
                            }
                            Box(Modifier.align(Alignment.TopEnd).offset(x = badge * 0.35f, y = -badge * 0.25f).size(badge)
                                .clip(RoundedCornerShape(16.dp)).background(GoldBrush), contentAlignment = Alignment.Center) {
                                val fs = (badge.value * 0.62f).sp
                                Text("${i + 1}", color = Color(0xFF3A2700), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = fs, lineHeight = fs)
                            }
                        }
                    }
                }
                Box(Modifier.size(w * 0.9f).miniGameTile(TileState.PICKED, hexColor("48BFE3"), 10.dp).padding(w * 0.07f), contentAlignment = Alignment.Center) {
                    com.rani.tofy.ui.chores.ChoreDrawing(steps[2], Modifier.fillMaxSize())
                }
            }
        }
    }
}

/** 🍎 Three apples on the pile, two in the basket that wants four. */
@Composable
private fun PreBasket(modifier: Modifier) {
    BoxWithConstraints(modifier.glassInset(16.dp).padding(5.dp), contentAlignment = Alignment.Center) {
        val s = minOf(maxHeight.value, maxWidth.value * 0.6f)   // ≈ 80 on a phone's tile
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((s * 0.04f).dp)) {
            Text("🍎 🍎 🍎", fontSize = (s * 0.19f).sp, lineHeight = (s * 0.24f).sp)
            Box(contentAlignment = Alignment.TopCenter) {
                Column(Modifier.padding(top = (s * 0.1f).dp).miniGameTile(TileState.NORMAL, KidColor.successMint, 10.dp)
                    .padding(start = (s * 0.14f).dp, end = (s * 0.14f).dp, top = (s * 0.1f).dp, bottom = (s * 0.02f).dp),
                    horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("🍎🍎", fontSize = (s * 0.15f).sp, lineHeight = (s * 0.19f).sp)
                    Text("🧺", fontSize = (s * 0.21f).sp, lineHeight = (s * 0.26f).sp)
                }
                // The number the basket wants, on its rim.
                val fs = (s * 0.15f).sp
                Text("4", color = Color(0xFF3A2700), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = fs, lineHeight = fs,
                    modifier = Modifier.clip(RoundedCornerShape(16.dp)).background(GoldBrush).padding(horizontal = (s * 0.07f).dp, vertical = 1.dp))
            }
        }
    }
}

/**
 * WorldEntryView: should a tap on this world skip the chooser? A parent asked
 * for regular questions only, or there is nothing else to choose (no game fits
 * and no boss yet). Decide it ONCE, when the world opens.
 */
internal fun goesStraightToQuestions(world: PlayWorld): Boolean {
    if (GameEnv.source.onlyRegularQuestions) return true
    return !bossUnlocked(world) && worldGames(world).isEmpty()
}

/** GamesMenuView.swift — the four classic modes, as big colourful cards (pre-readers: memory only). */
@Composable
internal fun GamesMenu(onClose: () -> Unit) {
    val ready = rememberGamesReady()
    var open by remember { mutableStateOf<String?>(null) }
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    when (open) {
        "tf" -> { TrueFalseRace { open = null }; return }
        "quiz" -> { QuickQuiz { open = null }; return }
        "match" -> { MatchPairs { open = null }; return }
        "memory" -> { MemoryMatch { open = null }; return }
    }
    // Pre-readers (גן) can't read the text-based games — only the visual memory game.
    val preReader = GameEnv.grade(1) < 1
    ClassicBackdrop(listOf("5B6CFF", "9B5DE5", "EF476F"), 0, 0, onClose) {
        Column(Modifier.fillMaxSize().padding(horizontal = 22.dp).padding(top = 80.dp), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Text(tr("מִשְׂחָקִים 🎮"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 36.sp)
            Text(com.rani.tofy.kid.ui.social.SocialMe.g(tr("בְּחַר מִשְׂחָק וְקָדִימָה!"), tr("בַּחֲרִי מִשְׂחָק וְקָדִימָה!")), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 17.sp)
            if (!ready) { CircularProgressIndicator(color = Color.White); return@Column }
            Column(Modifier.verticalScroll(rememberScrollState()).padding(bottom = 24.dp).widthIn(max = 600.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                if (!preReader) {
                    MenuCard("⚡️", tr("מֵרוֹץ נָכוֹן/לֹא נָכוֹן"), tr("מַהֵר! נָכוֹן אוֹ לֹא? בּוֹנוּס עַל מְהִירוּת 🔥"), listOf("EF476F", "FF8A5B"), appeared) { open = "tf" }
                    MenuCard("🎯", tr("חִידוֹן בָּזָק"), com.rani.tofy.kid.ui.social.SocialMe.g(tr("אַרְבַּע תְּשׁוּבוֹת — בְּחַר אֶת הַנְּכוֹנָה מַהֵר!"), tr("אַרְבַּע תְּשׁוּבוֹת — בַּחֲרִי אֶת הַנְּכוֹנָה מַהֵר!")), listOf("118AB2", "5B6CFF"), appeared) { open = "quiz" }
                    MenuCard("🧩", tr("הַתְאָמַת זוּגוֹת"), tr("הַתְאִימוּ שְׁאֵלָה לַתְּשׁוּבָה וּזְכוּ בִּפְרָסִים"), listOf("06D6A0", "118AB2"), appeared) { open = "match" }
                }
                MenuCard("🧠", tr("מִשְׂחַק הַזִּכָּרוֹן"), if (preReader) tr("מִצְאוּ שְׁתֵּי תְּמוּנוֹת זֵהוֹת") else tr("מָצְאוּ אֶת הָאֶמוֹגִ'י וְהַמִּלָּה בְּאַנְגְּלִית"), listOf("9B5DE5", "EF476F"), appeared) { open = "memory" }
            }
        }
    }
}

@Composable
private fun MenuCard(emoji: String, title: String, subtitle: String, colors: List<String>, appeared: Boolean, onClick: () -> Unit) {
    val h = rememberHaptics()
    val s by animateFloatAsState(if (appeared) 1f else 0.85f, spring(dampingRatio = 0.7f), label = "menu")
    Row(
        Modifier.fillMaxWidth().graphicsLayer { scaleX = s; scaleY = s; alpha = if (appeared) 1f else 0f }.clip(RoundedCornerShape(16.dp))
            .background(androidx.compose.ui.graphics.Brush.linearGradient(colors.map { hexColor(it) }))
            .border(1.5.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(16.dp)).juicyClick { h.light(); onClick() }.padding(18.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        // Text first → in RTL it sits flush against the right edge; the medallion on the left.
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 23.sp)
            Text(subtitle, color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        }
        Box(Modifier.size(92.dp).clip(androidx.compose.foundation.shape.CircleShape).background(Color.White.copy(alpha = 0.22f))
            .border(1.5.dp, Color.White.copy(alpha = 0.4f), androidx.compose.foundation.shape.CircleShape).floating(5f), contentAlignment = Alignment.Center) {
            Text(emoji, fontSize = 56.sp)
        }
    }
}

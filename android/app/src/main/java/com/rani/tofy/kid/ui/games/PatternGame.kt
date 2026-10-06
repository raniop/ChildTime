package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🧠 PatternGameView.swift — "הַתַּבְנִית": a row of tiles, one a gold "?",
 * and four answers. Numbers, letters (English / Hebrew worlds) or pictures. A
 * right answer drops into the "?" in mint; a miss glows soft warm, try again.
 * Six a round (five in a surprise). 👶 גן: two pictures, five cells, three choices.
 */
@Composable
fun PatternGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val preReader = GameEnv.activeChildIsPreReader
    val count = if (preReader) PreReaderGames.PATTERN_COUNT else if (surprise) 5 else PatternGen.ROUND_COUNT
    val grade = if (preReader) 0 else when (topic) {
        Topic.ENGLISH, Topic.HEBREW -> maxOf(1, GameEnv.grade(2))
        else -> MiniGameLevel.grade(topic ?: Topic.MATH)
    }

    var phase by remember { mutableIntStateOf(0) }
    var round by remember { mutableStateOf<PatternRound?>(null) }
    var index by remember { mutableIntStateOf(0) }
    var picked by remember { mutableStateOf<String?>(null) }
    val wrongPicks = remember { mutableStateListOf<String>() }
    var missed by remember { mutableStateOf(false) }
    var clean by remember { mutableIntStateOf(0) }
    var shake by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    val solved = picked != null && picked == round?.answer

    fun load() {
        var r = PatternGen.make(topic, grade)
        // Never the very same row twice in a row.
        var tries = 0
        while (r.cells == round?.cells && tries < 5) { r = PatternGen.make(topic, grade); tries++ }
        round = r; picked = null; wrongPicks.clear(); missed = false; shownAt = nowSecs()
    }

    fun start() { index = 0; clean = 0; grant = null; load(); phase = 1 }

    fun finish() {
        if (phase != 1) return
        // Every round the child SOLVED pays (the board only moves on when solved) — `clean` is the headline.
        grant = MiniGameReward.grant("pattern", count, 2, 1, count, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }

    fun pick(opt: String) {
        val r = round ?: return
        if (phase != 1 || solved) return
        if (opt == r.answer) {
            picked = opt
            if (!missed) clean++
            // A round solved on the second try still pays — the runner's re-ask.
            MiniGameLedger.record(true, r.topic, (nowSecs() - shownAt) * 1000, clean, earn, surprise, retry = missed)
            burst++; play(AppSound.CORRECT_BIG); h.success()
            scope.launch {
                delay(1000)
                if (phase != 1) return@launch
                if (index + 1 < count) { index++; load() } else finish()
            }
        } else {
            if (!missed) { missed = true; MiniGameLedger.record(false, r.topic, earn = earn, surprise = surprise) }
            play(AppSound.WRONG_SOFT); h.light()
            if (preReader) GameEnv.speak(PreReaderGames.almost)
            wrongPicks += opt; shake++
        }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    val chip = if (preReader) "🧠 " + PreReaderChrome.dots(index, count) else "🧠 ${minOf(index + 1, count)}/$count"
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered {
                if (preReader) PreReaderIntroCard(MiniGameKind.PATTERN, PreReaderGames.patternCue) { start() }
                else MiniGameIntroCard(MiniGameKind.PATTERN) { start() }
            }
            2 -> Centered {
                val title = if (clean == count) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉")
                val d = tr("פִּצַּחְתֶּם %lld תַּבְנִיּוֹת!", count)
                if (preReader) PreReaderEndCard(title, d, "🧠", clean, grant, surprise, tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
                else MiniGameEndCard(title, d, grant, surprise, tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (preReader) (if (m.compact) 560.dp else 620.dp) else (if (m.compact) 640.dp else 820.dp))
                    .fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 24.dp, Alignment.CenterVertically),
            ) {
                val r = round
                val dx = shakeOffset(shake)
                Column(Modifier.fillMaxWidth().graphicsLayer { translationX = dx * density }.glassPane(24.dp).padding(horizontal = 12.dp, vertical = 18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    if (preReader) PreReaderCueCard(PreReaderGames.patternCue, m.compact)
                    else TitleText(tr("מָה מַשְׁלִים אֶת הַתַּבְנִית?"), (if (m.compact) 20 else 26).sp)
                    // Numbers and pictures read left-to-right; Hebrew letters from the right.
                    CompositionLocalProvider(LocalLayoutDirection provides if (r?.rtl == true) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                        val cells = r?.cells ?: emptyList()
                        BoxWithConstraints(Modifier.fillMaxWidth().height(if (preReader) (if (m.short) 66.dp else if (m.compact) 90.dp else 124.dp) else (if (m.compact) 74.dp else 108.dp)),
                            contentAlignment = Alignment.Center) {
                            val gap = if (m.compact) 6.dp else 10.dp
                            val maxSide = if (preReader) (if (m.short) 62.dp else if (m.compact) 86.dp else 120.dp) else (if (m.compact) 70.dp else 104.dp)
                            val side = minOf(maxSide, (maxWidth - gap * maxOf(0, cells.size - 1)) / maxOf(1, cells.size))
                            Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                                cells.forEach { cell ->
                                    val hole = cell == "?"
                                    val shown = if (hole && solved) r?.answer ?: "?" else cell
                                    val k by animateFloatAsState(if (hole && solved) 1.12f else 1f, spring(dampingRatio = 0.5f), label = "hole")
                                    val n = shown.graphemes()
                                    Box(Modifier.size(side).graphicsLayer { scaleX = k; scaleY = k }
                                        .miniGameTile(if (hole) (if (solved) TileState.CORRECT else TileState.PICKED) else TileState.NORMAL, Color.White.copy(alpha = 0.25f), side * 0.24f)
                                        .then(if (hole && !solved) Modifier.drawWithContent {
                                            drawContent()
                                            val inset = 4.dp.toPx()
                                            drawRoundRect(KidColor.starGold.copy(alpha = 0.8f), Offset(inset, inset), Size(size.width - 2 * inset, size.height - 2 * inset),
                                                CornerRadius(side.toPx() * 0.2f), style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx()))))
                                        } else Modifier),
                                        contentAlignment = Alignment.Center) {
                                        FitText(shown, (side.value * (if (n > 3) 0.3f else if (n > 2) 0.36f else 0.46f)).sp,
                                            color = if (hole && !solved) KidColor.starGold else Color.White, weight = FontWeight.Black, maxLines = 1, minScale = 0.5f)
                                    }
                                }
                            }
                        }
                    }
                }
                // 👶 גן: three choices in one row, each a big picture.
                val opts = r?.options ?: emptyList()
                val cols = if (preReader) minOf(3, maxOf(1, opts.size)) else if (m.compact) 2 else 4
                Ltr(r?.rtl != true) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        opts.chunked(cols).forEachIndexed { row, chunk ->
                            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                chunk.forEachIndexed { k, opt ->
                                    val i = row * cols + k
                                    val state = if (opt == picked && solved) TileState.CORRECT else if (opt in wrongPicks) TileState.WRONG else TileState.NORMAL
                                    Box(Modifier.weight(1f).heightIn(min = if (preReader) (if (m.short) 70.dp else if (m.compact) 100.dp else 120.dp) else (if (m.compact) 76.dp else 110.dp))
                                        .miniGameTile(state, TileTints[i % 4], 22.dp).juicyClick(!solved && opt !in wrongPicks) { pick(opt) },
                                        contentAlignment = Alignment.Center) {
                                        FitText(opt, (if (preReader) (if (m.short) 34 else if (m.compact) 46 else 58) else (if (m.compact) 32 else 42)).sp,
                                            weight = FontWeight.Black, maxLines = 1, minScale = 0.5f)
                                    }
                                }
                                repeat(cols - chunk.size) { Spacer(Modifier.weight(1f)) }
                            }
                        }
                    }
                }
            }
        }
    }
}

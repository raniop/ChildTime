package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🧺 SortBasketsView.swift — "מִיּוּן לַסַּלִּים": two (from ד׳ often three)
 * baskets with dashed rims, one item at a time. Drag it into its basket (or tap
 * the basket): right → it drops in; a miss → it floats back, nothing said.
 * A world with no baskets of its own sorts its questions into ✓ / ✗.
 * 👶 גן: picture baskets, six pictures, no clock, the rule spoken.
 */
@Composable
fun SortBasketsGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val preReader = GameEnv.activeChildIsPreReader
    val grade = if (topic == Topic.MATH) MiniGameLevel.grade(Topic.MATH) else maxOf(1, GameEnv.grade(2))
    val roundSeconds = MiniGameKind.SORT.seconds(surprise).toDouble()
    val tints = remember { listOf(hexColor("48BFE3"), hexColor("FF6B9D"), hexColor("FFB84D")) }

    var phase by remember { mutableIntStateOf(0) }
    var set by remember { mutableStateOf<SortSet?>(null) }
    var queue by remember { mutableStateOf(listOf<SortItem>()) }
    val sorted = remember { mutableStateMapOf<Int, List<SortItem>>() }
    var missedCurrent by remember { mutableStateOf(false) }
    var cleanCount by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var bestStreak by remember { mutableIntStateOf(0) }
    val drag = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    var dropping by remember { mutableStateOf<Int?>(null) }
    var glow by remember { mutableStateOf<Pair<Int, Boolean>?>(null) }
    val frames = remember { mutableStateMapOf<Int, Rect>() }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var cue by remember { mutableStateOf<PreReaderCue?>(null) }
    var roundTotal by remember { mutableIntStateOf(SortSets.ROUND_ITEMS) }
    var preDealt by remember { mutableStateOf(false) }
    val current = queue.firstOrNull()
    val placedCount = sorted.values.sumOf { it.size }
    val remaining = maxOf(0.0, roundSeconds - (now - startedAt))

    fun dealPreReader() {
        val round = PreReaderGames.baskets()
        set = round.set; cue = round.cue
        queue = PreReaderGames.basketRound(round.set); roundTotal = queue.size; preDealt = true
    }

    fun resetCommon() {
        sorted.clear(); missedCurrent = false; cleanCount = 0; streak = 0; bestStreak = 0; grant = null
        dropping = null; glow = null; scope.launch { drag.snapTo(Offset.Zero) }
        startedAt = nowSecs(); now = startedAt; shownAt = startedAt
        phase = 1
    }

    fun start() {
        if (preReader) {
            if (!preDealt) dealPreReader()
            preDealt = false
            resetCommon(); return
        }
        cue = null
        var made: SortSet? = topic?.let { SortSets.make(it, grade) ?: SortSets.trueFalse(it, grade) }
        if (made == null) made = SortSets.make(Topic.ANIMALS, grade)
        val s = made ?: run { onClose(); return }
        set = s
        queue = if (s.items.firstOrNull()?.detail != null) s.items else SortSets.round(s)
        roundTotal = minOf(queue.size, SortSets.ROUND_ITEMS)
        resetCommon()
    }

    fun finish() {
        if (phase != 1) return
        // Every item that reached a basket pays — `cleanCount` is the headline, not the price.
        grant = MiniGameReward.grant("sort", placedCount, 1, 1, roundTotal, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
        if (placedCount > 0) confetti++
    }

    fun drop(b: Int) {
        val item = current ?: return
        val s = set ?: return
        if (phase != 1 || dropping != null) return
        if (item.basket == b) {
            if (!missedCurrent) { cleanCount++; streak++; bestStreak = maxOf(bestStreak, streak) }
            // An item that found its basket on the second try still pays (the runner's re-ask).
            MiniGameLedger.record(true, s.topic, (nowSecs() - shownAt) * 1000, streak, earn, surprise, retry = missedCurrent)
            burst++
            play(if (streak > 0 && streak % 5 == 0) AppSound.STREAK_UP else AppSound.CORRECT_SMALL); h.success()
            dropping = b; glow = b to true
            scope.launch {
                // Into the basket — wherever the finger let go (or from the top, on a tap).
                val chip = frames[-1]; val to = frames[b]
                if (chip != null && to != null) launch { drag.animateTo(to.center - chip.center, spring(dampingRatio = 0.7f)) }
                delay(320)
                if (phase != 1) return@launch
                sorted[b] = (sorted[b] ?: emptyList()) + item
                queue = queue.drop(1)
                drag.snapTo(Offset.Zero); dropping = null; glow = null
                missedCurrent = false; shownAt = nowSecs()
                if (queue.isEmpty()) finish()
            }
        } else {
            // It floats back — the basket glows soft warm for a moment.
            if (!missedCurrent) { missedCurrent = true; streak = 0; MiniGameLedger.record(false, s.topic, earn = earn, surprise = surprise) }
            play(AppSound.WRONG_SOFT); h.light()
            if (preReader) GameEnv.speak(PreReaderGames.almost)
            glow = b to false
            scope.launch { drag.animateTo(Offset.Zero, spring(dampingRatio = 0.6f)) }
            scope.launch { delay(500); if (glow?.first == b) glow = null }
        }
    }

    LaunchedEffect(Unit) {
        if (preReader && !preDealt) dealPreReader()
        if ((surprise || earn != null) && phase == 0) start()
    }
    // 👶 גן has no clock: the round ends when the last basket is filled.
    LaunchedEffect(phase) {
        while (phase == 1 && !preReader) { delay(100); now = nowSecs(); if (roundSeconds - (now - startedAt) <= 0) finish() }
    }

    val chip = if (preReader) "🧺 " + PreReaderChrome.dots(placedCount, roundTotal) else "🧺 $placedCount/$roundTotal"
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered {
                if (preReader) PreReaderIntroCard(MiniGameKind.SORT, cue ?: PreReaderCue(spoken = PreReaderGames.startCue)) { start() }
                else MiniGameIntroCard(MiniGameKind.SORT) { start() }
            }
            2 -> Centered {
                val first = when (placedCount) {
                    0 -> if (surprise) tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") else tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
                    1 -> tr("פְּרִיט אֶחָד בַּסַּל")
                    else -> tr("%lld פְּרִיטִים בַּסַּלִּים", placedCount)
                }
                val d = if (bestStreak >= 2) first + "\n" + tr("הָרֶצֶף הֲכִי אָרֹךְ: %lld 🔥", bestStreak) else first
                val title = if (cleanCount == roundTotal) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉")
                if (preReader) PreReaderEndCard(title, d, "🧺", placedCount, grant, surprise, tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
                else MiniGameEndCard(title, d, grant, surprise, tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (preReader) (if (m.compact) 560.dp else 620.dp) else (if (m.compact) 640.dp else 820.dp))
                    .fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
            ) {
                val c = cue
                if (preReader && c != null) PreReaderCueCard(c, m.compact)
                else Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    TitleText(if (current?.detail != null) tr("נָכוֹן אוֹ לֹא נָכוֹן? גִּרְרוּ לַסַּל") else tr("גִּרְרוּ כָּל פְּרִיט לַסַּל הַמַּתְאִים"),
                        (if (m.compact) 16 else 20).sp)
                    MiniGameTimerBar(remaining, roundSeconds)
                }
                Text(if (preReader) PreReaderChrome.streak(streak) else if (streak >= 2) tr("🔥 %lld בְּרֶצֶף", streak) else " ",
                    color = KidColor.starGold, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                Box(Modifier.weight(1f).fillMaxWidth().zIndex(2f), contentAlignment = Alignment.Center) {
                    val item = current
                    if (item != null) {
                        val s by animateFloatAsState(if (dropping != null) 0.3f else 1f, spring(dampingRatio = 0.7f), label = "chip")
                        Column(
                            Modifier.onGloballyPositioned { frames[-1] = it.boundsInRoot() }
                                .graphicsLayer { translationX = drag.value.x; translationY = drag.value.y; scaleX = s; scaleY = s; alpha = if (dropping != null) 0.3f else 1f }
                                .pointerInput(item.id) {
                                    detectDragGestures(
                                        onDrag = { change, amount -> change.consume(); scope.launch { drag.snapTo(drag.value + amount) } },
                                        onDragEnd = {
                                            val chipRect = frames[-1]
                                            val center = (chipRect?.center ?: Offset.Zero) + drag.value
                                            val hit = frames.entries.firstOrNull { it.key >= 0 && it.value.contains(center) }?.key
                                            if (hit != null) drop(hit) else scope.launch { drag.animateTo(Offset.Zero, spring(dampingRatio = 0.7f)) }
                                        },
                                    )
                                }
                                .widthIn(min = if (m.compact) 150.dp else 210.dp, max = if (m.compact) 300.dp else 420.dp)
                                .miniGameTile(TileState.PICKED, KidColor.starGold, 24.dp).padding(horizontal = 22.dp, vertical = 14.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            if (item.emoji.isNotEmpty()) Text(item.emoji, fontSize = (if (preReader) (if (m.short) 52 else if (m.compact) 76 else 100) else (if (m.compact) 44 else 60)).sp)
                            if (item.label.isNotEmpty()) GameText(item.label, (if (item.detail != null) (if (m.compact) 19 else 24) else (if (m.compact) 26 else 34)).sp, maxLines = 3, minScale = 0.6f)
                            item.detail?.let { GameText(it, (if (m.compact) 24 else 30).sp, color = KidColor.starGold, weight = FontWeight.Black, maxLines = 1, minScale = 0.6f) }
                        }
                    }
                }
                // Baskets in reading order — the first on the right in Hebrew / Arabic (the app's RTL does it).
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(if (m.compact) 10.dp else 18.dp)) {
                    (set?.baskets ?: emptyList()).forEachIndexed { b, basket ->
                        val state = glow?.let { if (it.first == b) (if (it.second) TileState.CORRECT else TileState.WRONG) else TileState.NORMAL } ?: TileState.NORMAL
                        val bs by animateFloatAsState(if (dropping == b) 1.06f else 1f, spring(dampingRatio = 0.55f), label = "basket")
                        Column(
                            Modifier.weight(1f).heightIn(min = if (preReader) (if (m.short) 108.dp else if (m.compact) 180.dp else 230.dp) else (if (m.compact) 140.dp else 190.dp))
                                .onGloballyPositioned { frames[b] = it.boundsInRoot() }
                                .graphicsLayer { scaleX = bs; scaleY = bs }
                                .miniGameTile(state, tints[b % tints.size], 24.dp)
                                .drawWithContent {
                                    drawContent()
                                    val inset = 6.dp.toPx()
                                    drawRoundRect(Color.White.copy(alpha = 0.55f), topLeft = Offset(inset, inset),
                                        size = androidx.compose.ui.geometry.Size(size.width - 2 * inset, size.height - 2 * inset),
                                        cornerRadius = androidx.compose.ui.geometry.CornerRadius(20.dp.toPx()),
                                        style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 6.dp.toPx()))))
                                }
                                .juicyClick { drop(b) }.padding(vertical = 12.dp, horizontal = 6.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
                        ) {
                            // What's in it so far — a little heap of pictures.
                            Row(Modifier.height(if (m.compact) 22.dp else 30.dp), horizontalArrangement = Arrangement.spacedBy((-6).dp)) {
                                (sorted[b] ?: emptyList()).takeLast(5).forEach { Text(it.emoji.ifEmpty { "•" }, fontSize = (if (m.compact) 16 else 22).sp) }
                            }
                            FitText(basket.emoji, (if (preReader) (if (m.short) 34 else if (m.compact) 46 else 60) else (if (m.compact) 28 else 38)).sp, maxLines = 1, minScale = 0.5f)
                            if (basket.label.isNotEmpty()) TitleText(basket.label, (if (m.compact) 15 else 19).sp)
                        }
                    }
                }
            }
        }
    }
}

package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🍎 BasketCountView.swift — "שִׂימוּ בַּסַּל": counting by DOING (Sasha,
 * 2026-10-15: "גרור 4 תפוחים לסל"). A pile of apples (or fish, or stars) at the
 * top, a basket at the bottom wearing the number it wants. The child drags — or
 * taps — items into the basket, taps one in the basket to take it back out, and
 * presses ✅ when they think it is right. Too few or too many is never "wrong":
 * Tofy says how to fix it and the basket stays as it is. Five baskets a round,
 * no clock.
 */
@Composable
fun BasketCountGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val topicForLedger = Topic.MATH
    val rounds = 5

    var phase by remember { mutableIntStateOf(0) }
    var roundIndex by remember { mutableIntStateOf(0) }
    var emoji by remember { mutableStateOf("🍎") }
    var plural by remember { mutableStateOf("") }
    var target by remember { mutableIntStateOf(3) }
    var pile by remember { mutableStateOf(listOf<Int>()) }
    var inBasket by remember { mutableStateOf(listOf<Int>()) }
    var dragging by remember { mutableStateOf<Int?>(null) }
    val drag = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    var fingerStart by remember { mutableStateOf(Offset.Zero) }
    val itemFrames = remember { HashMap<Int, Rect>() }
    var basketFrame by remember { mutableStateOf(Rect.Zero) }
    var wiggle by remember { mutableIntStateOf(0) }
    var hint by remember { mutableStateOf<String?>(null) }
    var missedThisRound by remember { mutableStateOf(false) }
    // A full basket is on its way to the next one: ✅ waits (a double tap must not count it twice).
    var settling by remember { mutableStateOf(false) }
    var cleanCount by remember { mutableIntStateOf(0) }
    var doneCount by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }

    val cue = PreReaderCue(spoken = tr("שִׂימוּ %@ בַּסַּל!", PreReaderGames.countPhrase(target, plural)))

    fun deal() {
        val (e, p) = PreReaderGames.countables.random()
        emoji = e; plural = p
        val range = when (MiniGameLevel.dealLevel(Topic.MATH)) {
            Difficulty.EASY -> 2..4; Difficulty.MEDIUM -> 2..6; Difficulty.HARD -> 5..8
        }
        target = range.random()
        val extra = (2..4).random()
        pile = (0 until minOf(10, target + extra)).map { roundIndex * 100 + it }
        inBasket = emptyList()
        hint = null; missedThisRound = false; dragging = null; settling = false
        scope.launch { drag.snapTo(Offset.Zero) }
        shownAt = nowSecs()
        // (The cue card says "שִׂימוּ … בַּסַּל!" when it appears.)
    }

    fun start() {
        roundIndex = 0; doneCount = 0; cleanCount = 0; streak = 0; grant = null
        deal()
        phase = 1
    }

    fun finish() {
        if (phase != 1) return
        grant = MiniGameReward.grant("basket", doneCount, 1, 1, rounds, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
    }

    fun put(item: Int) {
        if (phase != 1 || item !in pile) return
        h.light()
        hint = null
        pile = pile - item
        inBasket = inBasket + item
        dragging = null
        scope.launch { drag.snapTo(Offset.Zero) }
    }

    fun takeOut(item: Int) {
        if (phase != 1 || item !in inBasket) return
        h.light()
        hint = null
        inBasket = inBasket - item
        pile = pile + item
    }

    fun check() {
        if (phase != 1 || inBasket.isEmpty() || settling) return
        if (inBasket.size == target) {
            val first = !missedThisRound
            if (first) { cleanCount++; streak++ }
            doneCount++
            MiniGameLedger.record(true, topicForLedger, (nowSecs() - shownAt) * 1000, streak, earn, surprise, retry = !first)
            burst++; confetti++
            play(AppSound.CORRECT_SMALL); h.success()
            GameEnv.speak(PreReaderGames.wellDone)
            settling = true
            scope.launch {
                delay(1400)
                if (phase != 1) return@launch
                if (roundIndex + 1 < rounds) { roundIndex++; deal() } else finish()
            }
        } else {
            if (!missedThisRound) {
                missedThisRound = true
                streak = 0
                MiniGameLedger.record(false, topicForLedger, earn = earn, surprise = surprise)
            }
            val line = if (inBasket.size < target) tr("כִּמְעַט! צָרִיךְ עוֹד.") else tr("כִּמְעַט! יֵשׁ קְצָת יוֹתֵר מִדַּי — הוֹצִיאוּ מֵהַסַּל.")
            hint = line
            wiggle++
            play(AppSound.WRONG_SOFT); h.light()
            GameEnv.speak(line)
        }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    @Composable
    fun PileItem(item: Int, side: Dp) {
        val isDragging = dragging == item
        Box(
            Modifier.size(side).zIndex(if (isDragging) 5f else 0f)
                .onGloballyPositioned { itemFrames[item] = it.boundsInRoot() }
                .graphicsLayer {
                    if (isDragging) { translationX = drag.value.x; translationY = drag.value.y }
                    val s = if (isDragging) 1.25f else 1f
                    scaleX = s; scaleY = s
                }
                .pointerInput(item) {
                    detectDragGestures(
                        onDragStart = { at ->
                            dragging = item
                            fingerStart = (itemFrames[item]?.topLeft ?: Offset.Zero) + at
                            scope.launch { drag.snapTo(Offset.Zero) }
                        },
                        onDrag = { change, amount -> change.consume(); scope.launch { drag.snapTo(drag.value + amount) } },
                        onDragEnd = {
                            if (basketFrame.inflate(20.dp.toPx()).contains(fingerStart + drag.value)) put(item)
                            else scope.launch {
                                drag.animateTo(Offset.Zero, spring(dampingRatio = 0.7f))
                                if (dragging == item) dragging = null
                            }
                        },
                        onDragCancel = { scope.launch { drag.snapTo(Offset.Zero); if (dragging == item) dragging = null } },
                    )
                }
                .clickable(remember { MutableInteractionSource() }, null) { put(item) },
            contentAlignment = Alignment.Center,
        ) { Text(emoji, fontSize = (side.value * 0.72f).sp) }
    }

    @Composable
    fun Basket(itemSide: Dp) {
        val small = itemSide * 0.78f
        val dx = shakeOffset(wiggle)
        Box(
            Modifier.fillMaxWidth()
                .onGloballyPositioned { basketFrame = it.boundsInRoot() }
                .graphicsLayer { translationX = dx * density }
                .semantics { contentDescription = "${inBasket.size} / $target" },
            contentAlignment = Alignment.TopCenter,
        ) {
            Column(
                Modifier.padding(top = 22.dp).fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                    .drawWithContent {
                        drawContent()
                        val w = 2.dp.toPx()
                        drawRoundRect(Color.White.copy(alpha = 0.55f), topLeft = Offset(w / 2, w / 2), size = Size(size.width - w, size.height - w),
                            cornerRadius = CornerRadius(16.dp.toPx()),
                            style = Stroke(w, pathEffect = PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx()))))
                    }
                    .padding(top = 26.dp, bottom = 8.dp, start = 10.dp, end = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // What is in the basket, five to a row — a tap takes one out.
                Column(Modifier.heightIn(min = small * 2 + 4.dp), verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.Bottom),
                    horizontalAlignment = Alignment.CenterHorizontally) {
                    inBasket.chunked(5).forEach { row ->
                        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            row.forEach { item ->
                                key(item) {
                                    val pop = remember { Animatable(0.3f) }
                                    LaunchedEffect(Unit) { pop.animateTo(1f, spring(dampingRatio = 0.7f)) }
                                    Box(Modifier.size(small).graphicsLayer { scaleX = pop.value; scaleY = pop.value; alpha = pop.value }
                                        .clickable(remember { MutableInteractionSource() }, null) { takeOut(item) },
                                        contentAlignment = Alignment.Center) {
                                        Text(emoji, fontSize = (small.value * 0.72f).sp)
                                    }
                                }
                            }
                        }
                    }
                }
                Text("🧺", fontSize = (if (m.compact) 46 else 60).sp, modifier = Modifier.offset(y = (-8).dp))
            }
            // The number the basket wants — read left to right like every number.
            Ltr {
                Row(
                    Modifier.clip(RoundedCornerShape(16.dp)).background(GoldBrush).padding(horizontal = 14.dp, vertical = 4.dp),
                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    Text("$target", color = Color(0xFF3A2700), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (if (m.compact) 30 else 38).sp)
                    Text(emoji, fontSize = (if (m.compact) 24 else 30).sp)
                }
            }
        }
    }

    val chip = "🍎 " + PreReaderChrome.dots(doneCount, rounds)
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered {
                PreReaderIntroCard(MiniGameKind.BASKET, PreReaderCue(spoken = tr("שִׂימוּ בַּסַּל בְּדִיּוּק כַּמָּה שֶׁצָּרִיךְ, וְלַחֲצוּ ✅"))) { start() }
            }
            2 -> Centered {
                PreReaderEndCard(
                    if (cleanCount == rounds) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"),
                    tr("מִלֵּאתֶם %lld סַלִּים", rounds), "🧺", doneCount, grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> {
                val itemSide = if (m.compact) 54.dp else 72.dp
                Column(
                    Modifier.weight(1f).widthIn(max = if (m.compact) 560.dp else 720.dp).fillMaxWidth()
                        .padding(horizontal = 16.dp).padding(bottom = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
                ) {
                    key(roundIndex) { PreReaderCueCard(cue, m.compact) }
                    val line = hint
                    Text(line ?: PreReaderChrome.streak(streak), color = if (line == null) KidColor.starGold else Color.White,
                        fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (line == null) 15 else 19).sp, textAlign = TextAlign.Center)
                    // The pile.
                    Column(Modifier.fillMaxWidth().heightIn(min = itemSide * 2 + 8.dp).zIndex(1f),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        pile.chunked(5).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { row.forEach { item -> key(item) { PileItem(item, itemSide) } } }
                        }
                    }
                    Spacer(Modifier.weight(1f))
                    Basket(itemSide)
                    val empty = inBasket.isEmpty()
                    Box(
                        Modifier.widthIn(max = if (m.compact) 220.dp else 300.dp).fillMaxWidth().height(if (m.compact) 62.dp else 78.dp)
                            .graphicsLayer { alpha = if (empty) 0.5f else 1f }
                            // (No glow while it waits: under a half-clear button the shadow turned it grey.)
                            .then(if (empty) Modifier else Modifier.shadow(10.dp, RoundedCornerShape(16.dp),
                                ambientColor = KidColor.starGold.copy(alpha = 0.4f), spotColor = KidColor.starGold.copy(alpha = 0.4f)))
                            .clip(RoundedCornerShape(16.dp)).background(GoldBrush)
                            .juicyClick(!empty) { check() }
                            .semantics { contentDescription = tr("סִיַּמְנוּ") },
                        contentAlignment = Alignment.Center,
                    ) { Text("✅", fontSize = (if (m.compact) 34 else 44).sp) }
                }
            }
        }
    }
}

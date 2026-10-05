package com.rani.tofy.kid.ui.shop

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.util.VelocityTracker
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.min
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.kid.ui.play.StarBurstOverlay
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * LuckyWheelView.swift — 8 glass wedges; tap the wheel (or flick it) to spin.
 * The winner is picked FIRST and the wheel lands on it; the prize is granted
 * through KidSession.edit. Entering consumes the earned free spin
 * (WorldMapView.maybeAutoPresentWheel → resetWheelProgress); with no spin
 * earned the wheel shows how many questions are left and can't be spun.
 */
@Composable
fun WheelScreenImpl(onExit: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidSounds.init(ctx); CosmeticStore.init(ctx); 0 }
    val view = LocalView.current
    val haptics = remember(view) { KidHaptics(view) }
    val scope = rememberCoroutineScope()

    val canSpin = remember { KidSession.engine()?.freeWheelAvailable == true }
    val untilWheel = remember { KidSession.engine()?.questionsUntilWheel ?: 0 }
    var wedges by remember { mutableStateOf(LuckyWheel.wedgesForSpin()) }
    LaunchedEffect(Unit) {
        KidSession.edit { e ->
            e.applyDailyRolloverIfNeeded()
            // Spend the earned spin on entry (closing via "skip" spends it too, like iOS).
            if (canSpin && e.freeWheelAvailable) e.resetWheelProgress()
            // No room for play-minutes today (cap full AND tomorrow's bank full) → no minute wedges.
            if (e.bonusMinutesRoom() <= 0) wedges = LuckyWheel.wedgesForSpin(excludeMinutes = true)
        }
    }

    val rotation = remember { Animatable(0f) }
    val drag = remember { Animatable(0f) }
    var spinning by remember { mutableStateOf(false) }
    var winner by remember { mutableStateOf<WheelPrize?>(null) }
    var message by remember { mutableStateOf("") }
    var confetti by remember { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }

    BackHandler(enabled = !spinning) { onExit() }

    fun spin() {
        if (!canSpin || spinning || winner != null || wedges.isEmpty()) return
        spinning = true
        KidSounds.play(AppSound.PORTAL_APPEAR)
        haptics.medium()
        val idx = LuckyWheel.winnerIndex(wedges.size)
        scope.launch {
            drag.snapTo(0f)
            // .easeOut(duration: 3.4) to the landing angle, prize at 3.5 s.
            rotation.animateTo(LuckyWheel.landingRotation(idx, wedges.size).toFloat(), tween(3400, easing = CubicBezierEasing(0f, 0f, 0.58f, 1f)))
            delay(100)
            val prize = wedges[idx]
            message = KidSession.edit { e ->
                LuckyWheel.apply(prize, e) { item ->
                    if (CosmeticStore.owns(item.id, e.local.ownedCosmetics)) false else { CosmeticStore.unlockFree(item.id); true }
                }
            } ?: ""
            KidSession.pushNow()
            winner = prize
            spinning = false
            KidSounds.play(if (prize.isPenalty) AppSound.WRONG_SOFT else AppSound.LEVEL_UP)
            haptics.success()
            if (!prize.isPenalty) { confetti++; burst++ }
        }
    }

    val pulseT = rememberInfiniteTransition(label = "pulse")
    val pulse by pulseT.animateFloat(1f, 1.02f, infiniteRepeatable(tween(1200), RepeatMode.Reverse), label = "p")

    GlassBackdrop {
        BoxWithConstraints(Modifier.fillMaxSize().systemBarsPadding()) {
            val landscape = maxWidth > maxHeight
            val wheelSize = min(380.dp, min(maxHeight * (if (landscape) 0.80f else 0.56f), maxWidth * (if (landscape) 0.46f else 0.98f)))
            val wheel = @Composable {
                WheelStack(
                    wedges, wheelSize, rotation.value + drag.value,
                    scale = if (canSpin && winner == null && !spinning) pulse else 1f,
                    onTap = { spin() },
                    onDrag = { d -> if (canSpin && !spinning && winner == null) scope.launch { drag.snapTo(d) } },
                    onDragEnd = { turned, flick ->
                        scope.launch { drag.animateTo(0f, tween(250)) }
                        // A real flick, or a decent pull — spin. A tiny nudge just settles back.
                        if (flick || abs(turned) > 40f) spin()
                    },
                )
            }
            val info = @Composable {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Header(winner != null, canSpin, untilWheel)
                    AnimatedVisibility(winner != null, enter = scaleIn() + fadeIn()) { winner?.let { WinnerCard(it, message) } }
                    val label = when {
                        winner != null || !canSpin -> if (winner != null) tr("אַחְלָה — סְגוֹר") else tr("סְגוֹר")
                        spinning -> tr("מִסְתּוֹבֵב…")
                        else -> tr("סוֹבֵב!")
                    }
                    KidCta(label, Color(0xFF5E60CE), Color(0xFF3E8BF0), Modifier.graphicsLayer { alpha = if (spinning && winner == null) 0.6f else 1f },
                        enabled = !(spinning && winner == null)) { if (winner != null || !canSpin) onExit() else spin() }
                    if (winner == null && canSpin) Text(
                        tr("דַּלֵּג הַפַּעַם"),
                        Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
                            .border(1.dp, Color.White.copy(alpha = 0.30f), RoundedCornerShape(50))
                            .clickable(enabled = !spinning) { haptics.light(); onExit() }.padding(horizontal = 16.dp, vertical = 9.dp),
                        color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp,
                    )
                }
            }
            if (landscape) {
                Row(Modifier.fillMaxSize().padding(24.dp), horizontalArrangement = Arrangement.spacedBy(32.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically) {
                    wheel()
                    Box(Modifier.widthIn(max = 380.dp)) { info() }
                }
            } else {
                Column(
                    Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
                ) {
                    Box(Modifier.padding(vertical = 8.dp)) { wheel() }
                    Box(Modifier.widthIn(max = 480.dp)) { info() }
                }
            }
        }
        // After the prize: a tap ANYWHERE continues.
        if (winner != null) Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, null) { haptics.light(); onExit() })
        StarBurstOverlay(burst)
        ConfettiOverlay(confetti)
    }
}

@Composable
private fun Header(won: Boolean, canSpin: Boolean, untilWheel: Int) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(tr("גַּלְגַּל מַזָּל!"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 30.sp, textAlign = TextAlign.Center)
        val sub = when {
            won -> tr("אֵיזֶה כֵּיף! 🎉")
            canSpin -> tr("הַקֵּשׁ עַל הַגַּלְגַּל כְּדֵי לְסוֹבֵב ✨")
            else -> tr("גַּלְגַּל בְּ-%lld", untilWheel)
        }
        Text(sub, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp, textAlign = TextAlign.Center)
    }
}

@Composable
private fun WinnerCard(prize: WheelPrize, message: String) {
    val tint = if (prize.isPenalty) KidColor.companionGlow else Color(0xFFFFD23F)
    Column(
        Modifier.widthIn(max = 420.dp).fillMaxWidth().tintedPane(tint).padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(prize.emoji, fontSize = 54.sp)
        Text(if (prize.isPenalty) tr("מְשִׂימָה מִשְׁפַּחְתִּית 🤗") else tr("זָכִיתָ!"),
            color = if (prize.isPenalty) KidColor.companionGlow else KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp)
        Text(prize.label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 24.sp, textAlign = TextAlign.Center)
        if (message.isNotEmpty()) Text(message, color = Color.White.copy(alpha = 0.8f), fontFamily = Rounded, fontWeight = FontWeight.Medium,
            fontSize = 14.sp, textAlign = TextAlign.Center, lineHeight = 19.sp)
    }
}

/**
 * The wheel is GEOMETRY: drawn LTR so the landing maths, the pointer and the
 * label offsets agree (on iOS the RTL mirror made it stop one wedge off). Each
 * label counter-rotates so it stays upright and readable, in the app's direction.
 */
@Composable
private fun WheelStack(
    wedges: List<WheelPrize>, size: Dp, rotation: Float, scale: Float,
    onTap: () -> Unit, onDrag: (Float) -> Unit, onDragEnd: (turned: Float, flick: Boolean) -> Unit,
) {
    val appDir = LocalLayoutDirection.current
    val density = LocalDensity.current
    // pointerInput(Unit) keeps its first lambdas — read the latest through these.
    val tap by rememberUpdatedState(onTap)
    val dragTo by rememberUpdatedState(onDrag)
    val dragEnd by rememberUpdatedState(onDragEnd)
    val n = wedges.size.coerceAtLeast(1)
    val per = 360f / n
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Box(Modifier.size(size), contentAlignment = Alignment.Center) {
            Box(
                Modifier.size(size).scale(scale)
                    .pointerInput(Unit) { detectTapGestures { tap() } }
                    .pointerInput(Unit) {
                        var start: Float? = null
                        var turned = 0f
                        val vt = VelocityTracker()
                        detectDragGestures(
                            onDragStart = { p -> start = angle(p, this.size.width / 2f); turned = 0f; vt.resetTracking() },
                            onDragEnd = {
                                val v = vt.calculateVelocity()
                                val flick = hypot(v.x, v.y) / density.density > 700f
                                start = null
                                dragEnd(turned, flick)
                            },
                            onDragCancel = { start = null; dragEnd(0f, false) },
                        ) { change, _ ->
                            vt.addPosition(change.uptimeMillis, change.position)
                            val s0 = start ?: return@detectDragGestures
                            var d = angle(change.position, this.size.width / 2f) - s0
                            if (d > 180) d -= 360; if (d < -180) d += 360
                            turned = d
                            dragTo(d)
                        }
                    }
                    .graphicsLayer { rotationZ = rotation },
                contentAlignment = Alignment.Center,
            ) {
                Canvas(Modifier.size(size)) {
                    val r = this.size.minDimension / 2
                    wedges.forEachIndexed { i, p ->
                        val start = i * per - 90f
                        drawArc(Color.White.copy(alpha = 0.16f), start, per, useCenter = true)
                        drawArc(
                            Brush.radialGradient(listOf(p.color.copy(alpha = 0.85f), p.color.copy(alpha = 0.45f)), center, r),
                            start, per, useCenter = true,
                        )
                        drawArc(Color.White.copy(alpha = 0.75f), start, per, useCenter = true, style = Stroke(2.dp.toPx()))
                    }
                    // Glass rim — a light edge; the wedges are the colour.
                    drawCircle(
                        Brush.verticalGradient(listOf(Color.White.copy(alpha = 0.95f), Color.White.copy(alpha = 0.5f))),
                        r - 3.5.dp.toPx(), style = Stroke(7.dp.toPx()),
                    )
                }
                // Every label above every fill, so none is washed out by the next wedge.
                wedges.forEachIndexed { i, p ->
                    val mid = Math.toRadians((i * per + per / 2 - 90).toDouble())
                    val dist = with(density) { (size * 0.33f).toPx() }
                    Column(
                        Modifier.offset { IntOffset((cos(mid) * dist).roundToInt(), (sin(mid) * dist).roundToInt()) }
                            .graphicsLayer { rotationZ = -rotation }.width(size * 0.25f),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp),
                    ) {
                        Text(p.emoji, fontSize = (size.value * 0.09f).sp)
                        CompositionLocalProvider(LocalLayoutDirection provides appDir) {
                            FitText(p.label, (size.value * 0.038f).sp, weight = FontWeight.Black, maxLines = 2, minScale = 0.6f)
                        }
                    }
                }
            }
            // Glass hub.
            Box(
                Modifier.size(size * 0.18f).clip(CircleShape).background(Color.White.copy(alpha = 0.26f))
                    .border(2.dp, Color.White.copy(alpha = 0.7f), CircleShape),
                contentAlignment = Alignment.Center,
            ) { Text("🎡", fontSize = (size.value * 0.10f).sp) }
            // The pointer at 12 o'clock.
            Canvas(Modifier.align(Alignment.TopCenter).offset(y = 8.dp).size(26.dp, 30.dp)) {
                val path = Path().apply {
                    moveTo(this@Canvas.size.width / 2, this@Canvas.size.height)
                    lineTo(0f, 0f); lineTo(this@Canvas.size.width, 0f); close()
                }
                drawPath(path, Color.Black.copy(alpha = 0.25f), alpha = 1f)
                translate(top = -2.dp.toPx()) { drawPath(path, Color.White) }
            }
        }
    }
}

/** Degrees of [p] around the centre of a square of side 2·[c]. */
private fun angle(p: Offset, c: Float): Float = Math.toDegrees(atan2((p.y - c).toDouble(), (p.x - c).toDouble())).toFloat()


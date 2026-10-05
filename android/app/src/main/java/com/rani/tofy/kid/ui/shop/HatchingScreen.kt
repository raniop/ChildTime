package com.rani.tofy.kid.ui.shop

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.zIndex
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.CompanionBubble
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.kid.ui.play.StarBurstOverlay
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private const val TEETH = 7
private const val SPLIT = 0.46f
private const val TOOTH = 0.05f

/**
 * HatchingView.swift — the onboarding egg: tap it, it shakes, cracks along a
 * zigzag, the top shell flies off and Tofy rises out of the bottom half. The
 * iOS companion is drawn with shapes; here it is the fox PNG.
 */
@Composable
fun HatchingScreen(onContinue: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidSounds.init(ctx); 0 }
    val view = LocalView.current
    val haptics = remember(view) { KidHaptics(view) }
    val scope = rememberCoroutineScope()

    var stage by remember { mutableIntStateOf(0) }
    val shake = remember { Animatable(0f) }
    val crack = remember { Animatable(0f) }
    val topOffset = remember { Animatable(0f) }
    val topRot = remember { Animatable(0f) }
    val topAlpha = remember { Animatable(1f) }
    val bottomTilt = remember { Animatable(0f) }
    val flash = remember { Animatable(0f) }
    var split by remember { mutableStateOf(false) }
    var companionVisible by remember { mutableStateOf(false) }
    val compScale = remember { Animatable(0.2f) }
    val compY = remember { Animatable(0f) }
    var bubble by remember { mutableStateOf(false) }
    var confetti by remember { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }

    val eggW = 150.dp
    val eggH = eggW * 1.32f
    val companionSize = 130.dp

    fun CoroutineScope.jitter(a: Float, times: Int, ms: Int) = launch {
        repeat(times) { shake.animateTo(if (it % 2 == 0) a else -a, tween(ms)) }
        shake.animateTo(0f, tween(ms))
    }

    fun start() {
        stage = 1
        KidSounds.play(AppSound.STREAK_UP)
        haptics.medium()
        scope.launch {
            // 1) A few hard shakes.
            repeat(3) { i ->
                launch { delay(i * 400L); jitter(14f, 5, 35); haptics.medium(); KidSounds.play(AppSound.UI_TAP) }
            }
            // 2) The crack draws across the shell.
            delay(1350)
            stage = 2
            KidSounds.play(AppSound.PORTAL_APPEAR)
            haptics.heavy()
            launch { crack.animateTo(1f, tween(500)) }
            jitter(8f, 4, 30)
            // 3) Split! The top flies up, Tofy bursts out.
            delay(700)
            stage = 3
            split = true
            flash.snapTo(0.95f)
            launch { flash.animateTo(0f, tween(500)) }
            burst++; confetti++
            KidSounds.play(AppSound.COMPANION_CHEER)
            haptics.success()
            val hPx = eggH.value * view.resources.displayMetrics.density
            launch { topOffset.animateTo(-hPx * 1.1f, tween(700)) }
            launch { topRot.animateTo(-28f, tween(700)) }
            launch { topAlpha.animateTo(0f, tween(700)) }
            launch { bottomTilt.animateTo(-3f, tween(700)) }
            companionVisible = true
            compY.snapTo(hPx * 0.12f)
            launch { compScale.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = 120f)) }
            launch { compY.animateTo(-hPx * 0.32f, spring(dampingRatio = 0.5f, stiffness = 120f)) }
            // 4) The bubble, then the way on.
            delay(1350); bubble = true
            delay(1600); stage = 4
        }
    }

    val idle = rememberInfiniteTransition(label = "idle")
    val wobble by idle.animateFloat(-5f, 5f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "w")

    Box(
        Modifier.fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF5E60CE), Color.Black, KidColor.gemPurple)))
            .clickable(remember { MutableInteractionSource() }, null) { if (stage == 0) start() },
    ) {
        Column(Modifier.fillMaxSize().systemBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally) {
            Spacer(Modifier.weight(1f))
            Box(Modifier.height(320.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
                // Warm glow behind.
                Box(Modifier.size(eggW * 2.2f).background(Brush.radialGradient(listOf(KidColor.starGold.copy(alpha = 0.45f), Color.Transparent)), CircleShape))
                Box(
                    Modifier.size(eggW, eggH).graphicsLayer {
                        translationX = shake.value * density
                        rotationZ = if (stage == 0) wobble else 0f
                        transformOrigin = TransformOrigin(0.5f, 1f)
                    },
                ) {
                    // Bottom shell (in front of the companion, so Tofy "emerges").
                    Canvas(Modifier.fillMaxSize().zIndex(3f).graphicsLayer { rotationZ = bottomTilt.value; transformOrigin = TransformOrigin(0.5f, 1f) }) {
                        clipPath(shellMask(size, top = false)) { drawEgg() }
                    }
                    if (companionVisible) ShopCharImage(
                        CharacterCatalog.DEFAULT_ID,
                        Modifier.align(Alignment.Center).size(companionSize).zIndex(2f)
                            .graphicsLayer { scaleX = compScale.value; scaleY = compScale.value; translationY = compY.value },
                    )
                    Canvas(Modifier.fillMaxSize().zIndex(if (split) 4f else 1f).graphicsLayer {
                        translationY = topOffset.value; rotationZ = topRot.value; alpha = topAlpha.value
                    }) { clipPath(shellMask(size, top = true)) { drawEgg() } }
                    if (stage >= 2 && !split) Canvas(Modifier.fillMaxSize().zIndex(5f)) {
                        val full = crackPath(size)
                        val pm = PathMeasure().apply { setPath(full, false) }
                        val part = Path().also { pm.getSegment(0f, pm.length * crack.value, it, true) }
                        drawPath(part, Color(0xCC6E4B1A), style = Stroke(3.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
                    }
                }
                // The bright flash at the moment of hatching.
                if (flash.value > 0f) Box(
                    Modifier.size(eggW * 2.4f).graphicsLayer { scaleX = 0.4f + flash.value; scaleY = 0.4f + flash.value; alpha = flash.value }
                        .background(Brush.radialGradient(listOf(Color.White, Color.White.copy(alpha = 0f))), CircleShape),
                )
            }
            AnimatedVisibility(bubble, enter = scaleIn() + fadeIn()) {
                CompanionBubble(tr("הֵיי! חִכִּיתִי לְךָ... אֲנִי טוֹפִי! 💫"))
            }
            Spacer(Modifier.weight(1f))
            AnimatedVisibility(stage >= 4, enter = fadeIn()) {
                KidCta(tr("בּוֹאוּ נֵצֵא לְהַרְפַּתְקָה!"), Color(0xFFFFD23F), Color(0xFFFFB547),
                    Modifier.padding(horizontal = 32.dp, vertical = 32.dp).widthIn(max = 480.dp), size = 22) { onContinue() }
            }
        }
        if (stage == 0) {
            val pulse = rememberInfiniteTransition(label = "p")
            val ps by pulse.animateFloat(0.95f, 1.06f, infiniteRepeatable(tween(650), RepeatMode.Reverse), label = "ps")
            Text(tr("לַחֲצוּ עַל הַבֵּיצָה"), Modifier.align(Alignment.BottomCenter).systemBarsPadding().padding(bottom = 180.dp).scale(ps),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 22.sp, textAlign = TextAlign.Center)
        }
        StarBurstOverlay(burst)
        ConfettiOverlay(confetti)
    }
}

// ── egg geometry (EggShape / ShellMask / CrackLine) ─────────────────────────

private fun eggPath(s: Size): Path = Path().apply {
    val w = s.width; val h = s.height; val cx = w / 2
    moveTo(cx, h)
    cubicTo(0f, h - h * 0.16f, w * 0.13f, 0f, cx, 0f)
    cubicTo(w - w * 0.13f, 0f, w, h - h * 0.16f, cx, h)
    close()
}

private fun Path.zigzag(s: Size) {
    val midY = s.height * SPLIT; val toothH = s.height * TOOTH; val step = s.width / TEETH
    for (i in 0 until TEETH) lineTo(step * (i + 0.5f), midY + if (i % 2 == 0) -toothH else toothH)
    lineTo(s.width, midY)
}

/** A rectangle whose dividing edge is the zigzag — clips the egg into two shells that fit together. */
private fun shellMask(s: Size, top: Boolean): Path = Path().apply {
    val edge = if (top) 0f else s.height
    moveTo(0f, edge); lineTo(0f, s.height * SPLIT); zigzag(s); lineTo(s.width, edge); close()
}

private fun crackPath(s: Size): Path = Path().apply { moveTo(0f, s.height * SPLIT); zigzag(s) }

/** The cream egg with speckles and a soft highlight. */
private fun DrawScope.drawEgg() {
    val egg = eggPath(size)
    clipPath(egg) {
        drawRect(Brush.verticalGradient(listOf(Color(0xFFFFFDF5), Color(0xFFFBE7BC), Color(0xFFF1CE92))))
        for ((x, y, d) in listOf(Triple(0.34f, 0.5f, 0.10f), Triple(0.62f, 0.4f, 0.07f), Triple(0.5f, 0.66f, 0.09f), Triple(0.7f, 0.62f, 0.06f), Triple(0.4f, 0.78f, 0.05f))) {
            val ew = size.width * d
            drawOval(Color(0x8CD7AE62), Offset(size.width * x - ew / 2, size.height * y - ew * 0.4f), Size(ew, ew * 0.8f))
        }
        drawOval(
            Brush.radialGradient(listOf(Color.White.copy(alpha = 0.35f), Color.Transparent), Offset(size.width * 0.36f, size.height * 0.28f), size.width * 0.2f),
            Offset(size.width * 0.21f, size.height * 0.17f), Size(size.width * 0.3f, size.height * 0.22f),
        )
    }
    drawPath(egg, Color(0xB3E4C385), style = Stroke(2.dp.toPx()))
}


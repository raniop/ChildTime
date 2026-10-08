package com.rani.tofy.kid.ui.play

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.R
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin
import kotlin.random.Random

// ── Companion (CompanionState.swift) ────────────────────────────────────────

enum class CompanionMood { IDLE, CHEER, HYPE, WOW, CONSOLE }

/**
 * CompanionController: a mood + a speech bubble held long enough to READ
 * (~0.55 s per word + 2.6 s, never under 4 s). Each mood has its iOS sound/haptic.
 */
class CompanionController(private val scope: CoroutineScope, private val haptics: () -> KidHaptics?) {
    var mood by mutableStateOf(CompanionMood.IDLE); private set
    var bubble by mutableStateOf<String?>(null); private set
    /** Bumps on every reaction so the buddy can hop. */
    var pulse by mutableStateOf(0); private set
    private var hold: Job? = null

    fun cheer(text: String? = null) { react(CompanionMood.CHEER, text, 1.4); KidSounds.play(AppSound.COMPANION_CHEER); haptics()?.light() }
    fun hype(text: String? = null) { react(CompanionMood.HYPE, text, 1.6); KidSounds.play(AppSound.STREAK_UP); haptics()?.medium() }
    fun wow(text: String? = null) { react(CompanionMood.WOW, text, 2.0); KidSounds.play(AppSound.PORTAL_APPEAR); haptics()?.heavy() }
    fun console(text: String? = null) { react(CompanionMood.CONSOLE, text ?: com.rani.tofy.i18n.tr("כִּמְעַט!"), 1.6); haptics()?.soft() }

    private fun react(m: CompanionMood, text: String?, idleAfter: Double) {
        mood = m; bubble = text; pulse++
        hold?.cancel()
        val words = max(1, text?.split(" ")?.size ?: 1)
        val visible = max(4.0, words * 0.55 + 2.6)
        hold = scope.launch {
            delay((idleAfter * 1000).toLong())
            mood = CompanionMood.IDLE
            delay(((visible - idleAfter).coerceAtLeast(0.0) * 1000).toLong())
            if (mood == CompanionMood.IDLE) bubble = null
        }
    }
}

/** The equipped character (R.drawable.char_<id>), falling back to the fox. */
@Composable
fun characterRes(characterID: String?): Int {
    val ctx = LocalContext.current
    return remember(characterID) {
        characterID?.let { ctx.resources.getIdentifier("char_$it", "drawable", ctx.packageName) }?.takeIf { it != 0 } ?: R.drawable.char_fox
    }
}

/** The buddy: hops on every reaction, wiggles when hyped. */
@Composable
fun CompanionBuddy(controller: CompanionController, characterID: String?, size: Dp, modifier: Modifier = Modifier) {
    val hop = remember { Animatable(0f) }
    LaunchedEffect(controller.pulse) {
        if (controller.pulse == 0) return@LaunchedEffect
        hop.animateTo(-1f, tween(140, easing = FastOutSlowInEasing))
        hop.animateTo(0f, spring(dampingRatio = 0.35f, stiffness = Spring.StiffnessMediumLow))
    }
    val tilt = when (controller.mood) { CompanionMood.HYPE, CompanionMood.WOW -> 8f; CompanionMood.CONSOLE -> -4f; else -> 0f }
    val rot by animateFloatAsState(tilt, spring(dampingRatio = 0.4f), label = "tilt")
    Image(
        painterResource(characterRes(characterID)), null,
        modifier.size(size).graphicsLayer { translationY = hop.value * size.toPx() * 0.22f; rotationZ = rot },
    )
}

/** The speech bubble (BubbleSpeech). */
@Composable
fun CompanionBubble(text: String?, modifier: Modifier = Modifier) {
    AnimatedVisibility(text != null, modifier, enter = scaleIn() + fadeIn(), exit = fadeOut()) {
        var last by remember { mutableStateOf("") }
        if (text != null) last = text
        Text(
            last, color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp,
            textAlign = TextAlign.Center, lineHeight = 18.sp,
            modifier = Modifier.widthIn(max = 240.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.95f))
                .padding(horizontal = 12.dp, vertical = 8.dp),
        )
    }
}

// ── Text that shrinks instead of breaking (SwiftUI minimumScaleFactor) ──────

@Composable
fun FitText(
    text: String, size: TextUnit, modifier: Modifier = Modifier, color: Color = Color.White,
    weight: FontWeight = FontWeight.Bold, maxLines: Int = 2, minScale: Float = 0.45f,
    align: TextAlign = TextAlign.Center, decoration: TextDecoration? = null,
) {
    var scale by remember(text, size) { mutableStateOf(1f) }
    // ContentOrLtr: a Hebrew prompt still reads right-to-left (first strong
    // letter), but pure math like "6 × 4 + 17 = ?" has no letters at all — with
    // the default it fell back to the RTL layout and showed "? = 17 + 4 × 6".
    Text(
        text, modifier, style = androidx.compose.material3.LocalTextStyle.current.copy(textDirection = androidx.compose.ui.text.style.TextDirection.ContentOrLtr),
        color = color, fontFamily = Rounded, fontWeight = weight, fontSize = size * scale,
        lineHeight = size * scale * 1.2f, textAlign = align, maxLines = maxLines, softWrap = true, textDecoration = decoration,
        onTextLayout = { r -> if ((r.hasVisualOverflow || r.didOverflowWidth) && scale > minScale) scale = (scale * 0.9f).coerceAtLeast(minScale) },
    )
}

// ── Answer tile (OptionCard.swift) ──────────────────────────────────────────

enum class OptionFeedback { NORMAL, CORRECT, WRONG, REVEALED, DIMMED, ELIMINATED }

private val optionTints = listOf(Color(0xFF8CFFC4), Color(0xFFB7ABFF), Color(0xFFFFD23F), Color(0xFF7CF3FF))

/**
 * Glass answer: every option the same pane with its palette colour glowing
 * through; right turns mint, a miss turns warm; a hint-removed option gets a 💡
 * badge + strikethrough. The number tag rides the top edge.
 */
@Composable
fun OptionCard(text: String, feedback: OptionFeedback, index: Int, minHeight: Dp, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val longest = text.split(" ").maxOfOrNull { it.length } ?: text.length
    val fontSize = when { longest >= 11 -> 19.sp; longest >= 8 -> 25.sp; text.length >= 16 -> 23.sp; else -> 30.sp }
    val shape = RoundedCornerShape(16.dp)
    val scale by animateFloatAsState(
        when (feedback) {
            OptionFeedback.CORRECT, OptionFeedback.REVEALED -> 1.05f; OptionFeedback.WRONG -> 0.97f
            OptionFeedback.DIMMED -> 0.95f; OptionFeedback.ELIMINATED -> 0.92f; else -> 1f
        }, spring(dampingRatio = 0.6f, stiffness = Spring.StiffnessMediumLow), label = "opt",
    )
    val border = when (feedback) {
        OptionFeedback.CORRECT, OptionFeedback.REVEALED -> Color(0xFF8CFFC4).copy(alpha = 0.9f)
        OptionFeedback.WRONG -> Color(0xFFFF9AA0).copy(alpha = 0.9f)
        OptionFeedback.ELIMINATED -> KidColor.starGold.copy(alpha = 0.8f)
        else -> Color.White.copy(alpha = 0.32f)
    }
    val bw = when (feedback) { OptionFeedback.CORRECT, OptionFeedback.WRONG, OptionFeedback.REVEALED -> 2.dp; OptionFeedback.ELIMINATED -> 1.5.dp; else -> 1.dp }
    val tint = optionTints[index % optionTints.size]
    Box(modifier.scale(scale).graphicsLayer { alpha = if (feedback == OptionFeedback.ELIMINATED) 0.55f else 1f }) {
        Box(
            Modifier.fillMaxWidth().heightIn(min = minHeight).clip(shape)
                .background(Color.White.copy(alpha = if (feedback == OptionFeedback.DIMMED) 0.06f else 0.14f))
                .then(if (feedback == OptionFeedback.NORMAL || feedback == OptionFeedback.ELIMINATED)
                    Modifier.background(Brush.radialGradient(listOf(tint.copy(alpha = 0.55f), Color.Transparent), center = Offset(90f, 50f), radius = 600f))
                else Modifier)
                .background(Brush.verticalGradient(0f to Color.White.copy(alpha = 0.22f), 0.2f to Color.Transparent))
                .background(
                    when (feedback) {
                        OptionFeedback.CORRECT, OptionFeedback.REVEALED -> Brush.linearGradient(listOf(Color(0xFF06D6A0).copy(alpha = 0.55f), Color(0xFF5CFF9D).copy(alpha = 0.35f)))
                        OptionFeedback.WRONG -> Brush.linearGradient(listOf(Color(0xFFFF6B6B).copy(alpha = 0.5f), Color(0xFFFF9AA0).copy(alpha = 0.3f)))
                        OptionFeedback.ELIMINATED -> Brush.linearGradient(listOf(Color(0x1FFFD23F), Color(0x1FFFD23F)))
                        else -> Brush.linearGradient(listOf(Color.Transparent, Color.Transparent))
                    },
                )
                .border(bw, border, shape)
                .clickable(enabled = feedback == OptionFeedback.NORMAL, onClick = onClick)
                .padding(horizontal = 14.dp, vertical = 8.dp),
            contentAlignment = Alignment.Center,
        ) {
            val mark = if (feedback == OptionFeedback.CORRECT || feedback == OptionFeedback.REVEALED) "✓ " else ""
            FitText(mark + text, fontSize, decoration = if (feedback == OptionFeedback.ELIMINATED) TextDecoration.LineThrough else null)
            if (feedback == OptionFeedback.ELIMINATED) {
                Box(Modifier.align(Alignment.TopEnd).size(28.dp).clip(CircleShape).background(KidColor.starGold), contentAlignment = Alignment.Center) {
                    Text("💡", fontSize = 15.sp)
                }
            }
        }
        // Number tag riding the tile's top edge, centred.
        Box(
            Modifier.align(Alignment.TopCenter).offset(y = (-11).dp).size(22.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.92f)),
            contentAlignment = Alignment.Center,
        ) { Text("${index + 1}", color = Ink.indigo, fontSize = 11.sp, fontWeight = FontWeight.ExtraBold, fontFamily = Rounded) }
    }
}

// ── Small glass bits ────────────────────────────────────────────────────────

@Composable
fun QuizChip(text: String, color: Color = Color.White, modifier: Modifier = Modifier, onClick: (() -> Unit)? = null) {
    Box(
        modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.30f), RoundedCornerShape(16.dp))
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) { Text(text, color = color, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp, maxLines = 1) }
}

/** cardIconButton — the round 36pt controls of the tool row. */
@Composable
fun RoundIconButton(emoji: String, bg: Color, glow: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.size(40.dp)
            .then(if (glow) Modifier.background(Brush.radialGradient(listOf(KidColor.starGold.copy(alpha = 0.6f), Color.Transparent)), CircleShape) else Modifier)
            .clip(CircleShape).background(bg).border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(emoji, fontSize = 16.sp) }
}

/** The flying "+X דקות 🎮" popup (EarnedMinutesPopup): pops at the centre, then flies up to the timer. */
@Composable
fun EarnedMinutesPopup(minutes: Int, trigger: Int, modifier: Modifier = Modifier) {
    val y = remember { Animatable(30f) }
    val a = remember { Animatable(0f) }
    val s = remember { Animatable(0.4f) }
    LaunchedEffect(trigger) {
        if (trigger == 0) return@LaunchedEffect
        y.snapTo(30f); a.snapTo(0f); s.snapTo(0.4f)
        launch { y.animateTo(-20f, spring(dampingRatio = 0.55f)) }
        launch { s.animateTo(1f, spring(dampingRatio = 0.55f)) }
        a.animateTo(1f, tween(200))
        delay(550)
        launch { y.animateTo(-300f, tween(550, easing = LinearEasing)) }
        launch { s.animateTo(0.5f, tween(550)) }
        a.animateTo(0f, tween(550))
    }
    if (a.value > 0.01f) Box(modifier.graphicsLayer { translationY = y.value * density; alpha = a.value; scaleX = s.value; scaleY = s.value }) {
        Text(
            "+$minutes ${com.rani.tofy.i18n.tr("דַּקּוֹת")} 🎮", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp,
            modifier = Modifier.clip(RoundedCornerShape(16.dp)).background(Ink.deep.copy(alpha = 0.7f))
                .border(3.dp, KidColor.successMint, RoundedCornerShape(16.dp)).padding(horizontal = 24.dp, vertical = 14.dp),
        )
    }
}

// ── Effects (StarBurst / FancyConfetti / rumble) ────────────────────────────

private data class Particle(val angle: Float, val dist: Float, val color: Color, val size: Float, val spin: Float, val x0: Float)

private val confettiColors = listOf(KidColor.starGold, KidColor.gemPurple, KidColor.successMint, KidColor.diamondBlue, KidColor.flameOrange, Color(0xFFFF7BD3))

/** FancyConfetti: a shower from the top on every trigger bump. */
@Composable
fun ConfettiOverlay(trigger: Int, modifier: Modifier = Modifier) {
    val t = remember { Animatable(1f) }
    val parts = remember(trigger) {
        List(48) { Particle(0f, 0.6f + Random.nextFloat() * 0.5f, confettiColors[it % confettiColors.size], 6f + Random.nextFloat() * 7f, Random.nextFloat() * 720f - 360f, Random.nextFloat()) }
    }
    LaunchedEffect(trigger) { if (trigger > 0) { t.snapTo(0f); t.animateTo(1f, tween(1800, easing = LinearEasing)) } }
    if (t.value < 1f) Canvas(modifier.fillMaxSize()) {
        parts.forEachIndexed { i, p ->
            val x = p.x0 * size.width + sin((t.value * 6 + i).toDouble()).toFloat() * 18f
            val y = -20f + t.value * size.height * p.dist * 1.2f
            val alpha = (1f - t.value).coerceIn(0f, 1f)
            drawRect(p.color.copy(alpha = alpha), Offset(x, y), Size(p.size, p.size * 1.6f))
        }
    }
}

/** StarBurst: sparks fly out from the centre on a right answer / hint. */
@Composable
fun StarBurstOverlay(trigger: Int, color: Color = KidColor.starGold, modifier: Modifier = Modifier) {
    val t = remember { Animatable(1f) }
    LaunchedEffect(trigger) { if (trigger > 0) { t.snapTo(0f); t.animateTo(1f, tween(700)) } }
    if (t.value < 1f) Canvas(modifier.fillMaxSize()) {
        val c = Offset(size.width / 2, size.height * 0.42f)
        for (i in 0 until 14) {
            val a = i / 14f * 6.283f
            val d = t.value * size.minDimension * 0.42f
            drawCircle(color.copy(alpha = 1f - t.value), radius = 7f * (1f - t.value * 0.5f), center = Offset(c.x + cos(a) * d, c.y + sin(a) * d))
        }
    }
}

/** .rumble — a short shake of the whole screen on big moments. */
@Composable
fun rumbleOffset(trigger: Int): Float {
    val x = remember { Animatable(0f) }
    LaunchedEffect(trigger) {
        if (trigger == 0) return@LaunchedEffect
        repeat(4) { x.animateTo(if (it % 2 == 0) 9f else -9f, tween(45)) }
        x.animateTo(0f, tween(45))
    }
    return x.value
}

/** A full-screen tap-catcher that blocks the content under an overlay. */
@Composable
fun BoxScope.Scrim(color: Color) {
    Box(Modifier.matchParentSize().background(color).clickable(remember { MutableInteractionSource() }, null) {})
}

@Composable
fun GlassLine(text: String, modifier: Modifier = Modifier) {
    Text(
        text, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp, maxLines = 1,
        textAlign = TextAlign.Center, modifier = modifier.fillMaxWidth().glassInset(16.dp).padding(vertical = 9.dp, horizontal = 12.dp),
    )
}

@Composable
fun GlassCard(modifier: Modifier = Modifier, radius: Dp = 22.dp, content: @Composable BoxScope.() -> Unit) =
    Box(modifier.glassPane(radius), content = content)

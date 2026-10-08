package com.rani.tofy.kid.ui.games

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.togetherWith
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.EarnedMinutesPopup
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.kid.ui.play.clockLabel
import com.rani.tofy.kid.ui.play.currencyShort
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.sin
import kotlin.random.Random

// 🎮 MiniGameKit.swift — the pieces every game is built from, all out of the
// app's own glass kit (GlassBackdrop, glassPane, the runner's chips, the answer
// tiles' mint-for-right / soft-warm-for-a-miss), so a game looks like Tofy.

// MARK: - Screen metrics, sound, haptics

/** hsc == .compact (a phone) and DisplayGeometry.isShort (a phone on its side). */
data class GameMetrics(val compact: Boolean, val short: Boolean) { val roomy: Boolean get() = !compact && !short }

@Composable
fun gameMetrics(): GameMetrics {
    val c = LocalConfiguration.current
    return GameMetrics(compact = c.screenWidthDp < 600, short = c.screenHeightDp < 480)
}

@Composable
fun rememberHaptics(): KidHaptics {
    val v = LocalView.current
    return remember(v) { KidHaptics(v) }
}

internal fun play(s: AppSound) = runCatching { KidSounds.play(s) }.let { }

/** Hex "FF6B9D" → Color. */
internal fun hexColor(hex: String): Color = Color(("FF$hex").toLong(16))

/** A gentle bob (`.float(amplitude:)`). */
@Composable
fun Modifier.floating(amplitude: Float = 6f): Modifier {
    val t = rememberInfiniteTransition(label = "float")
    val y by t.animateFloat(0f, -amplitude, infiniteRepeatable(tween(1300), RepeatMode.Reverse), label = "float")
    return this.graphicsLayer { translationY = y * density }
}

/** MiniGameShake: a small horizontal shake on every `trigger` bump — the only thing a miss does to the screen. */
@Composable
fun shakeOffset(trigger: Int): Float {
    val x = remember { Animatable(0f) }
    LaunchedEffect(trigger) {
        if (trigger == 0) return@LaunchedEffect
        x.snapTo(0f)
        x.animateTo(1f, tween(350))
        x.snapTo(0f)
    }
    return (sin(x.value * PI * 4) * 8).toFloat()
}

/** Lays math / numbers out left-to-right whatever the app direction (`.mathLTR()`). */
@Composable
fun Ltr(on: Boolean = true, content: @Composable () -> Unit) {
    if (on) CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr, content = content) else content()
}

/** Text that shrinks to fit, with math shown left-to-right (MiniGameText.show). */
@Composable
fun GameText(
    text: String, size: TextUnit, modifier: Modifier = Modifier, color: Color = Color.White,
    weight: FontWeight = FontWeight.ExtraBold, maxLines: Int = 2, minScale: Float = 0.5f, align: TextAlign = TextAlign.Center,
) {
    val math = MiniGameText.isMath(text)
    Ltr(math) { FitText(MiniGameText.show(text), size, modifier, color, weight, maxLines, minScale, align) }
}

// MARK: - Backdrop & top bar (the runner's)

/** SparkleField: a few twinkling dots over the glass. */
@Composable
fun SparkleField(count: Int = 10, size: Float = 11f, modifier: Modifier = Modifier) {
    val dots = remember(count) { List(count) { Triple(Random.nextFloat(), Random.nextFloat(), Random.nextFloat() * 6.28f) } }
    val t = rememberInfiniteTransition(label = "sparkle")
    val phase by t.animateFloat(0f, 6.28f, infiniteRepeatable(tween(4000)), label = "phase")
    Canvas(modifier.fillMaxSize()) {
        dots.forEach { (x, y, p) ->
            val a = (0.25f + 0.35f * (1 + sin(phase + p)) / 2f)
            drawCircle(Color.White.copy(alpha = a), radius = size * 0.22f * density, center = Offset(x * this.size.width, y * this.size.height))
        }
    }
}

/** The runner's backdrop, one to one. */
@Composable
fun MiniGameBackdrop(content: @Composable BoxScope.() -> Unit) {
    GlassBackdrop {
        SparkleField(10, 11f)
        content()
    }
}

/** A glass chip — the runner's quizChip. */
@Composable
fun MiniGameChip(modifier: Modifier = Modifier, onClick: (() -> Unit)? = null, content: @Composable () -> Unit) {
    Box(
        modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.30f), RoundedCornerShape(50))
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) { content() }
}

@Composable
fun ChipText(text: String, color: Color = Color.White) =
    // "⭐ 213", emoji first, like iOS — an RTL paragraph flipped it to "213 ⭐"
    // (Rani: "הכוכבים והיהלומים לא יושבים שם תקין"). A chip holds an emoji and
    // a number, never a sentence, so it always reads left to right.
    Text("\u200E" + text, color = color, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp, maxLines = 1,
        style = androidx.compose.ui.text.TextStyle(textDirection = androidx.compose.ui.text.style.TextDirection.Ltr))

/** The game chip, with "×2" during a surprise round. */
@Composable
fun MiniGameChipLabel(text: String, surprise: Boolean = false) {
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
        ChipText(text)
        if (surprise) ChipText("×2", KidColor.starGold)
    }
}

/** The runner's top row: ✕ · 💎 · ⭐ · the game's own chip (+ the earned-time bar from a chooser). */
@Composable
fun MiniGameTopBar(onClose: () -> Unit, earn: MiniGameEarnSession? = null, gameChip: @Composable () -> Unit) {
    val state by KidSession.state.collectAsState()
    val snap = state?.snapshot
    Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            MiniGameChip(onClick = onClose) { Text("✕", color = Color.White, fontWeight = FontWeight.Black, fontSize = 13.sp) }
            Spacer(Modifier.weight(1f))
            MiniGameChip { ChipText("💎 ${(snap?.diamonds ?: 0).currencyShort()}", KidColor.diamondBlue) }
            MiniGameChip { ChipText("⭐ ${(snap?.stars ?: 0).currencyShort()}", KidColor.starGold) }
            MiniGameChip { gameChip() }
        }
        if (earn != null) MiniGameEarnBar()
    }
}

/** The runner's earned-time bar: the child's REAL balance, to the second (each "+24 שניות" lands in it). */
@Composable
fun MiniGameEarnBar() {
    EarnedBalanceRow(Modifier.fillMaxWidth().glassPane(14.dp).padding(horizontal = 12.dp, vertical = 7.dp), size = 13f)
}

/**
 * "⏱ 23:47 דַּקּ׳ לְשַׂחֵק" — the earned wallet, the same number the home screen
 * and "פתחו לי" show (iOS EarnedBalanceRow). It used to be a bar toward the next
 * batch of 10, which the home screen never showed (Rani, 2026-10-06).
 */
@Composable
fun EarnedBalanceRow(modifier: Modifier = Modifier, size: Float = 14f) {
    val state by KidSession.state.collectAsState()
    val secs = remember(state) { KidSession.engine()?.openableSeconds(false) ?: 0 }
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("⏱", fontSize = (size + 1).sp)
        Ltr {
            AnimatedContent(secs, transitionSpec = { (slideInVertically { it } + fadeIn()) togetherWith (slideOutVertically { -it } + fadeOut()) },
                label = "balance") { v ->
                Text("%d:%02d".format(v / 60, v % 60), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (size + 3).sp)
            }
        }
        Text(tr("דַּקּ׳ לְשַׂחֵק"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = (size - 1).sp, maxLines = 1)
        Spacer(Modifier.weight(1f))
    }
}

/** A capsule track with a gold fill (start → end in the app's direction). */
@Composable
fun GoldBar(frac: Float, modifier: Modifier = Modifier, colors: List<Color> = listOf(Color(0xFFFFD23F), Color(0xFFFF9F1C))) {
    Box(modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.18f))) {
        Box(Modifier.fillMaxHeight().fillMaxWidth(frac.coerceIn(0.02f, 1f)).clip(RoundedCornerShape(50)).background(Brush.horizontalGradient(colors)))
    }
}

/** Every game's timer: the gold bar, a clock and the seconds left. */
@Composable
fun MiniGameTimerBar(remaining: Double, total: Double) {
    val frac = if (total > 0) (remaining / total).coerceIn(0.0, 1.0).toFloat() else 0f
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("⏱", fontSize = 14.sp)
        GoldBar(frac, Modifier.weight(1f).height(8.dp))
        Text("${Math.ceil(remaining).toInt()}″", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
            fontSize = 14.sp, modifier = Modifier.widthIn(min = 30.dp))
    }
}

// MARK: - Glass tiles (the answer cards' look)

enum class TileState { NORMAL, PICKED, CORRECT, WRONG }

/** The tints the answer tiles glow with (OptionCard.tints). */
val TileTints = listOf(Color(0xFF8CFFC4), Color(0xFFB7ABFF), Color(0xFFFFD23F), Color(0xFF7CF3FF))

/** A pane of glass with its own colour glowing through; mint when right, soft warm for a miss, gold edge when picked. */
fun Modifier.miniGameTile(state: TileState, tint: Color, radius: Dp = 22.dp): Modifier {
    val shape = RoundedCornerShape(radius)
    val border = when (state) {
        TileState.CORRECT -> Color(0xFF8CFFC4).copy(alpha = 0.9f)
        TileState.WRONG -> Color(0xFFFF9AA0).copy(alpha = 0.9f)
        TileState.PICKED -> KidColor.starGold
        TileState.NORMAL -> Color.White.copy(alpha = 0.32f)
    }
    val bw = when (state) { TileState.NORMAL -> 1.dp; TileState.PICKED -> 2.5.dp; else -> 2.dp }
    return this.clip(shape)
        .background(Color.White.copy(alpha = if (state == TileState.PICKED) 0.22f else 0.14f))
        .then(if (state == TileState.NORMAL || state == TileState.PICKED)
            Modifier.background(Brush.radialGradient(listOf(tint.copy(alpha = 0.55f), Color.Transparent), center = Offset(80f, 40f), radius = 560f))
        else Modifier)
        .background(Brush.verticalGradient(0f to Color.White.copy(alpha = 0.22f), 0.2f to Color.Transparent))
        .then(when (state) {
            TileState.CORRECT -> Modifier.background(Brush.linearGradient(listOf(Color(0xFF06D6A0).copy(alpha = 0.55f), Color(0xFF5CFF9D).copy(alpha = 0.35f))))
            TileState.WRONG -> Modifier.background(Brush.linearGradient(listOf(Color(0xFFFF6B6B).copy(alpha = 0.5f), Color(0xFFFF9AA0).copy(alpha = 0.3f))))
            else -> Modifier
        })
        .border(bw, border, shape)
}

/** `.buttonStyle(.juicy)`: a little squash on press. */
@Composable
fun Modifier.juicyClick(enabled: Boolean = true, onClick: () -> Unit): Modifier {
    val src = remember { MutableInteractionSource() }
    var pressed by remember { mutableStateOf(false) }
    LaunchedEffect(src) {
        src.interactions.collect { i ->
            pressed = i is androidx.compose.foundation.interaction.PressInteraction.Press
        }
    }
    val s by animateFloatAsState(if (pressed) 0.95f else 1f, spring(dampingRatio = 0.5f, stiffness = Spring.StiffnessHigh), label = "juicy")
    return this.scale(s).clickable(src, null, enabled = enabled, onClick = onClick)
}

// MARK: - Buttons

/** The app's gold CTA (the "הַמְשֵׁךְ" buttons). */
@Composable
fun MiniGameGoldButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val h = rememberHaptics()
    Box(
        modifier.fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(GoldBrush)
            .border(1.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(24.dp))
            .juicyClick { h.medium(); onClick() }.padding(vertical = 15.dp, horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) { FitText(title, 21.sp, color = Color.White, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f) }
}

/** The quieter second choice — plain glass. */
@Composable
fun MiniGameGlassButton(title: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val h = rememberHaptics()
    Box(
        modifier.fillMaxWidth().glassPane(24.dp).juicyClick { h.light(); onClick() }.padding(vertical = 13.dp, horizontal = 12.dp),
        contentAlignment = Alignment.Center,
    ) { FitText(title, 18.sp, color = Color.White, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f) }
}

/** A centered glass card column (the intro / end cards). */
@Composable
fun GameCard(modifier: Modifier = Modifier, maxWidth: Dp = 440.dp, padding: Dp = 24.dp, spacing: Dp = 14.dp,
             content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier.padding(horizontal = 20.dp).widthIn(max = maxWidth).fillMaxWidth().glassPane(28.dp).padding(padding),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(spacing), content = content,
    )
}

@Composable
fun TitleText(text: String, size: TextUnit, modifier: Modifier = Modifier, maxLines: Int = 2) =
    FitText(text, size, modifier, Color.White, FontWeight.ExtraBold, maxLines, 0.7f)

@Composable
fun SubText(text: String, size: TextUnit = 17.sp, modifier: Modifier = Modifier, color: Color = Ink.secondary) =
    Text(text, modifier, color = color, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = size,
        textAlign = TextAlign.Center, lineHeight = size * 1.3f)

// MARK: - 👶 גן chrome: pictures first, words beside them

/** The 🔊 a גן round always carries — big on purpose, beside the sentence it speaks. */
@Composable
fun PreReaderSpeakButton(spoken: String, side: Dp = 52.dp) {
    val h = rememberHaptics()
    Box(
        Modifier.size(side).clip(CircleShape).background(Color.White.copy(alpha = 0.16f))
            .border(1.5.dp, Color.White.copy(alpha = 0.4f), CircleShape).juicyClick { h.light(); GameEnv.speak(spoken) },
        contentAlignment = Alignment.Center,
    ) { Text("🔊", fontSize = (side.value * 0.52f).sp) }
}

/** The card at the top of a גן round: the question (the biggest text) + 🔊, then the rule as pictures. */
@Composable
fun PreReaderCueCard(cue: PreReaderCue, compact: Boolean = true) {
    val m = gameMetrics()
    LaunchedEffect(cue.spoken) { GameEnv.speak(cue.spoken) }
    Column(
        Modifier.fillMaxWidth().glassPane(24.dp).padding(horizontal = if (compact) 14.dp else 20.dp, vertical = if (m.short) 8.dp else 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 6.dp else 9.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp, Alignment.CenterHorizontally),
            modifier = Modifier.fillMaxWidth()) {
            FitText(cue.spoken, if (m.short) 16.sp else if (compact) 19.sp else 26.sp, Modifier.weight(1f, fill = false),
                weight = FontWeight.ExtraBold, maxLines = 3, minScale = 0.7f)
            PreReaderSpeakButton(cue.spoken, if (m.short) 40.dp else if (compact) 46.dp else 58.dp)
        }
        if (cue.icons.isNotEmpty()) {
            val base = if (m.short) 36f else if (compact) 50f else 76f
            val s = when (cue.icons.size) { 1 -> base; 2, 3 -> base * 0.86f; 4 -> base * 0.74f; else -> base * 0.62f }
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) { cue.icons.take(6).forEach { Text(it, fontSize = s.sp) } }
        }
    }
}

/** 👶 The intro a גן round opens with: the game's emoji, the rule's pictures, its name, the rule, 🔊 and ▶️. */
@Composable
fun PreReaderIntroCard(kind: MiniGameKind, cue: PreReaderCue, onStart: () -> Unit) {
    val m = gameMetrics()
    LaunchedEffect(Unit) { GameEnv.speak(PreReaderGames.startCue + " " + cue.spoken) }
    GameCard(maxWidth = if (m.compact) 410.dp else 540.dp, padding = if (m.short) 16.dp else 24.dp, spacing = if (m.short) 9.dp else 13.dp) {
        Text(kind.emoji, fontSize = (if (m.short) 58 else if (m.compact) 88 else 118).sp, modifier = Modifier.floating(6f))
        if (cue.icons.isNotEmpty()) Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            cue.icons.take(6).forEach { Text(it, fontSize = (if (m.short) 32 else if (m.compact) 42 else 56).sp) }
        }
        TitleText(kind.title, (if (m.short) 22 else if (m.compact) 27 else 34).sp)
        SubText(cue.spoken, (if (m.short) 14 else if (m.compact) 16 else 19).sp)
        PreReaderSpeakButton(cue.spoken, if (m.short) 48.dp else if (m.compact) 60.dp else 72.dp)
        MiniGameGoldButton(tr("יַאלְלָה! 🚀"), onClick = onStart)
    }
}

/** 👶 A גן round's counters: the dots AND the figure, never one without the other. */
object PreReaderChrome {
    fun dots(done: Int, total: Int): String {
        val shown = minOf(total, 6)
        val filled = minOf(done, shown)
        return "●".repeat(filled) + "○".repeat(shown - filled) + " $done/$total"
    }

    /** An open-ended round (🎈): a dot per success, and a ✨ past the sixth. */
    fun dots(done: Int): String {
        val pips = if (done > 6) "●".repeat(6) + "✨" else "●".repeat(done)
        return if (pips.isEmpty()) "$done" else "$pips $done"
    }

    /** 🔥 as a streak — the flames and the figure together. */
    fun streak(n: Int): String = if (n < 2) " " else "🔥".repeat(minOf(n, 4)) + " $n"
}

// MARK: - Intro / end cards

/** The intro card a game opens with from a world screen — the rules in one line and a start button. */
@Composable
fun MiniGameIntroCard(kind: MiniGameKind, onStart: () -> Unit) {
    val m = gameMetrics()
    GameCard(maxWidth = if (m.compact) 440.dp else 580.dp, padding = if (m.compact) 24.dp else 36.dp) {
        Text(kind.emoji, fontSize = (if (m.compact) 84 else 120).sp, modifier = Modifier.floating(6f))
        TitleText(kind.title, (if (m.compact) 30 else 40).sp)
        SubText(kind.subtitle(false), (if (m.compact) 17 else 22).sp)
        Spacer(Modifier.height(4.dp))
        MiniGameGoldButton(tr("יַאלְלָה! 🚀"), onClick = onStart)
    }
}

/**
 * "+12 ⭐" / "+12 💎" / "⏱ +1:36" — ONE row of EQUAL chips (build 198): same
 * width, same height whatever each number is; the unit line is always laid out
 * (hidden when there is none) so no chip is taller than its neighbours.
 */
@Composable
fun MiniGameRewardChip(emoji: String, text: String, color: Color, shown: Boolean, modifier: Modifier = Modifier, unit: String? = null) {
    val s by animateFloatAsState(if (shown) 1f else 0.4f, spring(dampingRatio = 0.55f), label = "chip")
    val a by animateFloatAsState(if (shown) 1f else 0f, tween(200), label = "chipA")
    Column(
        // At least 58dp and growing with its two lines: a fixed 54dp pushed the
        // "+36 ⭐" line against the top edge on a tablet (Rani's screenshot).
        modifier.graphicsLayer { scaleX = s; scaleY = s; alpha = a }.heightIn(min = 64.dp)
            .clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.30f), RoundedCornerShape(50)).padding(horizontal = 10.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp, Alignment.CenterVertically),
    ) {
        Ltr { FitText("$emoji +$text", 21.sp, color = color, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.6f) }
        Text(unit ?: " ", color = color.copy(alpha = if (unit == null) 0f else 0.85f), fontFamily = Rounded,
            fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1)
    }
}

/** The ⭐ 💎 ⏱ row of a round's end — a chip is skipped when its own number is 0. */
@Composable
fun RewardChipsRow(grant: MiniGameReward.Grant, reveal: Int, withUnits: Boolean) {
    if (grant.stars <= 0 && grant.diamonds <= 0 && grant.seconds <= 0) return
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally)) {
        val chip = Modifier.weight(1f).widthIn(max = 132.dp)
        if (grant.stars > 0) MiniGameRewardChip("⭐", "${grant.stars}", KidColor.starGold, reveal >= 1, chip, if (withUnits) tr("כּוֹכָבִים") else null)
        if (grant.diamonds > 0) MiniGameRewardChip("💎", "${grant.diamonds}", KidColor.diamondBlue, reveal >= 2, chip, if (withUnits) tr("יַהֲלוֹמִים") else null)
        if (grant.seconds > 0) MiniGameRewardChip("⏱", clockLabel(grant.seconds), KidColor.successMint, reveal >= 3, chip, if (withUnits) tr("זְמַן מָסָךְ") else null)
    }
}

/** Reveal the chips one by one, a small chime each. */
@Composable
fun rememberReveal(key: Any?): Int {
    var reveal by remember(key) { mutableIntStateOf(0) }
    LaunchedEffect(key) {
        for (s in 1..3) { delay(250); reveal = s; play(AppSound.CORRECT_SMALL) }
    }
    return reveal
}

/**
 * The shared end screen: the child's own buddy, a headline, a line about the
 * round, the ⭐/💎/⏱ just added, and the way on. Never framed as a failure.
 * From a world: "again" + "done". In a surprise round: one "מַמְשִׁיכִים".
 */
@Composable
fun MiniGameEndCard(
    title: String, detail: String, grant: MiniGameReward.Grant?, surprise: Boolean = false,
    againLabel: String = "", onAgain: () -> Unit = {}, onDone: () -> Unit,
) {
    val m = gameMetrics()
    val reveal = rememberReveal(grant)
    GameCard(maxWidth = if (m.compact) 440.dp else 580.dp, padding = if (m.compact) 24.dp else 36.dp) {
        CharacterImage(GameEnv.source.characterID, Modifier.size(if (m.compact) 120.dp else 160.dp).floating(8f))
        TitleText(title, (if (m.compact) 30 else 40).sp)
        SubText(detail, (if (m.compact) 17 else 21).sp)
        if (grant != null) {
            RewardChipsRow(grant, reveal, withUnits = true)
            if (grant.doubled && (grant.stars > 0 || grant.diamonds > 0)) {
                Text(tr("פִּי 2 — סִבּוּב הַפְתָּעָה! ⚡"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp)
            } else if (!grant.full && grant.stars > 0) {
                Text(tr("הַפְּרָס הַגָּדוֹל חוֹזֵר מָחָר 🌟"), color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
            }
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.padding(top = 6.dp)) {
            if (surprise) MiniGameGoldButton(tr("מַמְשִׁיכִים! 🚀"), onClick = onDone)
            else {
                MiniGameGoldButton(againLabel, onClick = onAgain)
                MiniGameGlassButton(tr("סִיּוּם"), onClick = onDone)
            }
        }
    }
}

/** 👶 The end of a גן round: the buddy, what they did as pictures AND a line, the chips, 🔊, the way on. */
@Composable
fun PreReaderEndCard(
    title: String, detail: String, tally: String, tallyCount: Int, grant: MiniGameReward.Grant?,
    surprise: Boolean = false, againLabel: String = "", onAgain: () -> Unit = {}, onDone: () -> Unit,
) {
    val m = gameMetrics()
    val reveal = rememberReveal(grant)
    val spokenPraise = if (detail.isEmpty()) title else "$title. $detail"
    LaunchedEffect(Unit) { GameEnv.speak(spokenPraise) }
    GameCard(maxWidth = if (m.compact) 410.dp else 540.dp, padding = if (m.short) 14.dp else 22.dp, spacing = if (m.short) 8.dp else 12.dp) {
        CharacterImage(GameEnv.source.characterID, Modifier.size(if (m.short) 78.dp else if (m.compact) 108.dp else 140.dp).floating(8f))
        if (tallyCount > 0) Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            val fs = (if (m.short) 22 else if (m.compact) 27 else 34).sp
            repeat(minOf(tallyCount, 8)) { Text(tally, fontSize = fs) }
            if (tallyCount > 8) Text("✨", fontSize = fs)
        }
        TitleText(title, (if (m.short) 23 else if (m.compact) 28 else 36).sp)
        if (detail.isNotEmpty()) SubText(detail, (if (m.short) 14 else if (m.compact) 16 else 19).sp)
        // 👶 Same three chips as the big card, same size — a "+0" one is still left out.
        if (grant != null) RewardChipsRow(grant, reveal, withUnits = false)
        PreReaderSpeakButton(spokenPraise, if (m.short) 44.dp else if (m.compact) 52.dp else 62.dp)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (surprise) MiniGameGoldButton(tr("מַמְשִׁיכִים! 🚀"), onClick = onDone)
            else {
                MiniGameGoldButton(againLabel.ifEmpty { tr("עוֹד סִבּוּב 🔁") }, onClick = onAgain)
                MiniGameGlassButton(tr("סִיּוּם"), onClick = onDone)
            }
        }
    }
}

// MARK: - The round's chrome: a full game screen

/**
 * A game's frame: the backdrop, the top bar, the body, and the burst /
 * confetti layers. `body` fills the space under the top bar.
 */
@Composable
fun GameFrame(
    onClose: () -> Unit, earn: MiniGameEarnSession?, surprise: Boolean, chip: String,
    burst: Int = 0, burstColor: Color = KidColor.starGold, confetti: Int = 0,
    body: @Composable ColumnScope.() -> Unit,
) {
    androidx.activity.compose.BackHandler(onBack = onClose)
    MiniGameBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding(), horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)) {
            MiniGameTopBar(onClose, if (surprise) null else earn) { MiniGameChipLabel(chip, surprise) }
            body()
        }
        com.rani.tofy.kid.ui.play.StarBurstOverlay(burst, burstColor)
        ConfettiOverlay(confetti)
        if (earn != null && !surprise) MiniGameEarnOverlay(earn)
    }
}

/** The intro / end card centered in the space under the top bar. */
@Composable
fun ColumnScope.Centered(content: @Composable () -> Unit) {
    Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) { content() }
}

// MARK: - ⏱ Earn overlay

/** "+24 שְׁנִיּוֹת" rising toward the bar, the "+4 דקות" pop, and today's-cap line. */
@Composable
fun BoxScope.MiniGameEarnOverlay(earn: MiniGameEarnSession) {
    Box(Modifier.matchParentSize().systemBarsPadding()) {
        EarnedMinutesPopup(earn.popupMinutes, earn.popupTrigger, Modifier.align(Alignment.Center))
        AnimatedVisibility(earn.flashText != null, Modifier.align(Alignment.TopCenter).padding(top = 104.dp),
            enter = scaleIn(initialScale = 0.5f) + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
            var last by remember { mutableStateOf("") }
            earn.flashText?.let { last = it }
            val c = if (earn.flashPositive) KidColor.successMint else KidColor.flameOrange
            Text(last, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp,
                modifier = Modifier.clip(RoundedCornerShape(50)).background(c.copy(alpha = 0.95f)).padding(horizontal = 16.dp, vertical = 8.dp))
        }
        // ⏰ Today's time is full — the child keeps playing and keeps earning ⭐/💎, so say that.
        AnimatedVisibility(earn.capReached, Modifier.align(Alignment.TopCenter).padding(top = 150.dp, start = 24.dp, end = 24.dp),
            enter = fadeIn(), exit = fadeOut()) {
            Text(tr("אָסַפְתֶּם אֶת כָּל הַזְּמַן לְהַיּוֹם! מַמְשִׁיכִים לֶאֱסֹף כּוֹכָבִים ⭐"), color = Color.White, fontFamily = Rounded,
                fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, textAlign = TextAlign.Center,
                modifier = Modifier.clip(RoundedCornerShape(50)).background(KidColor.starGold.copy(alpha = 0.9f)).padding(horizontal = 14.dp, vertical = 8.dp))
        }
    }
}

// MARK: - Shared pieces for the newer games

/** A short multiple-choice card (2048's bonus, the vault's keys); a miss glows soft warm, the right tile mint. */
@Composable
fun MiniGameQuestionCard(item: GameItem, header: String, onDone: (Boolean) -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val options = remember(item) { item.shuffledOptions() }
    var picked by remember(item) { mutableStateOf<String?>(null) }
    var shake by remember(item) { mutableIntStateOf(0) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()
    Column(
        Modifier.padding(horizontal = 16.dp).widthIn(max = 560.dp).fillMaxWidth().graphicsLayer { translationX = 0f }
            .glassPane(24.dp).padding(18.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        val dx = shakeOffset(shake)
        Text(header, color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
        GameText(item.prompt, if (m.compact) 22.sp else 28.sp, Modifier.graphicsLayer { translationX = dx * density }, maxLines = 4, minScale = 0.6f)
        options.chunked(2).forEachIndexed { row, pair ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                pair.forEachIndexed { col, opt ->
                    val i = row * 2 + col
                    val state = when {
                        picked == null -> TileState.NORMAL
                        opt == item.answer -> TileState.CORRECT
                        opt == picked -> TileState.WRONG
                        else -> TileState.NORMAL
                    }
                    Box(
                        Modifier.weight(1f).heightIn(min = if (m.compact) 54.dp else 70.dp).miniGameTile(state, TileTints[i % 4], 18.dp)
                            .juicyClick(picked == null) {
                                if (picked != null) return@juicyClick
                                val right = opt == item.answer
                                picked = opt
                                if (right) { play(AppSound.CORRECT_BIG); h.success() }
                                else { play(AppSound.WRONG_SOFT); h.light(); shake++ }
                                scope.launch { delay(if (right) 700 else 1300); onDone(right) }
                            }.padding(horizontal = 6.dp, vertical = 6.dp),
                        contentAlignment = Alignment.Center,
                    ) { GameText(opt, if (m.compact) 19.sp else 24.sp, maxLines = 2, minScale = 0.6f) }
                }
                if (pair.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

/** A number pad laid out left-to-right in every language: 1–9, then ⌫ 0 and (decimal) a point. */
@Composable
fun MiniGameNumberPad(decimal: Boolean = false, keyHeight: Dp = 52.dp, onKey: (String) -> Unit) {
    val h = rememberHaptics()
    val rows = listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf(if (decimal) "." else "", "0", "⌫"))
    Ltr {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            rows.forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { key ->
                        if (key.isEmpty()) Spacer(Modifier.weight(1f).height(keyHeight))
                        else Box(
                            Modifier.weight(1f).height(keyHeight).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.14f))
                                .border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(14.dp))
                                .juicyClick { h.light(); onKey(key) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(key, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                                fontSize = (keyHeight.value * (if (key == "⌫") 0.4f else 0.46f)).sp)
                        }
                    }
                }
            }
        }
    }
}

/** The amount typed on a pad, shown big in a glass well (left-to-right). */
@Composable
fun MiniGameAnswerWell(text: String, state: TileState = TileState.NORMAL, prefix: String = "", suffix: String = "", height: Dp = 60.dp) {
    Ltr {
        Box(Modifier.widthIn(min = 140.dp).height(height).miniGameTile(state, KidColor.starGold, 18.dp).padding(horizontal = 18.dp),
            contentAlignment = Alignment.Center) {
            Text(MiniGameText.ltr(prefix + text.ifEmpty { "?" } + suffix),
                color = if (text.isEmpty()) Color.White.copy(alpha = 0.5f) else Color.White,
                fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (height.value * 0.5f).sp, maxLines = 1)
        }
    }
}

// MARK: - ⚡ The surprise round's interstitial

/** "⚡ סִבּוּב הַפְתָּעָה!" — the theme, the game, ×2 ⭐ 💎, a gold "יַאלְלָה! 🚀" and a quiet "דִּלּוּג". */
@Composable
fun SurpriseRoundIntro(plan: SurprisePlan, onStart: () -> Unit, onSkip: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    var appeared by remember { mutableStateOf(false) }
    var confetti by remember { mutableIntStateOf(0) }
    val s by animateFloatAsState(if (appeared) 1f else 0.85f, spring(dampingRatio = 0.65f), label = "intro")
    val emojiScale by animateFloatAsState(if (appeared) 1f else 0.5f, spring(dampingRatio = 0.65f), label = "emoji")
    LaunchedEffect(Unit) {
        appeared = true
        delay(200); confetti++
        // 👶 A גן child can't read the game's name here, so it is also said out loud.
        if (GameEnv.activeChildIsPreReader) GameEnv.speak(PreReaderGames.startCue + " " + plan.game.title)
    }
    GlassBackdrop {
        SparkleField(24, 13f)
        Box(Modifier.fillMaxSize().systemBarsPadding(), contentAlignment = Alignment.Center) {
            GameCard(Modifier.graphicsLayer { scaleX = s; scaleY = s; alpha = if (appeared) 1f else 0f },
                spacing = if (m.short) 10.dp else 14.dp) {
                MiniGameChip { Text(tr("⚡ סִבּוּב הַפְתָּעָה!"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp) }
                Text(plan.topic.emoji, fontSize = (if (m.short) 84 else if (m.compact) 112 else 140).sp,
                    modifier = Modifier.floating(8f).graphicsLayer { scaleX = emojiScale; scaleY = emojiScale; rotationZ = (1 - emojiScale) * -40f })
                Text(SurpriseRound.themeName(plan.topic), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                TitleText(plan.game.emoji + " " + plan.game.title, (if (m.compact) 28 else 36).sp)
                SubText(plan.game.subtitle(true), 16.sp)
                MiniGameChip { Text("×2 ⭐ 💎", color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp) }
                MiniGameGoldButton(tr("יַאלְלָה! 🚀"), onClick = onStart)
                Text(tr("דִּלּוּג"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp,
                    modifier = Modifier.clip(RoundedCornerShape(50)).clickable { h.light(); onSkip() }.padding(horizontal = 20.dp, vertical = 6.dp))
            }
        }
        ConfettiOverlay(confetti)
    }
}

/** The whole ⚡ surprise round: the interstitial, then the game (no intro card). Skip / ✕ / "מַמְשִׁיכִים" → back. */
@Composable
fun SurpriseRoundFlow(plan: SurprisePlan, onFinish: () -> Unit) {
    var playing by remember(plan.id) { mutableStateOf(false) }
    val h = rememberHaptics()
    LaunchedEffect(plan.id) { play(AppSound.PORTAL_APPEAR); h.success() }
    if (playing) MiniGameScreen(plan.game, plan.topic, surprise = true, earn = null, onClose = onFinish)
    else SurpriseRoundIntro(plan, onStart = { playing = true }, onSkip = onFinish)
}

// MARK: - The game screen

/**
 * The game screen itself. `surprise` = launched by the runner's ⚡ surprise
 * round (no intro, one round, ×2 ⭐/💎). `earn` = launched from a world's
 * chooser: every right answer earns screen time like a regular question.
 */
@Composable
fun MiniGameScreen(kind: MiniGameKind, topic: Topic?, surprise: Boolean = false, earn: MiniGameEarnSession? = null, onClose: () -> Unit) {
    when (kind) {
        MiniGameKind.PAIRS -> PairsGame(topic, surprise, earn, onClose)
        MiniGameKind.BALLOON -> BalloonPopGame(topic, surprise, earn, onClose)
        MiniGameKind.WORD -> BuildWordGame(topic, surprise, earn, onClose)
        MiniGameKind.CRUSH -> NumberCrushGame(topic, surprise, earn, onClose)
        MiniGameKind.WORD_SEARCH -> WordSearchGame(topic, surprise, earn, onClose)
        MiniGameKind.LIGHTNING -> LightningGame(topic, surprise, earn, onClose)
        MiniGameKind.SORT -> SortBasketsGame(topic, surprise, earn, onClose)
        MiniGameKind.PATTERN -> PatternGame(topic, surprise, earn, onClose)
        MiniGameKind.GAME2048 -> Game2048(topic, surprise, earn, onClose)
        MiniGameKind.VAULT -> VaultGame(topic, surprise, earn, onClose)
        MiniGameKind.GROCERY -> GroceryGame(topic, surprise, earn, onClose)
        MiniGameKind.BALANCE -> BalanceGame(topic, surprise, earn, onClose)
    }
}

/** "1:36" — WorldMapView.clockLabel (re-exported for the games). */
internal fun clock(seconds: Int) = clockLabel(seconds)

/** Monotonic seconds for the in-round clocks. */
internal fun nowSecs(): Double = System.nanoTime() / 1e9

/** A full-width capsule for a small status line. */
@Composable
fun StatusPill(text: String, color: Color = Color.White, modifier: Modifier = Modifier) {
    Text(text, modifier.glassInset(14.dp).padding(horizontal = 12.dp, vertical = 6.dp), color = color, fontFamily = Rounded,
        fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, textAlign = TextAlign.Center)
}

@Composable
internal fun VGap(h: Int) = Spacer(Modifier.height(h.dp))

@Composable
internal fun HGap(w: Int) = Spacer(Modifier.width(w.dp))

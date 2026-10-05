package com.rani.tofy.kid.ui.play

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.ChestKind
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.ProgressEngine
import com.rani.tofy.kid.core.RewardEngine
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin

/*
 * The end of a round — ChildTime/Views/RewardScreenView.swift + ChestView +
 * LevelUpView + WorldUnlockView. Every round ends with a prize (build 198):
 * the chest always pays ⭐ + 💎 (+ a minute or more), and the ⏱ pill says the
 * EXACT screen time the round was worth ("1:36"), never a rounded-away 0.
 */

enum class ChestStage { CLOSED, GLOWING, OPENING, REVEALED }

private enum class RewardStep { CHEST, LEVEL_UP, WORLD_UNLOCK }

@Composable
fun RewardScreen(
    kind: ChestKind, world: PlayWorld, startedLevel: Int, roundSeconds: Int,
    isGirl: Boolean, characterID: String?, onDismiss: () -> Unit,
) {
    val view = LocalView.current
    val haptics = remember(view) { KidHaptics(view) }
    val scope = rememberCoroutineScope()
    val companion = remember { CompanionController(scope) { haptics } }
    var step by remember { mutableStateOf(RewardStep.CHEST) }
    var unlocked by remember { mutableStateOf<PlayWorld?>(null) }
    var newLevel by remember { mutableIntStateOf(1) }

    var stage by remember { mutableStateOf(ChestStage.CLOSED) }
    var taps by remember { mutableIntStateOf(0) }
    val tapsToOpen = 5
    var revealed by remember { mutableIntStateOf(0) }
    val reward = remember(kind) { RewardEngine.chestContents(kind) }
    var bankedNote by remember { mutableStateOf<String?>(null) }
    var confetti by remember { mutableIntStateOf(0) }
    // What this round paid, read once when the chest lands (KidSession.startSession reset the session counters).
    var stars by remember { mutableIntStateOf(0) }
    var diamonds by remember { mutableIntStateOf(0) }
    var timeSeconds by remember { mutableIntStateOf(0) }

    fun applyReward() {
        val s = KidSession.engine()?.session
        // Most minutes were granted live; the chest adds a small bonus (cap-aware, overflow banked).
        val grant = KidSession.edit { it.applyChestReward(reward) }
        stars = (s?.sessionStarsEarned ?: 0) + reward.stars
        diamonds = (s?.sessionDiamondsEarned ?: 0) + reward.diamonds
        timeSeconds = roundSeconds + ((grant?.addedToday ?: 0) + (grant?.bankedForTomorrow ?: 0)) * 60
        if (grant != null && grant.bankedForTomorrow > 0) {
            val carry = KidSession.engine()?.snapshot?.carryOverMinutes ?: 0
            bankedNote = tr("הִגַּעְתָּ לַמַּקְסִימוּם הַיּוֹמִי! %lld דַּקּוֹת נִשְׁמְרוּ לְמָחָר 🎁 (%lld/%lld)",
                grant.bankedForTomorrow, carry, ProgressEngine.MAX_CARRY_OVER)
        }
        KidSession.edit { it.advanceRoom(world.id) }
    }

    fun openChest() {
        KidSounds.play(AppSound.CHEST_OPEN)
        haptics.heavy()
        stage = ChestStage.OPENING
        scope.launch {
            delay(500)
            stage = ChestStage.REVEALED
            confetti++
            companion.wow(tr("טָא-דָה!"))
            applyReward()
            for ((i, d) in listOf(300L, 700L, 600L).withIndex()) {
                delay(d)
                revealed = i + 1
                KidSounds.play(AppSound.STREAK_UP)
                haptics.light()
            }
        }
    }

    fun tapChest() {
        if (stage != ChestStage.GLOWING) return
        taps++
        when { taps >= tapsToOpen -> haptics.heavy(); taps >= tapsToOpen - 2 -> haptics.medium(); else -> haptics.light() }
        KidSounds.play(AppSound.UI_TAP)
        if (taps >= tapsToOpen) openChest()
    }

    fun proceed() {
        val level = KidSession.engine()?.companionLevel ?: startedLevel
        if (level > startedLevel) {
            // Every level reached pays its 💎 bonus (a two-level jump pays both).
            KidSession.edit { e -> for (l in (startedLevel + 1)..level) e.addDiamonds(RewardEngine.levelUpDiamonds(l)) }
            newLevel = level
            step = RewardStep.LEVEL_UP
            return
        }
        val owned = KidSession.engine()?.snapshot?.unlockedWorlds ?: emptyList()
        for (w in PlayWorlds.all) {
            if (w.id == world.id || w.id in owned) continue
            if (KidSession.engine()?.canUnlock(0) == true) {
                KidSession.edit { it.unlockWorld(w.id) }
                KidSession.reportEvent("worldUnlocked", value = w.name)
                unlocked = w
                step = RewardStep.WORLD_UNLOCK
                return
            }
        }
        onDismiss()
    }

    LaunchedEffect(Unit) {
        KidSounds.play(AppSound.CHEST_OPEN)
        companion.cheer(tr("%@ מְצוּיָּן!", if (isGirl) tr("שִׂחַקְתְּ") else tr("שִׂחַקְתָּ")))
        delay(500)
        stage = ChestStage.GLOWING
    }

    when (step) {
        RewardStep.LEVEL_UP -> { LevelUpScreen(newLevel, characterID, onDismiss); return }
        RewardStep.WORLD_UNLOCK -> { unlocked?.let { WorldUnlockScreen(it, onDismiss) }; return }
        RewardStep.CHEST -> Unit
    }

    GlassBackdrop {
        Box(Modifier.fillMaxSize().background(world.glow.copy(alpha = 0.18f)))
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Column(
                Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                Spacer(Modifier.height(24.dp))
                if (stage == ChestStage.REVEALED) {
                    Text("🎉", fontSize = 60.sp)
                    Text(tr("אֵיזֶה נִצָּחוֹן!"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 30.sp, textAlign = TextAlign.Center)
                } else {
                    Text(kind.label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 28.sp, textAlign = TextAlign.Center)
                }
                Box(contentAlignment = Alignment.Center) {
                    Box(Modifier.size(192.dp).background(Brush.radialGradient(listOf(KidColor.starGold.copy(alpha = 0.5f), Color.Transparent)), CircleShape)
                        .graphicsLayer { alpha = if (stage == ChestStage.CLOSED) 0.3f else 0.85f })
                    ChestView(kind, stage, 120.dp, nudge = taps, charge = taps.toFloat() / tapsToOpen,
                        modifier = Modifier.clickable(remember { MutableInteractionSource() }, null) { tapChest() })
                }
                if (stage == ChestStage.GLOWING) {
                    val pulse = rememberInfiniteTransition(label = "p")
                    val ps by pulse.animateFloat(0.95f, 1.06f, infiniteRepeatable(tween(650), RepeatMode.Reverse), label = "ps")
                    Text(if (taps == 0) tr("לַחֲצוּ שׁוּב וָשׁוּב לִפְתִיחָה! ✨") else tr("עוֹד %lld!", tapsToOpen - taps),
                        color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 20.sp, textAlign = TextAlign.Center,
                        modifier = Modifier.scale(ps))
                    Spacer(Modifier.height(12.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        repeat(tapsToOpen) { i ->
                            val on = i < taps
                            val sc by animateFloatAsState(if (on) 1.18f else 1f, spring(dampingRatio = 0.5f), label = "dot")
                            Box(Modifier.size(18.dp).scale(sc).clip(CircleShape).background(if (on) KidColor.starGold else Color.White.copy(alpha = 0.22f))
                                .border(1.dp, Color.White.copy(alpha = 0.45f), CircleShape))
                        }
                    }
                }
                if (stage == ChestStage.REVEALED) {
                    Spacer(Modifier.height(24.dp))
                    Column(Modifier.widthIn(max = 420.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        RewardPill(revealed >= 1, "⭐", "+$stars", tr("כּוֹכָבִים"), KidColor.starGold)
                        if (diamonds > 0) RewardPill(revealed >= 2, "💎", "+$diamonds", tr("יַהֲלוֹמִים"), KidColor.gemPurple)
                        if (timeSeconds > 0) RewardPill(revealed >= 3, "⏱", "+" + clockLabel(timeSeconds), tr("זְמַן מָסָךְ"), KidColor.successMint)
                        AnimatedVisibility(revealed >= 3 && bankedNote != null, enter = scaleIn() + fadeIn()) {
                            Text(bankedNote ?: "", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp,
                                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
                        }
                    }
                }
                Spacer(Modifier.height(24.dp))
            }
            // Pinned to the bottom so a child always sees it.
            if (stage == ChestStage.REVEALED) {
                Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                    Text(tr("הַמְשֵׁךְ"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp,
                        modifier = Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.18f))
                            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(50))
                            .clickable { haptics.light(); proceed() }.padding(horizontal = 40.dp, vertical = 12.dp))
                }
            }
        }
        // Tap ANYWHERE while it's glowing — a child shouldn't have to aim at the chest.
        if (stage == ChestStage.GLOWING) Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, null) { tapChest() })
        // The buddy in the corner (bottom-start), clear of the CTA.
        Column(Modifier.align(Alignment.BottomStart).systemBarsPadding().padding(start = 16.dp, bottom = 16.dp)) {
            CompanionBubble(companion.bubble)
            CompanionBuddy(companion, characterID, 64.dp)
        }
        ConfettiOverlay(confetti)
    }
}

/** One reward as a centred pill: ⭐  +18  כוכבים — all pills the same width. */
@Composable
private fun RewardPill(shown: Boolean, emoji: String, value: String, label: String, color: Color) {
    AnimatedVisibility(shown, enter = scaleIn(initialScale = 0.5f) + fadeIn() + slideInVertically { it / 2 }) {
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(50))
                .background(Brush.horizontalGradient(listOf(color.copy(alpha = 0.35f), color.copy(alpha = 0.15f))))
                .border(2.dp, color.copy(alpha = 0.85f), RoundedCornerShape(50)).padding(horizontal = 24.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(emoji, fontSize = 26.sp)
            Text(value, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 24.sp)
            Text(label, color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
        }
    }
}

// ── ChestView (Components/ChestView.swift) ──────────────────────────────────

private data class ChestPalette(val top: Color, val bottom: Color, val metal: Color, val metalDark: Color, val glow: Color)

private fun palette(kind: ChestKind) = when (kind) {
    ChestKind.WOOD -> ChestPalette(Color(0xFFA9743F), Color(0xFF6E4621), Color(0xFFFFD23F), Color(0xFFC9961F), KidColor.companionGlow)
    ChestKind.GOLD -> ChestPalette(Color(0xFFFFDE7A), Color(0xFFE0A82E), Color(0xFFFFF3C4), Color(0xFFC9961F), KidColor.starGold)
    ChestKind.MAGIC -> ChestPalette(Color(0xFF8B6BE6), Color(0xFF4B2E9E), Color(0xFFE7C9FF), Color(0xFF8E5BD0), KidColor.gemPurple)
    ChestKind.LEGENDARY -> ChestPalette(Color(0xFFFF8FB4), Color(0xFFC03A6E), Color(0xFFFFE08A), Color(0xFFD98BA6), Color(0xFFFF6B9D))
}

/**
 * A drawn treasure chest whose domed lid lifts open: god-rays, a breathing glow,
 * bob + rock while glowing (the lid cracks a little more each tap), then a
 * shiver, a white flash, a shockwave and a burst of stars on open.
 */
@Composable
fun ChestView(kind: ChestKind, stage: ChestStage, size: Dp, nudge: Int, charge: Float, modifier: Modifier = Modifier) {
    val p = palette(kind)
    val active = stage != ChestStage.CLOSED
    val loop = rememberInfiniteTransition(label = "chest")
    val rays by loop.animateFloat(0f, 360f, infiniteRepeatable(tween(18000, easing = LinearEasing)), label = "rays")
    val orbit by loop.animateFloat(0f, 360f, infiniteRepeatable(tween(7000, easing = LinearEasing)), label = "orbit")
    val breathe by loop.animateFloat(1f, 1.18f, infiniteRepeatable(tween(1000, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "glow")
    val bobLoop by loop.animateFloat(0f, 1f, infiniteRepeatable(tween(900, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "bob")
    val rockLoop by loop.animateFloat(-1f, 1f, infiniteRepeatable(tween(1400, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "rock")

    val shake = remember { Animatable(0f) }
    val pop = remember { Animatable(1f) }
    val nudgeScale = remember { Animatable(1f) }
    val flash = remember { Animatable(0f) }
    val ring = remember { Animatable(1f) }
    val burst = remember { Animatable(1f) }

    LaunchedEffect(stage) {
        when (stage) {
            ChestStage.OPENING -> {
                launch { repeat(8) { shake.animateTo(if (it % 2 == 0) 6f else -6f, tween(50)) }; shake.snapTo(0f) }
                pop.animateTo(0.82f, tween(280))
                launch { ring.snapTo(0f); ring.animateTo(1f, tween(800)) }
                launch { burst.snapTo(0f); burst.animateTo(1f, tween(900)) }
                launch { flash.snapTo(0.95f); flash.animateTo(0f, tween(450)) }
                pop.animateTo(1.25f, spring(dampingRatio = 0.45f))
            }
            ChestStage.REVEALED -> pop.animateTo(1.12f, spring(dampingRatio = 0.6f))
            else -> Unit
        }
    }
    LaunchedEffect(nudge) {
        if (nudge <= 0) return@LaunchedEffect
        launch { flash.snapTo(0.55f); flash.animateTo(0f, tween(400)) }
        launch { ring.snapTo(0f); ring.animateTo(1f, tween(800)) }
        launch { burst.snapTo(0f); burst.animateTo(1f, tween(900)) }
        nudgeScale.animateTo(0.84f, tween(80))
        nudgeScale.animateTo(1f, spring(dampingRatio = 0.36f))
    }

    val open = stage == ChestStage.OPENING || stage == ChestStage.REVEALED
    val lidAngle by animateFloatAsState(if (open) 118f else if (stage == ChestStage.GLOWING) charge * 28f else 0f, spring(dampingRatio = 0.6f), label = "lid")
    val bob = when (stage) { ChestStage.GLOWING -> -0.06f * bobLoop; ChestStage.REVEALED -> -0.04f * bobLoop; else -> 0f }
    val rock = if (stage == ChestStage.GLOWING) 5f * rockLoop else 0f
    val box = size * 2.6f

    Box(modifier.size(box), contentAlignment = Alignment.Center) {
        // 1. Rotating god-rays + 2. breathing glow + 3. shockwave + 4. orbiting sparkles.
        Canvas(Modifier.size(box)) {
            val s = size.toPx()
            val c = center
            if (active) {
                val a = if (stage == ChestStage.REVEALED) 0.9f else 0.6f
                rotate(rays, c) {
                    for (i in 0 until 12) rotate(i * 30f, c) {
                        drawRoundRect(
                            Brush.verticalGradient(listOf(p.glow.copy(alpha = 0.55f * a), p.glow.copy(alpha = 0f)), startY = c.y - s * 1.53f, endY = c.y - s * 0.03f),
                            topLeft = Offset(c.x - s * 0.06f, c.y - s * 1.53f), size = Size(s * 0.12f, s * 1.5f), cornerRadius = CornerRadius(s * 0.06f),
                        )
                    }
                }
            }
            val gs = if (stage == ChestStage.GLOWING) breathe else 1f
            drawCircle(Brush.radialGradient(listOf(p.glow.copy(alpha = 0.75f), Color.Transparent), c, s * 1.2f * gs),
                radius = s * 1.2f * gs, center = c, alpha = if (stage == ChestStage.CLOSED) 0.5f else 1f)
            if (ring.value < 1f) {
                for (k in 0..1) {
                    val t = (ring.value - k * 0.12f).coerceIn(0f, 1f)
                    drawCircle(p.glow.copy(alpha = 0.85f * (1f - t)), radius = s * 0.7f * (0.3f + 2.1f * t), center = c, style = Stroke(5f))
                }
            }
        }
        if (active) for (i in 0 until 4) {
            val a = Math.toRadians((orbit + i * 90f).toDouble())
            Text("✦", color = if (i % 2 == 0) KidColor.starGold else Color.White, fontSize = (if (i % 2 == 0) 20 else 14).sp,
                modifier = Modifier.offset(x = size * 0.95f * cos(a).toFloat(), y = size * 0.78f * sin(a).toFloat()))
        }

        // 5. The chest itself.
        Box(
            Modifier.size(size).graphicsLayer {
                translationX = shake.value * density
                translationY = bob * size.toPx()
                rotationZ = rock
                val sc = pop.value * nudgeScale.value
                scaleX = sc; scaleY = sc
            },
        ) {
            TreasureChest(p, open, lidAngle, size)
        }

        // 6. White flash + 7. particle burst.
        if (flash.value > 0.01f) Canvas(Modifier.size(box)) {
            val s = size.toPx()
            drawCircle(Brush.radialGradient(listOf(Color.White, Color.White.copy(alpha = 0f)), center, s * 1.3f),
                radius = s * 1.3f * (0.4f + flash.value * 1.2f), alpha = flash.value)
        }
        if (burst.value < 1f) {
            val glyphs = listOf("⭐️", "✨", "🎉", "💫", "🌟")
            for (i in 0 until 16) {
                val ang = i / 16.0 * Math.PI * 2 + (i % 3) * 0.2
                val dist = size * 1.5f * (0.7f + (i % 4) * 0.12f)
                val t = burst.value
                Text(glyphs[i % glyphs.size], fontSize = (22 + (i % 3) * 8).sp,
                    modifier = Modifier.offset(x = dist * cos(ang).toFloat() * t, y = dist * sin(ang).toFloat() * t - (t * 18).dp)
                        .graphicsLayer { alpha = if (t < 0.5f) 1f else (1f - t) * 2f; scaleX = 0.4f + t * 0.9f; scaleY = 0.4f + t * 0.9f; rotationZ = (if (i % 2 == 0) 220f else -220f) * t })
            }
        }
    }
}

/** Wood body + metal straps + gold lock; a domed lid hinged at its bottom edge. */
@Composable
private fun TreasureChest(p: ChestPalette, open: Boolean, lidAngle: Float, size: Dp) {
    val bodyH = size * 0.5f
    val lidH = size * 0.34f
    val w = size * 0.92f
    Box(Modifier.size(size), contentAlignment = Alignment.Center) {
        // Glow + gems spilling out of the open chest (behind the lid).
        if (open) {
            Canvas(Modifier.size(w, bodyH * 1.1f).offset(y = -bodyH * 0.55f + size * 0.18f)) {
                drawOval(Brush.radialGradient(listOf(Color.White, p.metal.copy(alpha = 0f)), center, this.size.width * 0.5f))
                val gw = this.size.width
                listOf(Color(0xFF06D6A0) to 0.12f, Color(0xFFFF5C8A) to 0.15f, Color(0xFF48BFE3) to 0.11f).forEachIndexed { i, (col, d) ->
                    val r = gw * d / 2
                    val cx = center.x + (i - 1) * gw * 0.2f
                    val cy = center.y + if (i == 1) -this.size.height * 0.06f else 0f
                    drawCircle(Brush.radialGradient(listOf(Color.White, col), Offset(cx - r * 0.3f, cy - r * 0.4f), r * 2), r, Offset(cx, cy))
                }
            }
        }
        // Body.
        Canvas(Modifier.size(w, bodyH).offset(y = size * 0.18f)) {
            val s = size.toPx()
            val r = CornerRadius(s * 0.07f)
            drawRoundRect(Brush.verticalGradient(listOf(p.top, p.bottom)), cornerRadius = r)
            drawRoundRect(p.metalDark.copy(alpha = 0.5f), cornerRadius = r, style = Stroke(s * 0.015f))
            val seam = this.size.width * 0.14f
            drawRect(p.bottom.copy(alpha = 0.35f), Offset(center.x - seam - s * 0.006f, 0f), Size(s * 0.012f, this.size.height))
            drawRect(p.bottom.copy(alpha = 0.35f), Offset(center.x + seam - s * 0.006f, 0f), Size(s * 0.012f, this.size.height))
            drawRect(Brush.horizontalGradient(listOf(p.metal, p.metalDark), center.x - s * 0.06f, center.x + s * 0.06f),
                Offset(center.x - s * 0.06f, 0f), Size(s * 0.12f, this.size.height))
            // Lock + keyhole.
            drawRoundRect(Brush.verticalGradient(listOf(p.metal, p.metalDark)), Offset(center.x - s * 0.08f, center.y - s * 0.07f),
                Size(s * 0.16f, s * 0.14f), CornerRadius(s * 0.02f))
            drawCircle(Color.Black.copy(alpha = 0.55f), s * 0.02f, Offset(center.x, center.y - s * 0.01f))
        }
        // Domed lid, swinging on its bottom edge.
        Canvas(
            Modifier.size(w, lidH).offset(y = size * 0.18f - bodyH * 0.5f - lidH * 0.5f + size * 0.02f)
                .graphicsLayer { transformOrigin = TransformOrigin(0.5f, 1f); rotationX = lidAngle; cameraDistance = 8 * density },
        ) {
            val s = size.toPx()
            val rr = minOf(this.size.width * 0.5f, this.size.height)
            val path = Path().apply {
                moveTo(0f, this@Canvas.size.height)
                lineTo(0f, rr)
                quadraticTo(0f, 0f, rr, 0f)
                lineTo(this@Canvas.size.width - rr, 0f)
                quadraticTo(this@Canvas.size.width, 0f, this@Canvas.size.width, rr)
                lineTo(this@Canvas.size.width, this@Canvas.size.height)
                close()
            }
            drawPath(path, Brush.verticalGradient(listOf(p.top, p.bottom)))
            drawPath(path, p.metalDark.copy(alpha = 0.5f), style = Stroke(s * 0.015f))
            drawRect(Brush.verticalGradient(listOf(p.metal, p.metalDark), this.size.height - s * 0.07f, this.size.height),
                Offset(0f, this.size.height - s * 0.07f), Size(this.size.width, s * 0.07f))
            drawRect(Brush.horizontalGradient(listOf(p.metal, p.metalDark), center.x - s * 0.06f, center.x + s * 0.06f),
                Offset(center.x - s * 0.06f, 0f), Size(s * 0.12f, this.size.height))
        }
    }
}

// ── LevelUpView ─────────────────────────────────────────────────────────────

@Composable
fun LevelUpScreen(level: Int, characterID: String?, onContinue: () -> Unit) {
    val view = LocalView.current
    val haptics = remember(view) { KidHaptics(view) }
    val scale = remember { Animatable(0.3f) }
    var titleVisible by remember { mutableStateOf(false) }
    var confetti by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        KidSounds.play(AppSound.LEVEL_UP)
        haptics.heavy()
        launch { scale.animateTo(1.3f, spring(dampingRatio = 0.5f, stiffness = 120f)) }
        delay(700)
        launch { scale.animateTo(1f, spring(dampingRatio = 0.7f)) }
        titleVisible = true
        confetti++
    }
    val perk = when (level) {
        5 -> tr("🥉 מִסְגֶּרֶת בְּרוֹנְזָה לָאַוָּטָאר!")
        10 -> tr("🥈 מִסְגֶּרֶת כֶּסֶף לָאַוָּטָאר!")
        20 -> tr("🥇 מִסְגֶּרֶת זָהָב לָאַוָּטָאר!")
        else -> null
    }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterVertically),
        ) {
            androidx.compose.foundation.Image(
                androidx.compose.ui.res.painterResource(characterRes(characterID)), null,
                Modifier.size(120.dp).scale(scale.value),
            )
            AnimatedVisibility(titleVisible, enter = scaleIn() + fadeIn()) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(tr("עָלִיתָ רָמָה!"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 46.sp, textAlign = TextAlign.Center)
                    Text(tr("רָמָה %lld", level), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 28.sp)
                    Text(tr("+%lld 💎 בּוֹנוּס לַחֲנוּת!", RewardEngine.levelUpDiamonds(level)), color = KidColor.starGold, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 22.sp, textAlign = TextAlign.Center)
                    perk?.let { Text(it, color = KidColor.companionGlow, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 22.sp, textAlign = TextAlign.Center) }
                }
            }
            CtaGlass(tr("הַמְשֵׁךְ"), visible = titleVisible) { haptics.light(); onContinue() }
        }
        ConfettiOverlay(confetti)
    }
}

// ── WorldUnlockView ─────────────────────────────────────────────────────────

@Composable
fun WorldUnlockScreen(world: PlayWorld, onContinue: () -> Unit) {
    val view = LocalView.current
    val haptics = remember(view) { KidHaptics(view) }
    var stage by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) {
        KidSounds.play(AppSound.WORLD_UNLOCK)
        haptics.heavy()
        delay(300); stage = 1; confetti++
        delay(1200); stage = 2
        delay(1100); stage = 3
    }
    val emojiScale by animateFloatAsState(if (stage >= 1) 1.2f else 0.5f, spring(dampingRatio = 0.5f, stiffness = 120f), label = "e")
    GlassBackdrop {
        Box(Modifier.fillMaxSize().background(world.glow.copy(alpha = 0.22f)))
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(28.dp, Alignment.CenterVertically),
        ) {
            Text(world.emoji, fontSize = 110.sp, modifier = Modifier.scale(emojiScale).graphicsLayer { alpha = if (stage >= 1) 1f else 0f })
            AnimatedVisibility(stage >= 2, enter = scaleIn() + fadeIn()) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(tr("עוֹלָם חָדָשׁ נִפְתַּח!"), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 26.sp, textAlign = TextAlign.Center)
                    Text(world.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 40.sp, textAlign = TextAlign.Center)
                }
            }
            CtaGlass(tr("בּוֹא נַחְקוֹר!"), visible = stage >= 3) { haptics.light(); onContinue() }
        }
        ConfettiOverlay(confetti)
    }
}

/** .ctaGlass(5E60CE → 3E8BF0) — the big continue button. */
@Composable
private fun CtaGlass(text: String, visible: Boolean, onClick: () -> Unit) {
    Box(
        Modifier.widthIn(max = 420.dp).fillMaxWidth().graphicsLayer { alpha = if (visible) 1f else 0f }.clip(RoundedCornerShape(22.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF5E60CE), Color(0xFF3E8BF0))))
            .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(22.dp))
            .clickable(enabled = visible, onClick = onClick).padding(vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) { Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp) }
}

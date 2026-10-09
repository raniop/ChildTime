package com.rani.tofy.kid.ui.shop

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.scaleIn
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.ChestKind
import com.rani.tofy.kid.core.ChestReward
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.ProgressEngine
import com.rani.tofy.kid.core.RewardEngine
import com.rani.tofy.kid.ui.KidCta
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ChestStage
import com.rani.tofy.kid.ui.play.ChestView
import com.rani.tofy.kid.ui.play.CompanionBubble
import com.rani.tofy.kid.ui.play.CompanionBuddy
import com.rani.tofy.kid.ui.play.CompanionController
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.KidHaptics
import com.rani.tofy.kid.ui.play.KidSounds
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.rani.tofy.kid.ui.social.SocialMe

/**
 * DailyChestView.swift — today's magic box: tap it 5 times to pry it open,
 * then ⭐ / 💎 / ⏱ reveal one by one. Granted once per calendar day
 * (lastDailyChestDate). If there's no room left for minutes the box gives
 * +5⭐ +5💎 instead. Entered when already opened today → closes straight away.
 */
@Composable
fun DailyChestScreenImpl(onExit: () -> Unit) {
    val ctx = LocalContext.current
    remember { KidSounds.init(ctx); 0 }
    val view = LocalView.current
    val haptics = remember(view) { KidHaptics(view) }
    val scope = rememberCoroutineScope()
    val companion = remember { CompanionController(scope) { haptics } }
    val child = rememberBoundChild()

    val ready = remember { KidSession.engine()?.dailyChestAvailable == true }
    var reward by remember { mutableStateOf(RewardEngine.chestContents(ChestKind.MAGIC)) }
    val tapsToOpen = 5
    var stage by remember { mutableStateOf(ChestStage.CLOSED) }
    var taps by remember { mutableIntStateOf(0) }
    var revealed by remember { mutableIntStateOf(0) }
    var granted by remember { mutableStateOf<ChestReward?>(null) }
    var bankedNote by remember { mutableStateOf<String?>(null) }
    var confetti by remember { mutableIntStateOf(0) }

    BackHandler(enabled = stage != ChestStage.OPENING) { onExit() }

    fun open() {
        KidSounds.play(AppSound.CHEST_OPEN)
        haptics.heavy()
        stage = ChestStage.OPENING
        scope.launch {
            delay(500)
            stage = ChestStage.REVEALED
            confetti++
            companion.wow(tr("טָא-דָה!"))
            // Stamp the day FIRST, in the same edit — the box can never pay twice.
            val grant = KidSession.edit { e ->
                if (!e.dailyChestAvailable) null else { e.openDailyChest(); e.applyChestReward(reward) }
            }
            if (grant != null) {
                granted = reward
                if (grant.bankedForTomorrow > 0) {
                    val carry = KidSession.engine()?.snapshot?.carryOverMinutes ?: 0
                    bankedNote = com.rani.tofy.kid.ui.BankedNote.capReached(grant.bankedForTomorrow, carry, ProgressEngine.MAX_CARRY_OVER, SocialMe.isGirl)
                }
                KidSession.pushNow()
            }
            for ((i, d) in listOf(300L, 700L, 600L).withIndex()) {
                delay(d)
                revealed = i + 1
                KidSounds.play(AppSound.STREAK_UP)
            }
        }
    }

    fun tapChest() {
        if (stage != ChestStage.GLOWING) return
        taps++
        when { taps >= tapsToOpen -> haptics.heavy(); taps >= tapsToOpen - 2 -> haptics.medium(); else -> haptics.light() }
        KidSounds.play(AppSound.UI_TAP)
        if (taps >= tapsToOpen) open()
    }

    LaunchedEffect(Unit) {
        if (!ready) { onExit(); return@LaunchedEffect }
        // onAppear: roll the day over first — the minutes room is today's.
        KidSession.edit { e -> e.applyDailyRolloverIfNeeded(); reward = e.dailyChestReward(RewardEngine.chestContents(ChestKind.MAGIC)) }
        companion.cheer(SocialMe.g(tr("חִכִּיתִי לְךָ!"), tr("חִכִּיתִי לָךְ!")))
        delay(400)
        stage = ChestStage.GLOWING
    }

    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            Column(
                Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center,
            ) {
                Spacer(Modifier.height(24.dp))
                Text(tr("קוּפְסַת קֶסֶם יוֹמִית"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp,
                    textAlign = TextAlign.Center, lineHeight = 40.sp)
                Spacer(Modifier.height(16.dp))
                // The chest on a soft golden halo inside a glass disc — the one precious object here.
                Box(contentAlignment = Alignment.Center) {
                    val halo by animateFloatAsState(if (stage == ChestStage.REVEALED) 0.55f else 0.32f, label = "halo")
                    Box(Modifier.size(276.dp).background(Brush.radialGradient(listOf(KidColor.starGold.copy(alpha = halo), Color.Transparent)), CircleShape))
                    Box(Modifier.size(228.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.10f)).border(1.dp, Color.White.copy(alpha = 0.35f), CircleShape))
                    ChestView(ChestKind.MAGIC, stage, 120.dp, nudge = taps, charge = taps.toFloat() / tapsToOpen,
                        modifier = Modifier.clickable(remember { MutableInteractionSource() }, null) { tapChest() })
                }
                if (stage == ChestStage.GLOWING) {
                    val pulse = rememberInfiniteTransition(label = "p")
                    val ps by pulse.animateFloat(0.95f, 1.06f, infiniteRepeatable(tween(650), RepeatMode.Reverse), label = "ps")
                    Spacer(Modifier.height(12.dp))
                    Text(if (taps == 0) tr("לַחֲצוּ שׁוּב וָשׁוּב לִפְתִיחָה!") else tr("עוֹד %lld!", tapsToOpen - taps),
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
                val g = granted
                if (stage == ChestStage.REVEALED && g != null) {
                    Spacer(Modifier.height(16.dp))
                    Column(Modifier.widthIn(max = 360.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally) {
                        RewardRow(revealed >= 1, "⭐", tr("+%lld כּוֹכָבִים", g.stars), KidColor.starGold)
                        if (g.diamonds > 0) RewardRow(revealed >= 1, "💎", tr("+%lld יַהֲלוֹמִים", g.diamonds), KidColor.gemPurple)
                        if (g.minutes > 0) RewardRow(revealed >= 2, "⏱", tr("+%lld דַּקּוֹת", g.minutes), KidColor.starGold)
                        AnimatedVisibility(revealed >= 2 && bankedNote != null, enter = scaleIn() + fadeIn()) {
                            Text(bankedNote ?: "", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp,
                                textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp))
                        }
                    }
                }
                // Room for the companion standing at the bottom.
                Spacer(Modifier.height(120.dp))
            }
            // "הַמְשֵׁךְ" pinned outside the scroll so it's always visible.
            if (stage == ChestStage.REVEALED) {
                Box(Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 16.dp), contentAlignment = Alignment.Center) {
                    KidCta(SocialMe.g(tr("הַמְשֵׁךְ"), tr("הַמְשִׁיכִי")), Color(0xFF5E60CE), Color(0xFF3E8BF0), Modifier.widthIn(max = 360.dp), size = 22) { haptics.light(); onExit() }
                }
            }
        }
        // The child's OWN character greets from the bottom-start, its bubble right above.
        Column(Modifier.align(Alignment.BottomStart).systemBarsPadding().padding(start = 20.dp, bottom = if (stage == ChestStage.REVEALED) 96.dp else 20.dp)) {
            CompanionBubble(companion.bubble)
            CompanionBuddy(companion, child?.character3DID ?: CharacterCatalog.DEFAULT_ID, 70.dp)
        }
        // Tap ANYWHERE to charge it open while glowing — not only on the chest.
        if (stage == ChestStage.GLOWING) Box(Modifier.fillMaxSize().clickable(remember { MutableInteractionSource() }, null) { tapChest() })
        ConfettiOverlay(confetti)
    }
}

@Composable
private fun RewardRow(shown: Boolean, emoji: String, text: String, glow: Color) {
    AnimatedVisibility(shown, enter = scaleIn(initialScale = 0.5f) + fadeIn()) {
        Row(
            Modifier.fillMaxWidth().tintedPane(glow, 18.dp).padding(horizontal = 24.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(emoji, fontSize = 36.sp)
            Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 24.sp)
        }
    }
}

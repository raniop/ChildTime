package com.rani.tofy.kid.ui.play

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
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
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.slideOutVertically
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.ContentMode
import com.rani.tofy.kid.content.Question
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.kid.core.RewardEngine
import com.rani.tofy.ui.child.skillName
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlin.math.roundToInt

/**
 * QuestionRunnerView + RewardScreenView: one round, then the end-of-round prize.
 * KidSession is already bound to the child when this is shown. Logic lives in
 * [RunnerController]; this file is the glass quiz layout (mockup order, top-down:
 * chips · timer · question card · answers · streak · tool row).
 *
 * TODO(android): ⚡ surprise mini-game rounds, 🎡 the lucky wheel and 🐉 the boss
 *  battle are not ported yet (iOS: SurpriseRoundFlow / LuckyWheelView / BossBattleView).
 */
@Composable
fun QuestionRunnerScreen(mode: ContentMode, onExit: () -> Unit) {
    val ctx = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val haptics = remember(view) { KidHaptics(view) }
    remember { KidSounds.init(ctx); KidSpeech.init(ctx); HelpRequestSender.init(ctx); LearningHistoryRecorder.init(ctx); 0 }
    val runner = remember { RunnerController(mode, scope) { haptics } }
    LaunchedEffect(Unit) { if (!runner.prepare()) onExit() }
    DisposableEffect(Unit) { onDispose { KidSpeech.stop(); HelpRequestSender.expireActiveRequest() } }

    val leave = { runner.leave(); onExit() }
    BackHandler { leave() }

    when (runner.phase) {
        RunnerController.Phase.LOADING -> GlassBackdrop {
            CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White)
        }
        RunnerController.Phase.PLAYING -> RunnerPlaying(runner, leave)
        RunnerController.Phase.REWARD -> RewardScreen(
            kind = runner.chestKind, world = runner.world, startedLevel = runner.startedLevel,
            roundSeconds = runner.roundSeconds, isGirl = runner.isGirl, characterID = runner.child?.character3DID,
            onDismiss = onExit,
        )
    }
}

@Composable
private fun RunnerPlaying(r: RunnerController, onClose: () -> Unit) {
    val kid by KidSession.state.collectAsState()
    val reply by HelpRequestSender.lastReply.collectAsState()
    val activeQuestion by HelpRequestSender.activeQuestion.collectAsState()
    var showAssist by remember { mutableStateOf(false) }
    var showReport by remember { mutableStateOf(false) }

    // The parent answered from their notification → remove the wrong option.
    LaunchedEffect(reply) { reply?.let { r.applyParentHelp(it) } }

    val shake = rumbleOffset(r.rumbleTrigger)
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().graphicsLayer { translationX = shake * density }.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TopBar(r, kid?.snapshot?.stars ?: 0, kid?.snapshot?.diamonds ?: 0, kid?.snapshot?.cycleSeconds ?: 0.0, onClose)
            val q = r.current
            if (q != null) {
                val serial = r.serial
                key(serial) {
                    Column(
                        Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        Spacer(Modifier.height(2.dp))
                        // The question reads in its CONTENT language's direction (a ru child on a he phone).
                        CompositionLocalProvider(LocalLayoutDirection provides if (r.contentLang.rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                            QuestionHeader(r, q)
                            Spacer(Modifier.height(4.dp))
                            AnswersGrid(r, q, serial)
                        }
                        StreakAndWorth(r, kid?.snapshot?.currentStreak ?: 0, kid?.snapshot?.cycleSeconds ?: 0.0)
                    }
                }
                ToolRow(r, q, waiting = HelpRequestSender.hasActiveRequest && activeQuestion == q.prompt,
                    onAssist = { if (r.askParentTapped(q, HelpRequestSender.hasActiveRequest && activeQuestion == q.prompt)) showAssist = true },
                    onReport = { showReport = true })
            } else Spacer(Modifier.weight(1f))
        }

        StarBurstOverlay(r.burstTrigger)
        ConfettiOverlay(r.confettiTrigger)
        EarnedMinutesPopup(r.lastEarnedMinutes, r.earnedPopupTrigger, Modifier.align(Alignment.Center))
        SecondsFlash(r)
        // 💬 What the buddy says — just above its slot at the end of the tool row.
        CompanionBubble(r.companion.bubble, Modifier.align(Alignment.BottomEnd).systemBarsPadding().padding(end = 16.dp, bottom = 72.dp))

        AnimatedVisibility(r.showBonusIntro, Modifier.fillMaxSize(), enter = fadeIn(), exit = fadeOut()) { BonusIntro() }
        AnimatedVisibility(r.showPortalIntro, Modifier.fillMaxSize(), enter = fadeIn(), exit = fadeOut()) { PortalIntro() }
    }

    if (showAssist) r.current?.let { q ->
        ParentAssistSheet(r, q, r.currentTopic, onDismiss = { showAssist = false })
    }
    if (showReport) AlertDialog(
        onDismissRequest = { showReport = false },
        containerColor = Ink.sheet,
        title = { Text(tr("דִּוּוּחַ עַל הַשְּׁאֵלָה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold) },
        text = { Text(tr("נָסִיר אֶת הַשְּׁאֵלָה הַזּוֹ וְלֹא נַצִּיג אוֹתָהּ שׁוּב, וְנִשְׁלַח עָלֶיהָ דִּוּוּחַ כְּדֵי שֶׁנְּשַׁפֵּר."), color = Ink.secondary, fontFamily = Rounded) },
        confirmButton = {
            TextButton(onClick = { showReport = false; r.reportCurrent() }) {
                Text(tr("דַּוְּחוּ וְהַסִּירוּ אֶת הַשְּׁאֵלָה"), color = Color(0xFFFF9AA0), fontFamily = Rounded, fontWeight = FontWeight.Bold)
            }
        },
        dismissButton = { TextButton(onClick = { showReport = false }) { Text(tr("בִּטּוּל"), color = Color.White, fontFamily = Rounded) } },
    )
}

// ── top bar ─────────────────────────────────────────────────────────────────

@Composable
private fun TopBar(r: RunnerController, stars: Int, diamonds: Int, cycleSeconds: Double, onClose: () -> Unit) {
    val total = maxOf(1, r.totalQuestions)
    val done = minOf(r.questionIndex + 1, total)
    Column(Modifier.padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            QuizChip("✕", onClick = onClose)
            Spacer(Modifier.weight(1f))
            QuizChip("💎 ${diamonds.currencyShort()}", KidColor.diamondBlue)
            QuizChip("⭐ ${stars.currencyShort()}", KidColor.starGold)
            QuizChip(tr("%@ שְׁאֵלָה %lld/%lld", r.current?.topic?.emoji ?: r.world.emoji, done, total))
        }
        EarnedTimeBar(cycleSeconds)
    }
}

/** The fractional-reward timer: seconds earned toward the next bonus batch, exact to the second. */
@Composable
private fun EarnedTimeBar(cycleSeconds: Double) {
    val target = KidSession.engine()?.settings?.bonusTargetSeconds ?: 240
    val secs = minOf(target, cycleSeconds.roundToInt())
    val frac by animateFloatAsState(if (target > 0) minOf(1f, secs.toFloat() / target) else 0f, spring(dampingRatio = 0.7f), label = "timer")
    Row(
        Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("⏱", fontSize = 14.sp)
        Box(Modifier.weight(1f).height(8.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.18f))) {
            Box(
                Modifier.fillMaxWidth(maxOf(0.03f, frac)).height(8.dp).clip(RoundedCornerShape(50))
                    .background(Brush.horizontalGradient(listOf(Color(0xFFFFD23F), Color(0xFFFF9F1C)))),
            )
        }
        Text(tr("+%lld שְׁנִ׳", secs), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
    }
}

// ── question card ───────────────────────────────────────────────────────────

private fun promptSize(prompt: String, passage: Boolean): Float {
    val longest = prompt.split(' ', '\n').maxOfOrNull { it.length } ?: 0
    var size = 42f
    if (longest >= 13) size = 26f else if (longest >= 10) size = 32f else if (longest >= 8) size = 37f
    if (prompt.length >= 75) size = minOf(size, 30f)
    return minOf(size, if (passage) 22f else 30f)
}

@Composable
private fun QuestionHeader(r: RunnerController, q: Question) {
    val golden = r.isSuperQuestion || r.isBonusQuestion || r.isArena
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 8.dp).glassPane(22.dp)
            .then(if (golden) Modifier.border(2.dp, KidColor.starGold.copy(alpha = 0.9f), RoundedCornerShape(22.dp)) else Modifier)
            .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(q.topic.emoji, fontSize = 28.sp)
            val (label, color, size) = when {
                r.isBonusQuestion -> Triple(tr("💫 שְׁאֵלַת עֲנָק! +%lld דַּקּוֹת", RewardEngine.bonusQuestionMinutes), KidColor.starGold, 20)
                r.isArena -> Triple(tr("💫 %@ דַּקּוֹת כְּפוּלוֹת!", q.topic.emoji), KidColor.starGold, 20)
                r.isSuperQuestion -> Triple(tr("⭐ שְׁאֵלַת זָהָב!"), KidColor.starGold, 22)
                r.isInPortal -> Triple(tr("🌀 בּוֹנוּס ×3 כּוֹכָבִים!"), Color.White, 20)
                else -> Triple(q.topic.displayName + (q.skill?.let { " · ${skillName(it)}" } ?: ""), Ink.secondary, 13)
            }
            FitText(label, size.sp, color = color, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f)
        }

        // 📖 The passage card — the child reads here, then answers below (scrolls inside a ceiling).
        q.passage?.let { passage ->
            Box(Modifier.fillMaxWidth().heightIn(max = 210.dp).glassInset(16.dp).verticalScroll(rememberScrollState())) {
                Text(passage, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 17.sp,
                    lineHeight = 24.sp, modifier = Modifier.fillMaxWidth().padding(16.dp))
            }
        }
        // Early readers: the instruction ABOVE the pictures too, not only read aloud.
        q.spoken?.takeIf { it.isNotEmpty() }?.let {
            FitText(it, 26.sp, weight = FontWeight.ExtraBold, maxLines = 3, minScale = 0.6f, modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp))
        }
        FitText(q.prompt, promptSize(q.prompt, q.passage != null).sp, weight = FontWeight.ExtraBold, maxLines = 12, minScale = 0.4f,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp))
        Text(tr("בַּחֲרוּ תְּשׁוּבָה אַחַת"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

/** Two rows of two equal tiles; 1 sits at the reading start (top-right in RTL). */
@Composable
private fun AnswersGrid(r: RunnerController, q: Question, serial: Int) {
    Column(Modifier.fillMaxWidth().padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        q.options.indices.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                row.forEach { idx ->
                    OptionCard(q.options[idx], r.feedback[idx] ?: OptionFeedback.NORMAL, idx, minHeight = 80.dp, modifier = Modifier.weight(1f)) {
                        r.pickOption(idx, serial)
                    }
                }
                if (row.size == 1) Spacer(Modifier.weight(1f))
            }
        }
    }
}

@Composable
private fun StreakAndWorth(r: RunnerController, streak: Int, cycleSeconds: Double) {
    val s = KidSession.engine()?.settings
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        // "🔥 3 ברצף · עוד 2 ובונוס!" in gold under the answers.
        if (streak >= 2) {
            val total = s?.cycleQuestionsTotal ?: 10
            val perSec = (s?.bonusTargetSeconds ?: 240).toDouble() / total
            val done = minOf(total, maxOf(0, (cycleSeconds / maxOf(1.0, perSec)).roundToInt()))
            val left = maxOf(0, total - done)
            Text(tr("🔥 %lld בְּרֶצֶף", streak) + (if (left > 0) tr(" · עוֹד %lld וּבוֹנוּס!", left) else "!"),
                color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
        }
        // What a right answer is worth.
        GlassLine(tr("💡 כָּל תְּשׁוּבָה נְכוֹנָה = %lld שְׁנִיּוֹת שֶׁל מִשְׂחָק", s?.secondsPerCorrect ?: 24))
        Spacer(Modifier.height(4.dp))
    }
}

// ── tool row: 🚩 🔊 🙋 · 💡 hint · 🪄 wand · buddy ──────────────────────────

@Composable
private fun ToolRow(r: RunnerController, q: Question, waiting: Boolean, onAssist: () -> Unit, onReport: () -> Unit) {
    val stuck = r.consecutiveWrong >= 2 && !r.receivedHelpThisQuestion && !waiting && !r.showFeedback
    val pulse = rememberInfiniteTransition(label = "stuck")
    val pulseScale by pulse.animateFloat(1f, 1.08f, infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "s")
    Box(Modifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Row(Modifier.fillMaxWidth().height(56.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RoundIconButton("🚩", Color.White.copy(alpha = 0.14f)) { onReport() }
            RoundIconButton("🔊", Color.White.copy(alpha = 0.22f)) { r.readAloud(q) }
            if (!r.isPreReader) {
                RoundIconButton(
                    if (waiting) "⏳" else "🙋",
                    if (waiting) KidColor.starGold.copy(alpha = 0.55f) else Color.White.copy(alpha = if (stuck) 0.34f else 0.22f),
                    glow = stuck, modifier = Modifier.scale(if (stuck) pulseScale else 1f),
                ) { onAssist() }
            }
            // Hint in the middle; the wand joins it after two misses in a row. Both
            // shrink as one label rather than squeezing the buddy out of the row.
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically) {
                if (!r.showFeedback) HintPill(r, q, Modifier.weight(1f, fill = false))
                if (r.consecutiveWrong >= 2 && !r.showFeedback) {
                    Pill("🪄 " + tr("הַחְלֵף שְׁאֵלָה"), enabled = true, modifier = Modifier.weight(1f, fill = false)) { r.magicWand() }
                }
            }
            CompanionBuddy(r.companion, r.child?.character3DID, 48.dp)
        }
    }
}

@Composable
private fun HintPill(r: RunnerController, q: Question, modifier: Modifier = Modifier) {
    val enabled = r.canUseHint(q)
    val cost = r.hintCost
    val serial = r.serial
    Pill("💡 " + tr("רֶמֶז") + "  " + (if (cost == 0) tr("(חִנָּם)") else tr("(%lld שְׁנִיּוֹת)", cost)), enabled = enabled, gold = true, modifier = modifier) { r.useHint(serial) }
}

@Composable
private fun Pill(text: String, enabled: Boolean, gold: Boolean = false, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(
        modifier.widthIn(max = 170.dp).graphicsLayer { alpha = if (enabled) 1f else 0.45f }.clip(RoundedCornerShape(50))
            .background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, if (gold) KidColor.starGold.copy(alpha = if (enabled) 0.7f else 0.3f) else Color.White.copy(alpha = 0.3f), RoundedCornerShape(50))
            .clickable(enabled = enabled, onClick = onClick).padding(horizontal = 14.dp, vertical = 9.dp),
    ) { FitText(text, 16.sp, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.6f) }
}

// ── overlays ────────────────────────────────────────────────────────────────

@Composable
private fun SecondsFlash(r: RunnerController) {
    val f = r.secondsFlash
    var last by remember { mutableStateOf<Pair<String, Boolean>?>(null) }
    if (f != null) last = f
    Box(Modifier.fillMaxSize().padding(top = 140.dp), contentAlignment = Alignment.TopCenter) {
        AnimatedVisibility(f != null, enter = scaleIn(initialScale = 0.5f) + fadeIn(), exit = slideOutVertically { -it } + fadeOut()) {
            last?.let { (text, positive) ->
                Text(
                    text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp,
                    modifier = Modifier.clip(RoundedCornerShape(50))
                        .background((if (positive) KidColor.successMint else KidColor.flameOrange).copy(alpha = 0.95f))
                        .padding(horizontal = 16.dp, vertical = 9.dp),
                )
            }
        }
    }
}

/** 💫 Full-screen announcement before the rare really-hard bonus question — the promise here is MINUTES. */
@Composable
private fun BonusIntro() {
    val t = rememberInfiniteTransition(label = "bonus")
    val s by t.animateFloat(0.9f, 1.15f, infiniteRepeatable(tween(700, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "s")
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFFFFD23F), Color(0xFFFF9F1C)))).clickable(remember { MutableInteractionSource() }, null) {}, contentAlignment = Alignment.Center) {
        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text("💫", fontSize = 110.sp, modifier = Modifier.scale(s))
            Text(tr("שְׁאֵלַת עֲנָק!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 36.sp, textAlign = TextAlign.Center)
            Text(tr("🎮 +%lld דַּקּוֹת", RewardEngine.bonusQuestionMinutes), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp,
                modifier = Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.25f)).padding(horizontal = 24.dp, vertical = 10.dp))
            Text(tr("שְׁאֵלָה קָשָׁה בִּמְיוּחָד — עֲנוּ נָכוֹן וְקַבְּלוּ אֶת כָּל הַדַּקּוֹת!"), color = Color.White, fontFamily = Rounded,
                fontWeight = FontWeight.Bold, fontSize = 18.sp, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun PortalIntro() {
    val t = rememberInfiniteTransition(label = "portal")
    val rot by t.animateFloat(0f, 360f, infiniteRepeatable(tween(1500, easing = LinearEasing)), label = "r")
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFF7A5CFF), Color(0xFF9B5DE5), Color(0xFF48BFE3)))).clickable(remember { MutableInteractionSource() }, null) {}, contentAlignment = Alignment.Center) {
        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text("🌀", fontSize = 110.sp, modifier = Modifier.graphicsLayer { rotationZ = rot })
            Text(tr("שְׁאֵלַת בּוֹנוּס!"), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 36.sp, textAlign = TextAlign.Center)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { repeat(3) { Text("⭐️", fontSize = 28.sp) } }
            Text(tr("עֲנוּ נָכוֹן וְקַבְּלוּ פִּי 3 כּוֹכָבִים!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold,
                fontSize = 18.sp, textAlign = TextAlign.Center)
        }
    }
}

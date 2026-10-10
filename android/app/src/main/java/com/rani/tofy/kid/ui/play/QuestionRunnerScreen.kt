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
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.togetherWith
import androidx.compose.animation.scaleOut
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.unit.Dp
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
import com.rani.tofy.kid.ui.games.GoldBar
import com.rani.tofy.kid.ui.games.Ltr
import com.rani.tofy.kid.ui.games.GameEnv
import com.rani.tofy.kid.ui.games.SurpriseRoundOverlay
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
 * ⚡ The surprise round (iOS: a fullScreenCover of SurpriseRoundFlow) takes the
 * screen while [RunnerController.surprisePlan] is set. 🎡 The wheel pops on the
 * kid home after the round; 🐉 the boss lives in the world's game chooser.
 */
@Composable
fun QuestionRunnerScreen(mode: ContentMode, onExit: () -> Unit) {
    val ctx = LocalContext.current
    val view = LocalView.current
    val scope = rememberCoroutineScope()
    val haptics = remember(view) { KidHaptics(view) }
    // GameEnv: the surprise round's day/rotation prefs persist like iOS's UserDefaults.
    remember { KidSounds.init(ctx); KidSpeech.init(ctx); HelpRequestSender.init(ctx); LearningHistoryRecorder.init(ctx); GameEnv.init(ctx); 0 }
    val runner = remember { RunnerController(mode, scope) { haptics } }
    LaunchedEffect(Unit) { if (!runner.prepare()) onExit() }
    DisposableEffect(Unit) { onDispose { KidSpeech.stop(); HelpRequestSender.expireActiveRequest() } }

    val leave = { runner.leave(); onExit() }
    BackHandler { leave() }

    when (runner.phase) {
        RunnerController.Phase.LOADING -> GlassBackdrop {
            CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White)
        }
        RunnerController.Phase.PLAYING -> {
            val plan = runner.surprisePlan
            if (plan != null) {
                // Back skips the surprise (its "דִּלּוּג"), never the whole round.
                BackHandler { runner.surpriseDone() }
                SurpriseRoundOverlay(plan) { runner.surpriseDone() }
            }
            else RunnerPlaying(runner, leave)
        }
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
    // The layout Rani approved on the iPhone (2026-10-10, QuestionRunnerView
    // `.inCard`): ONE row above the card, the play time on the shelf, the buddy
    // standing on the shelf beside its bubble. 12dp from the edges; 30 on a tablet.
    val tablet = LocalConfiguration.current.screenWidthDp >= 600
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().graphicsLayer { translationX = shake * density }
                .padding(horizontal = if (tablet) 30.dp else 12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TopRow(r, kid?.snapshot?.stars ?: 0, kid?.snapshot?.diamonds ?: 0, tablet, onClose)
            val q = r.current
            if (q != null) {
                val serial = r.serial
                key(serial) {
                    Column(
                        Modifier.weight(1f).fillMaxWidth().verticalScroll(rememberScrollState()),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        // The question reads in its CONTENT language's direction (a ru child on a he phone).
                        CompositionLocalProvider(LocalLayoutDirection provides if (r.contentLang.rtl) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                            QuestionHeader(r, q)
                            AnswersGrid(r, q, serial)
                        }
                    }
                }
                Shelf(r, q, kid?.snapshot?.currentStreak ?: 0, tablet,
                    waiting = HelpRequestSender.hasActiveRequest && activeQuestion == q.prompt,
                    onAssist = { if (r.askParentTapped(q, HelpRequestSender.hasActiveRequest && activeQuestion == q.prompt)) showAssist = true },
                    onReport = { showReport = true })
            } else Spacer(Modifier.weight(1f))
        }

        StarBurstOverlay(r.burstTrigger)
        ConfettiOverlay(r.confettiTrigger)
        EarnedMinutesPopup(r.lastEarnedMinutes, r.earnedPopupTrigger, Modifier.align(Alignment.Center))

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

/** ✕ · "🧩 שאלה 1/15" + a thin gold bar · "⭐ 30 💎 15" (no frame) — one row above the card. */
@Composable
private fun TopRow(r: RunnerController, stars: Int, diamonds: Int, tablet: Boolean, onClose: () -> Unit) {
    val total = maxOf(1, r.totalQuestions)
    val done = minOf(r.questionIndex + 1, total)
    val topic = r.current?.topic
    Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.size(32.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f)).clickable(onClick = onClose),
            contentAlignment = Alignment.Center) {
            Text("✕", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 13.sp)
        }
        // A tablet has the room: the world's icon and name beside ✕.
        if (tablet && topic != null) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(topic.emoji, fontSize = 14.sp)
                Text(topic.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp, maxLines = 1)
            }
        }
        if (total < 1000) {   // free play has no end
            Text(
                if (tablet) tr("שְׁאֵלָה %lld/%lld", done, total) else tr("%@ שְׁאֵלָה %lld/%lld", topic?.emoji ?: r.world.emoji, done, total),
                color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp, maxLines = 1,
            )
            GoldBar(done / total.toFloat(), Modifier.weight(1f).height(6.dp))
        } else Spacer(Modifier.weight(1f))
        Text("⭐ ${stars.currencyShort()}  💎 ${diamonds.currencyShort()}", color = Color.White, fontFamily = Rounded,
            fontWeight = FontWeight.ExtraBold, fontSize = 12.sp, maxLines = 1)
    }
}

// ── question card ───────────────────────────────────────────────────────────

/**
 * "מָה בָּא אַחֲרֵי?\n50, 40, 30, ?" — a number SEQUENCE is read in the
 * sentence's direction. Laid out left-to-right in a Hebrew question, a child
 * reads it right-to-left as "?, 30, 40, 50": the ? comes FIRST, and "what comes
 * next" looks like "what came before" (Rani, on the tablet — and on the iPad).
 * A Right-to-Left Mark makes such a line an RTL paragraph, so the ? sits at the
 * end of the reading. Arithmetic ("6 × 4 + 17 = ?") has no commas and stays
 * left-to-right, as numbers are written. Same rule as Question.displayPrompt on iOS.
 */
internal fun sequenceAware(prompt: String, rtl: Boolean): String {
    if (!rtl) return prompt
    return prompt.split("\n").joinToString("\n") { line ->
        val sequence = line.contains(',') && line.any { it.isDigit() } && line.none { it.isLetter() }
        if (sequence) "\u200F" + line else line
    }
}

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
        Modifier.fillMaxWidth().glassPane(16.dp)
            .then(if (golden) Modifier.border(2.dp, KidColor.starGold.copy(alpha = 0.9f), RoundedCornerShape(16.dp)) else Modifier)
            .padding(start = 14.dp, end = 14.dp, top = 12.dp, bottom = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // The plain topic is the emoji beside "שאלה 1/15" now — its own line cost a whole row.
        if (r.isBonusQuestion || r.isArena || r.isSuperQuestion || r.isInPortal)
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
            Box(Modifier.fillMaxWidth().heightIn(max = 170.dp).glassInset(16.dp).verticalScroll(rememberScrollState())) {
                Text(passage, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 17.sp,
                    lineHeight = 24.sp, modifier = Modifier.fillMaxWidth().padding(16.dp))
            }
        }
        // Early readers: the instruction ABOVE the pictures too, not only read aloud.
        q.spoken?.takeIf { it.isNotEmpty() }?.let {
            FitText(it, 26.sp, weight = FontWeight.ExtraBold, maxLines = 3, minScale = 0.6f, modifier = Modifier.fillMaxWidth().padding(horizontal = 24.dp))
        }
        FitText(sequenceAware(q.prompt, r.contentLang.rtl), promptSize(q.prompt, q.passage != null).sp, weight = FontWeight.ExtraBold, maxLines = 12, minScale = 0.4f,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp))
        Text(tr("בַּחֲרוּ תְּשׁוּבָה אַחַת"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

/** Two rows of two equal tiles; 1 sits at the reading start (top-right in RTL). */
@Composable
private fun AnswersGrid(r: RunnerController, q: Question, serial: Int) {
    Column(Modifier.fillMaxWidth().padding(top = 10.dp), verticalArrangement = Arrangement.spacedBy(22.dp)) {
        q.options.indices.chunked(2).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
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

// ── the glass shelf: 🔥 streak · the play time · 🚩 🔊 🙋 · 💡 hint — and the buddy on its edge ──

@Composable
private fun Shelf(r: RunnerController, q: Question, streak: Int, tablet: Boolean, waiting: Boolean, onAssist: () -> Unit, onReport: () -> Unit) {
    val stuck = r.consecutiveWrong >= 2 && !r.receivedHelpThisQuestion && !waiting && !r.showFeedback
    val pulse = rememberInfiniteTransition(label = "stuck")
    val pulseScale by pulse.animateFloat(1f, 1.08f, infiniteRepeatable(tween(700), RepeatMode.Reverse), label = "s")
    val buddy: Dp = if (tablet) 80.dp else 64.dp
    // The strip above the shelf is exactly the buddy's height (it stands 6dp into the glass).
    Box(Modifier.fillMaxWidth().padding(top = buddy - 6.dp, bottom = if (tablet) 28.dp else 8.dp)) {
        Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(Modifier.fillMaxWidth().heightIn(min = 30.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // No "🔥 0" after a miss — the count shows from the first right answer.
                if (streak > 0) {
                    Text(tr("🔥 %lld בְּרֶצֶף", streak), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1)
                }
                GoldBar(minOf(streak, 10) / 10f, Modifier.weight(1f).height(12.dp), colors = listOf(Color(0xFFFFB347), Color(0xFFFF5E62)))
                TimeChip(r)
            }
            Row(Modifier.fillMaxWidth().height(46.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                RoundIconButton("🚩", Color.White.copy(alpha = 0.14f)) { onReport() }
                RoundIconButton("🔊", Color.White.copy(alpha = 0.22f)) { r.readAloud(q) }
                if (!r.isPreReader) {
                    RoundIconButton(
                        if (waiting) "⏳" else "🙋",
                        if (waiting) KidColor.starGold.copy(alpha = 0.55f) else Color.White.copy(alpha = if (stuck) 0.34f else 0.22f),
                        glow = stuck, modifier = Modifier.scale(if (stuck) pulseScale else 1f),
                    ) { onAssist() }
                }
                Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.End), verticalAlignment = Alignment.CenterVertically) {
                    if (r.consecutiveWrong >= 2 && !r.showFeedback) {
                        Pill("🪄 " + r.g(tr("הַחְלֵף שְׁאֵלָה"), tr("הַחְלִיפִי שְׁאֵלָה")), enabled = true, modifier = Modifier.weight(1f, fill = false)) { r.magicWand() }
                    }
                    if (!r.showFeedback) HintPill(r, q, Modifier.weight(1f, fill = false))
                }
            }
        }
        // 🧸 The buddy is PART of the shelf — always right above "🔥 ברצף" — and what
        // it says sits beside it, an arrow pointing at it.
        Row(Modifier.align(Alignment.TopStart).offset(y = -(buddy - 6.dp)).padding(start = 6.dp).height(buddy),
            verticalAlignment = Alignment.CenterVertically) {
            CompanionBuddy(r.companion, r.child?.character3DID, buddy)
            SideBubble(r.companion.bubble)
        }
    }
}

/** The play time to the second; a right answer turns it into "+24 שניות" for a moment. */
@Composable
private fun TimeChip(r: RunnerController) {
    val state by KidSession.state.collectAsState()
    val secs = remember(state) { KidSession.engine()?.openableSeconds(false) ?: 0 }
    val flash = r.secondsFlash
    AnimatedContent(flash, transitionSpec = { (scaleIn(initialScale = 0.7f) + fadeIn()) togetherWith (scaleOut(targetScale = 0.7f) + fadeOut()) }, label = "time") { f ->
        if (f != null) {
            Text(f.first, color = if (f.second) Color(0xFF053D2E) else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, maxLines = 1,
                modifier = Modifier.clip(RoundedCornerShape(16.dp)).background(if (f.second) KidColor.successMint else KidColor.flameOrange)
                    .padding(horizontal = 10.dp, vertical = 5.dp))
        } else {
            Row(Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).padding(horizontal = 10.dp, vertical = 5.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Text("⏱", fontSize = 13.sp)
                Ltr { Text("%d:%02d".format(secs / 60, secs % 60), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp) }
            }
        }
    }
}

/** The buddy's bubble BESIDE it: a small arrow on the buddy's side, then the words. */
@Composable
private fun SideBubble(text: String?) {
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    AnimatedVisibility(text != null, enter = scaleIn(initialScale = 0.85f) + fadeIn(), exit = fadeOut()) {
        var last by remember { mutableStateOf("") }
        if (text != null) last = text
        Row(verticalAlignment = Alignment.CenterVertically) {
            Canvas(Modifier.size(width = 9.dp, height = 18.dp)) {
                val tipX = if (rtl) size.width else 0f          // the tip points at the buddy (the row's start)
                val baseX = if (rtl) 0f else size.width
                drawPath(Path().apply { moveTo(baseX, 0f); lineTo(tipX, size.height / 2); lineTo(baseX, size.height); close() }, Color.White)
            }
            Text(last, color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, lineHeight = 19.sp,
                modifier = Modifier.widthIn(max = 230.dp).clip(RoundedCornerShape(16.dp)).background(Color.White)
                    .padding(horizontal = 14.dp, vertical = 10.dp))
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
        modifier.widthIn(max = 170.dp).graphicsLayer { alpha = if (enabled) 1f else 0.45f }.clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, if (gold) KidColor.starGold.copy(alpha = if (enabled) 0.7f else 0.3f) else Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .clickable(enabled = enabled, onClick = onClick).padding(horizontal = 14.dp, vertical = 9.dp),
    ) { FitText(text, 16.sp, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.6f) }
}

// ── overlays ────────────────────────────────────────────────────────────────

@Composable
private fun BonusIntro() {
    val t = rememberInfiniteTransition(label = "bonus")
    val s by t.animateFloat(0.9f, 1.15f, infiniteRepeatable(tween(700, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "s")
    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFFFFD23F), Color(0xFFFF9F1C)))).clickable(remember { MutableInteractionSource() }, null) {}, contentAlignment = Alignment.Center) {
        Column(Modifier.padding(horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(24.dp)) {
            Text("💫", fontSize = 110.sp, modifier = Modifier.scale(s))
            Text(tr("שְׁאֵלַת עֲנָק!"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 36.sp, textAlign = TextAlign.Center)
            Text(tr("🎮 +%lld דַּקּוֹת", RewardEngine.bonusQuestionMinutes), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp,
                modifier = Modifier.clip(RoundedCornerShape(16.dp)).background(Color.Black.copy(alpha = 0.25f)).padding(horizontal = 24.dp, vertical = 10.dp))
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

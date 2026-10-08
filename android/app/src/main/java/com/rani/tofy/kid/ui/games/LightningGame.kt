package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * ⚡ LightningTrueFalseView.swift — "נָכוֹן אוֹ לֹא נָכוֹן?": a 60-second race,
 * one statement at a time and two big glass buttons. The answer shows at once —
 * mint for right; a miss only glows soft warm, shows the right button, moves on.
 */
@Composable
fun LightningGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    // Math cards follow the child's adaptive level in math.
    val grade = if (topic == Topic.MATH) MiniGameLevel.grade(Topic.MATH) else maxOf(1, GameEnv.grade(2))
    val roundSeconds = MiniGameKind.LIGHTNING.seconds(surprise).toDouble()

    var phase by remember { mutableIntStateOf(0) }
    var statement by remember { mutableStateOf<LightningStatement?>(null) }
    val seen = remember { HashSet<String>() }
    var picked by remember { mutableStateOf<Boolean?>(null) }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var correct by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var bestStreak by remember { mutableIntStateOf(0) }
    var shake by remember { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    val remaining = maxOf(0.0, roundSeconds - (now - startedAt))

    fun nextStatement() { statement = LightningStatements.make(topic, grade, seen); picked = null; shownAt = nowSecs() }

    fun start() {
        seen.clear(); correct = 0; streak = 0; bestStreak = 0; grant = null
        startedAt = nowSecs(); now = startedAt
        nextStatement(); phase = 1
    }

    fun finish() {
        if (phase != 1) return
        grant = MiniGameReward.grant("lightning", correct, 1, 1, if (surprise) 12 else 15, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
        if (correct > 0) confetti++
    }

    fun answer(value: Boolean) {
        val s = statement ?: return
        if (phase != 1 || picked != null) return
        picked = value
        val right = value == s.isTrue
        if (right) {
            correct++; streak++; bestStreak = maxOf(bestStreak, streak); burst++
            play(if (streak % 5 == 0) AppSound.STREAK_UP else AppSound.CORRECT_SMALL); h.success()
        } else {
            streak = 0; play(AppSound.WRONG_SOFT); h.light(); shake++
        }
        // Every card is an answer in the parent's reports.
        MiniGameLedger.record(right, s.topic, (nowSecs() - shownAt) * 1000, streak, earn, surprise)
        scope.launch { delay(if (right) 500 else 1000); if (phase == 1) nextStatement() }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }
    LaunchedEffect(phase) {
        while (phase == 1) { delay(100); now = nowSecs(); if (roundSeconds - (now - startedAt) <= 0) finish() }
    }

    GameFrame(onClose, earn, surprise, "✓ $correct", burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered { MiniGameIntroCard(MiniGameKind.LIGHTNING) { start() } }
            2 -> Centered {
                val first = when (correct) {
                    0 -> if (surprise) tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") else tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
                    1 -> tr("תְּשׁוּבָה נְכוֹנָה אַחַת")
                    else -> tr("%lld תְּשׁוּבוֹת נְכוֹנוֹת", correct)
                }
                val d = if (bestStreak >= 2) first + "\n" + tr("הָרֶצֶף הֲכִי אָרֹךְ: %lld 🔥", bestStreak) else first
                MiniGameEndCard(if (correct >= 15) tr("וָואוּ, מְצֻיָּן! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"), d, grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (m.compact) 640.dp else 780.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
            ) {
                Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 10.dp)) { MiniGameTimerBar(remaining, roundSeconds) }
                Text(if (streak >= 2) tr("🔥 %lld בְּרֶצֶף", streak) else " ", color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                Spacer(Modifier.weight(1f))
                val s = statement
                val dx = shakeOffset(shake)
                Column(Modifier.fillMaxWidth().graphicsLayer { translationX = dx * density }.glassPane(16.dp).padding(horizontal = 16.dp, vertical = 18.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text(tr("נָכוֹן אוֹ לֹא נָכוֹן?"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                    s?.prompt?.let { GameText(it, if (m.compact) 20.sp else 26.sp, color = Color.White.copy(alpha = 0.92f), weight = FontWeight.Bold, maxLines = 4, minScale = 0.6f) }
                    val base = if (s?.prompt == null) (if (m.compact) 44f else 58f) else (if (m.compact) 32f else 42f)
                    val claimState = if (picked != null && s != null && picked == s.isTrue) TileState.CORRECT else TileState.NORMAL
                    Column(Modifier.fillMaxWidth().miniGameTile(claimState, KidColor.starGold, 20.dp).padding(horizontal = 14.dp, vertical = 8.dp),
                        horizontalAlignment = Alignment.CenterHorizontally) {
                        GameText(s?.claim ?: "", (if (m.short) base * 0.85f else base).sp, maxLines = 3, minScale = 0.5f)
                    }
                }
                Spacer(Modifier.weight(1f))
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    listOf(true, false).forEach { value ->
                        val state = if (picked == null || s == null) TileState.NORMAL
                        else if (value == s.isTrue) TileState.CORRECT   // the right one always lights up
                        else if (picked == value) TileState.WRONG else TileState.NORMAL
                        Column(Modifier.weight(1f).height(if (m.short) 104.dp else if (m.compact) 124.dp else 150.dp)
                            .miniGameTile(state, if (value) KidColor.successMint else Color(0xFFB7ABFF), 26.dp)
                            .juicyClick(picked == null) { answer(value) },
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically)) {
                            Text(if (value) "✓" else "✗", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (if (m.compact) 38 else 48).sp)
                            TitleText(if (value) tr("נָכוֹן") else tr("לֹא נָכוֹן"), (if (m.compact) 21 else 26).sp, maxLines = 1)
                        }
                    }
                }
            }
        }
    }
}

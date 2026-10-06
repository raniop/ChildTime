package com.rani.tofy.kid.ui.games

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.content.PreReaderContent
import com.rani.tofy.kid.content.Question
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.PlayWorld
import com.rani.tofy.kid.ui.play.PlayWorlds
import com.rani.tofy.kid.ui.play.StarBurstOverlay
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The world a topic raw string names; anything that is not a Topic is the 💫 arena. */
internal fun playWorldFor(topic: String): PlayWorld = Topic.of(topic)?.let { PlayWorlds.forTopic(it) } ?: PlayWorlds.arena

/**
 * 🐉 BossBattleView.swift — "קְרַב בּוֹס", the finale of a world. The world's
 * emoji becomes a friendly boss with 5 hearts; each correct (harder) answer lands
 * a hit. The kid has 3 hearts — a wrong answer costs one, but losing is "almost,
 * let's try again". The full prize (20⭐ 30💎 5🎮) once per boss per day; replays 2⭐.
 */
@Composable
internal fun BossBattle(world: PlayWorld, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val bossMaxHP = 5; val startHearts = 3

    var phase by remember { mutableIntStateOf(0) }   // 0 fighting · 1 won · 2 lost
    var bossHP by remember { mutableIntStateOf(bossMaxHP) }
    var hearts by remember { mutableIntStateOf(startHearts) }
    var question by remember { mutableStateOf<Question?>(null) }
    var picked by remember { mutableStateOf<Int?>(null) }
    var locked by remember { mutableStateOf(false) }
    var bossHit by remember { mutableStateOf(false) }
    var shake by remember { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var prize by remember { mutableStateOf(Triple(0, 0, 0)) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }

    fun newQuestion() {
        val grade = GameEnv.source.grade
        question = when {
            // Pre-readers (גן) get the text-free visual path, exactly like the runner.
            (grade ?: 1) < 1 -> PreReaderContent.generate(world.topic)
            // 💫 Arena boss: extra-hard bonus questions across ALL playable topics.
            world.isBonus -> GameQuestions.generateBonus(GameQuestions.playableTopics().randomOrNull() ?: Topic.LOGIC, grade)
            else -> {
                // A boss must BITE: at the top adaptive band (≥ 1.75) it draws from one grade up.
                val base = GameEnv.source.difficulty(world.topic)
                val level = GameEnv.adaptiveLevel(world.topic, base)
                GameQuestions.generate(world.topic, Difficulty.HARD, if (grade != null && level >= 1.75) grade + 1 else grade)
            }
        }
        picked = null; locked = false; shownAt = nowSecs()
    }

    fun win() {
        phase = 1
        // Full jackpot only ONCE per boss per day — replays give a small practice reward.
        val dayKey = "boss.won.${world.id}"
        prize = if (GameDayGate.usedToday(dayKey)) Triple(2, 0, 0) else { GameDayGate.mark(dayKey); Triple(20, 30, 5) }
        MiniGameLedger.sink.applyChest(prize.first, prize.second, prize.third)
        play(AppSound.WORLD_UNLOCK); h.success(); confetti++
    }

    fun pick(idx: Int) {
        val q = question ?: return
        if (locked) return
        locked = true; picked = idx
        val correct = idx == q.correctIndex
        // Every boss answer counts in the parent's reports — without paying minutes per answer.
        MiniGameLedger.sink.bossAnswer(correct)
        MiniGameLedger.sink.recordHistory(q.topic.raw, correct, (nowSecs() - shownAt) * 1000, 0, MiniGameLedger.sink.currentStreak, false)
        if (correct) { play(AppSound.CORRECT_BIG); h.success(); burst++; bossHit = true; bossHP = maxOf(0, bossHP - 1) }
        else { play(AppSound.WRONG_SOFT); h.light(); shake++; hearts = maxOf(0, hearts - 1) }
        scope.launch {
            delay(700)
            bossHit = false
            when { bossHP == 0 -> win(); hearts == 0 -> phase = 2; else -> newQuestion() }
        }
    }

    fun restart() { bossHP = bossMaxHP; hearts = startHearts; phase = 0; newQuestion() }

    LaunchedEffect(Unit) { if (question == null) newQuestion() }

    Box(Modifier.fillMaxSize().background(Brush.linearGradient(listOf(world.glow, Ink.indigo, Ink.deep)))) {
        SparkleField(20, 13f)
        Box(Modifier.fillMaxSize().systemBarsPadding()) {
            if (phase == 0) Column(Modifier.fillMaxSize().padding(top = 40.dp), horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(18.dp)) {
                // Boss + HP
                val s by animateFloatAsState(if (bossHit) 1.18f else 1f, spring(dampingRatio = 0.5f), label = "boss")
                Text(world.emoji, fontSize = 92.sp, modifier = Modifier.graphicsLayer { scaleX = s; scaleY = s; rotationZ = if (bossHit) -8f else 0f })
                Text(tr("הַבּוֹס שֶׁל %@", world.name), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                HeartsRow(bossMaxHP, bossHP, hexColor("EF476F"), "💖")
                Spacer(Modifier.weight(1f))
                question?.let { q ->
                    q.passage?.let { passage ->
                        // 📖 Reading-world boss: the passage scrolls above the question.
                        Box(Modifier.padding(horizontal = 18.dp).heightIn(max = 150.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp))
                            .background(Color.White.copy(alpha = 0.10f)).verticalScroll(rememberScrollState()).padding(12.dp)) {
                            Text(passage, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
                        }
                    }
                    val dx = shakeOffset(shake)
                    Text(q.prompt, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 24.sp, textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 18.dp).graphicsLayer { translationX = dx * density })
                    Column(Modifier.padding(horizontal = 18.dp).widthIn(max = 560.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        q.options.forEachIndexed { idx, opt ->
                            val show = picked != null
                            val bg = if (show && idx == q.correctIndex) KidColor.successMint else if (show && picked == idx) hexColor("EF476F") else Color.White.copy(alpha = 0.14f)
                            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(bg).border(1.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(18.dp))
                                .juicyClick(!locked) { pick(idx) }.padding(vertical = 15.dp, horizontal = 10.dp), contentAlignment = Alignment.Center) {
                                GameText(opt, 19.sp, maxLines = 2)
                            }
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
                Row(Modifier.padding(bottom = 24.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("הַלְּבָבוֹת שֶׁלְּךָ:"), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    HeartsRow(startHearts, hearts, hexColor("FF5E78"), "❤️")
                }
            } else {
                val win = phase == 1
                val reveal = rememberReveal(phase)
                Column(Modifier.fillMaxSize().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically)) {
                    CharacterImage("lion", Modifier.size(130.dp))
                    Text(if (win) tr("נִצַּחְתָּ אֶת הַבּוֹס! 🏆") else tr("כִּמְעַט! בּוֹא נְנַסֶּה שׁוּב 💪"), color = Color.White, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 28.sp, textAlign = TextAlign.Center)
                    if (win) Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        // The pills say what was actually added (iOS shows 20/30 even on a replay that paid 2⭐).
                        RewardPill("⭐", prize.first, KidColor.starGold, reveal >= 1)
                        RewardPill("💎", prize.second, KidColor.gemPurple, reveal >= 2)
                        RewardPill("🎮", prize.third, KidColor.successMint, reveal >= 3, tr(" דק׳"))
                    }
                    Column(Modifier.padding(horizontal = 16.dp).widthIn(max = 420.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (!win) ClassicCta(tr("עוֹד נִסָּיוֹן 🔁"), true) { restart() }
                        ClassicCta(if (win) tr("יֵשׁ! 🎉") else tr("חֲזָרָה"), win, onClose)
                    }
                }
            }
        }
        StarBurstOverlay(burst, KidColor.starGold)
        ConfettiOverlay(confetti)
        Box(Modifier.systemBarsPadding().padding(20.dp).size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.18f))
            .juicyClick(onClick = onClose), contentAlignment = Alignment.Center) {
            Text("✕", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }
    }
}

@Composable
private fun HeartsRow(count: Int, filled: Int, color: Color, symbol: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        repeat(count) { i ->
            Text(symbol, fontSize = 18.sp, modifier = Modifier.graphicsLayer { alpha = if (i < filled) 1f else 0.25f })
        }
    }
}

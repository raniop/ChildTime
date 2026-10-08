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
import com.rani.tofy.kid.content.CurriculumMath
import com.rani.tofy.kid.core.WorldStage
import com.rani.tofy.kid.ui.home.KidWorld
import com.rani.tofy.kid.ui.home.WorldRouter
import com.rani.tofy.ui.child.WorldTiers
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
    /** 🏆 The tier this win completed (0 bronze…2 gold), null on a replay — and an unvisited world to suggest next. */
    var completedTier by remember { mutableStateOf<Int?>(null) }
    var suggested by remember { mutableStateOf<KidWorld?>(null) }
    val girl = GameEnv.source.isGirl
    fun g(boy: String, girlText: String) = if (girl) girlText else boy
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
                // 🏆 Silver/gold bosses start one/two grades up, like their rooms.
                var g = grade?.let { it + GameEnv.source.tierGradeOffset(world.id) }
                if (g != null && level >= 1.75) g += 1
                GameQuestions.generate(world.topic, Difficulty.HARD, g?.let { minOf(CurriculumMath.TOP_GRADE, it) })
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
        // 🏆 Beaten in the last room → the tier is complete (+100 💎, the next tier
        // a grade up). Not for the arena — it has no tiers.
        if (!world.isBonus) MiniGameLedger.sink.completeTier(world.id)?.let { done ->
            completedTier = done
            prize = prize.copy(second = prize.second + WorldStage.TIER_COMPLETE_DIAMONDS)
            suggested = WorldRouter.suggestedNewWorld(excluding = world.id)
        }
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

    fun restart() { bossHP = bossMaxHP; hearts = startHearts; phase = 0; completedTier = null; suggested = null; newQuestion() }

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
                            Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(bg).border(1.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(16.dp))
                                .juicyClick(!locked) { pick(idx) }.padding(vertical = 15.dp, horizontal = 10.dp), contentAlignment = Alignment.Center) {
                                GameText(opt, 19.sp, maxLines = 2)
                            }
                        }
                    }
                }
                Spacer(Modifier.weight(1f))
                Row(Modifier.padding(bottom = 24.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(g(tr("הַלְּבָבוֹת שֶׁלְּךָ:"), tr("הַלְּבָבוֹת שֶׁלָּךְ:")), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                    HeartsRow(startHearts, hearts, hexColor("FF5E78"), "❤️")
                }
            } else {
                val win = phase == 1
                val reveal = rememberReveal(phase)
                Column(Modifier.fillMaxSize().padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically)) {
                    CharacterImage("lion", Modifier.size(130.dp))
                    val done = completedTier
                    val title = when {
                        !win -> g(tr("כִּמְעַט! בּוֹא נְנַסֶּה שׁוּב 💪"), tr("כִּמְעַט! בּוֹאִי נְנַסֶּה שׁוּב 💪"))
                        done == null -> g(tr("נִצַּחְתָּ אֶת הַבּוֹס! 🏆"), tr("נִצַּחַתְּ אֶת הַבּוֹס! 🏆"))
                        done >= WorldStage.TIER_COUNT - 1 -> g(tr("אַלּוּף הָעוֹלָם! 👑"), tr("אַלּוּפַת הָעוֹלָם! 👑"))
                        else -> g(tr("הִשְׁלַמְתָּ אֶת הַדַּרְגָּה! 🏆"), tr("הִשְׁלַמְתְּ אֶת הַדַּרְגָּה! 🏆"))
                    }
                    Text(title, color = Color.White, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 28.sp, textAlign = TextAlign.Center)
                    if (win) Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                        // The pills say what was actually added — a same-day replay pays 2⭐ only.
                        if (prize.first > 0) RewardPill("⭐", prize.first, KidColor.starGold, reveal >= 1)
                        if (prize.second > 0) RewardPill("💎", prize.second, KidColor.gemPurple, reveal >= 2)
                        if (prize.third > 0) RewardPill("🎮", prize.third, KidColor.successMint, reveal >= 3, tr(" דק׳"))
                    }
                    if (win && done != null) TierUnlockCard(done, girl)
                    Column(Modifier.padding(horizontal = 16.dp).widthIn(max = 420.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        if (!win) ClassicCta(tr("עוֹד נִסָּיוֹן 🔁"), true) { restart() }
                        val cta = when {
                            !win -> tr("חֲזָרָה")
                            done != null && done < WorldStage.TIER_COUNT - 1 -> tr("לְדַרְגָּה %lld 🚀", done + 2)
                            else -> tr("יֵשׁ! 🎉")
                        }
                        ClassicCta(cta, win, onClose)
                        val next = suggested
                        if (win && done != null && next != null) Text(
                            tr("אוֹ עוֹלָם חָדָשׁ: %@ ✨ +%lld 💎", next.name, WorldStage.FIRST_VISIT_DIAMONDS),
                            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
                                .border(1.dp, Color.White.copy(alpha = 0.4f), RoundedCornerShape(16.dp))
                                .juicyClick { h.light(); WorldRouter.pending.value = next.id }
                                .padding(vertical = 12.dp, horizontal = 10.dp),
                            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp,
                            textAlign = TextAlign.Center, maxLines = 2,
                        )
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

/** "⭐⭐ דַּרְגַּת כֶּסֶף נִפְתְּחָה!" — or, after gold, the world is done. */
@Composable
private fun TierUnlockCard(done: Int, girl: Boolean) {
    val next = done + 1
    val (title, line) = when (next) {
        1 -> tr("⭐⭐ דַּרְגַּת כֶּסֶף נִפְתְּחָה!") to tr("שְׁאֵלוֹת קָשׁוֹת יוֹתֵר, פְּרָסִים גְּדוֹלִים יוֹתֵר")
        2 -> tr("⭐⭐⭐ דַּרְגַּת זָהָב נִפְתְּחָה!") to tr("הַדַּרְגָּה הָאַחֲרוֹנָה — וְהִיא הַכִּי קָשָׁה")
        else -> tr("👑 הָעוֹלָם הֻשְׁלַם") to (if (girl) tr("עָבַרְתְּ אֶת כָּל הַדַּרְגּוֹת! אֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק כָּאן תָּמִיד")
            else tr("עָבַרְתָּ אֶת כָּל הַדַּרְגּוֹת! אֶפְשָׁר לְהַמְשִׁיךְ לְשַׂחֵק כָּאן תָּמִיד"))
    }
    Column(
        Modifier.padding(horizontal = 20.dp).widthIn(max = 460.dp).fillMaxWidth().clip(RoundedCornerShape(16.dp))
            .background(Color.White.copy(alpha = 0.14f))
            .border(1.5.dp, WorldTiers.color(next).copy(alpha = 0.9f), RoundedCornerShape(16.dp))
            .padding(vertical = 12.dp, horizontal = 14.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center)
        Text(line, color = Color.White.copy(alpha = 0.88f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, textAlign = TextAlign.Center)
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

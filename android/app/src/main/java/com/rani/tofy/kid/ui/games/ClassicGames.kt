package com.rani.tofy.kid.ui.games

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
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
import androidx.compose.runtime.mutableStateListOf
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
import com.rani.tofy.kid.content.Question
import com.rani.tofy.kid.ui.CharacterImage
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.ConfettiOverlay
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.kid.ui.play.StarBurstOverlay
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// 🎮 The four classic modes of GamesMenuView.swift — ⚡ TrueFalseRaceView,
// 🎯 QuickQuizView, 🧩 MatchPairsView, 🧠 MemoryMatchView. Each pays ⭐ 💎 and
// up to 2 🎮 play-minutes once at the end (the daily-cap-aware bonus path).

internal val textOnLight = Color(0xFF2A1E5C)

/** The classic modes' lively gradient backdrop + the round ✕ at the top start. */
@Composable
internal fun ClassicBackdrop(colors: List<String>, burst: Int, confetti: Int, onClose: () -> Unit, content: @Composable BoxScope.() -> Unit) {
    BackHandler(onBack = onClose)
    Box(Modifier.fillMaxSize().background(Brush.linearGradient(colors.map { hexColor(it) }))) {
        SparkleField(22, 12f)
        Box(Modifier.fillMaxSize().systemBarsPadding(), content = content)
        StarBurstOverlay(burst, KidColor.starGold)
        ConfettiOverlay(confetti)
        Box(Modifier.systemBarsPadding().padding(20.dp).size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f))
            .juicyClick(onClick = onClose), contentAlignment = Alignment.Center) {
            Text("✕", color = Color.White, fontWeight = FontWeight.Bold, fontSize = 16.sp)
        }
    }
}

@Composable
internal fun RewardPill(emoji: String, value: Int, color: Color, shown: Boolean, suffix: String = "") {
    val s by animateFloatAsState(if (shown) 1f else 0.3f, spring(dampingRatio = 0.5f), label = "pill")
    Column(
        Modifier.graphicsLayer { scaleX = s; scaleY = s; alpha = if (shown) 1f else 0f }.widthIn(min = 76.dp)
            .clip(RoundedCornerShape(18.dp)).background(color.copy(alpha = 0.25f)).border(1.5.dp, color, RoundedCornerShape(18.dp))
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Text(emoji, fontSize = 26.sp)
        Text("+$value$suffix", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
    }
}

@Composable
internal fun ClassicCta(text: String, dark: Boolean, onClick: () -> Unit) {
    Box(Modifier.fillMaxWidth().clip(RoundedCornerShape(50)).then(if (dark) Modifier.background(GoldBrush) else Modifier.background(Color.White.copy(alpha = 0.18f)))
        .juicyClick(onClick = onClick).padding(vertical = 14.dp), contentAlignment = Alignment.Center) {
        Text(text, color = if (dark) textOnLight else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
    }
}

/** The classic summary: the lion, a headline, a line, three pills (⭐ 💎 🎮) and the two CTAs. */
@Composable
internal fun ClassicSummary(title: String, line: String, stars: Int, diamonds: Int, minutes: Int?, againLabel: String,
                            onAgain: (() -> Unit)?, doneLabel: String, doneDark: Boolean = false, onDone: () -> Unit) {
    val reveal = rememberReveal(title + line)
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(28.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp, Alignment.CenterVertically)) {
        CharacterImage("lion", Modifier.size(140.dp).floating(10f))
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 32.sp, textAlign = TextAlign.Center)
        Text(line, color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 18.sp, textAlign = TextAlign.Center)
        if (minutes != null) Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            RewardPill("⭐", stars, KidColor.starGold, reveal >= 1)
            RewardPill("💎", diamonds, KidColor.gemPurple, reveal >= 2)
            RewardPill("🎮", minutes, KidColor.successMint, reveal >= 3, tr(" דק׳"))
        }
        Column(Modifier.padding(horizontal = 16.dp).widthIn(max = 420.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            if (onAgain != null) ClassicCta(againLabel, true, onAgain)
            ClassicCta(doneLabel, doneDark, onDone)
        }
    }
}

/** The ⏱ bar of the races — gold, turning red in the last 30%. */
@Composable
internal fun RaceBar(frac: Float) {
    GoldBar(frac, Modifier.fillMaxWidth().height(10.dp), if (frac > 0.3f) listOf(Color(0xFFFFB547), Color(0xFFFFD84A)) else listOf(Color.Red, Color.Red))
}

/** The races' header: "3/10", the 🔥 combo, "⚡ score", the timer bar. */
@Composable
internal fun RaceHeader(index: Int, total: Int, combo: Int, score: Int, frac: Float, pop: Boolean = false) {
    Column(Modifier.padding(horizontal = 22.dp).padding(top = 64.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("☰ ${minOf(index + 1, total)}/$total", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
            Spacer(Modifier.weight(1f))
            if (combo >= 2) {
                val s by animateFloatAsState(if (pop) 1.15f else 1f, label = "combo")
                Text(tr("🔥 קוֹמְבּוֹ ×%lld", combo), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp,
                    modifier = Modifier.graphicsLayer { scaleX = s; scaleY = s }.clip(RoundedCornerShape(50)).background(KidColor.flameOrange).padding(horizontal = 10.dp, vertical = 4.dp))
            }
            Spacer(Modifier.weight(1f))
            Text("⚡️ $score", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
        }
        RaceBar(frac)
    }
}

/** "Max 2 play-minutes per round (2 for a strong round, else 1)." */
internal fun raceMinutes(correct: Int, total: Int) = if (correct >= (total * 3) / 4) 2 else 1

// MARK: - ⚡ TrueFalseRaceView

/**
 * "מֵרוֹץ נָכוֹן/לֹא נָכוֹן" — a question + a CANDIDATE answer (half the time the
 * real one), ✓ / ✗, a gentle 7 s timer that rewards speed. Pays ⭐ 💎 🎮 at the end.
 */
@Composable
fun TrueFalseRace(onClose: () -> Unit) {
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val total = 10; val limit = 7.0; val fastBonusUnder = 3.0

    data class TFItem(val question: Question, val candidate: String, val isTrue: Boolean)
    var done by remember { mutableStateOf(false) }
    var item by remember { mutableStateOf<TFItem?>(null) }
    var index by remember { mutableIntStateOf(0) }
    var correctCount by remember { mutableIntStateOf(0) }
    var score by remember { mutableIntStateOf(0) }
    var combo by remember { mutableIntStateOf(0) }
    var answered by remember { mutableStateOf(false) }
    var lastResult by remember { mutableStateOf<Boolean?>(null) }
    var questionStart by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var cardPop by remember { mutableStateOf(false) }
    var shake by remember { mutableIntStateOf(0) }
    var earnedMinutes by remember { mutableIntStateOf(0) }
    val elapsed = now - questionStart
    val frac = (maxOf(0.0, limit - elapsed) / limit).toFloat()

    fun makeItem(): TFItem {
        // Reading passages don't fit the single-candidate format; set-dependent prompts are skipped.
        val topics = GameQuestions.playableTopics().filter { it != Topic.READING }
        fun one(): Question { val t = topics.randomOrNull() ?: Topic.MATH; return GameQuestions.generate(t, GameQuestions.sampledDifficulty(t), GameEnv.source.grade) }
        var q = one(); var tries = 0
        while (!q.isSelfContainedPrompt && tries < 12) { q = one(); tries++ }
        if (kotlin.random.Random.nextBoolean()) return TFItem(q, q.correctAnswer, true)
        val wrong = q.options.indices.filter { it != q.correctIndex }.randomOrNull()?.let { q.options[it] } ?: q.correctAnswer
        return TFItem(q, wrong, wrong == q.correctAnswer)
    }
    fun loadNext() { item = makeItem(); answered = false; lastResult = null; questionStart = nowSecs(); now = questionStart }
    fun finish() {
        done = true
        earnedMinutes = raceMinutes(correctCount, total)
        MiniGameLedger.sink.applyChest(correctCount, score, earnedMinutes)
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }
    fun advance() { index++; if (index >= total) finish() else loadNext() }
    fun answer(saidTrue: Boolean) {
        val it0 = item ?: return
        if (answered) return
        answered = true
        val correct = saidTrue == it0.isTrue
        lastResult = correct
        if (correct) {
            correctCount++; combo++
            val bonus = (if (elapsed < fastBonusUnder) 1 else 0) + (if (combo >= 3) 1 else 0)
            score += 1 + bonus; burst++
            play(if (bonus > 0) AppSound.CORRECT_BIG else AppSound.CORRECT_SMALL); h.success(); cardPop = true
        } else { combo = 0; play(AppSound.WRONG_SOFT); h.light(); shake++ }
        scope.launch { delay(700); cardPop = false; advance() }
    }

    LaunchedEffect(Unit) { if (item == null) loadNext() }
    LaunchedEffect(done) {
        while (!done) {
            delay(50); now = nowSecs()
            if (now - questionStart >= limit && !answered) {
                answered = true; lastResult = false; combo = 0; play(AppSound.WRONG_SOFT)
                scope.launch { delay(500); advance() }
            }
        }
    }

    ClassicBackdrop(listOf("5B6CFF", "9B5DE5", "EF476F"), burst, confetti, onClose) {
        if (done) ClassicSummary(if (correctCount >= total - 2) tr("וָואוּ, מְצֻיָּן! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"),
            tr("עָנִיתָ נָכוֹן עַל %lld מִתּוֹךְ %lld", correctCount, total), correctCount, score, earnedMinutes,
            tr("עוֹד סִבּוּב 🔁"), { index = 0; correctCount = 0; score = 0; combo = 0; done = false; loadNext() }, tr("סִיּוּם"), onDone = onClose)
        else Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(20.dp)) {
            RaceHeader(index, total, combo, score, frac, cardPop)
            Spacer(Modifier.weight(1f))
            item?.let { it0 ->
                val dx = shakeOffset(shake)
                Column(Modifier.fillMaxWidth().padding(horizontal = 18.dp).floating(5f), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    Text(it0.question.prompt, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 27.sp,
                        textAlign = TextAlign.Center, modifier = Modifier.padding(horizontal = 16.dp).graphicsLayer { translationX = dx * density })
                    Text(tr("הַתְּשׁוּבָה הִיא…"), color = Color.White.copy(alpha = 0.7f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    val s by animateFloatAsState(if (cardPop) 1.06f else 1f, spring(dampingRatio = 0.45f), label = "card")
                    val ring = lastResult?.let { if (it) KidColor.successMint else hexColor("EF476F") }
                    Box(Modifier.graphicsLayer { scaleX = s; scaleY = s }.glassPane(24.dp, 0.18f)
                        .then(if (ring != null) Modifier.border(6.dp, ring, RoundedCornerShape(24.dp)) else Modifier)
                        .padding(horizontal = 28.dp, vertical = 18.dp)) {
                        GameText(it0.candidate, 34.sp, maxLines = 3)
                    }
                }
            }
            Spacer(Modifier.weight(1f))
            Row(Modifier.padding(horizontal = 18.dp).padding(bottom = 28.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                listOf(false to "EF476F", true to "06D6A0").forEach { (said, hex) ->
                    val c = hexColor(hex)
                    Column(Modifier.weight(1f).clip(RoundedCornerShape(26.dp)).background(Brush.verticalGradient(listOf(c, c.copy(alpha = 0.78f))))
                        .border(1.5.dp, Color.White.copy(alpha = 0.5f), RoundedCornerShape(26.dp)).juicyClick(!answered) { answer(said) }.padding(vertical = 24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(if (said) "✓" else "✕", color = Color.White, fontWeight = FontWeight.Black, fontSize = 34.sp)
                        Text(if (said) tr("נָכוֹן") else tr("לֹא נָכוֹן"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 21.sp)
                    }
                }
            }
        }
    }
}

// MARK: - 🎯 QuickQuizView

/** "חִידוֹן בָּזָק" — a rapid 4-answer race: 🔥 combo, speed bonus, ⭐ / 💎 / 🎮 at the end. */
@Composable
fun QuickQuiz(onClose: () -> Unit) {
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val total = 10; val limit = 9.0; val fastBonusUnder = 4.0
    var done by remember { mutableStateOf(false) }
    var question by remember { mutableStateOf<Question?>(null) }
    var index by remember { mutableIntStateOf(0) }
    var correctCount by remember { mutableIntStateOf(0) }
    var score by remember { mutableIntStateOf(0) }
    var combo by remember { mutableIntStateOf(0) }
    var picked by remember { mutableStateOf<Int?>(null) }
    var locked by remember { mutableStateOf(false) }
    var questionStart by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var shake by remember { mutableIntStateOf(0) }
    var earnedMinutes by remember { mutableIntStateOf(0) }
    val elapsed = now - questionStart
    val frac = (maxOf(0.0, limit - elapsed) / limit).toFloat()

    fun loadNext() {
        // Reading passages don't fit the quick one-liner format.
        val t = GameQuestions.playableTopics().filter { it != Topic.READING }.randomOrNull() ?: Topic.MATH
        question = GameQuestions.generate(t, GameQuestions.sampledDifficulty(t), GameEnv.source.grade)
        picked = null; locked = false; questionStart = nowSecs(); now = questionStart
    }
    fun finish() {
        done = true
        earnedMinutes = raceMinutes(correctCount, total)
        MiniGameLedger.sink.applyChest(correctCount, score, earnedMinutes)
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }
    fun advance() { index++; if (index >= total) finish() else loadNext() }
    fun pick(idx: Int) {
        val q = question ?: return
        if (locked) return
        locked = true; picked = idx
        if (idx == q.correctIndex) {
            correctCount++; combo++
            val bonus = (if (elapsed < fastBonusUnder) 1 else 0) + (if (combo >= 3) 1 else 0)
            score += 1 + bonus; burst++
            play(if (bonus > 0) AppSound.CORRECT_BIG else AppSound.CORRECT_SMALL); h.success()
        } else { combo = 0; play(AppSound.WRONG_SOFT); h.light(); shake++ }
        scope.launch { delay(750); advance() }
    }

    LaunchedEffect(Unit) { if (question == null) loadNext() }
    LaunchedEffect(done) {
        while (!done) {
            delay(50); now = nowSecs()
            if (now - questionStart >= limit && !locked) { locked = true; combo = 0; play(AppSound.WRONG_SOFT); scope.launch { delay(400); advance() } }
        }
    }

    ClassicBackdrop(listOf("118AB2", "5B6CFF", "9B5DE5"), burst, confetti, onClose) {
        if (done) ClassicSummary(if (correctCount >= total - 2) tr("וָואוּ, מְצֻיָּן! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"),
            tr("עָנִיתָ נָכוֹן עַל %lld מִתּוֹךְ %lld", correctCount, total), correctCount, score, earnedMinutes,
            tr("עוֹד סִבּוּב 🔁"), { index = 0; correctCount = 0; score = 0; combo = 0; done = false; loadNext() }, tr("סִיּוּם"), onDone = onClose)
        else Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.spacedBy(18.dp)) {
            RaceHeader(index, total, combo, score, frac)
            Spacer(Modifier.weight(1f))
            question?.let { q ->
                val dx = shakeOffset(shake)
                Text(q.prompt, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 26.sp, textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp).graphicsLayer { translationX = dx * density })
                Column(Modifier.padding(horizontal = 18.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    q.options.chunked(2).forEachIndexed { row, chunk ->
                        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            chunk.forEachIndexed { k, opt ->
                                val idx = row * 2 + k
                                val show = picked != null
                                val bg = if (show && idx == q.correctIndex) KidColor.successMint else if (show && picked == idx) hexColor("EF476F") else Color.White.copy(alpha = 0.16f)
                                Box(Modifier.weight(1f).heightIn(min = 64.dp).clip(RoundedCornerShape(20.dp)).background(bg)
                                    .border(1.5.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(20.dp)).juicyClick(!locked) { pick(idx) }
                                    .padding(horizontal = 8.dp, vertical = 10.dp), contentAlignment = Alignment.Center) {
                                    GameText(opt, 19.sp, maxLines = 3, minScale = 0.6f)
                                }
                            }
                            if (chunk.size == 1) Spacer(Modifier.weight(1f))
                        }
                    }
                }
            }
            Spacer(Modifier.weight(1f))
        }
    }
}

// MARK: - 🧩 MatchPairsView

/** "הַתְאָמַת זוּגוֹת" — tap a question and its answer; match all five → ⭐ 💎 🎮. */
@Composable
fun MatchPairs(onClose: () -> Unit) {
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val pairCount = 5
    data class Card(val id: Long, val pair: Int, val text: String)
    var lefts by remember { mutableStateOf(listOf<Card>()) }
    var rights by remember { mutableStateOf(listOf<Card>()) }
    val matched = remember { mutableStateListOf<Int>() }
    var pickedLeft by remember { mutableStateOf<Long?>(null) }
    var pickedRight by remember { mutableStateOf<Long?>(null) }
    var wrongFlash by remember { mutableStateOf(false) }
    var won by remember { mutableStateOf(false) }
    var mistakes by remember { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var earnedMinutes by remember { mutableIntStateOf(0) }

    fun deal() {
        matched.clear(); pickedLeft = null; pickedRight = null; mistakes = 0; wrongFlash = false
        val topics = GameQuestions.playableTopics().filter { it != Topic.READING }
        val pairs = mutableListOf<Pair<String, String>>()
        val seenA = HashSet<String>(); val seenP = HashSet<String>()
        var tries = 0
        while (pairs.size < pairCount && tries < 60) {
            tries++
            val t = topics.randomOrNull() ?: Topic.MATH
            val q = GameQuestions.generate(t, GameEnv.source.difficulty(t), GameEnv.source.grade)
            val ans = q.correctAnswer
            // Skip odd-one-out prompts and any repeated prompt/answer.
            if (!q.isSelfContainedPrompt || ans.graphemes() > 24 || q.prompt.graphemes() > 60 || ans in seenA || q.prompt in seenP) continue
            seenA += ans; seenP += q.prompt; pairs += q.prompt to ans
        }
        lefts = pairs.mapIndexed { i, p -> Card(nextId(), i, p.first) }.shuffled()
        rights = pairs.mapIndexed { i, p -> Card(nextId(), i, p.second) }.shuffled()
    }
    fun win() {
        won = true
        earnedMinutes = if (mistakes <= 2) 2 else 1
        MiniGameLedger.sink.applyChest(pairCount, maxOf(8, 20 - mistakes * 2), earnedMinutes)
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }
    fun checkPair() {
        val lc = lefts.firstOrNull { it.id == pickedLeft } ?: return
        val rc = rights.firstOrNull { it.id == pickedRight } ?: return
        if (lc.pair == rc.pair) {
            play(AppSound.CORRECT_SMALL); h.success(); burst++
            matched += lc.pair; pickedLeft = null; pickedRight = null
            if (matched.size == lefts.size) win()
        } else {
            mistakes++; play(AppSound.WRONG_SOFT); h.light(); wrongFlash = true
            scope.launch { delay(450); wrongFlash = false; pickedLeft = null; pickedRight = null }
        }
    }
    LaunchedEffect(Unit) { if (lefts.isEmpty()) deal() }

    ClassicBackdrop(listOf("06D6A0", "5B6CFF", "9B5DE5"), burst, confetti, onClose) {
        if (won) ClassicSummary(if (mistakes == 0) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"), tr("הִתְאַמְתָּ אֶת כָּל הַזּוּגוֹת!"),
            pairCount, maxOf(8, 20 - mistakes * 2), earnedMinutes, tr("עוֹד לוּחַ 🔁"), { deal(); won = false }, tr("סִיּוּם"), onDone = onClose)
        else Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
            Column(Modifier.padding(top = 60.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(tr("הַתְאִימוּ אֶת הַשְּׁאֵלָה לַתְּשׁוּבָה 🧩"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
                Text(tr("%lld/%lld זוּגוֹת", matched.size, pairCount), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
            }
            Row(Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                listOf(true, false).forEach { left ->
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        (if (left) lefts else rights).forEach { card ->
                            val isMatched = card.pair in matched
                            val isPicked = (if (left) pickedLeft else pickedRight) == card.id
                            val bg = if (isMatched) KidColor.successMint else if (isPicked && wrongFlash) hexColor("EF476F") else Color.White
                            val s = if (isPicked) 1.04f else 1f
                            Box(Modifier.fillMaxWidth().heightIn(min = 62.dp).graphicsLayer { scaleX = s; scaleY = s; alpha = if (isMatched) 0.6f else 1f }
                                .clip(RoundedCornerShape(16.dp)).background(bg)
                                .border(if (isPicked) 3.dp else 1.dp, if (isPicked) KidColor.starGold else Color.White.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
                                .juicyClick(!isMatched) {
                                    if (won) return@juicyClick
                                    if (left) pickedLeft = if (pickedLeft == card.id) null else card.id
                                    else pickedRight = if (pickedRight == card.id) null else card.id
                                    checkPair()
                                }.padding(8.dp), contentAlignment = Alignment.Center) {
                                GameText(card.text, 16.sp, color = if (isMatched) Color.White else textOnLight, maxLines = 4, minScale = 0.65f)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 🧠 MemoryMatchView

/** "מִשְׂחַק הַזִּכָּרוֹן" — flip two cards: an emoji and its English word. Clear the board → ⭐ 💎 🎮. */
@Composable
fun MemoryMatch(onClose: () -> Unit) {
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val pairCount = 8
    val vocab = remember {
        listOf("🐶" to "dog", "🐱" to "cat", "☀️" to "sun", "🍎" to "apple", "🚗" to "car", "🌳" to "tree", "🏠" to "house", "⭐" to "star",
            "🐟" to "fish", "🌙" to "moon", "🌸" to "flower", "🎈" to "balloon", "🦋" to "butterfly", "🐢" to "turtle", "🍌" to "banana", "🌈" to "rainbow")
    }
    data class MemCard(val id: Long, val key: String, val face: String)
    var cards by remember { mutableStateOf(listOf<MemCard>()) }
    val flipped = remember { mutableStateListOf<Long>() }
    val matched = remember { mutableStateListOf<String>() }
    var busy by remember { mutableStateOf(false) }
    var mistakes by remember { mutableIntStateOf(0) }
    var won by remember { mutableStateOf(false) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var earnedMinutes by remember { mutableIntStateOf(0) }

    fun deal() {
        matched.clear(); flipped.clear(); busy = false; mistakes = 0
        cards = vocab.shuffled().take(pairCount).flatMap { (e, w) -> listOf(MemCard(nextId(), w, e), MemCard(nextId(), w, w)) }.shuffled()
    }
    fun win() {
        won = true
        earnedMinutes = if (mistakes <= 2) 2 else 1
        MiniGameLedger.sink.applyChest(pairCount, maxOf(8, 20 - mistakes * 2), earnedMinutes)
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }
    fun tap(card: MemCard) {
        if (busy || won || card.key in matched || card.id in flipped) return
        play(AppSound.UI_TAP)
        flipped += card.id
        if (flipped.size != 2) return
        val a = cards.firstOrNull { it.id == flipped[0] }; val b = cards.firstOrNull { it.id == flipped[1] }
        if (a != null && b != null && a.key == b.key) {
            play(AppSound.CORRECT_SMALL); h.success(); burst++
            matched += a.key; flipped.clear()
            if (matched.size == pairCount) win()
        } else {
            mistakes++; play(AppSound.WRONG_SOFT); h.light(); busy = true
            scope.launch { delay(800); flipped.clear(); busy = false }
        }
    }
    LaunchedEffect(Unit) { if (cards.isEmpty()) deal() }

    ClassicBackdrop(listOf("9B5DE5", "5B6CFF", "06D6A0"), burst, confetti, onClose) {
        if (won) ClassicSummary(if (mistakes <= 2) tr("זִכָּרוֹן מְצֻיָּן! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"), tr("מָצָאתָ אֶת כָּל הַזּוּגוֹת!"),
            pairCount, maxOf(8, 20 - mistakes * 2), earnedMinutes, tr("עוֹד לוּחַ 🔁"), { deal(); won = false }, tr("סִיּוּם"), onDone = onClose)
        else Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Column(Modifier.padding(top = 60.dp).padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(tr("מִשְׂחַק הַזִּכָּרוֹן 🧠"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
                Text(tr("מָצְאוּ אֶת הָאֶמוֹגִ'י וְהַמִּלָּה הַתּוֹאֶמֶת בְּאַנְגְּלִית"), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded,
                    fontWeight = FontWeight.SemiBold, fontSize = 13.sp, textAlign = TextAlign.Center)
            }
            Spacer(Modifier.weight(1f))
            Column(Modifier.padding(horizontal = 14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                cards.chunked(4).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        row.forEach { card ->
                            val isMatched = card.key in matched
                            val isUp = isMatched || card.id in flipped
                            val rot by animateFloatAsState(if (isUp) 0f else 180f, label = "flip")
                            Box(Modifier.weight(1f).height(84.dp).graphicsLayer { rotationY = rot; cameraDistance = 12 * density; alpha = if (isMatched) 0.65f else 1f }
                                .clip(RoundedCornerShape(18.dp))
                                .background(if (rot < 90f) Brush.linearGradient(listOf(Color.White, Color.White)) else Brush.verticalGradient(listOf(hexColor("5B6CFF"), hexColor("9B5DE5"))))
                                .border(if (isMatched) 3.dp else 1.dp, if (isMatched) KidColor.successMint else Color.White.copy(alpha = 0.3f), RoundedCornerShape(18.dp))
                                .juicyClick(!isMatched && !busy) { tap(card) }, contentAlignment = Alignment.Center) {
                                if (rot < 90f) FitText(card.face, (if (card.face.graphemes() <= 2) 40 else 20).sp, Modifier.padding(4.dp), color = textOnLight,
                                    weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.5f)
                                // The back is drawn at 180°, so counter-mirror the "?".
                                else Text("?", color = Color.White.copy(alpha = 0.85f), fontWeight = FontWeight.ExtraBold, fontSize = 34.sp, modifier = Modifier.graphicsLayer { scaleX = -1f })
                            }
                        }
                    }
                }
            }
            Spacer(Modifier.weight(1f))
        }
    }
}

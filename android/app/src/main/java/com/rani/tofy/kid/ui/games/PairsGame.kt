package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Spacer
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.AppLanguage
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
 * 🔗 PairsGameView.swift — "חַבְּרוּ אֶת הַזּוּגוֹת": five pairs in two shuffled
 * columns. Tap one on each side: a right pair turns mint and locks, a wrong
 * one gives a short gentle shake and lets go. The board follows the world:
 * country ↔ capital, word ↔ English, exercise ↔ result, or bank question ↔ answer.
 * 👶 גן: four PICTURE pairs (🦴 ↔ 🐶), the rule spoken. ⚡ Surprise: ⭐/💎 only;
 * from a chooser each matched pair earns like a regular answer.
 */
@Composable
fun PairsGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val preReader = GameEnv.activeChildIsPreReader
    val grade = maxOf(1, GameEnv.grade(2))
    // 🎚️ Five pairs up to ד׳, six from ה׳ (a short screen keeps five); 👶 גן: four.
    val pairCount = if (preReader) PreReaderGames.PAIR_COUNT else if (MiniGameBand.of(grade) >= MiniGameBand.UPPER && !m.short) 6 else 5

    data class Card(val pair: Int, val text: String)

    var started by remember { mutableStateOf(false) }
    var done by remember { mutableStateOf(false) }
    var source by remember { mutableStateOf<MatchPairsSource>(MatchPairsSource.Math) }
    var lefts by remember { mutableStateOf(listOf<Card>()) }
    var rights by remember { mutableStateOf(listOf<Card>()) }
    val matched = remember { mutableStateListOf<Int>() }
    val missed = remember { mutableStateListOf<Int>() }
    var pickedLeft by remember { mutableStateOf<Int?>(null) }
    var pickedRight by remember { mutableStateOf<Int?>(null) }
    var wrongLeft by remember { mutableStateOf<Int?>(null) }
    var wrongRight by remember { mutableStateOf<Int?>(null) }
    var shake by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableStateOf(nowSecs()) }
    var cue by remember { mutableStateOf<PreReaderCue?>(null) }

    fun deal() {
        val pairs: List<MatchPair>
        if (preReader) {
            val round = PreReaderGames.pairs(pairCount)
            cue = round.cue
            source = MatchPairsSource.Bank(Topic.LOGIC)
            pairs = round.pairs
        } else {
            cue = null
            val picked = MatchPairsSource.pick(topic, grade)
            // Math follows the child's adaptive level in math.
            val g = if (picked == MatchPairsSource.Math) MiniGameLevel.grade(Topic.MATH) else grade
            val built = picked.pairs(pairCount, g)
            source = built.first
            pairs = built.second
        }
        lefts = pairs.mapIndexed { i, p -> Card(i, p.left) }.shuffled()
        rights = pairs.mapIndexed { i, p -> Card(i, p.right) }.shuffled()
        matched.clear(); missed.clear(); pickedLeft = null; pickedRight = null
        wrongLeft = null; wrongRight = null; grant = null
        shownAt = nowSecs()
        started = true; done = false
    }

    fun finish() {
        grant = MiniGameReward.grant("pairs", matched.size, 2, 2, pairCount, surprise)
        scope.launch {
            delay(450)
            done = true
            play(AppSound.CHEST_OPEN); h.success(); confetti++
        }
    }

    fun check() {
        val l = pickedLeft ?: return
        val r = pickedRight ?: return
        if (l == r) {
            // Every matched pair is a correct answer — one found on the second try pays too.
            MiniGameLedger.record(true, source.topic, (nowSecs() - shownAt) * 1000 / pairCount,
                earn = earn, surprise = surprise, retry = l in missed)
            play(AppSound.CORRECT_SMALL); h.success(); burst++
            matched += l
            pickedLeft = null; pickedRight = null
            if (matched.size == lefts.size) finish()
        } else {
            if (l !in missed) { missed += l; MiniGameLedger.record(false, source.topic, earn = earn, surprise = surprise) }
            play(AppSound.WRONG_SOFT); h.light()
            if (preReader) GameEnv.speak(PreReaderGames.almost)
            wrongLeft = l; wrongRight = r; shake++
            scope.launch {
                delay(450)
                wrongLeft = null; wrongRight = null; pickedLeft = null; pickedRight = null
            }
        }
    }

    fun tap(card: Card, left: Boolean) {
        if (done || card.pair in matched || wrongLeft != null) return
        h.light()
        if (left) pickedLeft = if (pickedLeft == card.pair) null else card.pair
        else pickedRight = if (pickedRight == card.pair) null else card.pair
        check()
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && !started) deal() }

    val chip = if (preReader) "🔗 " + PreReaderChrome.dots(matched.size, pairCount) else "🔗 ${matched.size}/$pairCount"
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.successMint, confetti) {
        when {
            !started -> Centered {
                if (preReader) PreReaderIntroCard(MiniGameKind.PAIRS, cue ?: PreReaderCue(spoken = PreReaderGames.startCue)) { deal() }
                else MiniGameIntroCard(MiniGameKind.PAIRS) { deal() }
            }
            done -> Centered {
                val title = if (missed.isEmpty()) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉")
                if (preReader) PreReaderEndCard(title, tr("כָּל הַזּוּגוֹת מְחֻבָּרִים!"), "🔗", matched.size, grant, surprise,
                    tr("עוֹד לוּחַ 🔁"), { deal() }, onClose)
                else MiniGameEndCard(title, tr("כָּל הַזּוּגוֹת מְחֻבָּרִים!"), grant, surprise, tr("עוֹד לוּחַ 🔁"), { deal() }, onClose)
            }
            else -> {
                val subtitle = when (source) {
                    MatchPairsSource.Capitals -> tr("כָּל מְדִינָה וְעִיר הַבִּירָה שֶׁלָּהּ")
                    MatchPairsSource.EnglishWords -> if (GameEnv.lang == AppLanguage.EN) tr("כָּל תְּמוּנָה וְהַמִּלָּה שֶׁלָּהּ")
                    else tr("כָּל מִלָּה וְהַתַּרְגּוּם שֶׁלָּהּ בְּאַנְגְּלִית")
                    MatchPairsSource.Math -> tr("כָּל תַּרְגִּיל וְהַתּוֹצָאָה שֶׁלּוֹ")
                    is MatchPairsSource.Bank -> tr("כָּל שְׁאֵלָה וְהַתְּשׁוּבָה שֶׁלָּהּ")
                }
                Column(
                    Modifier.weight(1f).widthIn(max = if (preReader) 600.dp else 760.dp).fillMaxWidth()
                        .verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    val pips = @Composable {
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            repeat(pairCount) { i ->
                                Box(Modifier.size(if (preReader) 13.dp else 9.dp).clip(CircleShape)
                                    .background(if (i < matched.size) KidColor.successMint else Color.White.copy(alpha = 0.25f)))
                            }
                        }
                    }
                    val c = cue
                    if (preReader && c != null) {
                        PreReaderCueCard(c, m.compact); pips()
                    } else {
                        Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 12.dp),
                            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            TitleText(tr("חַבְּרוּ אֶת הַזּוּגוֹת 🔗"), if (m.compact) 26.sp else 32.sp, maxLines = 1)
                            Text(subtitle, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                            pips()
                        }
                    }
                    val dx = shakeOffset(shake)
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        listOf(true, false).forEach { left ->
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                (if (left) lefts else rights).forEachIndexed { i, card ->
                                    val isMatched = card.pair in matched
                                    val isPicked = (if (left) pickedLeft else pickedRight) == card.pair
                                    val isWrong = (if (left) wrongLeft else wrongRight) == card.pair
                                    val state = when { isMatched -> TileState.CORRECT; isWrong -> TileState.WRONG; isPicked -> TileState.PICKED; else -> TileState.NORMAL }
                                    val minH = if (preReader) (if (m.short) 80.dp else if (m.compact) 96.dp else 130.dp)
                                    else (if (m.short) 56.dp else if (m.compact) 68.dp else 104.dp)
                                    val longest = card.text.split(" ", "\n").maxOfOrNull { it.length } ?: card.text.length
                                    val fs = if (preReader) (if (m.short) 40 else if (m.compact) 52 else 68)
                                    else { val base = if (m.compact) 20 else 28; if (longest >= 11 || card.text.length > 30) base - 4 else base }
                                    Box(
                                        Modifier.fillMaxWidth().heightIn(min = minH)
                                            .graphicsLayer { translationX = if (isWrong) dx * density else 0f; val s = if (isPicked) 1.04f else if (isMatched) 0.98f else 1f; scaleX = s; scaleY = s }
                                            .miniGameTile(state, TileTints[(i + if (left) 0 else 2) % 4], 20.dp)
                                            .juicyClick(!isMatched) { tap(card, left) }.padding(horizontal = 10.dp, vertical = 8.dp),
                                        contentAlignment = Alignment.Center,
                                    ) { GameText(card.text, fs.sp, weight = FontWeight.Bold, maxLines = 4, minScale = 0.55f) }
                                }
                            }
                        }
                    }
                    Spacer(Modifier.padding(4.dp))
                }
            }
        }
    }
}

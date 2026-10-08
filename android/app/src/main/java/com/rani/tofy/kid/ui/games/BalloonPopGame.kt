package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlin.math.abs
import kotlin.math.sin
import kotlin.random.Random

/**
 * 🎈 BalloonPopView.swift — "פּוֹצְצוּ אֶת הַבַּלּוֹנִים": a category rule and
 * balloons floating up at different speeds. Pop the right ones; a wrong one only
 * wobbles; one that floats away just floats away. 30 seconds.
 * A world without a category of its own plays it as questions (pop the answer).
 * 👶 גן: the rule is a picture + spoken, bigger balloons, no clock — six good pops.
 */
@Composable
fun BalloonPopGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val preReader = GameEnv.activeChildIsPreReader
    val grade = maxOf(1, GameEnv.grade(2))
    val roundSeconds = MiniGameKind.BALLOON.seconds(surprise).toDouble()
    val palette = remember { listOf("FF6B9D", "06D6A0", "FFB84D", "48BFE3", "9B5DE5").map { hexColor(it) } }

    class Balloon(val item: BalloonItem, val lane: Float, val spawnedAt: Double, val round: Int, val duration: Double,
                  val color: Color, val sway: Double) {
        var poppedAt by mutableStateOf<Double?>(null)
        var wobbledAt by mutableStateOf<Double?>(null)
        val id = Random.nextLong()
    }

    var phase by remember { mutableIntStateOf(0) }   // 0 intro · 1 playing · 2 done
    var set by remember { mutableStateOf<BalloonSet?>(null) }
    val balloons = remember { mutableStateListOf<Balloon>() }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var nextSpawnAt by remember { mutableDoubleStateOf(0.0) }
    val targetQueue = remember { ArrayList<BalloonItem>() }
    val otherQueue = remember { ArrayList<BalloonItem>() }
    var lastLane by remember { mutableStateOf(0.5f) }
    var popped by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var bestStreak by remember { mutableIntStateOf(0) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var cue by remember { mutableStateOf<PreReaderCue?>(null) }
    var preDealt by remember { mutableStateOf(false) }
    // Question mode — the world's questions, the one on screen, whether it already took a miss.
    var questions by remember { mutableStateOf(listOf<GameItem>()) }
    var qIndex by remember { mutableIntStateOf(0) }
    var qMissed by remember { mutableStateOf(false) }
    val qQueue = remember { ArrayList<String>() }
    var sinceCorrect by remember { mutableIntStateOf(0) }
    var qShownAt by remember { mutableDoubleStateOf(nowSecs()) }
    val questionMode = questions.isNotEmpty()
    val current: GameItem? = if (questionMode) questions[qIndex % questions.size] else null
    val remaining = maxOf(0.0, roundSeconds - (now - startedAt))

    fun dealPreReader() {
        val round = PreReaderGames.balloons()
        questions = emptyList(); qIndex = 0; qMissed = false; qQueue.clear(); sinceCorrect = 0; qShownAt = nowSecs()
        set = round.set; cue = round.cue; preDealt = true
    }

    fun resetRound() {
        targetQueue.clear(); otherQueue.clear(); balloons.clear()
        popped = 0; streak = 0; bestStreak = 0; grant = null
        startedAt = nowSecs(); now = startedAt; nextSpawnAt = startedAt
        phase = 1
    }

    fun start() {
        // 👶 גן never plays the world's bank: its board is pictures only.
        if (preReader) {
            if (!preDealt) dealPreReader()
            preDealt = false
            resetRound(); return
        }
        cue = null
        questions = if (topic != null && !BalloonSets.hasCategory(topic, grade))
            GameContent.items(topic, grade, maxPrompt = 70, maxAnswer = 16) else emptyList()
        qIndex = 0; qMissed = false; qQueue.clear(); sinceCorrect = 0; qShownAt = nowSecs()
        val s = BalloonSets.make(topic, grade)
        set = if (questions.isNotEmpty()) BalloonSet("", topic ?: s.topic, emptyList(), emptyList()) else s
        resetRound()
    }

    fun nextItem(): BalloonItem? {
        val q = if (questions.isNotEmpty()) questions[qIndex % questions.size] else null
        if (q != null) {
            // Its answers in turn — the right one never more than 3 balloons apart.
            if (sinceCorrect >= 2) { sinceCorrect = 0; return BalloonItem("", q.answer, true) }
            if (qQueue.isEmpty()) qQueue += q.shuffledOptions()
            val label = qQueue.removeAt(qQueue.size - 1)
            val right = label == q.answer
            sinceCorrect = if (right) 0 else sinceCorrect + 1
            return BalloonItem("", label, right)
        }
        val s = set ?: return null
        // 🎚️ The younger the child, the more of the balloons are the right ones.
        val share = when (MiniGameBand.of(if (preReader) 0 else grade)) {
            MiniGameBand.PRE_READER -> 0.70; MiniGameBand.LOWER -> 0.65; MiniGameBand.MIDDLE -> 0.55
            MiniGameBand.UPPER -> 0.48; MiniGameBand.TOP -> 0.42
        }
        if (Random.nextDouble() < share) {
            if (targetQueue.isEmpty()) targetQueue += s.targets.shuffled()
            return targetQueue.removeLastOrNull()
        }
        if (otherQueue.isEmpty()) otherQueue += s.others.shuffled()
        return otherQueue.removeLastOrNull()
    }

    fun finish() {
        if (phase != 1) return
        balloons.clear()
        grant = MiniGameReward.grant("balloon", popped, 1, 1, if (surprise) 12 else 15, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
        if (popped > 0) confetti++
    }

    fun tap(b: Balloon) {
        if (phase != 1 || b.poppedAt != null || b.wobbledAt != null) return
        val s = set ?: return
        if (questionMode && b.round != qIndex) return   // an earlier question's balloon
        if (b.item.correct) {
            b.poppedAt = nowSecs()
            popped++; streak++; bestStreak = maxOf(bestStreak, streak); burst++
            play(if (streak % 5 == 0) AppSound.STREAK_UP else AppSound.CORRECT_SMALL); h.success()
        } else {
            // A gentle wobble — the balloon stays and floats on; no word about it.
            b.wobbledAt = nowSecs()
            streak = 0
            play(AppSound.WRONG_SOFT); h.light()
        }
        val q = current
        if (q != null) {
            if (!b.item.correct) {
                if (!qMissed) { qMissed = true; MiniGameLedger.record(false, q.topic, earn = earn, surprise = surprise) }
                return
            }
            MiniGameLedger.record(true, q.topic, (nowSecs() - qShownAt) * 1000, streak, earn, surprise, retry = qMissed)
            // The next question: this one's other balloons drift off.
            val old = qIndex
            qIndex++
            qMissed = false; qQueue.clear(); sinceCorrect = 0; qShownAt = nowSecs()
            balloons.removeAll { it.round == old && it.poppedAt == null }
            nextSpawnAt = nowSecs() + 0.3
            return
        }
        // Every tap is an answer in the parent's reports.
        MiniGameLedger.record(b.item.correct, s.topic, streak = streak, earn = earn, surprise = surprise)
    }

    LaunchedEffect(Unit) {
        if (preReader && !preDealt) dealPreReader()
        if ((surprise || earn != null) && phase == 0) start()
    }

    // The ticker: positions are a function of time, so one clock drives the sky.
    LaunchedEffect(phase) {
        while (phase == 1) {
            withFrameMillis { }
            val t = nowSecs()
            now = t
            balloons.removeAll { b -> b.poppedAt?.let { t - it > 0.4 } ?: (t - b.spawnedAt > b.duration) }
            // 👶 גן: six good pops (a long backstop still closes it); everyone else: the clock.
            if (preReader) {
                if (popped >= PreReaderGames.ROUND_ITEMS || t - startedAt > 120) { finish(); break }
            } else if (roundSeconds - (t - startedAt) <= 0) { finish(); break }
            if (t >= nextSpawnAt && balloons.size < (if (preReader) 4 else 9)) {
                val item = nextItem()
                if (item != null) {
                    var lane = Random.nextFloat()
                    if (abs(lane - lastLane) < 0.25f) lane = if (lane > 0.5f) lane - 0.35f else lane + 0.35f
                    lastLane = lane
                    // 🎚️ And they rise faster: a ח׳ child has less time to decide.
                    val slow = when (MiniGameBand.of(if (preReader) 0 else grade)) {
                        MiniGameBand.PRE_READER -> 1.9; MiniGameBand.LOWER -> if (grade <= 1) 1.25 else 1.1
                        MiniGameBand.MIDDLE -> 1.0; MiniGameBand.UPPER -> 0.88; MiniGameBand.TOP -> 0.78
                    }
                    balloons += Balloon(item, lane, t, qIndex, (4.6 + Random.nextDouble() * 2.4) * slow, palette.random(), Random.nextDouble() * 6.28)
                    nextSpawnAt = t + (0.55 + Random.nextDouble() * 0.4) * slow
                }
            }
        }
    }

    val chip = if (preReader) "🎈 " + PreReaderChrome.dots(popped, PreReaderGames.ROUND_ITEMS) else "🎈 $popped"
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.starGold, confetti) {
        when (phase) {
            0 -> Centered {
                if (preReader) PreReaderIntroCard(MiniGameKind.BALLOON, cue ?: PreReaderCue(spoken = PreReaderGames.startCue)) { start() }
                else MiniGameIntroCard(MiniGameKind.BALLOON) { start() }
            }
            2 -> Centered {
                val first = when (popped) {
                    0 -> if (surprise) tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") else tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
                    1 -> tr("בַּלּוֹן נָכוֹן אֶחָד")
                    else -> tr("%lld בַּלּוֹנִים נְכוֹנִים", popped)
                }
                val summary = if (bestStreak >= 2) first + "\n" + tr("הָרֶצֶף הֲכִי אָרֹךְ: %lld 🔥", bestStreak) else first
                if (preReader) PreReaderEndCard(if (popped >= 6) tr("וָואוּ, מְצֻיָּן! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"), summary,
                    "🎈", popped, grant, surprise, tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
                else MiniGameEndCard(if (popped >= 12) tr("וָואוּ, מְצֻיָּן! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"), summary, grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (preReader) 700.dp else 900.dp).fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                val c = cue
                if (preReader && c != null) Box(Modifier.padding(horizontal = 16.dp)) { PreReaderCueCard(c, m.compact) }
                else Column(
                    Modifier.padding(horizontal = 16.dp).fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    if (current != null) {
                        Text(tr("פּוֹצְצוּ אֶת הַתְּשׁוּבָה הַנְּכוֹנָה!"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                        GameText(current.prompt, if (m.compact) 22.sp else 28.sp, maxLines = 4, minScale = 0.6f)
                    } else TitleText(set?.prompt ?: "", if (m.compact) 22.sp else 28.sp, maxLines = 3)
                    MiniGameTimerBar(remaining, roundSeconds)
                }
                Text(if (preReader) PreReaderChrome.streak(streak) else if (streak >= 2) tr("🔥 %lld בְּרֶצֶף", streak) else " ",
                    color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().clip(androidx.compose.ui.graphics.RectangleShape)) {
                    val size = if (preReader) { if (m.short) 100.dp to 120.dp else if (m.compact) 126.dp to 150.dp else 158.dp to 186.dp }
                    else if (m.compact) 96.dp to 114.dp else 124.dp to 146.dp
                    val fieldW = maxWidth; val fieldH = maxHeight
                    balloons.forEach { b ->
                        val age = now - b.spawnedAt
                        val progress = (age / b.duration).toFloat()
                        val y = fieldH + size.second / 2 - (fieldH + size.second * 1.4f) * progress
                        val sway = (sin(age * 1.6 + b.sway) * 10).toFloat().dp
                        val usable = maxOf(1.dp, fieldW - size.first)
                        val x = size.first / 2 + usable * b.lane + sway
                        val wob = b.wobbledAt?.let { w -> val dt = now - w; if (dt < 0.6) (sin(dt * 28) * 14 * (1 - dt / 0.6)).toFloat() else 0f } ?: 0f
                        val popT = b.poppedAt?.let { now - it } ?: -1.0
                        Box(Modifier.offset(x - size.first / 2, y - size.second / 2).size(size.first, size.second)) {
                            if (popT >= 0) PopRing(size.first, popT.toFloat())
                            else BalloonShape(b.item, b.item.colorHex?.let { hexColor(it) } ?: b.color, size.first, size.second, b.wobbledAt != null,
                                Modifier.graphicsLayer { rotationZ = wob; transformOrigin = TransformOrigin(0.5f, 1f) }
                                    .clickable(remember { MutableInteractionSource() }, null) { tap(b) })
                        }
                    }
                }
            }
        }
    }
}

/** Popped: a mint ring and a sparkle, gone in a moment. */
@Composable
private fun PopRing(w: Dp, t: Float) {
    Box(Modifier.fillMaxSize().graphicsLayer { alpha = maxOf(0f, 1 - t / 0.35f) }, contentAlignment = Alignment.Center) {
        val d = w * (0.6f + t * 2)
        Box(Modifier.size(d).border(4.dp, Color(0xFF8CFFC4), CircleShape))
        Text("✨", fontSize = 34.sp)
    }
}

/** One balloon: a glossy oval in its colour, a knot and a string, the word / number / picture riding on it. */
@Composable
private fun BalloonShape(item: BalloonItem, color: Color, w: Dp, h: Dp, tried: Boolean, modifier: Modifier) {
    val bodyH = h * 0.82f
    val pictureScale = when (item.emoji.graphemes()) { 0, 1 -> 0.52f; 2 -> 0.34f; 3 -> 0.26f; 4 -> 0.21f; else -> 0.17f }
    Column(modifier.size(w, h), horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier.size(w, bodyH).graphicsLayer { alpha = if (tried) 0.75f else 1f }.clip(androidx.compose.foundation.shape.GenericShape { s, _ ->
                addOval(androidx.compose.ui.geometry.Rect(0f, 0f, s.width, s.height))
            }).background(Brush.radialGradient(listOf(color.copy(alpha = 0.95f), color.copy(alpha = 0.78f)), center = Offset.Unspecified))
                .border(1.2.dp, Color.White.copy(alpha = 0.45f), androidx.compose.foundation.shape.GenericShape { s, _ ->
                    addOval(androidx.compose.ui.geometry.Rect(0f, 0f, s.width, s.height))
                }),
            contentAlignment = Alignment.Center,
        ) {
            Canvas(Modifier.fillMaxSize()) {
                drawOval(Color.White.copy(alpha = 0.35f), topLeft = Offset(size.width * 0.19f, size.height * 0.16f),
                    size = androidx.compose.ui.geometry.Size(size.width * 0.22f, size.height * 0.16f))
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val wv = w.value
                if (item.emoji.isNotEmpty()) {
                    FitText(item.emoji, (wv * (if (item.label.isEmpty()) pictureScale else 0.3f)).sp, Modifier.padding(horizontal = (wv * 0.1f).dp),
                        maxLines = 1, minScale = 0.4f)
                }
                if (item.label.isNotEmpty()) {
                    val fs = if (item.emoji.isEmpty()) wv * (if (item.label.length > 6) 0.2f else 0.26f) else wv * 0.15f
                    GameText(item.label, fs.sp, Modifier.padding(horizontal = 8.dp), maxLines = 2, minScale = 0.45f)
                }
            }
        }
        // Knot + string.
        Canvas(Modifier.width(10.dp).height(7.dp)) {
            val p = androidx.compose.ui.graphics.Path().apply { moveTo(size.width / 2, 0f); lineTo(size.width, size.height); lineTo(0f, size.height); close() }
            drawPath(p, color.copy(alpha = 0.9f))
        }
        Box(Modifier.width(1.2.dp).height(maxOf(1.dp, h * 0.18f - 7.dp)).background(Color.White.copy(alpha = 0.55f)))
    }
}

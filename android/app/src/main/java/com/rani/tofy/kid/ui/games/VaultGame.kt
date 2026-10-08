package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
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
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🔐 VaultGameView.swift — "הַכַּסֶּפֶת": a safe with three dials. Every right
 * answer turns the next dial onto its digit; three dials and the door swings
 * open on the treasure.
 *
 * Rani, 2026-10-07: "משחק הכספת הוא מסובך מידי! ולא מובן". The version before
 * opened a CLUE per answer and asked the child to deduce the code from all of
 * them — two games at once. Now: a question → a dial → the next question.
 * From ה׳ the digit hides in a small exercise and the child turns the dial.
 * A miss never fails: the dial stays put and the next question comes.
 */
@Composable
fun VaultGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val mathWorld = topic == null || topic in listOf(Topic.MATH, Topic.MONEY, Topic.LOGIC, Topic.GIFTED)
    val grade = MiniGameLevel.grade(if (mathWorld) Topic.MATH else topic)
    val recordTopic = topic ?: Topic.LOGIC
    // ה׳ and up work the digit out themselves.
    val solvesDigits = grade >= 5
    val dials = 3
    val rtl = GameEnv.lang.rtl

    var phase by remember { mutableIntStateOf(0) }
    val code = remember { mutableStateListOf<Int>() }
    var opened by remember { mutableIntStateOf(0) }
    var question by remember { mutableStateOf<GameItem?>(null) }
    var riddle by remember { mutableStateOf<String?>(null) }
    var riddleMiss by remember { mutableStateOf(false) }
    var missNote by remember { mutableStateOf(false) }
    // The next question is already on its way — the button is only for a
    // child who put a question away.
    var nextPending by remember { mutableStateOf(false) }
    val seen = remember { HashSet<String>() }
    var askedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var cracked by remember { mutableStateOf(false) }
    var doorOpen by remember { mutableStateOf(false) }
    var shake by remember { mutableIntStateOf(0) }
    var coins by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }

    fun ask() {
        nextPending = false
        if (phase != 1 || opened >= dials || question != null || riddle != null || cracked) return
        val item = if (mathWorld && kotlin.random.Random.nextBoolean()) VaultGen.dialQuestion(grade)
        else GameContent.card(topic, maxOf(1, GameEnv.grade(2)), seen)
        askedAt = nowSecs()
        question = item
    }

    fun finish() {
        if (phase != 1) return
        grant = MiniGameReward.grant("vault", 3 + opened, 2, 1, 10, surprise)
        phase = 2
        h.success()
    }

    fun crack() {
        cracked = true
        play(AppSound.LEVEL_UP)
        MiniGameLedger.record(true, recordTopic, (nowSecs() - startedAt) * 1000, earn = earn, surprise = surprise)
        scope.launch {
            delay(450); doorOpen = true; confetti++; coins++
            delay(1750); finish()
        }
    }

    /** Click — the next dial lands on its digit. */
    fun turnDial() {
        play(AppSound.CHEST_OPEN); h.success()
        opened++
        if (opened >= dials) crack()
        else { nextPending = true; scope.launch { delay(800); ask() } }
    }

    fun start() {
        code.clear(); code.addAll((1..9).shuffled().take(dials))
        opened = 0; question = null; riddle = null; riddleMiss = false; missNote = false
        nextPending = true   // the round asks its first question itself
        seen.clear(); cracked = false; doorOpen = false; grant = null
        startedAt = nowSecs()
        phase = 1
        scope.launch { delay(350); ask() }
    }

    fun answered(item: GameItem, right: Boolean) {
        MiniGameLedger.record(right, item.topic, (nowSecs() - askedAt) * 1000, earn = earn, surprise = surprise)
        question = null
        if (!right) {
            // The dial just stays put; the next question comes by itself.
            missNote = true; nextPending = true
            scope.launch { delay(900); ask() }
            return
        }
        missNote = false; coins++
        if (solvesDigits) { riddleMiss = false; riddle = VaultGen.expression(code[opened], grade) }
        else turnDial()
    }

    fun pickDigit(d: Int) {
        if (riddle == null || opened >= code.size) return
        if (d != code[opened]) { h.light(); shake++; riddleMiss = true; return }
        riddle = null; riddleMiss = false
        turnDial()
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    GameFrame(onClose, earn, surprise, if (code.isEmpty()) "🔐" else "🔐 $opened/$dials", coins, KidColor.starGold, confetti) {
        when (phase) {
            0 -> Centered { MiniGameIntroCard(MiniGameKind.VAULT) { start() } }
            2 -> Centered {
                MiniGameEndCard(tr("פְּתַחְתֶּם אֶת הַכַּסֶּפֶת! 🔓"), tr("שָׁלֹשׁ תְּשׁוּבוֹת נְכוֹנוֹת — וְהָאוֹצָר שֶׁלָּכֶם! 💎"), grant, surprise,
                    tr("עוֹד כַּסֶּפֶת 🔁"), { start() }, onClose)
            }
            else -> Box(Modifier.weight(1f).fillMaxWidth()) {
                Column(
                    Modifier.align(Alignment.TopCenter).widthIn(max = if (m.compact) 560.dp else 680.dp).fillMaxWidth().padding(horizontal = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 10.dp else 16.dp),
                ) {
                    FitText(tr("🔑 עוֹנִים נָכוֹן ← 🎡 גַּלְגַּל מִסְתּוֹבֵב ← 🔓 הַכַּסֶּפֶת נִפְתַּחַת"), (if (m.compact) 14 else 18).sp,
                        Modifier.fillMaxWidth().glassPane(18.dp).padding(horizontal = 12.dp, vertical = if (m.compact) 7.dp else 10.dp),
                        weight = FontWeight.ExtraBold, maxLines = 2, minScale = 0.7f)
                    Safe(code, opened, cracked, doorOpen, rtl, shake, if (m.compact) 76f else 104f)
                    val r = riddle
                    if (r != null) RiddlePanel(r, riddleMiss, m.compact) { pickDigit(it) }
                    else if (!cracked && question == null && !nextPending) {
                        MiniGameGoldButton(tr("🔑 לַשְּׁאֵלָה הַבָּאָה"), Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp)) { ask() }
                    }
                    if (missNote && riddle == null && !cracked) {
                        SubText(tr("לֹא נוֹרָא! הַגַּלְגַּל מְחַכֶּה לַשְּׁאֵלָה הַבָּאָה 💪"), (if (m.compact) 14 else 16).sp, color = Color.White)
                    }
                }
                val item = question
                if (item != null) {
                    // Tapping outside puts it away — the child must be able to reach the ✕.
                    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f))
                        .clickable(remember { MutableInteractionSource() }, null) { question = null }, contentAlignment = Alignment.Center) {
                        key(item) { MiniGameQuestionCard(item, tr("🔑 תְּשׁוּבָה נְכוֹנָה מְסוֹבֶבֶת גַּלְגַּל!")) { right -> answered(item, right) } }
                    }
                }
            }
        }
    }
}

/** The safe: a steel door with three dials and a handle; it swings open on the treasure. */
@Composable
private fun Safe(code: List<Int>, opened: Int, cracked: Boolean, doorOpen: Boolean, rtl: Boolean, shake: Int, dial: Float) {
    val swing by animateFloatAsState(if (doorOpen) 75f else 0f,
        spring(dampingRatio = 0.75f, stiffness = Spring.StiffnessLow), label = "door")
    val handle by animateFloatAsState(if (cracked) -35f else 0f, label = "handle")
    val dx = shakeOffset(shake)
    val shape = RoundedCornerShape(28.dp)
    Box(Modifier.fillMaxWidth().height((dial * 1.25f + if (dial > 90f) 110f else 80f).dp)) {
        // Behind the door: the treasure.
        Box(Modifier.fillMaxSize().clip(shape)
            .background(Brush.verticalGradient(listOf(Color(0xFF2A1F5C), Color(0xFF1A1240)))),
            contentAlignment = Alignment.Center) {
            if (doorOpen) Text("💎⭐💰", fontSize = (if (dial > 90f) 62 else 46).sp)
        }
        // The door.
        Column(
            Modifier.fillMaxSize()
                .graphicsLayer {
                    rotationY = swing
                    cameraDistance = 12f * density
                    transformOrigin = TransformOrigin(0f, 0.5f)
                }
                .clip(shape)
                .background(Brush.linearGradient(listOf(Color(0xFF8E86C9), Color(0xFF5B5196))))
                .border(2.dp, Color.White.copy(alpha = 0.4f), shape),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(if (dial > 90f) 20.dp else 14.dp, Alignment.CenterVertically),
        ) {
            // A number reads left to right in every language (Rani): first dial on the LEFT.
            Ltr {
                Row(Modifier.graphicsLayer { translationX = dx * density }, horizontalArrangement = Arrangement.spacedBy(if (dial > 90f) 18.dp else 12.dp)) {
                    for (i in 0 until 3) DialView(code.getOrNull(i), set = i < opened, next = i == opened && !cracked, size = dial)
                }
            }
            Box(Modifier.width((if (dial > 90f) 120 else 90).dp).height(14.dp)
                .graphicsLayer { rotationZ = handle }
                .clip(RoundedCornerShape(50))
                .background(Brush.verticalGradient(listOf(Color(0xFFE9E4FF), Color(0xFF9A93C9)))))
        }
    }
}

@Composable
private fun DialView(digit: Int?, set: Boolean, next: Boolean, size: Float) {
    val spin by animateFloatAsState(if (set) 360f else 0f, spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessLow), label = "dial")
    Box(
        Modifier.size(size.dp).graphicsLayer { rotationZ = spin }.clip(CircleShape)
            .background(Brush.radialGradient(listOf(Color.White.copy(alpha = if (set) 0.95f else 0.35f),
                Color(0xFFC9C3F0).copy(alpha = if (set) 0.9f else 0.2f))))
            .border(if (set || next) 3.dp else 1.5.dp,
                if (set) KidColor.starGold else Color.White.copy(alpha = if (next) 0.9f else 0.4f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        if (set && digit != null) Text("$digit", color = Color(0xFF3B2F86), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (size * 0.5f).sp)
        else Text("?", color = Color.White.copy(alpha = if (next) 0.85f else 0.45f), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (size * 0.42f).sp)
    }
}

/** ה׳+: the exercise for the dial just earned, and the nine digits. */
@Composable
private fun RiddlePanel(text: String, miss: Boolean, compact: Boolean, onDigit: (Int) -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(14.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
        FitText(tr("🎡 סוֹבְבוּ אֶת הַגַּלְגַּל לַתְּשׁוּבָה:"), (if (compact) 14 else 17).sp, color = KidColor.starGold, weight = FontWeight.ExtraBold, maxLines = 1)
        FitText(MiniGameText.ltr("$text = ?"), (if (compact) 26 else 34).sp, weight = FontWeight.Black, maxLines = 1, minScale = 0.6f)
        Ltr {
            Column(Modifier.widthIn(max = if (compact) 300.dp else 380.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                for (row in 0 until 3) Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    for (col in 1..3) {
                        val d = row * 3 + col
                        Box(Modifier.weight(1f).height(if (compact) 44.dp else 56.dp).clip(RoundedCornerShape(14.dp))
                            .background(Color.White.copy(alpha = 0.14f)).border(1.dp, Color.White.copy(alpha = 0.28f), RoundedCornerShape(14.dp))
                            .juicyClick { onDigit(d) }, contentAlignment = Alignment.Center) {
                            Text("$d", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (compact) 22 else 28).sp)
                        }
                    }
                }
            }
        }
        if (miss) SubText(tr("כִּמְעַט! בִּדְקוּ שׁוּב אֶת הַתַּרְגִּיל 🔍"), (if (compact) 13.5f else 15.5f).sp, color = Color.White)
    }
}

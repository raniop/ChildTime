package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.font.FontWeight
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.cos
import kotlin.math.sin

/**
 * ⚖️ BalanceGameView.swift — "מֹאזְנַיִם": two pans on a beam; pick the missing
 * value (a number pad from ו׳) and the beam swings to it — level when right,
 * still leaning when not, so a miss itself says "more" or "less". A world whose
 * questions have number answers plays it as "?" against a 🎁. Five a round.
 */
@Composable
fun BalanceGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val count = if (surprise) 4 else BalanceGen.ROUND_COUNT
    val numbersWorld = topic == null || topic in listOf(Topic.MATH, Topic.MONEY, Topic.LOGIC, Topic.GIFTED)
    val grade = MiniGameLevel.grade(if (numbersWorld) (topic ?: Topic.MATH) else topic)

    var phase by remember { mutableIntStateOf(0) }
    var puzzle by remember { mutableStateOf<BalancePuzzle?>(null) }
    var index by remember { mutableIntStateOf(0) }
    var trial by remember { mutableStateOf<String?>(null) }
    val wrongPicks = remember { mutableStateListOf<String>() }
    var solved by remember { mutableStateOf(false) }
    var missed by remember { mutableStateOf(false) }
    var clean by remember { mutableIntStateOf(0) }
    var typed by remember { mutableStateOf("") }
    var bank by remember { mutableStateOf(listOf<GameItem>()) }
    var shake by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }

    fun load() {
        puzzle = if (!numbersWorld && bank.isNotEmpty()) BalanceGen.compare(bank[index % bank.size], grade) ?: BalanceGen.make(grade, Topic.MATH)
        else BalanceGen.make(grade, topic ?: Topic.MATH)
        trial = null; wrongPicks.clear(); solved = false; missed = false; typed = ""; shownAt = nowSecs()
    }

    fun start() {
        index = 0; clean = 0; grant = null
        bank = if (numbersWorld) emptyList() else GameContent.numericItems(topic!!, grade)
        load(); phase = 1
    }

    fun finish() {
        if (phase != 1) return
        // Every puzzle SOLVED pays (the scales only move on when solved) — `clean` is the headline.
        grant = MiniGameReward.grant("balance", count, 2, 1, BalanceGen.ROUND_COUNT, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }

    fun tryIt(opt: String) {
        val p = puzzle ?: return
        if (phase != 1 || solved) return
        val v = p.value(opt) ?: return
        val target = p.value(p.answer) ?: Double.NaN
        val right = kotlin.math.abs(v - target) < 0.0001
        trial = opt
        if (right) {
            solved = true
            if (!missed) clean++
            // Solved on the second try still pays — the runner's re-ask.
            MiniGameLedger.record(true, p.topic, (nowSecs() - shownAt) * 1000, clean, earn, surprise, retry = missed)
            burst++; play(AppSound.CORRECT_BIG); h.success()
            scope.launch {
                delay(1400)
                if (phase != 1) return@launch
                if (index + 1 < count) { index++; load() } else finish()
            }
        } else {
            if (!missed) { missed = true; MiniGameLedger.record(false, p.topic, earn = earn, surprise = surprise) }
            play(AppSound.WRONG_SOFT); h.light()
            wrongPicks += opt
            if (p.numberPad) typed = ""
        }
    }

    fun press(k: String) {
        if (solved) return
        if (k == "⌫") { if (typed.isNotEmpty()) typed = typed.dropLast(1); return }
        if (k == "." || typed.length >= 4) return
        typed += k; trial = null
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    GameFrame(onClose, earn, surprise, "⚖️ ${minOf(index + 1, count)}/$count", burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered { MiniGameIntroCard(MiniGameKind.BALANCE) { start() } }
            2 -> Centered {
                MiniGameEndCard(if (clean == count) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"), tr("אִזַּנְתֶּם %lld מֹאזְנַיִם!", count), grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (m.compact) 640.dp else 820.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
            ) {
                val p = puzzle
                Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 12.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("מָה מֵבִיא אֶת הַמֹּאזְנַיִם לְאִזּוּן?"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 15 else 19).sp)
                    p?.question?.let { GameText(it, (if (m.compact) 21 else 27).sp, maxLines = 4, minScale = 0.6f) }
                }
                val dx = shakeOffset(shake)
                Box(Modifier.weight(1f).fillMaxWidth().heightIn(max = if (m.short) 190.dp else if (m.compact) 240.dp else 340.dp)
                    .graphicsLayer { translationX = dx * density }) {
                    if (p != null) Scale(p, trial, solved, m.compact)
                }
                if (p?.numberPad == true) {
                    MiniGameAnswerWell(typed, if (solved) TileState.CORRECT else if (trial != null && !solved) TileState.WRONG else TileState.NORMAL,
                        height = if (m.compact) 56.dp else 70.dp)
                    Box(Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp)) {
                        MiniGameNumberPad(keyHeight = if (m.short) 38.dp else if (m.compact) 44.dp else 58.dp) { press(it) }
                    }
                    Box(Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp).graphicsLayer { alpha = if (typed.isEmpty()) 0.5f else 1f }) {
                        MiniGameGoldButton(tr("בְּדִיקָה ✓")) { if (typed.isNotEmpty() && !solved) tryIt(typed) }
                    }
                } else {
                    val opts = p?.options ?: emptyList()
                    val cols = if (m.compact) 2 else 4
                    Ltr {
                        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            opts.chunked(cols).forEachIndexed { row, chunk ->
                                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                    chunk.forEachIndexed { k, opt ->
                                        val state = if (solved && opt == p?.answer) TileState.CORRECT else if (opt in wrongPicks) TileState.WRONG else TileState.NORMAL
                                        Box(Modifier.weight(1f).heightIn(min = if (m.compact) 70.dp else 100.dp).miniGameTile(state, TileTints[(row * cols + k) % 4], 22.dp)
                                            .juicyClick(!solved && opt !in wrongPicks) { tryIt(opt) }, contentAlignment = Alignment.Center) {
                                            FitText(MiniGameText.ltr(opt), (if (m.compact) 30 else 40).sp, weight = FontWeight.Black, maxLines = 1, minScale = 0.5f)
                                        }
                                    }
                                    repeat(cols - chunk.size) { Spacer(Modifier.weight(1f)) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** The beam, the stand, the strings and the two pans — geometry, so left stays left. */
@Composable
private fun Scale(p: BalancePuzzle, trial: String?, solved: Boolean, compact: Boolean) {
    val tilt by animateFloatAsState(BalanceGen.tilt(p, trial).toFloat(), spring(dampingRatio = 0.55f, stiffness = 120f), label = "tilt")
    Ltr {
        BoxWithConstraints(Modifier.fillMaxSize()) {
            val w = maxWidth; val hgt = maxHeight
            val pivotX = w / 2; val pivotY = hgt * 0.22f
            val arm = minOf(w * 0.29f, 300.dp)
            val a = Math.toRadians(tilt.toDouble())
            val lx = pivotX - arm * cos(a).toFloat(); val ly = pivotY - arm * sin(a).toFloat()
            val rx = pivotX + arm * cos(a).toFloat(); val ry = pivotY + arm * sin(a).toFloat()
            val string = hgt * 0.26f
            val panW = minOf(w * 0.38f, 260.dp)
            Canvas(Modifier.fillMaxSize()) {
                val pv = Offset(pivotX.toPx(), pivotY.toPx())
                drawLine(Color.White.copy(alpha = 0.55f), pv, Offset(pv.x, size.height * 0.92f), 6.dp.toPx(), StrokeCap.Round)
                drawRoundRect(Color.White.copy(alpha = 0.35f), Offset(pv.x - size.width * 0.16f, size.height * 0.93f - 6.dp.toPx()),
                    Size(size.width * 0.32f, 12.dp.toPx()), CornerRadius(6.dp.toPx()))
                val l = Offset(lx.toPx(), ly.toPx()); val r = Offset(rx.toPx(), ry.toPx())
                drawLine(Color.White.copy(alpha = 0.5f), l, Offset(l.x, l.y + string.toPx()), 1.5.dp.toPx())
                drawLine(Color.White.copy(alpha = 0.5f), r, Offset(r.x, r.y + string.toPx()), 1.5.dp.toPx())
                rotate(tilt, pv) {
                    val bw = arm.toPx() * 2 + 24.dp.toPx()
                    drawRoundRect(Brush.verticalGradient(listOf(Color(0xFFFFD23F), Color(0xFFFF9F1C))),
                        Offset(pv.x - bw / 2, pv.y - 6.dp.toPx()), Size(bw, 12.dp.toPx()), CornerRadius(6.dp.toPx()))
                    if (solved) drawRoundRect(KidColor.successMint.copy(alpha = 0.5f), Offset(pv.x - bw / 2, pv.y - 8.dp.toPx()), Size(bw, 16.dp.toPx()),
                        CornerRadius(8.dp.toPx()), style = Stroke(2.dp.toPx()))
                }
                drawCircle(Color.White, 8.dp.toPx(), pv)
            }
            PanAt(p.left, p, trial, solved, compact, panW, lx, ly + string + 30.dp)
            PanAt(p.right, p, trial, solved, compact, panW, rx, ry + string + 30.dp)
        }
    }
}

@Composable
private fun PanAt(text: String, p: BalancePuzzle, trial: String?, solved: Boolean, compact: Boolean,
                  width: androidx.compose.ui.unit.Dp, cx: androidx.compose.ui.unit.Dp, cy: androidx.compose.ui.unit.Dp) {
    // "?" is filled in when found; an equation's x keeps its letter and shows "x = 4" underneath.
    val isX = !text.contains("?") && text.contains("x")
    val hasHole = text.contains("?") || isX
    val mark = if (isX) "x" else "?"
    val shown = if (text.contains("?") && solved) text.replace("?", p.answer) else text
    // Centre the pan on (cx, cy): measure, then place.
    Layout(content = {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Box(Modifier.widthIn(max = width).miniGameTile(if (hasHole) (if (solved) TileState.CORRECT else TileState.PICKED) else TileState.NORMAL, KidColor.starGold, 18.dp)
                .padding(horizontal = 14.dp, vertical = 10.dp), contentAlignment = Alignment.Center) {
                FitText(MiniGameText.ltr(shown), (if (compact) 26 else 36).sp, weight = FontWeight.Black, maxLines = 1, minScale = 0.5f)
            }
            Canvas(Modifier.width(width * 0.9f).height(14.dp)) {
                val path = Path().apply { moveTo(0f, 0f); quadraticTo(size.width / 2, size.height * 2, size.width, 0f); close() }
                drawPath(path, Color.White.copy(alpha = 0.22f))
                drawPath(path, Color.White.copy(alpha = 0.4f), style = Stroke(1.dp.toPx()))
            }
            if (hasHole && trial != null && !solved) Text(MiniGameText.ltr("$mark = $trial"), color = KidColor.almostWarm, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            else if (isX && solved) Text(MiniGameText.ltr("x = ${p.answer}"), color = KidColor.successMint, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 17.sp)
        }
    }) { measurables, constraints ->
        val placeable = measurables.first().measure(constraints.copy(minWidth = 0, minHeight = 0))
        layout(constraints.maxWidth, constraints.maxHeight) {
            placeable.place(cx.roundToPx() - placeable.width / 2, cy.roundToPx() - placeable.height / 2)
        }
    }
}

package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.abs
import kotlin.math.ln

/**
 * 🔢 Game2048View.swift — the classic 4×4: swipe, equal tiles merge. Every few
 * moves a short bonus question from the world comes up — right → a bonus tile
 * drops onto the board. Ends at the clock (2½ min) or when no move is left.
 * The bonus questions are the learning: from a chooser each right one earns.
 */
@Composable
fun Game2048(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val grade = MiniGameLevel.grade(topic ?: Topic.MATH)
    val roundSeconds = MiniGameKind.GAME2048.seconds(surprise).toDouble()
    // 🎚️ ג׳–ד׳ every 5 moves, ה׳–ו׳ every 4, ז׳–ח׳ every 3; the bonus tile is half (¼ from ז׳) the biggest.
    val movesPerBonus = when (MiniGameBand.of(grade)) { MiniGameBand.UPPER -> 4; MiniGameBand.TOP -> 3; else -> 5 }
    val bonusTileDivisor = if (MiniGameBand.of(grade) >= MiniGameBand.TOP) 4 else 2

    var phase by remember { mutableIntStateOf(0) }
    var tiles by remember { mutableStateOf(listOf<Tile2048>()) }
    var ghostIDs by remember { mutableStateOf(setOf<Long>()) }
    var settling by remember { mutableStateOf(false) }
    var score by remember { mutableIntStateOf(0) }
    var best by remember { mutableIntStateOf(0) }
    var moves by remember { mutableIntStateOf(0) }
    var bonus by remember { mutableStateOf<GameItem?>(null) }
    val seenQuestions = remember { HashSet<String>() }
    var bonusRight by remember { mutableIntStateOf(0) }
    var bonusAsked by remember { mutableIntStateOf(0) }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var pausedFor by remember { mutableDoubleStateOf(0.0) }
    var bonusShownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var noMoves by remember { mutableStateOf(false) }

    // The clock stands still while a bonus question is on screen.
    val remaining = maxOf(0.0, roundSeconds - (now - startedAt) + pausedFor + (if (bonus != null) now - bonusShownAt else 0.0))
    val maxTile = tiles.maxOfOrNull { it.value } ?: 2

    fun spawn(value: Int? = null): Boolean {
        val (r, c) = Board2048.emptyCells(tiles).randomOrNull() ?: return false
        tiles = tiles + Tile2048(nextId(), value ?: if ((0 until 10).random() == 0) 4 else 2, r, c)
        return true
    }

    fun start() {
        tiles = emptyList(); ghostIDs = emptySet(); score = 0; moves = 0; bonus = null
        bonusRight = 0; bonusAsked = 0; noMoves = false; grant = null; pausedFor = 0.0
        best = GameEnv.prefs.getString(Board2048.bestKey())?.toIntOrNull() ?: 0
        spawn(); spawn()
        startedAt = nowSecs(); now = startedAt
        phase = 1
    }

    fun finish() {
        if (phase != 1) return
        bonus = null
        if (score > best) { best = score; GameEnv.prefs.putString(Board2048.bestKey(), "$score") }
        // Stars by the biggest tile reached (64 → 6 steps), plus the bonus answers.
        val steps = maxOf(0, (ln(maxOf(2, maxTile).toDouble()) / ln(2.0)).toInt() - 1)
        grant = MiniGameReward.grant("2048", steps + bonusRight, 1, 1, 12, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }

    fun askBonus() {
        val item = GameContent.card(topic, grade, seenQuestions)
        bonusShownAt = nowSecs(); bonusAsked++
        play(AppSound.PORTAL_APPEAR)
        bonus = item
    }

    fun answerBonus(item: GameItem, right: Boolean) {
        MiniGameLedger.record(right, item.topic, (nowSecs() - bonusShownAt) * 1000, bonusRight, earn, surprise)
        pausedFor += nowSecs() - bonusShownAt
        bonus = null
        if (right) {
            bonusRight++
            val v = maxOf(4, maxTile / bonusTileDivisor)
            scope.launch {
                delay(300)
                if (spawn(v)) { burst++; h.success() }
                if (!Board2048.canMove(tiles)) { noMoves = true; finish() }
            }
        } else if (!Board2048.canMove(tiles)) { noMoves = true; finish() }
    }

    fun move(dir: Move2048) {
        if (phase != 1 || bonus != null || settling) return
        val result = Board2048.slide(tiles, dir)
        if (!result.moved) { h.light(); return }
        h.light()
        settling = true
        ghostIDs = result.consumed.map { it.id }.toSet()
        tiles = result.tiles + result.consumed
        scope.launch {
            delay(130)
            tiles = tiles.filter { it.id !in ghostIDs }
            ghostIDs = emptySet()
            settling = false
            if (result.points > 0) {
                score += result.points
                play(if (result.points >= 64) AppSound.CORRECT_BIG else AppSound.UI_TAP)
                if (result.tiles.any { it.merged && it.value >= 128 }) burst++
            }
            scope.launch { delay(120); tiles = tiles.map { it.copy(merged = false) } }
            spawn()
            moves++
            if (moves % movesPerBonus == 0) askBonus()
            else if (!Board2048.canMove(tiles)) { noMoves = true; finish() }
        }
    }

    LaunchedEffect(Unit) {
        best = GameEnv.prefs.getString(Board2048.bestKey())?.toIntOrNull() ?: 0
        if ((surprise || earn != null) && phase == 0) start()
    }
    LaunchedEffect(phase) {
        while (phase == 1) {
            delay(250); now = nowSecs()
            val rem = roundSeconds - (now - startedAt) + pausedFor + (if (bonus != null) now - bonusShownAt else 0.0)
            if (rem <= 0 && bonus == null) finish()
        }
    }

    GameFrame(onClose, earn, surprise, "🔢 $score", burst, KidColor.starGold, confetti) {
        when (phase) {
            0 -> Centered { MiniGameIntroCard(MiniGameKind.GAME2048) { start() } }
            2 -> Centered {
                var line = tr("נְקֻדּוֹת: %lld · הָאָרִיחַ הַגָּדוֹל: %lld", score, maxTile)
                if (bonusAsked > 0) line += "\n" + tr("שְׁאֵלוֹת בּוֹנוּס: %lld מִתּוֹךְ %lld", bonusRight, bonusAsked)
                if (noMoves) line = tr("הַלּוּחַ הִתְמַלֵּא!") + "\n" + line
                MiniGameEndCard(if (score >= best && score > 0) tr("שִׂיא חָדָשׁ! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"), line, grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Box(Modifier.weight(1f).fillMaxWidth()) {
                Column(
                    Modifier.fillMaxSize().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
                ) {
                    Row(Modifier.widthIn(max = if (m.compact) 520.dp else 680.dp).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        @Composable fun box(label: String, value: String, color: Color) {
                            Column(Modifier.weight(1f).glassInset(14.dp).padding(vertical = 8.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 11.sp)
                                Text(value, color = color, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 20.sp)
                            }
                        }
                        box(tr("נְקֻדּוֹת"), "$score", Color.White)
                        box(tr("שִׂיא"), "${maxOf(best, score)}", Color.White)
                        box(tr("בּוֹנוּס בְּעוֹד"), "${movesPerBonus - moves % movesPerBonus}", KidColor.starGold)
                    }
                    Column(Modifier.widthIn(max = if (m.compact) 520.dp else 680.dp).fillMaxWidth().glassPane(18.dp).padding(horizontal = 14.dp, vertical = 10.dp)) {
                        MiniGameTimerBar(remaining, roundSeconds)
                    }
                    // The board is geometry, not text: left stays left in every language.
                    Ltr {
                        BoxWithConstraints(Modifier.weight(1f).widthIn(max = if (m.compact) 420.dp else 600.dp).fillMaxWidth(), contentAlignment = Alignment.Center) {
                            val side = minOf(maxWidth, maxHeight)
                            val n = Board2048.SIZE
                            val gap = side * 0.03f
                            val cell = (side - gap * (n + 1)) / n
                            Box(Modifier.size(side).glassPane(side * 0.05f).pointerInput(Unit) {
                                var total = Offset.Zero
                                detectDragGestures(onDragStart = { total = Offset.Zero }, onDrag = { ch, d -> ch.consume(); total += d },
                                    onDragEnd = {
                                        val dx = total.x; val dy = total.y
                                        if (maxOf(abs(dx), abs(dy)) > 18.dp.toPx()) {
                                            if (abs(dx) > abs(dy)) move(if (dx > 0) Move2048.RIGHT else Move2048.LEFT)
                                            else move(if (dy > 0) Move2048.DOWN else Move2048.UP)
                                        }
                                    })
                            }) {
                                for (i in 0 until n * n) {
                                    Box(Modifier.offset(gap + (cell + gap) * (i % n), gap + (cell + gap) * (i / n)).size(cell)
                                        .clip(RoundedCornerShape(cell * 0.18f)).background(Color.White.copy(alpha = 0.10f))
                                        .border(1.dp, Color.White.copy(alpha = 0.16f), RoundedCornerShape(cell * 0.18f)))
                                }
                                tiles.forEach { t ->
                                    key(t.id) {
                                        TileView(t, if (settling && t.merged) t.value / 2 else t.value, settling, cell,
                                            gap + (cell + gap) * t.c, gap + (cell + gap) * t.r)
                                    }
                                }
                            }
                        }
                    }
                    Text(tr("הַחְלִיקוּ לְכָל כִּוּוּן 👆"), color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
                }
                val item = bonus
                if (item != null) {
                    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)), contentAlignment = Alignment.Center) {
                        key(item) {
                            MiniGameQuestionCard(item, tr("⭐ שְׁאֵלַת בּוֹנוּס — תְּשׁוּבָה נְכוֹנָה מַפִּילָה אָרִיחַ!")) { right -> answerBonus(item, right) }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TileView(t: Tile2048, shown: Int, settling: Boolean, cell: Dp, x: Dp, y: Dp) {
    var appeared by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { appeared = true }
    val xx by animateDpAsState(x, tween(120), label = "x")
    val yy by animateDpAsState(y, tween(120), label = "y")
    val s by animateFloatAsState(if (!appeared) 0.2f else if (!settling && t.merged) 1.12f else 1f, spring(dampingRatio = 0.6f), label = "tile")
    val color = Color(Board2048.colorHex(shown))
    val digits = "$shown".length
    Box(Modifier.offset(xx, yy).size(cell).graphicsLayer { scaleX = s; scaleY = s }
        .clip(RoundedCornerShape(cell * 0.18f)).background(Brush.linearGradient(listOf(color.copy(alpha = 0.95f), color.copy(alpha = 0.72f))))
        .border(1.2.dp, Color.White.copy(alpha = 0.45f), RoundedCornerShape(cell * 0.18f)), contentAlignment = Alignment.Center) {
        Text("$shown", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black,
            fontSize = (cell.value * (if (digits >= 4) 0.28f else if (digits == 3) 0.34f else 0.42f)).sp)
    }
}

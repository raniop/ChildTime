package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.ceil

/**
 * 🧱 NumberCrushView.swift — "מְפַצְּחִים": a target and a grid of number
 * blocks. Tap blocks whose sum (product in a × round; ½ ⅓ ¼ or 0.1s from ה׳)
 * makes the target exactly; a hit bursts them and new ones drop in. Going past
 * only lets go of the selection with a small shake. Always solvable. 60 s (45).
 * 👶 גן: pure COUNTING — tap the one card that has exactly N; five baskets.
 */
@Composable
fun NumberCrushGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val preReader = GameEnv.activeChildIsPreReader
    val grade = MiniGameLevel.grade(Topic.MATH)
    val palette = remember { listOf("FF6B9D", "06D6A0", "FFB84D", "48BFE3", "9B5DE5").map { hexColor(it) } }
    val recordTopic = if (preReader) Topic.MATH else if (topic in listOf(Topic.MATH, Topic.MONEY, Topic.LOGIC, Topic.GIFTED)) topic!! else Topic.MATH
    val roundSeconds = MiniGameKind.CRUSH.seconds(surprise).toDouble()
    val colCount = if (m.compact || m.short) 4 else 5
    val rowCount = if (m.compact || m.short) 3 else 4

    data class Block(val id: Long, val value: Int, val color: Color)
    fun newBlock(rules: CrushRules, v: Int? = null) = Block(nextId(), v ?: CrushBoards.randomValue(rules), palette.random())

    var phase by remember { mutableIntStateOf(0) }
    var rules by remember { mutableStateOf(CrushRules(CrushMode.SUM, 10, (1..9).toList())) }
    var columns by remember { mutableStateOf(listOf<List<Block>>()) }
    val picked = remember { mutableStateListOf<Long>() }
    var bursting by remember { mutableStateOf(setOf<Long>()) }
    var hits by remember { mutableIntStateOf(0) }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    var pickStartedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var shake by remember { mutableIntStateOf(0) }
    var targetPop by remember { mutableStateOf(false) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var collect by remember { mutableStateOf<PreReaderGames.Collect?>(null) }
    var preSolved by remember { mutableStateOf<Int?>(null) }
    var preWrong by remember { mutableStateOf<Int?>(null) }
    var preMissed by remember { mutableStateOf(false) }
    var preSettling by remember { mutableStateOf(false) }
    var preDealt by remember { mutableStateOf(false) }

    val remaining = maxOf(0.0, roundSeconds - (now - startedAt))
    val pickedValues = picked.mapNotNull { id -> columns.flatten().firstOrNull { it.id == id }?.value }

    fun dealPreReader() {
        collect = PreReaderGames.collecting()
        preSolved = null; preWrong = null; preMissed = false; pickStartedAt = nowSecs(); preDealt = true
    }

    fun ensure(cols: List<List<Block>>, fresh: Set<Long>) =
        CrushBoards.ensureSolvable(cols, fresh, rules, { it.id }, { it.value }, { b, v -> Block(nextId(), v, b.color) })

    fun start() {
        if (preReader) {
            if (!preDealt) dealPreReader()
            preDealt = false
            columns = emptyList(); picked.clear(); bursting = emptySet(); hits = 0; grant = null; preSettling = false
            startedAt = nowSecs(); now = startedAt; pickStartedAt = startedAt
            phase = 1; return
        }
        collect = null
        rules = CrushBoards.rules(grade, topic)
        val cols = List(colCount) { List(rowCount) { newBlock(rules) } }
        columns = ensure(cols, cols.flatten().map { it.id }.toSet())
        picked.clear(); bursting = emptySet(); hits = 0; grant = null
        startedAt = nowSecs(); now = startedAt; pickStartedAt = startedAt
        phase = 1
    }

    fun finish() {
        if (phase != 1) return
        picked.clear()
        grant = MiniGameReward.grant("crush", hits, 2, 1, if (preReader) PreReaderGames.COUNTING_HITS else if (surprise) 8 else 10, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
        if (hits > 0) confetti++
    }

    fun crush() {
        val ids = picked.toSet()
        hits++; bursting = ids; burst++
        play(if (hits % 5 == 0) AppSound.STREAK_UP else AppSound.CORRECT_BIG); h.success()
        targetPop = true
        // One answer per hit in the parent's reports.
        MiniGameLedger.record(true, recordTopic, (nowSecs() - pickStartedAt) * 1000, hits, earn, surprise)
        scope.launch {
            delay(280)
            if (phase != 1) return@launch
            targetPop = false
            // Remove the burst blocks — the rest fall — and drop new ones in on top.
            val fresh = HashSet<Long>()
            val cols = columns.map { col -> col.filter { it.id !in ids }.toMutableList().also { c ->
                while (c.size < rowCount) { val b = newBlock(rules); fresh += b.id; c += b }
            } }
            columns = ensure(cols, fresh)
            picked.clear(); bursting = emptySet()
        }
    }

    fun tap(b: Block) {
        if (phase != 1 || bursting.isNotEmpty()) return
        if (b.id in picked) { h.light(); picked.remove(b.id); return }
        if (picked.isEmpty()) pickStartedAt = nowSecs()
        h.light(); play(AppSound.UI_TAP)
        picked += b.id
        val vals = picked.mapNotNull { id -> columns.flatten().firstOrNull { it.id == id }?.value }
        if (rules.hits(vals)) crush()
        else if (!rules.canStillReach(vals)) {
            // Past the target: the selection lets go with a small shake — no word, no answer recorded.
            play(AppSound.WRONG_SOFT); shake++
            scope.launch { delay(300); picked.clear() }
        }
    }

    fun preTap(c: PreReaderGames.Collect, index: Int) {
        if (phase != 1 || preSettling) return
        if (c.cards[index] == c.target) {
            preSettling = true; preWrong = null; hits++; burst++
            play(if (hits % 5 == 0) AppSound.STREAK_UP else AppSound.CORRECT_BIG); h.success()
            preSolved = index; targetPop = true
            MiniGameLedger.record(true, recordTopic, (nowSecs() - pickStartedAt) * 1000, hits, earn, surprise)
            scope.launch {
                delay(950)
                if (phase != 1) return@launch
                targetPop = false
                if (hits >= PreReaderGames.COUNTING_HITS) finish()
                else { dealPreReader(); preDealt = false; preSettling = false }
            }
        } else {
            if (!preMissed) { preMissed = true; MiniGameLedger.record(false, recordTopic, earn = earn, surprise = surprise) }
            play(AppSound.WRONG_SOFT); h.light()
            GameEnv.speak(PreReaderGames.almost)
            preWrong = index; shake++
            scope.launch { delay(600); if (preWrong == index) preWrong = null }
        }
    }

    LaunchedEffect(Unit) {
        if (preReader && !preDealt) dealPreReader()
        if ((surprise || earn != null) && phase == 0) start()
    }
    LaunchedEffect(phase) {
        while (phase == 1) {
            delay(100)
            now = nowSecs()
            // 👶 גן has no clock: five collections end it (a long backstop closes it the same celebrating way).
            if (preReader) { if (now - startedAt > 180) finish() }
            else if (roundSeconds - (now - startedAt) <= 0) finish()
        }
    }

    val chip = if (preReader) (collect?.emoji ?: "🧱") + " " + PreReaderChrome.dots(hits, PreReaderGames.COUNTING_HITS) else "🧱 $hits"
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.starGold, confetti) {
        when (phase) {
            0 -> Centered {
                if (preReader) PreReaderIntroCard(MiniGameKind.CRUSH, collect?.cue ?: PreReaderCue(spoken = PreReaderGames.startCue)) { start() }
                else MiniGameIntroCard(MiniGameKind.CRUSH) { start() }
            }
            2 -> Centered {
                if (preReader) {
                    val d = when (hits) {
                        0 -> tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
                        1 -> tr("מָצָאתֶם אֶת הַכַּרְטִיס הַנָּכוֹן פַּעַם אַחַת!")
                        else -> tr("מָצָאתֶם אֶת הַכַּרְטִיס הַנָּכוֹן %lld פְּעָמִים!", hits)
                    }
                    PreReaderEndCard(if (hits >= PreReaderGames.COUNTING_HITS) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"), d,
                        collect?.emoji ?: "🧱", hits, grant, surprise, tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
                } else {
                    val d = when (hits) {
                        0 -> if (surprise) tr("נְנַסֶּה שׁוּב בַּסִּבּוּב הַבָּא 💪") else tr("אֶפְשָׁר לְנַסּוֹת עוֹד סִבּוּב 💪")
                        1 -> tr("פִּצַּחְתֶּם אֶת הַיַּעַד פַּעַם אַחַת!")
                        else -> tr("פִּצַּחְתֶּם אֶת הַיַּעַד %lld פְּעָמִים!", hits)
                    }
                    MiniGameEndCard(if (hits >= 10) tr("וָואוּ, מְצֻיָּן! 🏆") else tr("כָּל הַכָּבוֹד! 🎉"), d, grant, surprise,
                        tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
                }
            }
            else -> {
                val c = collect
                val dx = shakeOffset(shake)
                if (preReader && c != null) Column(
                    Modifier.weight(1f).widthIn(max = if (m.compact) 620.dp else 700.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    // The goal drawn as the THING ITSELF, in a gold frame — "find the card that looks like this".
                    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 12.dp, vertical = if (m.short) 9.dp else 14.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 7.dp else 12.dp)) {
                        LaunchedEffect(c.cue.spoken) { GameEnv.speak(c.cue.spoken) }
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp, Alignment.CenterHorizontally)) {
                            FitText(c.cue.spoken, if (m.short) 16.sp else if (m.compact) 19.sp else 26.sp, Modifier.weight(1f, fill = false),
                                weight = FontWeight.ExtraBold, maxLines = 3, minScale = 0.7f)
                            PreReaderSpeakButton(c.cue.spoken, if (m.short) 40.dp else if (m.compact) 46.dp else 58.dp)
                        }
                        val base = if (m.short) 40f else if (m.compact) 62f else 92f
                        val glyph = when { c.target <= 2 -> base; c.target == 3 -> base * 0.92f; c.target == 4 -> base * 0.84f; else -> base * 0.76f }
                        val s by animateFloatAsState(if (targetPop) 1.08f else 1f, spring(dampingRatio = 0.55f), label = "goal")
                        Row(Modifier.graphicsLayer { scaleX = s; scaleY = s }.clip(RoundedCornerShape(16.dp)).background(KidColor.starGold.copy(alpha = 0.2f))
                            .border(2.5.dp, KidColor.starGold.copy(alpha = 0.9f), RoundedCornerShape(16.dp))
                            .padding(horizontal = if (m.compact) 16.dp else 24.dp, vertical = if (m.short) 7.dp else 12.dp),
                            horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                            repeat(maxOf(1, c.target)) { Text(c.emoji, fontSize = glyph.sp) }
                        }
                    }
                    // Six cards, each one to five objects; one tap, one answer.
                    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
                        val cols = if (m.short || !m.compact) 3 else 2
                        val rows = ceil(PreReaderGames.COUNTING_CARDS / cols.toDouble()).toInt()
                        val gap = if (m.compact) 10.dp else 14.dp
                        val w = (maxWidth - gap * (cols - 1)) / cols
                        val hh = (maxHeight - gap * (rows - 1)) / rows
                        val side = maxOf(60.dp, minOf(minOf(w, hh), if (m.compact) 190.dp else 210.dp))
                        Ltr {
                            Column(verticalArrangement = Arrangement.spacedBy(gap)) {
                                for (row in 0 until rows) Row(horizontalArrangement = Arrangement.spacedBy(gap)) {
                                    for (col in 0 until cols) {
                                        val i = row * cols + col
                                        if (i >= c.cards.size) continue
                                        val count = c.cards[i]
                                        val right = preSolved == i; val wrong = preWrong == i
                                        val scale = when { count <= 1 -> 0.52f; count == 2 -> 0.36f; count == 3 -> 0.28f; count == 4 -> 0.26f; else -> 0.24f }
                                        Box(Modifier.size(side).graphicsLayer { val k = if (right) 1.08f else 1f; scaleX = k; scaleY = k; translationX = if (wrong) dx * density else 0f }
                                            .miniGameTile(if (right) TileState.CORRECT else if (wrong) TileState.WRONG else TileState.NORMAL, palette[i % palette.size], side * 0.22f)
                                            .juicyClick(!preSettling) { preTap(c, i) }, contentAlignment = Alignment.Center) {
                                            FitText(c.emoji.repeat(maxOf(1, count)), (side.value * scale).sp, maxLines = 2, minScale = 0.4f)
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else Column(
                    Modifier.weight(1f).widthIn(max = if (m.compact) 620.dp else 760.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    val selection = if (pickedValues.isEmpty()) {
                        if (rules.mode == CrushMode.PRODUCT) tr("בַּחֲרוּ קֻבִּיּוֹת שֶׁהַמַּכְפֵּלָה שֶׁלָּהֶן מַגִּיעָה לַיַּעַד")
                        else tr("בַּחֲרוּ קֻבִּיּוֹת שֶׁהַסְּכוּם שֶׁלָּהֶן מַגִּיעַ לַיַּעַד")
                    } else {
                        val total = rules.total(pickedValues)
                        val tt = when (rules.mode) {
                            CrushMode.SUM, CrushMode.PRODUCT -> "$total"
                            CrushMode.FRACTION -> if (total == 12) "1" else rules.display(total)
                            CrushMode.DECIMAL -> if (total >= 10) "1" else "0.$total"
                        }
                        MiniGameText.ltr(rules.expression(pickedValues) + " = " + tt)
                    }
                    Column(Modifier.fillMaxWidth().graphicsLayer { translationX = dx * density }.glassPane(16.dp).padding(horizontal = 14.dp, vertical = 12.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        val ts by animateFloatAsState(if (targetPop) 1.25f else 1f, spring(dampingRatio = 0.5f), label = "target")
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                            Text(tr("יַעַד:"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 24 else 30).sp)
                            Ltr { Text(rules.targetText, color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.Black,
                                fontSize = (if (m.compact) 44 else 56).sp, modifier = Modifier.graphicsLayer { scaleX = ts; scaleY = ts }) }
                            if (rules.mode == CrushMode.PRODUCT) MiniGameChip { ChipText(tr("כֶּפֶל ×")) }
                        }
                        Ltr(pickedValues.isNotEmpty()) { FitText(selection, if (m.compact) 17.sp else 21.sp, color = Ink.secondary, weight = FontWeight.Bold, maxLines = 1, minScale = 0.6f) }
                        MiniGameTimerBar(remaining, roundSeconds)
                    }
                    BoxWithConstraints(Modifier.weight(1f).fillMaxWidth().heightIn(max = if (m.compact) 330.dp else 640.dp), contentAlignment = Alignment.Center) {
                        val gap = if (m.compact) 10.dp else 14.dp
                        val w = (maxWidth - gap * (colCount - 1)) / colCount
                        val hh = (maxHeight - gap * (rowCount - 1)) / rowCount
                        val side = minOf(w, hh)
                        Ltr {
                            Box(Modifier.size(side * colCount + gap * (colCount - 1), side * rowCount + gap * (rowCount - 1))) {
                                columns.forEachIndexed { c, column ->
                                    column.forEachIndexed { r, block ->
                                        key(block.id) {
                                            BlockTile(block.value, block.color, rules, side, block.id in picked, block.id in bursting,
                                                x = (side + gap) * c, y = (side + gap) * (rowCount - 1 - r)) { tap(block) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/** One number block — falls into its row (a spring on its y). */
@Composable
private fun BlockTile(value: Int, color: Color, rules: CrushRules, side: Dp, picked: Boolean, bursting: Boolean, x: Dp, y: Dp, onTap: () -> Unit) {
    var placed by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { placed = true }
    val yy by animateDpAsState(if (placed) y else y - side * 3, spring(dampingRatio = 0.72f), label = "fall")
    val s by animateFloatAsState(if (bursting) 1.15f else if (picked) 1.06f else 1f, spring(dampingRatio = 0.6f), label = "block")
    Box(
        Modifier.offset(x, yy).size(side).graphicsLayer { scaleX = s; scaleY = s }
            .clip(RoundedCornerShape(side * 0.24f)).background(color.copy(alpha = 0.35f))
            .miniGameTile(if (bursting) TileState.CORRECT else if (picked) TileState.PICKED else TileState.NORMAL, color, side * 0.24f)
            .juicyClick(!bursting, onTap),
        contentAlignment = Alignment.Center,
    ) {
        FitText(MiniGameText.ltr(rules.display(value)), (side.value * (if (rules.mode == CrushMode.DECIMAL) 0.32f else 0.42f)).sp,
            weight = FontWeight.Black, maxLines = 1, minScale = 0.5f)
    }
}

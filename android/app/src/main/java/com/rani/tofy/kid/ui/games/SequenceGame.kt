package com.rani.tofy.kid.ui.games

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.VectorConverter
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.boundsInRoot
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Difficulty
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.chores.ChoreDrawing
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

// MARK: - 🎞️ The stories

/**
 * One picture of a story: its drawing (`ChoreArt` key, an emoji where there is
 * none), the words read aloud for it, and its place in the story. Steps with
 * the SAME rank may come in either order — brushing teeth and getting dressed
 * are both right after making the bed — so a child is never told "wrong" for
 * an order that is just as true.
 */
data class SequenceStep(val art: String, val emoji: String, val spoken: String, val rank: Int) {
    val id: String get() = art + spoken
}

/**
 * A short everyday story the child puts back in order (Sasha, 2026-10-15:
 * "שגרת בוקר", "ארוחה" — "ויזואלי לחלוטין, ללא צורך בקריאה, עם גרירה").
 * `spoken` = what the story is — heard, with the instruction, when it opens.
 */
data class SequenceStory(val key: String, val spoken: String, val steps: List<SequenceStep>)

object SequenceStories {
    val all: List<SequenceStory>
        get() = listOf(
            SequenceStory("morning", tr("בֹּקֶר טוֹב! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), listOf(
                SequenceStep("wakeup", "⏰", tr("מִתְעוֹרְרִים"), 0),
                SequenceStep("bed", "🛏️", tr("מְסַדְּרִים אֶת הַמִּטָּה"), 1),
                SequenceStep("teeth", "🦷", tr("מְצַחְצְחִים שִׁנַּיִם"), 2),
                SequenceStep("dress", "👚", tr("מִתְלַבְּשִׁים"), 2),
                SequenceStep("breakfast", "🥣", tr("אוֹכְלִים אֲרוּחַת בֹּקֶר"), 3),
                SequenceStep("bag", "🎒", tr("לוֹקְחִים תִּיק וְהוֹלְכִים לַגַּן"), 4),
            )),
            SequenceStory("meal", tr("אֲרוּחָה! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), listOf(
                SequenceStep("cooking", "🍳", tr("מְבַשְּׁלִים"), 0),
                SequenceStep("table", "🍴", tr("עוֹרְכִים אֶת הַשֻּׁלְחָן"), 0),
                SequenceStep("plate", "🍽️", tr("אוֹכְלִים"), 1),
                SequenceStep("dishes", "🧽", tr("שׁוֹטְפִים אֶת הַכֵּלִים"), 2),
                SequenceStep("trash", "🗑️", tr("זוֹרְקִים אֶת הַשְּׁאֵרִיּוֹת לַפַּח"), 2),
            )),
            SequenceStory("plant", tr("שׁוֹתְלִים פֶּרַח! מָה קוֹרֶה קֹדֶם, וּמָה אַחַר כָּךְ?"), listOf(
                SequenceStep("seed", "🌰", tr("שָׂמִים זְרָעִים בָּאֲדָמָה"), 0),
                SequenceStep("plants", "💧", tr("מַשְׁקִים"), 1),
                SequenceStep("sprout", "🌱", tr("יוֹצֵא נֶבֶט קָטָן"), 2),
                SequenceStep("flower", "🌸", tr("פּוֹרֵחַ פֶּרַח"), 3),
            )),
            SequenceStory("laundry", tr("כְּבִיסָה! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), listOf(
                SequenceStep("clothes", "🧺", tr("שָׂמִים בְּגָדִים בַּסַּל"), 0),
                SequenceStep("washer", "🫧", tr("מְכַבְּסִים בַּמְּכוֹנָה"), 1),
                SequenceStep("clothesline", "👕", tr("תּוֹלִים לְיִבּוּשׁ"), 2),
                SequenceStep("laundry", "👚", tr("מְקַפְּלִים"), 3),
            )),
            SequenceStory("cake", tr("אוֹפִים עוּגָה! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), listOf(
                SequenceStep("mixing", "🥣", tr("מְעַרְבְּבִים"), 0),
                SequenceStep("oven", "🔥", tr("אוֹפִים בַּתַּנּוּר"), 1),
                SequenceStep("cake", "🎂", tr("מַדְלִיקִים נֵרוֹת וְחוֹגְגִים"), 2),
            )),
            SequenceStory("evening", tr("עֶרֶב! מָה עוֹשִׂים קֹדֶם, וּמָה אַחַר כָּךְ?"), listOf(
                SequenceStep("bath", "🛁", tr("מִתְרַחֲצִים"), 0),
                SequenceStep("bedtime", "🌙", tr("לוֹבְשִׁים פִּיגָ'מָה"), 1),
                SequenceStep("teeth", "🦷", tr("מְצַחְצְחִים שִׁנַּיִם"), 1),
                SequenceStep("reading", "📖", tr("קוֹרְאִים סִפּוּר"), 2),
                SequenceStep("lights", "💡", tr("מְכַבִּים אֶת הָאוֹר וְהוֹלְכִים לִישֹׁן"), 3),
            )),
        )

    /** How many pictures a story shows at this level: 3 · 4 · all of it. */
    fun stepCount(difficulty: Difficulty): Int = when (difficulty) {
        Difficulty.EASY -> 3; Difficulty.MEDIUM -> 4; Difficulty.HARD -> 6
    }

    /**
     * The pictures of one story for this round, in story order. A short story
     * keeps one picture per rank where it can — "first, then, last" with no
     * two that could swap — and always keeps the first and the last.
     */
    fun pick(story: SequenceStory, count: Int): List<SequenceStep> {
        val steps = story.steps.sortedBy { it.rank }
        if (count >= steps.size) return steps
        val byRank = steps.groupBy { it.rank }
        val ranks = byRank.keys.sorted()
        val chosen = mutableListOf<SequenceStep>()
        if (ranks.size >= count) {
            // Spread over the ranks, first and last included.
            val idx = (0 until count).map { i -> (i.toDouble() * (ranks.size - 1) / maxOf(1, count - 1)).roundToInt() }
            for (i in idx.toSet().sorted()) chosen += byRank.getValue(ranks[i]).random()
        }
        if (chosen.size < count) {
            val rest = steps.filter { it !in chosen }.shuffled()
            chosen += rest.take(count - chosen.size)
        }
        return chosen.sortedBy { it.rank }
    }

    /** A round: three different stories. */
    fun round(difficulty: Difficulty): List<Pair<SequenceStory, List<SequenceStep>>> =
        all.shuffled().take(3).map { it to pick(it, stepCount(difficulty)) }
}

// MARK: - 🎞️ The game

/**
 * 🎞️ SequenceGameView.swift — "סַדְּרוּ לְפִי הַסֵּדֶר": a story's pictures are
 * shuffled at the bottom and an empty frame waits for each above, numbered
 * 1 → 2 → 3 from the LEFT in every language (numbers always run left to right —
 * Rani, 2026-10-15). The child drags a picture into its frame (or taps the
 * picture, then the frame): right → it clicks in and its words are read; too
 * early or too late → it floats back, the frame glows warm for a moment,
 * nothing said but "כִּמְעַט". Three stories a round, no clock. Played by גן
 * with no words on screen, and by א׳–ב׳ the same way — the stories are life,
 * not reading.
 */
@Composable
fun SequenceGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val density = LocalDensity.current
    val topicForLedger = topic ?: Topic.LOGIC

    var phase by remember { mutableIntStateOf(0) }
    var round by remember { mutableStateOf(listOf<Pair<SequenceStory, List<SequenceStep>>>()) }
    var storyIndex by remember { mutableIntStateOf(0) }
    // Frame index → the picture that sits in it.
    val placed = remember { mutableStateMapOf<Int, SequenceStep>() }
    // The pictures still to place, in the order they lie at the bottom.
    var pool by remember { mutableStateOf(listOf<SequenceStep>()) }
    var selected by remember { mutableStateOf<SequenceStep?>(null) }
    var dragging by remember { mutableStateOf<SequenceStep?>(null) }
    val drag = remember { Animatable(Offset.Zero, Offset.VectorConverter) }
    var fingerStart by remember { mutableStateOf(Offset.Zero) }
    var glow by remember { mutableStateOf<Pair<Int, Boolean>?>(null) }
    val frames = remember { mutableStateMapOf<Int, Rect>() }
    val cardFrames = remember { mutableStateMapOf<String, Rect>() }
    var missed by remember { mutableStateOf(setOf<String>()) }
    var placedCount by remember { mutableIntStateOf(0) }
    var cleanCount by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }

    val current = round.getOrNull(storyIndex)
    val total = round.sumOf { it.second.size }
    val cue = PreReaderCue(spoken = current?.first?.spoken ?: PreReaderGames.startCue)
    // Up to three frames a row: a whole morning (six) is two rows of big pictures rather than one row of stamps.
    val steps = current?.second ?: emptyList()
    val slotRows = if (steps.size > 4) listOf((0 until 3).toList(), (3 until steps.size).toList()) else listOf(steps.indices.toList())

    fun openStory() {
        val cur = round.getOrNull(storyIndex) ?: return
        placed.clear(); frames.clear(); cardFrames.clear()
        var p = cur.second.shuffled()
        // Never dealt already in order — that would be a free story.
        if (p.map { it.rank } == cur.second.map { it.rank } && p.size > 1) p = listOf(p.last()) + p.subList(1, p.size - 1) + p.first()
        pool = p
        selected = null; dragging = null; glow = null
        scope.launch { drag.snapTo(Offset.Zero) }
        shownAt = nowSecs()
        // (The cue card reads the story aloud when it appears.)
    }

    fun start() {
        // `--es demoLevel hard` shows a whole six-picture story (screenshots).
        round = SequenceStories.round(MiniGameLevel.dealLevel(topicForLedger))
        storyIndex = 0
        placedCount = 0; cleanCount = 0; streak = 0; grant = null; missed = emptySet()
        openStory()
        phase = 1
    }

    fun finish() {
        if (phase != 1) return
        grant = MiniGameReward.grant("sequence", placedCount, 1, 1, total, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
    }

    fun storyDone() {
        confetti++
        play(AppSound.LEVEL_UP)
        scope.launch {
            delay(1300)
            if (phase != 1) return@launch
            if (storyIndex + 1 < round.size) { storyIndex++; openStory() } else finish()
        }
    }

    /** A picture let go anywhere but its frame floats back to its place, then lets go. */
    fun floatHome(step: SequenceStep, damping: Float = 0.7f) {
        scope.launch {
            drag.animateTo(Offset.Zero, spring(dampingRatio = damping))
            if (dragging == step) dragging = null
        }
    }

    /** The rank this frame wants: the frames read the story's ranks in order. */
    fun rankWanted(i: Int): Int? = round.getOrNull(storyIndex)?.second?.getOrNull(i)?.rank

    fun tryPlace(step: SequenceStep, i: Int) {
        val want = rankWanted(i)
        if (phase != 1 || placed[i] != null || want == null) { floatHome(step); return }
        if (step.rank == want) {
            val first = step.id !in missed
            if (first) { cleanCount++; streak++ }
            placedCount++
            MiniGameLedger.record(true, topicForLedger, (nowSecs() - shownAt) * 1000, streak, earn, surprise, retry = !first)
            burst++
            play(AppSound.CORRECT_SMALL); h.success()
            GameEnv.speak(step.spoken)
            placed[i] = step
            pool = pool.filter { it != step }
            glow = i to true
            dragging = null; selected = null
            scope.launch { drag.snapTo(Offset.Zero) }
            shownAt = nowSecs()
            scope.launch { delay(400); if (glow?.first == i) glow = null }
            if (pool.isEmpty()) storyDone()
        } else {
            if (step.id !in missed) {
                missed = missed + step.id
                streak = 0
                MiniGameLedger.record(false, topicForLedger, earn = earn, surprise = surprise)
            }
            play(AppSound.WRONG_SOFT); h.light()
            GameEnv.speak(PreReaderGames.almost)
            floatHome(step, 0.6f)
            glow = i to false
            scope.launch { delay(500); if (glow?.first == i) glow = null }
        }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    /** The story's drawing, or its emoji where there is none. */
    @Composable
    fun Picture(step: SequenceStep, side: Dp) {
        Box(Modifier.size(side).padding(side * 0.08f), contentAlignment = Alignment.Center) {
            if (!ChoreDrawing(step.art, Modifier.fillMaxSize())) Text(step.emoji, fontSize = (side.value * 0.6f).sp)
        }
    }

    @Composable
    fun Slot(i: Int, side: Dp) {
        val step = placed[i]
        val g = glow
        val state = if (g != null && g.first == i) (if (g.second) TileState.CORRECT else TileState.WRONG)
        else if (step != null) TileState.CORRECT else TileState.NORMAL
        val s by animateFloatAsState(if (g?.first == i) 1.06f else 1f, spring(dampingRatio = 0.6f), label = "slot")
        Box(
            Modifier.graphicsLayer { scaleX = s; scaleY = s }
                .onGloballyPositioned { frames[i] = it.boundsInRoot() }
                .clickable(remember { MutableInteractionSource() }, null) {
                    val sel = selected
                    if (sel != null) tryPlace(sel, i) else placed[i]?.let { GameEnv.speak(it.spoken) }
                }
                .semantics { contentDescription = step?.spoken ?: "${i + 1}" },
        ) {
            Box(
                Modifier.size(side).miniGameTile(state, KidColor.starGold, 16.dp)
                    .drawWithContent {
                        drawContent()
                        if (step == null) {
                            val inset = 4.dp.toPx()
                            drawRoundRect(Color.White.copy(alpha = 0.6f), topLeft = Offset(inset, inset),
                                size = Size(size.width - 2 * inset, size.height - 2 * inset), cornerRadius = CornerRadius(14.dp.toPx()),
                                style = Stroke(2.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx()))))
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                if (step != null) {
                    val pop = remember(step) { Animatable(0.5f) }
                    LaunchedEffect(step) { pop.animateTo(1f, spring(dampingRatio = 0.7f)) }
                    Box(Modifier.graphicsLayer { scaleX = pop.value; scaleY = pop.value; alpha = ((pop.value - 0.5f) * 2f).coerceIn(0f, 1f) }) {
                        Picture(step, side)
                    }
                }
            }
            // Its place in the story — a number a גן child already knows.
            val badge = maxOf(22.dp, side * 0.3f)
            Box(
                Modifier.align(Alignment.TopEnd).offset(x = 6.dp, y = (-8).dp).size(badge)
                    .clip(RoundedCornerShape(16.dp)).background(GoldBrush),
                contentAlignment = Alignment.Center,
            ) {
                Text("${i + 1}", color = Color(0xFF3A2700), fontFamily = Rounded, fontWeight = FontWeight.Black,
                    fontSize = maxOf(12f, side.value * 0.17f).sp)
            }
        }
    }

    @Composable
    fun Card(step: SequenceStep, side: Dp) {
        val isDragging = dragging == step
        val shape = RoundedCornerShape(16.dp)
        Box(
            Modifier.zIndex(if (isDragging) 5f else 0f)
                .onGloballyPositioned { cardFrames[step.id] = it.boundsInRoot() }
                .graphicsLayer {
                    if (isDragging) { translationX = drag.value.x; translationY = drag.value.y }
                    val s = if (isDragging) 1.1f else 1f
                    scaleX = s; scaleY = s
                }
                .shadow(if (isDragging) 14.dp else 6.dp, shape, ambientColor = Color.Black.copy(alpha = 0.3f), spotColor = Color.Black.copy(alpha = 0.3f))
                .miniGameTile(if (selected == step) TileState.PICKED else TileState.NORMAL, hexColor("48BFE3"), 16.dp)
                .pointerInput(step) {
                    detectDragGestures(
                        onDragStart = { at ->
                            if (dragging != step) { dragging = step; GameEnv.speak(step.spoken) }
                            fingerStart = (cardFrames[step.id]?.topLeft ?: Offset.Zero) + at
                            scope.launch { drag.snapTo(Offset.Zero) }
                        },
                        onDrag = { change, amount -> change.consume(); scope.launch { drag.snapTo(drag.value + amount) } },
                        onDragEnd = {
                            val finger = fingerStart + drag.value
                            val pad = with(density) { 6.dp.toPx() }
                            val hit = frames.entries.firstOrNull { it.value.inflate(pad).contains(finger) }?.key
                            if (hit != null) tryPlace(step, hit)
                            else floatHome(step)
                        },
                        onDragCancel = { floatHome(step) },
                    )
                }
                // A tap hears the picture and picks it; a tap on a frame then places it.
                .clickable(remember { MutableInteractionSource() }, null) {
                    GameEnv.speak(step.spoken); h.light()
                    selected = if (selected == step) null else step
                }
                .semantics { contentDescription = step.spoken },
        ) { Picture(step, side) }
    }

    val chip = "🎞️ " + PreReaderChrome.dots(placedCount, maxOf(total, 1))
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered {
                PreReaderIntroCard(MiniGameKind.SEQUENCE, PreReaderCue(spoken = tr("סַדְּרוּ אֶת הַתְּמוּנוֹת לְפִי הַסֵּדֶר: מָה קֹדֶם, וּמָה אַחַר כָּךְ?"))) { start() }
            }
            2 -> Centered {
                PreReaderEndCard(
                    if (cleanCount == total) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"),
                    tr("%lld סִפּוּרִים בַּסֵּדֶר הַנָּכוֹן", round.size), "🎞️", placedCount, grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (m.compact) 560.dp else 760.dp).fillMaxWidth()
                    .padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
            ) {
                key(storyIndex) { PreReaderCueCard(cue, m.compact) }
                Text(PreReaderChrome.streak(streak), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                BoxWithConstraints(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                    val gap = 10.dp
                    val rowGap = if (m.compact) 26.dp else 34.dp
                    // As many as the widest row holds: three, or four for a four-picture story
                    // (sized for three, a fourth frame ran off the screen).
                    val perRow = maxOf(1, slotRows.maxOf { it.size })
                    var side = minOf(if (m.compact) 118.dp else 160.dp, (maxWidth - 12.dp - gap * (perRow - 1)) / perRow)   // 12: room for the number badge
                    var cardSide = minOf(if (m.compact) 104.dp else 140.dp, (maxWidth - gap * 2) / 3)
                    // …and a whole story must fit the height too: shrink both together when it would not.
                    val poolRows = (steps.size + 2) / 3
                    val need = side * slotRows.size + (gap + 6.dp) * (slotRows.size - 1) + rowGap + cardSide * poolRows + gap * (poolRows - 1) + 8.dp
                    if (need > maxHeight && need > 0.dp) {
                        val k = maxHeight / need
                        side *= k; cardSide *= k
                    }
                    // Laid out left-to-right so a drag follows the finger, and so the
                    // numbered frames read 1 → 2 → 3 from the left (see `slotRows`).
                    Ltr {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(rowGap)) {
                            // The frames, in reading order.
                            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(gap + 6.dp)) {
                                slotRows.forEach { row ->
                                    Row(horizontalArrangement = Arrangement.spacedBy(gap)) { row.forEach { i -> Slot(i, side) } }
                                }
                            }
                            // The pictures to place.
                            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(gap)) {
                                pool.chunked(3).forEach { row ->
                                    Row(horizontalArrangement = Arrangement.spacedBy(gap)) { row.forEach { step -> key(step.id) { Card(step, cardSide) } } }
                                }
                                if (pool.isEmpty()) Spacer(Modifier.size(cardSide))
                            }
                        }
                    }
                }
            }
        }
    }
}

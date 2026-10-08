package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🔤 WordSearchView.swift — "תַּפְזֹרֶת": five words hidden in a letter grid.
 * Drag a finger along a word; a found word stays painted and is ticked off
 * underneath. Hebrew reads right-to-left (mirrored by hand so the drag maps one
 * way), English in capitals. 30 s without a find → a first letter glows.
 * Size, diagonals and backwards words come from WordSearchShape.
 */
@Composable
fun WordSearchGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val grade = maxOf(1, GameEnv.grade(2))
    val palette = remember { listOf("06D6A0", "48BFE3", "FF6B9D", "FFB84D", "9B5DE5").map { hexColor(it) } }

    var started by remember { mutableStateOf(false) }
    var done by remember { mutableStateOf(false) }
    var board by remember { mutableStateOf<WordSearchBoard?>(null) }
    val found = remember { mutableStateListOf<String>() }
    var dragStart by remember { mutableStateOf<GridCell?>(null) }
    var dragCells by remember { mutableStateOf(listOf<GridCell>()) }
    var taps by remember { mutableIntStateOf(0) }
    var lastFindAt by remember { mutableDoubleStateOf(nowSecs()) }
    var hintCell by remember { mutableStateOf<GridCell?>(null) }
    var hintPulse by remember { mutableStateOf(false) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var wordTopic by remember { mutableStateOf(Topic.ENGLISH) }
    val words = board?.words ?: emptyList()

    fun gridSize(script: SpellScript) = WordSearchShape.size(grade, script, m.roomy)

    fun deal() {
        val probe = if (topic != null && !WordSets.hasThemedList(topic, grade))
            GameContent.words(topic, grade, 8).firstOrNull()?.script else null
        val planned = probe ?: WordSets.script(topic, grade)
        val bank = if (topic != null && !WordSets.hasThemedList(topic, grade)) GameContent.words(topic, grade, gridSize(planned)) else emptyList()
        if (topic != null && bank.size >= WordSearch.WORD_COUNT) {
            // The world's own answers — no pictures, the words are the list.
            val script = bank.first().script
            board = WordSearch.make(bank.map { SpellWord("", it.word) }, script, grade, gridSize(script))
            wordTopic = topic
        } else {
            val script = WordSets.script(topic, grade)
            board = WordSearch.make(topic, script, grade, gridSize(script))
            wordTopic = script.topic
        }
        found.clear(); dragStart = null; dragCells = emptyList(); hintCell = null; grant = null; taps = 0
        lastFindAt = nowSecs(); shownAt = nowSecs()
        started = true; done = false
    }

    fun finish() {
        grant = MiniGameReward.grant("wordsearch", found.size, 2, 2, WordSearch.WORD_COUNT, surprise)
        scope.launch { delay(600); done = true; play(AppSound.CHEST_OPEN); h.success(); confetti++ }
    }

    fun dragEnded() {
        val cells = dragCells
        dragStart = null; dragCells = emptyList()
        if (cells.size < 2) { if (cells.size == 1) taps++; return }
        taps = 0
        // Either direction counts — a word dragged end-to-start is still found.
        val w = words.firstOrNull { it.word !in found && (it.cells == cells || it.cells == cells.reversed()) }
        if (w == null) { h.light(); return }   // not a word: the selection simply fades
        found += w.word
        if (hintCell?.let { it in w.cells } == true) hintCell = null
        lastFindAt = nowSecs(); burst++
        play(AppSound.CORRECT_BIG); h.success()
        MiniGameLedger.record(true, wordTopic, (nowSecs() - shownAt) * 1000 / maxOf(1, words.size), found.size, earn, surprise)
        if (found.size == words.size) finish()
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && !started) deal() }
    // 30 seconds without a find → the first letter of a hidden word glows for 5 s.
    LaunchedEffect(started, done) {
        while (started && !done) {
            delay(1000)
            if (hintCell != null) { hintPulse = !hintPulse; continue }
            if (nowSecs() - lastFindAt >= 30) {
                val w = words.filter { it.word !in found }.randomOrNull() ?: continue
                hintCell = w.cells.firstOrNull()
                play(AppSound.UI_TAP)
                scope.launch { delay(5000); hintCell = null; hintPulse = false; lastFindAt = nowSecs() }
            }
        }
    }

    GameFrame(onClose, earn, surprise, "🔤 ${found.size}/${maxOf(1, words.size)}", burst, KidColor.successMint, confetti) {
        when {
            !started -> Centered { MiniGameIntroCard(MiniGameKind.WORD_SEARCH) { deal() } }
            done -> Centered { MiniGameEndCard(tr("כָּל הַכָּבוֹד! 🎉"), tr("מְצָאתֶם אֶת כָּל הַמִּלִּים!"), grant, surprise, tr("עוֹד לוּחַ 🔁"), { deal() }, onClose) }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (m.compact) 620.dp else 700.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp),
            ) {
                // Children kept TAPPING letters one by one: spell out the gesture, again when a tap shows they haven't got it.
                Text(if (taps >= 2) tr("👆 לֹא לוֹחֲצִים — מַנִּיחִים אֶצְבַּע עַל הָאוֹת הָרִאשׁוֹנָה וּמַחְלִיקִים עַד הָאַחֲרוֹנָה")
                else tr("👆 מַנִּיחִים אֶצְבַּע עַל הָאוֹת הָרִאשׁוֹנָה שֶׁל הַמִּלָּה וּמַחְלִיקִים עַד הָאוֹת הָאַחֲרוֹנָה"),
                    color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 15 else 18).sp,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center,
                    modifier = Modifier.fillMaxWidth().glassPane(16.dp).padding(horizontal = 14.dp, vertical = 10.dp))
                val b = board
                if (b != null) Box(Modifier.widthIn(max = if (m.compact) 400.dp else 620.dp).fillMaxWidth().aspectRatio(1f).glassPane(16.dp).padding(10.dp)) {
                    // The grid is laid out left-to-right and mirrored by hand for RTL scripts.
                    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                        BoxWithConstraints(Modifier.fillMaxWidth().aspectRatio(1f)) {
                            val n = b.size
                            val cellDp = maxWidth / n
                            val cellPx = with(LocalDensity.current) { cellDp.toPx() }
                            fun cellAt(p: Offset): GridCell? {
                                val vc = (p.x / cellPx).toInt(); val r = (p.y / cellPx).toInt()
                                if (vc !in 0 until n || r !in 0 until n || p.x < 0 || p.y < 0) return null
                                return GridCell(r, if (b.script.rtl) n - 1 - vc else vc)
                            }
                            Box(Modifier.fillMaxWidth().aspectRatio(1f).pointerInput(b) {
                                awaitEachGesture {
                                    val down = awaitFirstDown()
                                    val s = cellAt(down.position) ?: return@awaitEachGesture
                                    dragStart = s; dragCells = listOf(s); h.light()
                                    var pos = down.position
                                    while (true) {
                                        val ev = awaitPointerEvent()
                                        val ch = ev.changes.firstOrNull() ?: break
                                        if (!ch.pressed) break
                                        pos = ch.position; ch.consume()
                                        val clamped = Offset(pos.x.coerceIn(0f, cellPx * n - 1), pos.y.coerceIn(0f, cellPx * n - 1))
                                        val e = cellAt(clamped) ?: continue
                                        val line = WordSearch.snappedLine(s, e, n, b.diagonals)
                                        if (line != dragCells) { if (line.size > dragCells.size) h.light(); dragCells = line }
                                    }
                                    dragEnded()
                                }
                            }) {
                                for (r in 0 until n) for (c in 0 until n) {
                                    val gc = GridCell(r, c)
                                    val foundIdx = words.indexOfFirst { it.word in found && gc in it.cells }
                                    val selecting = gc in dragCells
                                    val hint = gc == hintCell
                                    val fill = when {
                                        selecting -> KidColor.starGold.copy(alpha = 0.55f)
                                        foundIdx >= 0 -> palette[foundIdx % palette.size].copy(alpha = 0.62f)
                                        hint -> KidColor.starGold.copy(alpha = if (hintPulse) 0.7f else 0.2f)
                                        else -> Color.White.copy(alpha = 0.10f)
                                    }
                                    val vc = if (b.script.rtl) n - 1 - c else c
                                    Box(Modifier.offset(cellDp * vc + 2.dp, cellDp * r + 2.dp).size(cellDp - 4.dp)
                                        .clip(RoundedCornerShape(cellDp * 0.26f)).background(fill)
                                        .border(if (selecting || hint) 2.dp else 1.dp, if (selecting || hint) KidColor.starGold else Color.White.copy(alpha = 0.12f),
                                            RoundedCornerShape(cellDp * 0.26f)),
                                        contentAlignment = Alignment.Center) {
                                        Text(b.letters[r][c].toString(), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                                            fontSize = (cellDp.value * 0.5f).sp)
                                    }
                                }
                            }
                        }
                    }
                }
                // The words to find, ticked as they're found.
                val perRow = if (m.compact) 3 else 4
                Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    words.chunked(perRow).forEachIndexed { row, chunk ->
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                            chunk.forEachIndexed { k, w ->
                                val i = row * perRow + k
                                val isFound = w.word in found
                                Row(Modifier.weight(1f).clip(RoundedCornerShape(16.dp))
                                    .background(if (isFound) palette[i % palette.size].copy(alpha = 0.35f) else Color.White.copy(alpha = 0.14f))
                                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).padding(horizontal = 10.dp, vertical = 8.dp),
                                    horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally), verticalAlignment = Alignment.CenterVertically) {
                                    if (w.emoji.isNotEmpty() && w.emoji.graphemes() <= 2) Text(w.emoji, fontSize = 18.sp)
                                    CompositionLocalProvider(LocalLayoutDirection provides if (b?.script?.rtl == true) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                                        Text(w.word, color = Color.White.copy(alpha = if (isFound) 0.75f else 1f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold,
                                            fontSize = (if (m.compact) 16 else 19).sp, maxLines = 1,
                                            textDecoration = if (isFound) TextDecoration.LineThrough else null)
                                    }
                                    if (isFound) Text("✓", color = KidColor.successMint, fontWeight = FontWeight.Black, fontSize = 16.sp)
                                }
                            }
                            repeat(perRow - chunk.size) { androidx.compose.foundation.layout.Spacer(Modifier.weight(1f)) }
                        }
                    }
                }
            }
        }
    }
}

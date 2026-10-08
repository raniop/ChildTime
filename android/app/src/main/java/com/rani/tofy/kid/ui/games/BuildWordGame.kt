package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
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

/**
 * 🧩 BuildWordView.swift — "בְּנוּ אֶת הַמִּלָּה": a picture, a row of empty
 * slots and the word's letters shuffled underneath. Tap them in order (Hebrew
 * fills right-to-left, English left-to-right); a wrong letter just bounces back.
 * 5 words. A world without a picture list spells its own one-word answers with
 * the question as the clue. Spare letters grow with the grade (1 ג׳, 2 ה׳, 3 ז׳).
 */
@Composable
fun BuildWordGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val grade = maxOf(1, GameEnv.grade(2))
    val maxLetters = if (m.compact) 8 else 10
    val spareTiles = when (MiniGameBand.of(grade)) {
        MiniGameBand.PRE_READER, MiniGameBand.LOWER -> 0; MiniGameBand.MIDDLE -> 1; MiniGameBand.UPPER -> 2; MiniGameBand.TOP -> 3
    }

    data class Tile(val id: Int, val letter: Char)

    var started by remember { mutableStateOf(false) }
    var done by remember { mutableStateOf(false) }
    var script by remember { mutableStateOf(SpellScript.ENGLISH) }
    var words by remember { mutableStateOf(listOf<SpellWord>()) }
    var index by remember { mutableIntStateOf(0) }
    var tiles by remember { mutableStateOf(listOf<Tile>()) }
    val usedTiles = remember { mutableStateListOf<Int>() }
    val filled = remember { mutableStateListOf<Char>() }
    var mistakesThisWord by remember { mutableIntStateOf(0) }
    var cleanWords by remember { mutableIntStateOf(0) }
    var wordDone by remember { mutableStateOf(false) }
    var wrongTile by remember { mutableStateOf<Int?>(null) }
    var shake by remember { mutableIntStateOf(0) }
    var pop by remember { mutableStateOf(false) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var textClues by remember { mutableStateOf(false) }
    var wordTopic by remember { mutableStateOf(Topic.ENGLISH) }

    val current = words.getOrNull(index)
    val letters: List<Char> = current?.let { script.display(it.word).toList() } ?: emptyList()

    fun loadWord() {
        filled.clear(); usedTiles.clear(); mistakesThisWord = 0; wordDone = false; wrongTile = null
        val w = words.getOrNull(index) ?: return
        val pool = script.display(w.word).toMutableList()
        // From ג׳ spare letters keep it from being pure ordering.
        if (spareTiles > 0) {
            val spares = script.alphabet.filter { it !in pool }.shuffled().toMutableList()
            repeat(spareTiles) { spares.removeLastOrNull()?.let { pool += it } }
        }
        tiles = pool.shuffled().mapIndexed { i, c -> Tile(i, c) }
        shownAt = nowSecs()
    }

    fun begin() {
        // The world's own one-word answers where it has no picture list.
        val bank = if (topic != null && !WordSets.hasThemedList(topic, grade)) GameContent.words(topic, grade) else emptyList()
        if (topic != null && bank.size >= WordSets.WORD_COUNT) {
            script = bank.first().script
            words = bank.take(WordSets.WORD_COUNT).map { SpellWord(it.clue, it.word) }
            textClues = true
            wordTopic = topic
        } else {
            script = WordSets.script(topic, grade)
            words = WordSets.words(topic, script, grade, maxLetters)
            textClues = false
            wordTopic = script.topic
        }
        index = 0; cleanWords = 0; grant = null
        started = true; done = false
        loadWord()
    }

    fun finish() {
        grant = MiniGameReward.grant("word", words.size, 2, 2, WordSets.WORD_COUNT, surprise)
        done = true
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }

    fun wordFinished() {
        val clean = mistakesThisWord == 0
        if (clean) cleanWords++
        // A finished word is a correct answer, bounce or no bounce.
        MiniGameLedger.record(true, wordTopic, (nowSecs() - shownAt) * 1000, earn = earn, surprise = surprise, retry = !clean)
        wordDone = true; pop = true; burst++
        play(AppSound.CORRECT_BIG); h.success()
        scope.launch { delay(250); pop = false }
        scope.launch {
            delay(1100)
            if (!started || done) return@launch
            if (index + 1 < words.size) { index++; loadWord() } else finish()
        }
    }

    fun tap(t: Tile) {
        if (wordDone || t.id in usedTiles || filled.size >= letters.size) return
        if (t.letter == letters[filled.size]) {
            h.light(); play(AppSound.UI_TAP)
            usedTiles += t.id; filled += t.letter
            if (filled.size == letters.size) wordFinished()
        } else {
            // A gentle bounce; the first bounce of a word is its one recorded miss.
            if (mistakesThisWord == 0) MiniGameLedger.record(false, wordTopic, earn = earn, surprise = surprise)
            mistakesThisWord++
            play(AppSound.WRONG_SOFT); h.light()
            wrongTile = t.id; shake++
            scope.launch { delay(400); if (wrongTile == t.id) wrongTile = null }
        }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && !started) begin() }

    val chip = "🧩 ${minOf(index + 1, maxOf(1, words.size))}/${maxOf(1, words.size)}"
    GameFrame(onClose, earn, surprise, chip, burst, KidColor.successMint, confetti) {
        when {
            !started -> Centered { MiniGameIntroCard(MiniGameKind.WORD) { begin() } }
            done -> Centered {
                MiniGameEndCard(if (cleanWords == words.size) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"),
                    tr("בְּנִיתֶם %lld מִלִּים!", words.size), grant, surprise, tr("עוֹד סִבּוּב 🔁"), { begin() }, onClose)
            }
            else -> Column(
                Modifier.weight(1f).widthIn(max = if (m.compact) 600.dp else 720.dp).fillMaxWidth().padding(horizontal = 16.dp).padding(bottom = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 24.dp, Alignment.CenterVertically),
            ) {
                val dir = if (script.rtl) LayoutDirection.Rtl else LayoutDirection.Ltr
                Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(tr("בְּנוּ אֶת הַמִּלָּה"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp)
                    val s = if (pop) 1.12f else 1f
                    if (textClues) GameText(current?.emoji ?: "", if (m.compact) 22.sp else 30.sp, Modifier.graphicsLayer { scaleX = s; scaleY = s }.padding(vertical = 6.dp),
                        maxLines = 4, minScale = 0.6f)
                    else Text(current?.emoji ?: "", fontSize = (if (m.short) 72 else if (m.compact) 96 else 130).sp,
                        modifier = Modifier.graphicsLayer { scaleX = s * 1.03f; scaleY = s * 1.03f })
                    // Hebrew fills from the right, English from the left — whatever the app's language.
                    CompositionLocalProvider(LocalLayoutDirection provides dir) {
                        val n = maxOf(1, letters.size)
                        val sw = if (m.compact) minOf(52f, 330f / n) else minOf(76f, 620f / n)
                        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            letters.forEachIndexed { i, _ ->
                                val ch = filled.getOrNull(i)
                                Box(Modifier.size(sw.dp, (sw * 1.18f).dp).miniGameTile(
                                    if (wordDone) TileState.CORRECT else if (i == filled.size) TileState.PICKED else TileState.NORMAL,
                                    Color.White.copy(alpha = 0.2f), 12.dp), contentAlignment = Alignment.Center) {
                                    Text(ch?.toString() ?: " ", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (sw * 0.58f).sp)
                                }
                            }
                        }
                    }
                }
                CompositionLocalProvider(LocalLayoutDirection provides dir) {
                    val dx = shakeOffset(shake)
                    val perRow = if (m.compact) 5 else 7
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        tiles.chunked(perRow).forEach { row ->
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally), modifier = Modifier.fillMaxWidth()) {
                                row.forEach { t ->
                                    val used = t.id in usedTiles
                                    Box(
                                        Modifier.weight(1f, fill = false).widthIn(min = if (m.compact) 54.dp else 68.dp, max = if (m.compact) 72.dp else 90.dp)
                                            .height(if (m.compact) 62.dp else 76.dp)
                                            .graphicsLayer { alpha = if (used) 0f else 1f; translationX = if (wrongTile == t.id) dx * density else 0f }
                                            .miniGameTile(if (wrongTile == t.id) TileState.WRONG else TileState.NORMAL, TileTints[t.id % 4], 16.dp)
                                            .juicyClick(!used && !wordDone) { tap(t) },
                                        contentAlignment = Alignment.Center,
                                    ) { Text(t.letter.toString(), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 30 else 38).sp) }
                                }
                            }
                        }
                    }
                }
                Spacer(Modifier.height(1.dp))
            }
        }
    }
}

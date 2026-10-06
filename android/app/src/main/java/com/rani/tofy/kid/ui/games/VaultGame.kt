package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * 🔐 VaultGameView.swift — "הַכַּסֶּפֶת": a code of distinct digits 1–9 the
 * child WORKS OUT, never guesses. A question → one more clue opens and stays.
 * The clue set is proven to leave exactly one code (VaultGen.round), with at
 * least one slack clue — opening it early pays more. A wrong attempt only
 * points at the open clue it disagrees with ("💡 כִּמְעַט!"); no attempt limit.
 */
@Composable
fun VaultGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val mathWorld = topic == null || topic in listOf(Topic.MATH, Topic.MONEY, Topic.LOGIC, Topic.GIFTED)
    val grade = MiniGameLevel.grade(if (mathWorld) Topic.MATH else topic)
    val recordTopic = topic ?: Topic.LOGIC

    var phase by remember { mutableIntStateOf(0) }
    var round by remember { mutableStateOf(VaultGen.Round(emptyList(), emptyList(), 0)) }
    var revealed by remember { mutableIntStateOf(0) }
    val input = remember { mutableStateListOf<Int?>() }
    val attempts = remember { mutableStateListOf<List<Int>>() }
    var question by remember { mutableStateOf<GameItem?>(null) }
    var hint by remember { mutableStateOf("idle") }   // idle · broke · consistent · already · retry
    var flagged by remember { mutableStateOf<Int?>(null) }
    val seen = remember { HashSet<String>() }
    var askedAt by remember { mutableDoubleStateOf(nowSecs()) }
    var cracked by remember { mutableStateOf(false) }
    var shake by remember { mutableIntStateOf(0) }
    var coins by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }
    var startedAt by remember { mutableDoubleStateOf(nowSecs()) }

    val digits = round.code.size
    val total = round.clues.size
    val spare = maxOf(0, total - revealed)
    val opening = revealed == 0 && !cracked
    val full = input.isNotEmpty() && input.all { it != null }
    val firstEmpty = input.indexOfFirst { it == null }.takeIf { it >= 0 }
    val offerReveal = !cracked && revealed >= total && attempts.size >= 2

    fun ask() {
        if (revealed >= total || question != null || cracked) return
        val item = if (mathWorld && kotlin.random.Random.nextBoolean()) VaultGen.dialQuestion(grade)
        else GameContent.card(topic, maxOf(1, GameEnv.grade(2)), seen)
        askedAt = nowSecs()
        question = item
    }

    fun finish() {
        if (phase != 1) return
        // 🧠 Opening it with clues to spare is the big win: every clue NOT needed is worth double.
        val score = if (cracked) 3 + 2 * spare + revealed else revealed
        grant = MiniGameReward.grant("vault", score, 2, 1, 10, surprise)
        phase = 2
        play(AppSound.CHEST_OPEN); h.success()
        if (cracked) confetti++
    }

    fun start() {
        question = null; hint = "idle"; flagged = null; seen.clear(); cracked = false; grant = null
        revealed = 0; attempts.clear(); input.clear()
        scope.launch {
            // ⚡ A surprise round is a short deduction: three digits, four clues. (Brute-force proof → off the main thread.)
            val r = withContext(Dispatchers.Default) { VaultGen.round(grade, if (surprise) 3 else null, if (surprise) 4 else null) }
            round = r
            input.addAll(List(r.code.size) { null })
            startedAt = nowSecs()
            phase = 1
            // 🚪 The round OPENS with a question — clue ① flips open before the board appears.
            delay(350); ask()
        }
    }

    fun press(k: String) {
        if (phase != 1 || question != null || cracked) return
        if (k == "⌫") { input.indices.lastOrNull { input[it] != null }?.let { input[it] = null }; return }
        val d = k.toIntOrNull() ?: return
        val slot = firstEmpty ?: return
        // The lock's own two rules: every digit different, and 0 is not one of them.
        if (d == 0 || d in input) { shake++; h.light(); return }
        input[slot] = d
    }

    fun crack() {
        cracked = true; coins++
        play(AppSound.LEVEL_UP); h.success()
        MiniGameLedger.record(true, recordTopic, (nowSecs() - startedAt) * 1000, earn = earn, surprise = surprise)
        scope.launch { delay(1000); finish() }
    }

    fun submit() {
        if (!full || phase != 1 || cracked) return
        val guess = input.filterNotNull()
        if (guess == round.code) { crack(); return }
        if (guess in attempts) { hint = "already"; shake++; h.light(); return }
        attempts += guess
        // The one piece of feedback a miss gives: WHICH open clue it disagrees with.
        val i = (0 until revealed).firstOrNull { !round.clues[it].holds(guess) }
        if (i != null) { hint = "broke"; flagged = i } else { hint = "consistent"; flagged = null }
        play(AppSound.UI_TAP); h.light(); shake++
        for (j in input.indices) input[j] = null
    }

    fun answered(item: GameItem, right: Boolean) {
        MiniGameLedger.record(right, item.topic, (nowSecs() - askedAt) * 1000, earn = earn, surprise = surprise)
        question = null
        if (!right) {
            // Nothing is lost — the clue stays shut; before the first clue the next question comes by itself.
            hint = "retry"
            if (revealed == 0 && !cracked) scope.launch { delay(400); ask() }
            return
        }
        flagged = null; hint = "idle"; coins++
        play(AppSound.CHEST_OPEN)
        revealed++
    }

    fun giveTheCode() {
        if (cracked || phase != 1) return
        for (j in input.indices) input[j] = round.code[j]
        scope.launch { delay(700); finish() }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    GameFrame(onClose, earn, surprise, if (total > 0) "🔑 $revealed/$total" else "🔐", coins, KidColor.starGold, confetti) {
        when (phase) {
            0 -> Centered { MiniGameIntroCard(MiniGameKind.VAULT) { start() } }
            2 -> Centered {
                val codeText = MiniGameText.ltr(round.code.joinToString(""))
                val detail = when {
                    !cracked -> tr("הַקּוֹד הָיָה %@ — נְנַסֶּה שׁוּב?", codeText)
                    spare <= 0 -> tr("פְּתַרְתֶּם אֶת כָּל הָרְמָזִים וּפִצַּחְתֶּם אֶת הַקּוֹד!")
                    else -> tr("פִּצַּחְתֶּם אֶת הַקּוֹד וְעוֹד נִשְׁאֲרוּ רְמָזִים סְגוּרִים — הַסָּקָה מְשֻׁבַּחַת! 🧠")
                }
                MiniGameEndCard(if (cracked) tr("פִּצַּחְתֶּם אֶת הַכַּסֶּפֶת! 🔓") else tr("עֲבוֹדָה יָפָה! 💪"), detail, grant, surprise,
                    tr("עוֹד כַּסֶּפֶת 🔁"), { start() }, onClose)
            }
            else -> Box(Modifier.weight(1f).fillMaxWidth()) {
                val loopBanner = @Composable {
                    FitText(tr("🔑 עוֹנִים עַל שְׁאֵלָה ← 💡 נִפְתָּח רֶמֶז ← 🔓 פּוֹתְחִים אֶת הַכַּסֶּפֶת"), (if (m.compact) 14 else 18).sp,
                        Modifier.fillMaxWidth().glassPane(18.dp).padding(horizontal = 12.dp, vertical = if (m.compact) 7.dp else 10.dp),
                        weight = FontWeight.ExtraBold, maxLines = 2, minScale = 0.7f)
                }
                if (opening) Column(
                    Modifier.align(Alignment.TopCenter).widthIn(max = if (m.compact) 560.dp else 720.dp).fillMaxWidth().padding(horizontal = 20.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
                ) {
                    loopBanner()
                    if (question == null) {
                        Text(MiniGameKind.VAULT.emoji, fontSize = (if (m.compact) 76 else 110).sp, modifier = Modifier.padding(top = 20.dp).floating(6f))
                        MiniGameGoldButton(tr("🔑 לַשְּׁאֵלָה הָרִאשׁוֹנָה"), Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp)) { ask() }
                    }
                } else Column(
                    Modifier.align(Alignment.TopCenter).widthIn(max = if (m.compact) 600.dp else 760.dp).fillMaxWidth()
                        .verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 7.dp else 10.dp),
                ) {
                    loopBanner()
                    // The vault door: a captioned row of "?" slots + the codes already tried.
                    val slot = if (m.compact) (if (digits >= 4) 48f else 56f) else 68f
                    val dx = shakeOffset(shake)
                    Column(Modifier.fillMaxWidth().glassPane(22.dp).padding(horizontal = 12.dp, vertical = 10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        FitText(if (cracked) tr("הַכַּסֶּפֶת נִפְתְּחָה! 🔓") else tr("🔐 הַקּוֹד הַסּוֹדִי — הַקִּישׁוּ אוֹתוֹ כָּאן"), (if (m.compact) 12.5f else 15f).sp,
                            color = if (cracked) KidColor.successMint else KidColor.starGold, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.65f)
                        Ltr {
                            Row(Modifier.graphicsLayer { translationX = dx * density }, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                                for (i in 0 until maxOf(digits, 1)) {
                                    val d = if (cracked) round.code.getOrNull(i) else input.getOrNull(i)
                                    Box(Modifier.size(slot.dp, (slot * 1.1f).dp).miniGameTile(if (cracked) TileState.CORRECT else if (i == firstEmpty) TileState.PICKED else TileState.NORMAL,
                                        KidColor.starGold, 16.dp), contentAlignment = Alignment.Center) {
                                        Text(d?.toString() ?: "?", color = if (cracked) KidColor.starGold else if (d == null) Color.White.copy(alpha = 0.45f) else Color.White,
                                            fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (slot * (if (d == null) 0.46f else 0.52f)).sp)
                                    }
                                }
                            }
                        }
                        if (attempts.isNotEmpty()) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(tr("נִסִּינוּ:"), color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp)
                            Ltr {
                                Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                    attempts.forEach { a ->
                                        Text(a.joinToString(""), color = Color.White.copy(alpha = 0.45f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp,
                                            modifier = Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.08f)).padding(horizontal = 7.dp, vertical = 2.dp))
                                    }
                                }
                            }
                        }
                    }
                    val hintText = when (hint) {
                        "idle" -> if (revealed < total) tr("יוֹדְעִים אֶת הַקּוֹד? הַקִּישׁוּ אוֹתוֹ! וְאִם לֹא — פִּתְחוּ עוֹד רֶמֶז")
                        else tr("כָּל הָרְמָזִים כָּאן — וְיֵשׁ רַק קוֹד אֶחָד שֶׁמַּתְאִים לְכֻלָּם! 🧠")
                        "broke" -> tr("💡 כִּמְעַט! הַקּוֹד הַזֶּה לֹא מַסְכִּים עִם הָרֶמֶז הַמְּסֻמָּן")
                        "consistent" -> tr("✨ מַתְאִים לְכָל הָרְמָזִים שֶׁכָּאן — אֲבָל צָרִיךְ עוֹד רֶמֶז")
                        "already" -> tr("אֶת הַקּוֹד הַזֶּה כְּבָר נִסִּינוּ — בּוֹאוּ נְנַסֶּה אַחֵר")
                        else -> tr("💡 כִּמְעַט! אֶפְשָׁר לְבַקֵּשׁ שְׁאֵלָה חֲדָשָׁה")
                    }
                    SubText(hintText, (if (m.compact) 13 else 15).sp, color = if (hint == "idle") Ink.secondary else Color.White)
                    // The clue list — the heart of the screen.
                    val askRow = revealed < total && !cracked
                    Column(Modifier.fillMaxWidth().glassPane(20.dp).padding(10.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                        ClueRow("🔐", tr("בַּקּוֹד %lld סְפָרוֹת שׁוֹנוֹת, מִ־1 עַד 9", digits), rule = true, flagged = false, compact = m.compact)
                        round.clues.forEachIndexed { i, clue ->
                            key(i) {
                                when {
                                    i < revealed -> ClueRow("${i + 1}", clue.text, rule = false, flagged = flagged == i, compact = m.compact)
                                    i == revealed && askRow -> Row(
                                        Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(GoldBrush).juicyClick { ask() }
                                            .padding(horizontal = 9.dp, vertical = if (m.compact) 8.dp else 11.dp),
                                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    ) {
                                        Box(Modifier.size(22.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.28f)), contentAlignment = Alignment.Center) { Text("🔑", fontSize = 13.sp) }
                                        FitText(tr("עֲנוּ עַל שְׁאֵלָה וְיִפָּתַח רֶמֶז %lld", revealed + 1), (if (m.compact) 14f else 16.5f).sp, Modifier.weight(1f),
                                            weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.6f, align = androidx.compose.ui.text.style.TextAlign.Start)
                                    }
                                    else -> Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(Color.White.copy(alpha = 0.05f)).padding(horizontal = 9.dp, vertical = 5.dp),
                                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Box(Modifier.size(22.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.08f)), contentAlignment = Alignment.Center) { Text("🔒", fontSize = 12.sp) }
                                        Text(tr("רֶמֶז %lld", i + 1), color = Ink.tertiary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 13 else 15).sp)
                                    }
                                }
                            }
                        }
                    }
                    if (offerReveal) MiniGameGlassButton(tr("✨ לִפְתֹּחַ אֶת הַכַּסֶּפֶת יַחַד"), Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp)) { giveTheCode() }
                    Box(Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp)) {
                        MiniGameNumberPad(keyHeight = if (m.short) 38.dp else if (m.compact) 44.dp else 58.dp) { press(it) }
                    }
                    Box(Modifier.widthIn(max = if (m.compact) 320.dp else 420.dp).graphicsLayer { alpha = if (full && !cracked) 1f else 0.5f }) {
                        MiniGameGoldButton(tr("פְּתִיחָה 🔓")) { if (full && !cracked) submit() }
                    }
                }
                val item = question
                if (item != null) {
                    // Tapping outside closes it — nothing is spent by putting a question away.
                    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f))
                        .clickable(remember { MutableInteractionSource() }, null) { question = null }, contentAlignment = Alignment.Center) {
                        key(item) { MiniGameQuestionCard(item, tr("🔑 תְּשׁוּבָה נְכוֹנָה פּוֹתַחַת רֶמֶז!")) { right -> answered(item, right) } }
                    }
                }
            }
        }
    }
}

@Composable
private fun ClueRow(badge: String, text: String, rule: Boolean, flagged: Boolean, compact: Boolean) {
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(Color.White.copy(alpha = if (rule) 0.05f else 0.12f))
            .border(2.dp, if (flagged) KidColor.almostWarm else Color.Transparent, RoundedCornerShape(13.dp)).padding(horizontal = 9.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.size(22.dp).clip(CircleShape).background(if (flagged) KidColor.almostWarm.copy(alpha = 0.9f) else Color.White.copy(alpha = if (rule) 0.10f else 0.20f)),
            contentAlignment = Alignment.Center) {
            Text(badge, color = if (rule) Ink.secondary else Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 12.5.sp)
        }
        Text(text, Modifier.weight(1f), color = if (rule) Ink.secondary else Color.White, fontFamily = Rounded,
            fontWeight = if (rule) FontWeight.SemiBold else FontWeight.ExtraBold, fontSize = (if (compact) 14f else 16.5f).sp)
    }
}

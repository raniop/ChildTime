package com.rani.tofy.kid.ui.games

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.AppSound
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.kid.ui.play.KidColor
import com.rani.tofy.ui.child.Topic
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassInset
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * 🛒 GroceryGameView.swift — "הַמַּכֹּלֶת": a budget, a short shopping list and
 * a shelf of priced items. Tap the list's items into the cart, then at the till
 * work out the total and the change on a number pad. In the English / Hebrew
 * worlds the list is words only — reading it IS the game. Three trips (two in a
 * surprise). A second miss at the till shows the amount and the trip goes on.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun GroceryGame(topic: Topic?, surprise: Boolean, earn: MiniGameEarnSession?, onClose: () -> Unit) {
    val m = gameMetrics()
    val h = rememberHaptics()
    val scope = rememberCoroutineScope()
    val conf = LocalConfiguration.current
    val wide = conf.screenWidthDp >= conf.screenHeightDp * 1.2
    val trips = if (surprise) 2 else 3
    val grade = MiniGameLevel.grade(if (topic == Topic.MONEY) Topic.MONEY else Topic.MATH)
    val mode = when (topic) { Topic.ENGLISH -> "english"; Topic.HEBREW -> "hebrew"; else -> "pictures" }
    val mathTopic = if (topic == Topic.MONEY) Topic.MONEY else Topic.MATH
    val prefix = if (GameEnv.isIsraeli) "" else "$"
    val suffix = if (GameEnv.isIsraeli) " ₪" else ""

    var phase by remember { mutableIntStateOf(0) }   // 0 intro · 1 shopping · 2 total · 3 change · 4 done
    var trip by remember { mutableStateOf<GroceryTrip?>(null) }
    var tripIndex by remember { mutableIntStateOf(0) }
    val cart = remember { mutableStateListOf<GroceryShelfItem>() }
    var readingMissed by remember { mutableStateOf(false) }
    var typed by remember { mutableStateOf("") }
    var tries by remember { mutableIntStateOf(0) }
    var wellState by remember { mutableStateOf(TileState.NORMAL) }
    var note by remember { mutableStateOf<String?>(null) }
    var bounce by remember { mutableStateOf<Long?>(null) }
    var shake by remember { mutableIntStateOf(0) }
    var clean by remember { mutableIntStateOf(0) }
    var solvedCount by remember { mutableIntStateOf(0) }
    var answered by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableDoubleStateOf(nowSecs()) }
    var burst by remember { mutableIntStateOf(0) }
    var confetti by remember { mutableIntStateOf(0) }
    var grant by remember { mutableStateOf<MiniGameReward.Grant?>(null) }

    val cartTotal = cart.sumOf { it.finalPrice }
    val listDone = trip?.list?.all { item -> cart.any { it.id == item.id } } ?: false
    val overBudget = (trip?.budget ?: Int.MAX_VALUE) < cartTotal
    fun listName(p: GroceryProduct) = when (mode) { "english" -> p.english; "hebrew" -> p.hebrew; else -> p.emoji + " " + GroceryGen.localName(p) }
    fun money(c: Int) = MiniGameText.ltr(GroceryGen.money(c))

    fun newTrip() {
        trip = GroceryGen.trip(grade, reading = mode != "pictures")
        cart.clear(); readingMissed = false; typed = ""; tries = 0; wellState = TileState.NORMAL; note = null; shownAt = nowSecs()
    }

    fun start() { tripIndex = 0; clean = 0; solvedCount = 0; answered = 0; grant = null; newTrip(); phase = 1 }

    fun finish() {
        grant = MiniGameReward.grant("grocery", solvedCount, 2, 1, 6, surprise)
        phase = 4
        play(AppSound.CHEST_OPEN); h.success(); confetti++
    }

    fun advance() {
        if (phase != 2 && phase != 3) return
        typed = ""; tries = 0; wellState = TileState.NORMAL; note = null; shownAt = nowSecs()
        if (phase == 2) { phase = 3; return }
        if (tripIndex + 1 < trips) { tripIndex++; newTrip(); phase = 1 } else finish()
    }

    fun add(item: GroceryShelfItem) {
        val t = trip ?: return
        if (phase != 1 || cart.any { it.id == item.id }) return
        val onList = t.list.any { it.id == item.id }
        // Reading worlds: the list is the lesson — a word not on it bounces back.
        if (mode != "pictures" && !onList) {
            if (!readingMissed) { readingMissed = true; MiniGameLedger.record(false, topic ?: Topic.ENGLISH, earn = earn, surprise = surprise) }
            play(AppSound.WRONG_SOFT); h.light()
            bounce = item.id; shake++
            note = tr("זֶה לֹא בָּרְשִׁימָה — קִרְאוּ שׁוּב 📝")
            scope.launch { delay(1400); if (bounce == item.id) { bounce = null; note = null } }
            return
        }
        play(AppSound.UI_TAP); h.light()
        cart += item; note = null
    }

    fun checkout() {
        if (!listDone || overBudget) return
        if (mode != "pictures") {
            solvedCount++
            MiniGameLedger.record(true, topic ?: Topic.ENGLISH, (nowSecs() - shownAt) * 1000, earn = earn, surprise = surprise, retry = readingMissed)
        }
        play(AppSound.CORRECT_SMALL)
        typed = ""; tries = 0; wellState = TileState.NORMAL; note = null; shownAt = nowSecs()
        phase = 2
    }

    fun press(k: String) {
        if (wellState == TileState.CORRECT) return
        if (k == "⌫") { if (typed.isNotEmpty()) typed = typed.dropLast(1); return }
        if (k == "." && (typed.contains(".") || typed.isEmpty())) return
        val dot = typed.indexOf('.')
        if (dot >= 0 && typed.length - dot > 2) return
        if (typed.length >= 7) return
        typed += k
        if (wellState == TileState.WRONG) wellState = TileState.NORMAL
    }

    fun check() {
        val t = trip ?: return
        val value = GroceryGen.cents(typed) ?: return
        val target = if (phase == 2) cartTotal else t.budget - cartTotal
        if (value == target) {
            if (tries == 0) clean++
            // An amount right on the second try still pays — the runner pays a re-asked question in full too.
            solvedCount++
            MiniGameLedger.record(true, mathTopic, (nowSecs() - shownAt) * 1000, earn = earn, surprise = surprise, retry = tries > 0)
            answered++
            wellState = TileState.CORRECT; note = null; burst++
            play(AppSound.CORRECT_BIG); h.success()
            scope.launch { delay(1000); advance() }
            return
        }
        tries++
        if (tries == 1) {
            MiniGameLedger.record(false, mathTopic, earn = earn, surprise = surprise)
            play(AppSound.WRONG_SOFT); h.light(); shake++
            // The well is emptied for the second go — the child retypes instead of re-submitting.
            typed = ""; wellState = TileState.WRONG; note = tr("כִּמְעַט! נְנַסֶּה שׁוּב 💪")
        } else {
            // The second miss: the right amount appears, and the trip goes on.
            answered++
            typed = GroceryGen.money(target).removePrefix(prefix).removeSuffix(suffix)
            wellState = TileState.CORRECT; note = tr("הִנֵּה הַתְּשׁוּבָה — מַמְשִׁיכִים! ✨")
            play(AppSound.UI_TAP)
            scope.launch { delay(1800); advance() }
        }
    }

    LaunchedEffect(Unit) { if ((surprise || earn != null) && phase == 0) start() }

    GameFrame(onClose, earn, surprise, "🛒 ${minOf(tripIndex + 1, trips)}/$trips", burst, KidColor.successMint, confetti) {
        when (phase) {
            0 -> Centered { MiniGameIntroCard(MiniGameKind.GROCERY) { start() } }
            4 -> Centered {
                MiniGameEndCard(if (clean == answered) tr("מֻשְׁלָם! 🌟") else tr("כָּל הַכָּבוֹד! 🎉"), tr("%lld קְנִיּוֹת בַּמַּכֹּלֶת!", trips), grant, surprise,
                    tr("עוֹד סִבּוּב 🔁"), { start() }, onClose)
            }
            1 -> {
                val t = trip
                val listPane = @Composable {
                    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp),
                        horizontalAlignment = Alignment.CenterHorizontally) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(tr("רְשִׁימַת קְנִיּוֹת"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 18 else 22).sp)
                            Spacer(Modifier.weight(1f))
                            MiniGameChip { Text("💰 " + money(t?.budget ?: 0), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 16 else 19).sp) }
                        }
                        // A chooser or a ⚡ round skips the intro card, so the rule is on the board itself.
                        SubText(if (mode == "pictures") tr("אוֹסְפִים מֵהַמַּדָּף אֶת כָּל מָה שֶׁבָּרְשִׁימָה וְהוֹלְכִים לַקֻּפָּה")
                        else tr("קוֹרְאִים כָּל מִלָּה, מוֹצְאִים אוֹתָהּ עַל הַמַּדָּף — וְאָז לַקֻּפָּה"), (if (m.compact) 13 else 15).sp)
                        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            (t?.list ?: emptyList()).forEach { item ->
                                val inCart = cart.any { it.id == item.id }
                                Row(Modifier.clip(RoundedCornerShape(16.dp)).background(if (inCart) KidColor.successMint.copy(alpha = 0.25f) else Color.White.copy(alpha = 0.12f))
                                    .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp)).padding(horizontal = 12.dp, vertical = 7.dp),
                                    verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    Text(if (inCart) "✓" else "○", color = if (inCart) KidColor.successMint else Color.White.copy(alpha = 0.7f), fontWeight = FontWeight.Black, fontSize = 16.sp)
                                    Ltr(mode == "english") { Text(listName(item.product), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 17 else 21).sp) }
                                }
                            }
                        }
                    }
                }
                val shelf = @Composable {
                    val dx = shakeOffset(shake)
                    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        (t?.shelf ?: emptyList()).chunked(3).forEachIndexed { row, chunk ->
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                chunk.forEachIndexed { k, item ->
                                    val i = row * 3 + k
                                    val inCart = cart.any { it.id == item.id }
                                    Column(Modifier.weight(1f).heightIn(min = if (m.compact) 104.dp else 136.dp)
                                        .graphicsLayer { alpha = if (inCart) 0.55f else 1f; translationX = if (bounce == item.id) dx * density else 0f }
                                        .miniGameTile(if (inCart) TileState.PICKED else if (bounce == item.id) TileState.WRONG else TileState.NORMAL, TileTints[i % 4], 18.dp)
                                        .juicyClick(!inCart) { add(item) }.padding(vertical = 6.dp, horizontal = 4.dp),
                                        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterVertically)) {
                                        Text(item.product.emoji, fontSize = (if (m.compact) 34 else 46).sp)
                                        if (mode == "pictures") FitText(GroceryGen.localName(item.product), (if (m.compact) 12 else 15).sp, color = Ink.secondary, weight = FontWeight.Bold, maxLines = 1, minScale = 0.6f)
                                        Ltr { Text(money(item.price), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = (if (m.compact) 16 else 20).sp,
                                            textDecoration = if (item.discount > 0) TextDecoration.LineThrough else null) }
                                        if (item.discount > 0) FitText(tr("%lld%% הֲנָחָה", item.discount), (if (m.compact) 11.5f else 14f).sp, color = KidColor.starGold,
                                            weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f)
                                    }
                                }
                            }
                        }
                    }
                }
                val side = @Composable {
                    Row(Modifier.fillMaxWidth().heightIn(min = 54.dp).glassInset(16.dp).padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("🛒", fontSize = 26.sp)
                        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            cart.toList().forEach { item ->
                                Box(Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.16f)).juicyClick { h.light(); cart.removeAll { it.id == item.id } }.padding(6.dp)) {
                                    Text(item.product.emoji, fontSize = 24.sp)
                                }
                            }
                        }
                    }
                    val n = note
                    if (n != null) SubText(n, 15.sp, color = KidColor.almostWarm)
                    else if (overBudget) SubText(tr("אוֹפְּס, חָרַגְנוּ מֵהַתַּקְצִיב — מוֹצִיאִים מַשֶּׁהוּ מֵהָעֲגָלָה 🛒"), 15.sp, color = KidColor.almostWarm)
                    Box(Modifier.graphicsLayer { alpha = if (listDone && !overBudget) 1f else 0.5f }) { MiniGameGoldButton(tr("לַקֻּפָּה 🧾")) { checkout() } }
                }
                Column(Modifier.weight(1f).widthIn(max = if (m.compact) 600.dp else if (wide) 1100.dp else 760.dp).fillMaxWidth()
                    .verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (wide) Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) { listPane(); shelf() }
                        Column(Modifier.widthIn(max = 300.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) { side() }
                    } else { listPane(); shelf(); side() }
                }
            }
            else -> {
                val t = trip
                val isTotal = phase == 2
                val question = @Composable {
                    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(14.dp), horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(if (m.short) 6.dp else 10.dp)) {
                        // Two questions at the till, and the child is told which one this is.
                        Text(tr("שְׁאֵלָה %lld מִתּוֹךְ 2", if (isTotal) 1 else 2), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 13 else 15).sp)
                        TitleText(if (isTotal) tr("כַּמָּה עוֹלֶה הַכֹּל?") else tr("כַּמָּה עֹדֶף נְקַבֵּל?"), (if (m.compact) 22 else 28).sp)
                        SubText(if (isTotal) tr("מְחַבְּרִים אֶת כָּל הַמְּחִירִים שֶׁבַּקַּבָּלָה") else tr("הָעֹדֶף הוּא מַה שֶׁנָּתַנּוּ פָּחוֹת מַה שֶׁהַקְּנִיּוֹת עָלוּ"), (if (m.compact) 13 else 15).sp)
                        val fs = (if (m.compact) 15 else 18).sp
                        Column(Modifier.fillMaxWidth().glassInset(16.dp).padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            if (isTotal) cart.forEach { item ->
                                // The bill shows what the till charges — a sale line strikes the sticker price.
                                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                    FitText(item.product.emoji + " " + GroceryGen.localName(item.product), fs, Modifier.weight(1f), weight = FontWeight.Bold, maxLines = 1,
                                        minScale = 0.7f, align = androidx.compose.ui.text.style.TextAlign.Start)
                                    if (item.discount > 0) {
                                        Text(tr("%lld%% הֲנָחָה", item.discount), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = (if (m.compact) 11.5f else 13.5f).sp, maxLines = 1)
                                        Ltr { Text(money(item.price), color = Color.White.copy(alpha = 0.55f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = fs, textDecoration = TextDecoration.LineThrough) }
                                    }
                                    Ltr { Text(money(item.finalPrice), color = if (item.discount > 0) KidColor.starGold else Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = fs) }
                                }
                            } else {
                                val fs2 = (if (m.compact) 16 else 19).sp
                                Row { Text(tr("🧾 הַקְּנִיּוֹת עָלוּ"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = fs2)
                                    Ltr { Text(money(cartTotal), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = fs2) } }
                                Row { Text(tr("💰 נָתַנּוּ לַקֻּפָּה"), Modifier.weight(1f), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = fs2)
                                    Ltr { Text(money(t?.budget ?: 0), color = KidColor.starGold, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = fs2) } }
                            }
                        }
                    }
                }
                val answer = @Composable {
                    val dx = shakeOffset(shake)
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp)) {
                        Box(Modifier.graphicsLayer { translationX = dx * density }) { MiniGameAnswerWell(typed, wellState, prefix, suffix, if (m.compact) 60.dp else 76.dp) }
                        note?.let { SubText(it, 15.sp, color = KidColor.almostWarm) }
                        Box(Modifier.widthIn(max = if (m.compact) 340.dp else 440.dp)) {
                            MiniGameNumberPad(t?.decimals ?: false, if (m.short) 40.dp else if (m.compact) 48.dp else 62.dp) { press(it) }
                        }
                        Box(Modifier.widthIn(max = if (m.compact) 340.dp else 440.dp).graphicsLayer { alpha = if (typed.isEmpty()) 0.5f else 1f }) {
                            MiniGameGoldButton(tr("בְּדִיקָה ✓")) { if (typed.isNotEmpty() && wellState != TileState.CORRECT) check() }
                        }
                    }
                }
                Column(Modifier.weight(1f).widthIn(max = if (m.compact) 600.dp else if (wide) 1100.dp else 760.dp).fillMaxWidth()
                    .verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(if (m.short) 8.dp else 12.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    if (wide) Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Box(Modifier.weight(1f)) { question() }
                        Box(Modifier.widthIn(max = if (m.compact) 340.dp else 440.dp)) { answer() }
                    } else { question(); answer() }
                }
            }
        }
    }
}

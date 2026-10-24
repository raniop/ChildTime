package com.rani.tofy.ui.contest

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.Child
import com.rani.tofy.data.FamilyContest
import com.rani.tofy.data.FamilyContestStore
import com.rani.tofy.data.MistakeLog
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.ui.play.FitText
import com.rani.tofy.ui.common.ChildAvatar
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.launch

// 🏆 The weekly family contest — the screens (iOS FamilyContestViews; Rani approved
// the mockups 2026-10-24: reports/family-week-entry-cards.png). The child's copy
// carries niqqud; the parent's does not.

private val Gold = Color(0xFFFFD66B)
private val StarGold = Color(0xFFFFD23F)

@Composable
private fun Chevron() {
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Text(if (rtl) "‹" else "›", color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 18.sp)
}

/** Keeps the contest fresh while a card or the screen is on screen (at most once a minute unless [force]). */
@Composable
private fun RefreshContest(family: List<Child>, force: Boolean = false, also: Any? = null) {
    LaunchedEffect(family.map { it.id }, also) { if (family.isNotEmpty()) FamilyContestStore.refresh(family, force) }
}

// ── the kid home card ───────────────────────────────────────────────────────

/**
 * On the child's home, above the worlds: the jar alive in a card. When last week
 * just ended it turns gold and opens on the celebration. [correctToday] re-reads
 * the jar as the child answers.
 */
@Composable
fun FamilyContestKidCard(family: List<Child>, correctToday: Int, onOpen: () -> Unit) {
    RefreshContest(family, also = correctToday)
    val s by FamilyContestStore.state.collectAsState()
    val me = s.me
    if (!s.isActive || me == null) return
    val girl = me.child.isGirl
    val leader = me.id in s.champions
    val celebrating = s.celebration != null
    val shape = RoundedCornerShape(16.dp)
    Row(
        Modifier.fillMaxWidth().glassPane(16.dp).then(if (celebrating) Modifier.border(2.dp, StarGold, shape) else Modifier)
            .clip(shape).clickable(onClick = onOpen).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        FamilyJar(s.fillFraction, s.stageFractions, Modifier.size(62.dp, 84.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            FitText(tr("🏆 תַּחֲרוּת הַשָּׁבוּעַ"), 19.sp, color = Color.White, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.75f, align = TextAlign.Start)
            if (celebrating) {
                FitText(tr("הַשָּׁבוּעַ נִגְמַר! לְחִיצָה לַתּוֹצָאוֹת 🎉"), 14.sp, color = StarGold, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.75f, align = TextAlign.Start)
            } else {
                FitText(s.nextLine(parent = false), 13.5.sp, color = Ink.secondary, weight = FontWeight.SemiBold, maxLines = 1, minScale = 0.75f, align = TextAlign.Start)
                val done = if (girl) tr("עָשִׂית %lld מִתּוֹךְ %lld 🚀", me.standing.done, me.standing.goal)
                    else tr("עָשִׂיתָ %lld מִתּוֹךְ %lld 🚀", me.standing.done, me.standing.goal)
                FitText(done + if (leader) " 👑" else "", 13.5.sp, color = Color.White, weight = FontWeight.Bold, maxLines = 1, minScale = 0.75f, align = TextAlign.Start)
            }
        }
        Chevron()
    }
}

// ── the parent home card ────────────────────────────────────────────────────

/** On the parent's home, above the children: the jar and where each child is. */
@Composable
fun FamilyContestParentCard(family: List<Child>, onOpen: () -> Unit) {
    RefreshContest(family)
    val s by FamilyContestStore.state.collectAsState()
    if (!s.isActive) return
    Column(Modifier.fillMaxWidth().glassPane(16.dp).clip(RoundedCornerShape(16.dp)).clickable(onClick = onOpen).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            FamilyJar(s.fillFraction, s.stageFractions, Modifier.size(56.dp, 76.dp))
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(tr("🏆 תחרות השבוע"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, maxLines = 1)
                    Text(s.daysLeftLine(parent = true), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp, maxLines = 1)
                }
                Text(tr("צנצנת המשפחה: %lld מתוך %lld", s.filled, s.target), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                FitText(s.nextLine(parent = true), 12.5.sp, color = Ink.secondary, weight = FontWeight.SemiBold, maxLines = 1, minScale = 0.8f, align = TextAlign.Start)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            s.rows.forEach { row ->
                val lead = row.id in s.champions
                Row(Modifier.weight(1f).height(40.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = if (lead) 0.2f else 0.1f))
                    .padding(horizontal = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally)) {
                    Crowned(row.child, 30.dp, lead, 14)
                    FitText(MistakeLog.strip(row.child.name), 14.sp, Modifier.weight(1f, fill = false), color = Color.White, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f)
                    Ltr { Text("${row.standing.percent}%", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 14.sp, maxLines = 1) }
                }
            }
        }
        Text(if (s.single) tr("הילד מול השבוע שעבר שלו, ואתם מוסיפים לצנצנת משימות משפחתיות")
             else tr("כל ילד מול היעד שלו, לפי מה שעשה בשבועות הקודמים"),
            color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
    }
}

@Composable
private fun Ltr(content: @Composable () -> Unit) = CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr, content = content)

/** The child's avatar with 👑 on top for the leader. */
@Composable
private fun Crowned(child: Child, size: Dp, crown: Boolean, crownSize: Int) {
    Box(contentAlignment = Alignment.TopCenter) {
        ChildAvatar(child, size)
        if (crown) Text("👑", fontSize = crownSize.sp, modifier = Modifier.offset(y = -(crownSize * 0.8f).dp))
    }
}

// ── the full screen ─────────────────────────────────────────────────────────

/** The jar with its prize tags, the race (or the race against last week), and for one child the family tasks. */
@Composable
fun FamilyContestScreen(parent: Boolean, family: List<Child>, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    RefreshContest(family, force = true)
    val s by FamilyContestStore.state.collectAsState()
    var showCelebration by remember { mutableStateOf(!parent && s.celebration != null) }
    val celebration = s.celebration
    if (showCelebration && celebration != null) {
        FamilyContestCelebration(celebration, s) { showCelebration = false; FamilyContestStore.dismissCelebration() }
        return
    }
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp).padding(bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 560.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.End) {
                    Box(Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).clickable(onClick = onClose),
                        contentAlignment = Alignment.Center) { Text("✕", color = Color.White, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
                }
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("🏆", fontSize = 46.sp)
                    Text(if (parent) tr("תחרות השבוע") else tr("תַּחֲרוּת הַשָּׁבוּעַ"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 28.sp)
                    Text(s.daysLeftLine(parent), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
                }
                JarCard(s, parent)
                if (s.single) SelfRaceCard(s, parent) else RaceCard(s, parent)
                if (parent && s.single) FamilyTasksCard(s)
            }
        }
    }
}

private const val JAR_W = 140
private const val JAR_H = 210
private const val LID_H = 18

@Composable
private fun JarCard(s: FamilyContestStore.State, parent: Boolean) {
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (parent) tr("🫙 צנצנת המשפחה") else tr("🫙 צִנְצֶנֶת הַמִּשְׁפָּחָה"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded,
                fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
            Ltr { Text("${s.filled}/${s.target}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp) }
        }
        Text(when {
            parent && !s.single -> tr("כל תשובה נכונה של כל אחד מהילדים ממלאת את הצנצנת. בכל קו, כל הילדים מקבלים דקות 🎁")
            parent -> tr("כל תשובה נכונה ממלאת את הצנצנת, וגם אתם מוסיפים לה משימות משפחתיות. בכל קו הילד מקבל דקות 🎁")
            !s.single -> tr("כָּל תְּשׁוּבָה נְכוֹנָה שֶׁל כָּל אֶחָד מִכֶּם מְמַלֵּאת אֶת הַצִּנְצֶנֶת. כְּשֶׁהִיא מַגִּיעָה לְקַו, כֻּלָּם מְקַבְּלִים דַּקּוֹת 🎁")
            else -> tr("כָּל תְּשׁוּבָה נְכוֹנָה מְמַלֵּאת אֶת הַצִּנְצֶנֶת, וְגַם אַבָּא וְאִמָּא מוֹסִיפִים לָהּ. כְּשֶׁהִיא מַגִּיעָה לְקַו, מְקַבְּלִים דַּקּוֹת 🎁")
        }, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp, lineHeight = 19.sp)
        Row(verticalAlignment = Alignment.Top) {
            FamilyJar(s.fillFraction, s.stageFractions, Modifier.size(JAR_W.dp, JAR_H.dp))
            // Each tag sits at its line's height, the dashes carrying the line out of the glass.
            Layout(
                content = { if (s.target > 0) s.stages.forEachIndexed { i, at -> PrizeTag(s, parent, i, at) } },
                modifier = Modifier.weight(1f).height(JAR_H.dp),
            ) { measurables, c ->
                val placeables = measurables.map { it.measure(c.copy(minWidth = 0, minHeight = 0)) }
                layout(c.maxWidth, c.maxHeight) {
                    placeables.forEachIndexed { i, p ->
                        val at = s.stages.getOrElse(i) { 0 }
                        val f = if (s.target > 0) at.toDouble() / s.target else 0.0
                        val y = (LID_H + (JAR_H - LID_H) * (1 - f * HEADROOM)).dp.roundToPx()
                        p.placeRelative(0, y - p.height / 2)
                    }
                }
            }
        }
        Text(s.nextLine(parent), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
    }
}

/** ─── 🎁 20 דקות לכולם · ב־800 — the dashes continue the line on the glass. */
@Composable
private fun PrizeTag(s: FamilyContestStore.State, parent: Boolean, i: Int, at: Int) {
    val done = s.filled >= at && at > 0
    val next = !done && (i == 0 || s.filled >= s.stages[i - 1])
    val minutes = FamilyContest.stagePrize(i)
    val tint = if (next) Gold else Color.White.copy(alpha = if (done) 0.55f else 0.85f)
    val title = when {
        parent && !s.single -> tr("%lld דקות לכולם", minutes)
        parent -> tr("%lld דקות", minutes)
        !s.single -> tr("%lld דַּקּוֹת לְכֻלָּם", minutes)
        else -> tr("%lld דַּקּוֹת", minutes)
    }
    val sub = if (done) (if (parent) tr("הושג 🎉") else tr("הִשַּׂגְנוּ! 🎉"))
        else (if (parent) tr("ב־%lld תשובות", at) else tr("בְּ־%lld תְּשׁוּבוֹת", at))
    val shape = RoundedCornerShape(16.dp)
    Row(Modifier.alpha(if (done) 0.8f else 1f), verticalAlignment = Alignment.CenterVertically) {
        Canvas(Modifier.size(22.dp, 2.dp)) {
            drawLine(tint, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), strokeWidth = 2.dp.toPx(),
                pathEffect = PathEffect.dashPathEffect(floatArrayOf(6.dp.toPx(), 5.dp.toPx())))
        }
        Row(Modifier.clip(shape).background(if (next) Gold.copy(alpha = 0.28f) else Color.White.copy(alpha = 0.12f))
            .then(if (next) Modifier.border(1.5.dp, Gold, shape) else Modifier).padding(horizontal = 10.dp, vertical = 3.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(if (done) "✅" else "🎁", fontSize = 16.sp)
            Column {
                // Tight lines: on a small jar the three tags stand close together.
                Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp, maxLines = 1, lineHeight = 17.sp)
                Text(sub, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 11.5.sp, maxLines = 1, lineHeight = 14.sp)
            }
        }
    }
}

/** 👑 Siblings, each against their own goal. */
@Composable
private fun RaceCard(s: FamilyContestStore.State, parent: Boolean) {
    val meID = if (parent) null else s.me?.id
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(if (parent) tr("👑 אלוף השבוע") else tr("👑 אַלּוּף הַשָּׁבוּעַ"), Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
            Text(if (parent) tr("כל ילד מול היעד שלו") else tr("כָּל אֶחָד מוּל הַיַּעַד שֶׁלּוֹ"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp)
        }
        s.rows.forEach { row ->
            val lead = row.id in s.champions
            Row(Modifier.padding(vertical = 4.dp).padding(top = if (lead) 10.dp else 0.dp), verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Crowned(row.child, 46.dp, lead, 22)
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(if (parent) MistakeLog.strip(row.child.name) else row.child.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, maxLines = 1)
                        if (row.id == meID) Text(if (row.child.isGirl) tr("(אַתְּ)") else tr("(אַתָּה)"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
                        Spacer(Modifier.weight(1f))
                        if (parent) Text(tr("%lld מתוך %lld", row.standing.done, row.standing.goal), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp)
                        Ltr { Text("${row.standing.percent}%", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 16.sp) }
                    }
                    Bar(row.standing.fraction, lead)
                }
            }
        }
        val me = s.me
        if (me != null && !parent) {
            Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.2f)))
            Text(goalLine(me), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.5.sp)
        }
        Text(if (parent) tr("מי שמגיע ליעד מקבל %lld דקות, והאלוף עוד %lld 🎁", FamilyContest.GOAL_PRIZE, FamilyContest.CHAMPION_PRIZE)
             else tr("כָּל מִי שֶׁמַּגִּיעַ לַיַּעַד מְקַבֵּל %lld דַּקּוֹת, וְהָאַלּוּף מְקַבֵּל עוֹד %lld 🎁", FamilyContest.GOAL_PRIZE, FamilyContest.CHAMPION_PRIZE),
            color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp, lineHeight = 19.sp)
    }
}

/** 🔁 One child: this week against last week. */
@Composable
private fun SelfRaceCard(s: FamilyContestStore.State, parent: Boolean) {
    val row = s.rows.firstOrNull()
    val girl = row?.child?.isGirl == true
    val now = row?.standing?.done ?: 0
    val last = row?.let { s.lastWeekDone[it.id] } ?: 0
    val top = maxOf(now, last, 1)
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(if (parent) tr("🔁 מול השבוע שעבר") else if (girl) tr("🔁 אַתְּ מוּל הַשָּׁבוּעַ שֶׁעָבַר") else tr("🔁 אַתָּה מוּל הַשָּׁבוּעַ שֶׁעָבַר"),
            color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
        for (i in 0..1) {
            val value = if (i == 0) now else last
            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Row {
                    Text(if (i == 0) (if (parent) tr("השבוע") else tr("הַשָּׁבוּעַ")) else (if (parent) tr("שבוע שעבר") else tr("שָׁבוּעַ שֶׁעָבַר")),
                        Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                    Text("$value", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 16.sp)
                }
                Bar(value.toDouble() / top, gold = i == 0 && now > last)
            }
        }
        if (row != null && !parent) Text(goalLine(row), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.5.sp)
        Text(if (parent) tr("עובר את השבוע שעבר: כתר ועוד %lld דקות. מגיע ליעד: עוד %lld 🎁", FamilyContest.CHAMPION_PRIZE, FamilyContest.GOAL_PRIZE)
             else tr("מִי שֶׁעוֹבֵר אֶת הַשָּׁבוּעַ שֶׁעָבַר מְקַבֵּל כֶּתֶר 👑 וְעוֹד %lld דַּקּוֹת", FamilyContest.CHAMPION_PRIZE),
            color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp, lineHeight = 19.sp)
    }
}

/** ➕ Parents add to a one-child jar. */
@Composable
private fun FamilyTasksCard(s: FamilyContestStore.State) {
    val scope = rememberCoroutineScope()
    var sending by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(tr("➕ משימה משפחתית"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
        Text(tr("עשיתם משהו יחד? כל משימה מוסיפה %lld לצנצנת", FamilyContest.BOOST_PER_TASK), color = Ink.secondary, fontFamily = Rounded,
            fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
        for (label in listOf(tr("📖 קראנו יחד"), tr("🧹 עזרה בבית"), tr("🎲 שיחקנו משחק"))) {
            Box(Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.16f))
                .clickable(enabled = !sending) {
                    val id = s.rows.firstOrNull()?.id ?: return@clickable
                    sending = true
                    scope.launch { FamilyContestStore.addFamilyTask(id); sending = false }
                }, contentAlignment = Alignment.Center) {
                Text(label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
            }
        }
    }
}

private fun goalLine(me: FamilyContestStore.Row): String {
    val girl = me.child.isGirl
    if (me.standing.reachedGoal) return if (girl) tr("הִגַּעְתְּ לַיַּעַד שֶׁלָּךְ! 🎯") else tr("הִגַּעְתָּ לַיַּעַד שֶׁלְּךָ! 🎯")
    return if (girl) tr("הַיַּעַד שֶׁלָּךְ הַשָּׁבוּעַ: %lld תְּשׁוּבוֹת נְכוֹנוֹת. כְּבָר עָשִׂית %lld 🚀", me.standing.goal, me.standing.done)
        else tr("הַיַּעַד שֶׁלְּךָ הַשָּׁבוּעַ: %lld תְּשׁוּבוֹת נְכוֹנוֹת. כְּבָר עָשִׂיתָ %lld 🚀", me.standing.goal, me.standing.done)
}

@Composable
private fun Bar(f: Double, gold: Boolean) {
    val shape = RoundedCornerShape(16.dp)
    Box(Modifier.fillMaxWidth().height(10.dp).clip(shape).background(Color.White.copy(alpha = 0.18f))) {
        Box(Modifier.fillMaxWidth(f.coerceIn(0.0, 1.0).toFloat()).fillMaxHeight().clip(shape)
            .background(if (gold) GoldBrush else Brush.linearGradient(listOf(Color(0xFF7CF3FF), Color(0xFF7CF3FF)))))
    }
}

// ── the week's end ──────────────────────────────────────────────────────────

@Composable
fun FamilyContestCelebration(c: FamilyContestStore.Celebration, s: FamilyContestStore.State, onDone: () -> Unit) {
    BackHandler(onBack = onDone)
    val me = s.rows.firstOrNull { it.id == s.boundID }?.child
    val girl = me?.isGirl == true
    val champions = s.rows.map { it.child }.filter { it.id in c.championIDs }
    val hero = if (c.iWasChampion) me else champions.firstOrNull() ?: me
    val headline = when {
        c.single -> if (c.iWasChampion) (if (girl) tr("שָׁבַרְתְּ אֶת הַשִּׂיא שֶׁלָּךְ! 🏆") else tr("שָׁבַרְתָּ אֶת הַשִּׂיא שֶׁלְּךָ! 🏆")) else tr("שָׁבוּעַ שֶׁל לְמִידָה! 💪")
        c.iWasChampion -> if (girl) tr("אַתְּ אַלּוּפַת הַשָּׁבוּעַ!") else tr("אַתָּה אַלּוּף הַשָּׁבוּעַ!")
        champions.isEmpty() -> tr("שָׁבוּעַ שֶׁל לְמִידָה! 💪")
        champions.size > 1 -> tr("%@ אַלּוּפֵי הַשָּׁבוּעַ!", champions.joinToString(", ") { it.name })
        champions[0].isGirl -> tr("%@ אַלּוּפַת הַשָּׁבוּעַ!", champions[0].name)
        else -> tr("%@ אַלּוּף הַשָּׁבוּעַ!", champions[0].name)
    }
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Spacer(Modifier.height(10.dp))
            Text(tr("הַשָּׁבוּעַ נִגְמַר! 🎉"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 26.sp)
            hero?.let { Box(Modifier.padding(top = 30.dp)) { Crowned(it, 130.dp, c.iWasChampion || c.championIDs.isNotEmpty(), 56) } }
            Text(headline, color = Gold, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 28.sp, textAlign = TextAlign.Center)
            Column(Modifier.widthIn(max = 520.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                if (c.jarFull) CelebrationRow("🫙", tr("הַצִּנְצֶנֶת הִתְמַלְּאָה!"))
                if (c.reachedGoal) CelebrationRow("🎯", if (girl) tr("הִגַּעְתְּ לַיַּעַד שֶׁלָּךְ!") else tr("הִגַּעְתָּ לַיַּעַד שֶׁלְּךָ!"))
            }
            Spacer(Modifier.height(20.dp))
            Text(if (c.minutes > 0) (if (girl) tr("בְּסוֹף הַשָּׁבוּעַ קִבַּלְתְּ עוֹד %lld דַּקּוֹת 🎁", c.minutes) else tr("בְּסוֹף הַשָּׁבוּעַ קִבַּלְתָּ עוֹד %lld דַּקּוֹת 🎁", c.minutes))
                 else tr("בַּשָּׁבוּעַ הַחָדָשׁ מְמַלְּאִים שׁוּב 💪"),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, textAlign = TextAlign.Center)
            Box(Modifier.widthIn(max = 520.dp).fillMaxWidth().height(58.dp).clip(RoundedCornerShape(16.dp)).background(GoldBrush).clickable(onClick = onDone),
                contentAlignment = Alignment.Center) {
                Text(tr("אֵיזֶה כֵּיף!"), color = Color(0xFF3A2700), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
            }
            Text(tr("תַּחֲרוּת חֲדָשָׁה כְּבָר הִתְחִילָה 🚀"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
        }
    }
}

@Composable
private fun CelebrationRow(icon: String, title: String) {
    Row(Modifier.fillMaxWidth().glassPane(16.dp).padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(icon, fontSize = 30.sp)
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
    }
}

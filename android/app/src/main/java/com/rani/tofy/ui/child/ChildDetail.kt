package com.rani.tofy.ui.child

import com.rani.tofy.ui.common.contentColumn

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.animation.core.animateFloat
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.*
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.WorldStage
import com.rani.tofy.ui.common.ChildAvatar
import com.rani.tofy.ui.common.GlassButton
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.home.LiveWindow
import com.rani.tofy.ui.home.formatTime
import com.rani.tofy.ui.home.gradeName
import com.rani.tofy.ui.home.liveWindow
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/** The snapshot maps the report's engines read (ProgressSnapshot fields Progress doesn't model). */
internal data class SnapshotExtras(
    val adaptive: Map<String, Double>, val affinity: Map<String, Double>, val exposure: Map<String, Int>,
    /** 🏆 ProgressSnapshot.worldStage (tier × 10 + room) and the legacy worldProgress rooms. */
    val worldStage: Map<String, Int> = emptyMap(), val worldProgress: Map<String, Int> = emptyMap(),
) {
    companion object {
        private fun nums(d: Doc, k: String) = d.map(k)?.mapNotNull { (key, v) -> (v as? Number)?.let { key to it.toDouble() } }?.toMap() ?: emptyMap()
        private fun ints(d: Doc, k: String) = nums(d, k).mapValues { it.value.toInt() }
        fun from(d: Doc) = SnapshotExtras(nums(d, "topicAdaptiveLevel"), nums(d, "topicAffinity"), ints(d, "topicExposure"),
            ints(d, "worldStage"), ints(d, "worldProgress"))
    }
}

/**
 * The per-child page: ParentDashboardView.childDetailPage + ChildReportView.swift.
 * "Is my kid using it, actually learning, strong where / struggling where" — the
 * report is derived on this device from the child's own dailyStats.
 */
@Composable
internal fun ChildDetailContent(childID: String, onBack: () -> Unit, onSettings: () -> Unit, onActions: () -> Unit, onConnectDevice: () -> Unit) {
    val state by FamilyRepository.state.collectAsState()
    val child = state.children.firstOrNull { it.id == childID }
    val histories by ChildReportRepository.history.collectAsState()
    val stateDoc by remember(childID) { ChildReportRepository.stateDoc(childID) }.collectAsState(initial = emptyMap())
    var refreshing by remember { mutableStateOf(false) }
    var tick by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    val note = remember { WriteNote() }
    var removing by remember { mutableStateOf<ChildDevice?>(null) }

    LaunchedEffect(Unit) { while (true) { delay(1000); tick++ } }
    // The parent's phone never recorded this child's play — pull the history down.
    LaunchedEffect(childID) { refreshing = true; ChildReportRepository.refreshHistory(childID); refreshing = false }

    GlassBackdrop {
        if (child == null) {
            Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding().padding(16.dp)) { PageBar("", onBack) }
            return@GlassBackdrop
        }
        val progress = state.progress[childID] ?: Progress.EMPTY
        val extras = remember(stateDoc) { SnapshotExtras.from(stateDoc) }
        val engine = remember(histories[childID]) { ReportEngine(histories[childID] ?: emptyList()) }
        val devices = state.devicesOf(childID)
        val live = tick.let { state.liveWindow(child) }  // re-read on the 1 s tick

        LazyColumn(Modifier.contentColumn().fillMaxSize().systemBarsPadding(), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
            item {
                PageBar("", onBack) {
                    Row(Modifier.clip(RoundedCornerShape(20.dp)).clickable(onClick = onSettings).padding(horizontal = 10.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text("⚙️", fontSize = 16.sp)
                        Text(tr("הגדרות"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                    }
                }
            }
            item { ChildReport(child, progress, extras, engine, live, devices, refreshing, onSettings, onActions, onConnectDevice, onRemoveDevice = { removing = it }, onLock = { Commands.lock(childID) }) }
        }
        note.Host(Modifier.align(Alignment.BottomCenter).navigationBarsPadding())
    }

    removing?.let { d ->
        Confirm(
            title = tr("להסיר את \"%@\"?", d.name),
            message = tr("המכשיר יתנתק אוטומטית מהילד ויחזור למצב התחלתי (כאילו הותקן מחדש). ההתקדמות בענן נשמרת — כדי לחבר אותו שוב (או לילד אחר), סרקו בו מחדש את ה-QR של הילד הנכון."),
            confirm = tr("הסר מכשיר"), cancel = tr("ביטול"),
            onConfirm = { scope.launch { note.report(ChildReportRepository.withRetry { Commands.removeDevice(d.id) }) } },
            onDismiss = { removing = null },
        )
    }
}

@Composable
private fun ChildReport(
    child: Child, s: Progress, extras: SnapshotExtras, engine: ReportEngine, live: LiveWindow?, devices: List<ChildDevice>,
    refreshing: Boolean, onSettings: () -> Unit, onActions: () -> Unit, onConnectDevice: () -> Unit,
    onRemoveDevice: (ChildDevice) -> Unit, onLock: () -> Unit,
) {
    val girl = child.isGirl
    fun g(m: String, f: String) = if (girl) f else m
    var period by rememberSaveable { mutableStateOf(ReportPeriod.TODAY) }
    var expanded by remember { mutableStateOf<Topic?>(null) }
    var autoCollapsed by remember { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        // MARK: header — avatar + name (tap → settings), grade · playing now
        Row(Modifier.clip(RoundedCornerShape(16.dp)).clickable(onClick = onSettings), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ChildAvatar(child, 56.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Text(child.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    val sub = Color.White.copy(alpha = 0.85f)
                    Text(gradeName(child.effectiveGrade), color = sub, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
                    if (live != null) {
                        Text("·", color = sub, fontSize = 13.5.sp)
                        PulseDot()
                        val kind = devices.firstOrNull()?.kind ?: ""
                        Text(tr("%@ עכשיו", g(tr("משחק"), tr("משחקת"))) + (if (kind == "ipad") tr(" באיפד") else if (kind == "iphone") tr(" באיפון") else ""),
                            color = sub, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp, maxLines = 1)
                    }
                }
            }
            if (refreshing) CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
        }

        // MARK: top actions — the live banner (lock one tap away) + the actions sheet
        live?.let { LiveBanner(child, it, onLock) }
        GlassButton(tr("⚡ פעלות"), Modifier.fillMaxWidth()) { onActions() }

        // MARK: the four numbers
        val sum = engine.summary(period)
        val (capOn, capMin) = child.resolvedCap()
        val minutes = if (period == ReportPeriod.TODAY) (if (capOn) "${s.minutesEarnedToday}/$capMin" else "${s.minutesEarnedToday}") else "${sum.minutesEarned}"
        Row(Modifier.fillMaxWidth().glassPane(16.dp).padding(vertical = 10.dp)) {
            Snap(Modifier.weight(1f), "${sum.questions}", tr("שאלות"))
            Snap(Modifier.weight(1f), if (sum.questions > 0) pct(sum.accuracy) else "0%", tr("הצלחה"))
            Snap(Modifier.weight(1f), minutes, tr("דקות"))
            Snap(Modifier.weight(1f), "${s.dayStreak}", if (s.dayStreak == 1) tr("יום רצף") else tr("ימי רצף"))
        }
        // Period filter — drives every card below.
        Row(Modifier.fillMaxWidth().glassPane(12.dp).padding(3.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            ReportPeriod.entries.forEach { p ->
                val on = period == p
                Box(Modifier.weight(1f).clip(RoundedCornerShape(9.dp)).background(if (on) Color.White.copy(alpha = 0.92f) else Color.Transparent)
                    .clickable { period = p; expanded = null }.padding(vertical = 8.dp), contentAlignment = Alignment.Center) {
                    Text(p.title, color = if (on) Ink.indigo else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp)
                }
            }
        }

        // MARK: insight
        engine.dailyInsight(child.name, girl, period, minutesToday = s.minutesEarnedToday)?.let { InsightCard(it, period) }

        // MARK: topics
        TopicsCard(child, s, extras, engine, period, expanded, autoCollapsed) { t, open ->
            if (open) { expanded = null; autoCollapsed = true } else expanded = t
        }

        // MARK: 🏆 worlds (tiers)
        WorldsCard(child, extras)

        // MARK: improvement (week / month only)
        val deltas = engine.topicDeltas(period)
        val overall = engine.overallDelta(period)
        if (period != ReportPeriod.TODAY && (overall != null || deltas.isNotEmpty())) {
            ReportCard(tr("האם %@ %@?", child.name, g(tr("משתפר"), tr("משתפרת")))) {
                overall?.let { o ->
                    val up = o >= 0
                    // The tab above already names the period — no tab label inside the sentence.
                    Text(tr("%@ %@ ב-%lld%%", if (up) "📈" else "📉", if (up) g(tr("השתפר"), tr("השתפרה")) else tr("ירד קצת"),
                        Math.round(kotlin.math.abs(o)).toInt()),
                        color = if (up) Ink.good else Ink.weak, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    deltas.firstOrNull()?.takeIf { it.deltaPoints > 0 }?.let { TrendChip(tr("השפור הגדול"), it.topic.displayName, it.deltaPoints) }
                    deltas.lastOrNull()?.takeIf { it.deltaPoints < 0 }?.let { TrendChip(tr("דורש חזוק"), it.topic.displayName, it.deltaPoints) }
                }
            }
        }

        // MARK: charts
        val days = if (period == ReportPeriod.MONTH) 30 else 7
        val points = engine.dayPoints(days)
        ReportCard(tr("מגמת למידה"), detail = tr("%lld ימים אחרונים", days)) {
            if (points.all { it.questions == 0 }) EmptyLine(tr("אין עדין פעילות בתקופה הזו."))
            else {
                LearningTrendChart(points, Modifier.fillMaxWidth().height(130.dp))
                Legend(listOf(tr("שאלות") to Color.White.copy(alpha = 0.4f), tr("אחוז הצלחה") to Color.White))
            }
        }
        val earnedW = g(tr("הרויח"), tr("הרויחה")); val usedW = g(tr("נצל"), tr("נצלה"))
        ReportCard(tr("זמן מסך"), detail = tr("%@ מול %@", earnedW, usedW)) {
            if (points.all { it.earned == 0 && it.used == 0 }) EmptyLine(tr("עוד לא נפתח זמן מסך בתקופה הזו."))
            else {
                ScreenTimeChart(points, Modifier.fillMaxWidth().height(120.dp))
                Legend(listOf(earnedW to Color.White.copy(alpha = 0.4f), usedW to Color(0xFF7CF3FF)))
            }
        }

        // MARK: mastered / practise
        val done = engine.mastered(period); val todo = engine.toPractice(period)
        if (done.isNotEmpty() || todo.isNotEmpty()) {
            Row(Modifier.height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                ReportCard(tr("✅ כבר %@", g(tr("שולט"), tr("שולטת"))), Modifier.weight(1f).fillMaxHeight()) {
                    if (done.isEmpty()) EmptyLine(tr("עוד לא — בקרוב 😊")) else NamedList(done)
                }
                ReportCard(tr("🎯 כדאי לתרגל"), Modifier.weight(1f).fillMaxHeight()) {
                    if (todo.isEmpty()) EmptyLine(tr("שום דבר בולט 👏")) else NamedList(todo)
                }
            }
        }

        // MARK: devices
        DevicesCard(child, devices, live != null, onConnectDevice, onRemoveDevice)
        // (iOS's "תְּנוּ לְX לְשַׂחֵק כָּאן 🧒" kid-mode entry is left out — no kid mode on Android yet.)
    }
}

@Composable
private fun PulseDot() {
    val t = rememberInfiniteTransitionAlpha()
    Box(Modifier.size(8.dp).clip(CircleShape).background(Ink.live.copy(alpha = t)))
}

@Composable
private fun rememberInfiniteTransitionAlpha(): Float {
    val tr = androidx.compose.animation.core.rememberInfiniteTransition(label = "pulse")
    val a by tr.animateFloat(0.45f, 1f, androidx.compose.animation.core.infiniteRepeatable(androidx.compose.animation.core.tween(800), androidx.compose.animation.core.RepeatMode.Reverse), label = "a")
    return a
}

/** liveWindowBanner(compact: false) with its lock button. */
@Composable
private fun LiveBanner(child: Child, live: LiveWindow, onLock: () -> Unit) {
    val girl = child.isGirl
    val kind = live.device?.kind
    val deviceLabel = if (kind == "ipad") tr("באיפד") else if (kind == "iphone") tr("באיפון") else tr("במכשיר")
    val source = if (live.isGift) tr("זמן שנתתם") else if (girl) tr("זמן שהרויחה") else tr("זמן שהרויח")
    val opened = if (girl) tr("פתחה") else tr("פתח")
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF22C55E), Color(0xFF16A34A)))).padding(horizontal = 12.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        PulseDot()
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Text(if (live.isGift) tr("%@ %@ דקות מתנה %@ 💝", child.name, opened, deviceLabel) else tr("%@ %@ זמן מסך %@ 🎮", child.name, opened, deviceLabel),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
            Text(tr("נשארו %@ דקות · %@", formatTime(live.secondsLeft), source), color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
        }
        Box(Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.95f)).clickable(onClick = onLock).padding(horizontal = 12.dp, vertical = 7.dp)) {
            Text("🔒 " + tr("נעילה"), color = Color(0xFF15803D), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
        }
    }
}

@Composable
private fun Snap(modifier: Modifier, value: String, label: String) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(value, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp, maxLines = 1)
        Text(label, color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 10.5.sp, maxLines = 1)
    }
}

/** The one WARM pane on the page — gold glass so it leads the eye. */
@Composable
private fun InsightCard(i: DailyInsight, period: ReportPeriod) {
    val shape = RoundedCornerShape(22.dp)
    Column(
        Modifier.fillMaxWidth().clip(shape)
            .background(Brush.linearGradient(listOf(Color(0xFFFFE082).copy(alpha = 0.66f), Color(0xFFFFB840).copy(alpha = 0.52f))))
            .border(1.dp, Color(0xFFFFEBAA).copy(alpha = 0.7f), shape).padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // One whole key per period: dropping the TAB label ("This week" / "Эта неделя")
        // into a template read "Insight for This week" / "Вывод о Эта неделя".
        val title = when (period) { ReportPeriod.TODAY -> tr("💡 תובנת היום"); ReportPeriod.WEEK -> tr("💡 תובנת השבוע"); ReportPeriod.MONTH -> tr("💡 תובנת החדש") }
        Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp)
        Text(i.body, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.5.sp)
        i.recommendation?.let {
            Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.35f)))
            Text(tr("ממלץ: %@", it), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp)
        }
    }
}

@Composable
private fun TopicsCard(
    child: Child, s: Progress, extras: SnapshotExtras, engine: ReportEngine, period: ReportPeriod,
    expanded: Topic?, autoCollapsed: Boolean, onToggle: (Topic, Boolean) -> Unit,
) {
    val topics = engine.topicReports(period)
    ReportCard(tr("ביצועים לימודיים"), detail = tr("לפי נושא, %@", period.title.lowercase())) {
        if (topics.isEmpty()) { EmptyLine(tr("עוד לא נענו שאלות %@.", period.title.lowercase())); return@ReportCard }
        // The weakest topic opens on its own; any row toggles on tap.
        val weakest = topics.reversed().firstOrNull { it.verdict == TopicReport.Verdict.WEAK && engine.skillReports(it.topic, period).isNotEmpty() }
            ?: topics.firstOrNull { it.verdict == TopicReport.Verdict.WEAK }
        val open = expanded ?: (if (autoCollapsed) null else weakest?.topic)
        LearningProfileLines(child, s, extras)
        topics.forEachIndexed { idx, t ->
            TopicRow(child, s, extras, t, open == t.topic) { onToggle(t.topic, open == t.topic) }
            if (open == t.topic) {
                val skills = engine.skillReports(t.topic, period)
                if (skills.isEmpty()) P(tr("אין עדין פרוט לפי מימנות בנושא זה."), 12.5f)
                else skills.forEach { sk ->
                    Row(Modifier.fillMaxWidth().padding(start = 44.dp).glassInset(11.dp).padding(horizontal = 10.dp, vertical = 8.dp)) {
                        Text(sk.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp)
                        Text(pct(sk.accuracy), color = if (sk.accuracy >= 0.65) Ink.good else Ink.weak, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp)
                    }
                }
            }
            if (idx != topics.lastIndex) RowDivider()
        }
    }
}

/**
 * 🏆 ChildReportView.worldsCard — the child's worlds by how far they got: tier,
 * room, and a couple they never visited (where to nudge next). Reads the synced
 * snapshot doc, so it is right on the parent's phone too.
 */
@Composable
private fun WorldsCard(child: Child, extras: SnapshotExtras) {
    fun g(m: String, f: String) = if (child.isGirl) f else m
    val stageOf = { w: World -> WorldStage.stage(extras.worldStage, extras.worldProgress, w.id) }
    val visited = { w: World -> WorldStage.visited(extras.worldStage, extras.worldProgress, w.id) }
    val playable = child.playableTopics
    val candidates = (BaseWorlds + Topic.entries.filter { it.isPack }.map { World("${it.raw}_world", "", it.emoji, it) })
        .filter { it.topic in playable }
    val played = candidates.filter(visited).sortedByDescending(stageOf)
    val notYet = candidates.filterNot(visited).take(2)
    val crowns = played.sumOf { minOf(WorldStage.tier(stageOf(it)), WorldStage.TIER_COUNT) }
    ReportCard(tr("🏆 העולמות של %@", child.name), detail = if (crowns > 0) tr("👑 דרגות שהשלמו: %lld", crowns) else null) {
        if (played.isEmpty()) { EmptyLine(g(tr("עוד לא שחק באף עולם."), tr("עוד לא שחקה באף עולם."))); return@ReportCard }
        Column {
            played.forEach { w ->
                val st = stageOf(w)
                WorldRow(w, WorldTiers.parentLabel(WorldStage.tier(st), st % 10), WorldTiers.color(WorldStage.tier(st)))
            }
            notYet.forEach { w -> WorldRow(w, g(tr("עוד לא בקר"), tr("עוד לא בקרה")), null) }
        }
    }
}

@Composable
private fun WorldRow(w: World, label: String, tint: Color?) {
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(w.emoji, fontSize = 20.sp)
        Text(w.name, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.5.sp, maxLines = 2, lineHeight = 18.sp)
        Text(label, Modifier.clip(RoundedCornerShape(50)).background(tint ?: Color.White.copy(alpha = 0.18f)).padding(horizontal = 9.dp, vertical = 4.dp),
            color = if (tint == null) Ink.secondary else Color(0xFF2A1D00), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp, maxLines = 1)
    }
}

/** "💪 חֲזָקָה בְּ… / ❤️ אוֹהֶבֶת…" — LearningProfile.strong / .favorites from the snapshot. */
@Composable
private fun LearningProfileLines(child: Child, s: Progress, extras: SnapshotExtras) {
    if (s.totalAnswered < 4) return
    val strong = Topic.entries.filter { (s.topicAnswered[it.raw] ?: 0) >= 4 && (s.topicAccuracy[it.raw] ?: 0.7) >= 0.8 }
        .sortedWith(compareByDescending<Topic> { s.topicAccuracy[it.raw] ?: 0.7 }.thenBy { it.raw }).take(3)
    val enabled = child.playableTopics
    val favorites = enabled.filter { (extras.exposure[it.raw] ?: 0) > 0 }
        .sortedWith(compareByDescending<Topic> { extras.affinity[it.raw] ?: 0.6 }.thenBy { it.raw }).take(3)
    if (strong.isEmpty() && favorites.isEmpty()) return
    fun g(m: String, f: String) = if (child.isGirl) f else m
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        if (strong.isNotEmpty()) ChipLine("💪 " + g(tr("חזק ב"), tr("חזקה ב")), strong)
        if (favorites.isNotEmpty()) ChipLine("❤️ " + g(tr("אוהב"), tr("אוהבת")), favorites)
    }
    RowDivider()
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun ChipLine(label: String, topics: List<Topic>) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.5.sp, modifier = Modifier.align(Alignment.CenterVertically))
        topics.forEach { t ->
            Text("${t.emoji} ${t.displayName}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.sp,
                modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.14f))
                    .border(1.dp, Color.White.copy(alpha = 0.24f), RoundedCornerShape(20.dp)).padding(horizontal = 8.dp, vertical = 3.dp))
        }
    }
}

@Composable
private fun TopicRow(child: Child, s: Progress, extras: SnapshotExtras, t: TopicReport, open: Boolean, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 2.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(t.topic.emoji, fontSize = 22.sp, modifier = Modifier.width(34.dp))
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(t.topic.displayName, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1)
                // The level the adaptive engine serves now, and where it moved from the parent's base.
                if (hasAdaptiveSignal(s)) {
                    val st = adaptiveState(t.topic, child, extras.adaptive)
                    val hint = st.direction?.let { if (it == Direction.EASED) "↓ " + tr("בונה בטחון") else "↑ " + tr("מאתגר יותר") }
                    Text(st.served.displayName + (hint?.let { " · $it" } ?: ""), maxLines = 1,
                        color = when (st.direction) { Direction.EASED -> Ink.warn; Direction.RAISED -> Ink.good; null -> Ink.secondary },
                        fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 10.5.sp,
                        modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.10f)).padding(horizontal = 7.dp, vertical = 2.dp))
                }
            }
            Text(tr("%lld שאלות", t.answered) + " · " + tr("%lld נכונות", t.correct) + (if (t.wrong > 0) tr(" · %lld טעיות", t.wrong) else ""),
                color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp)
        }
        val (label, color) = when (t.verdict) {
            TopicReport.Verdict.STRONG -> (if (t.accuracy >= 0.95) tr("חזק מאוד") else tr("חזק")) to Ink.good
            TopicReport.Verdict.OK -> tr("בסדר") to Ink.warn
            TopicReport.Verdict.WEAK -> tr("דורש חזוק") to Ink.weak
            TopicReport.Verdict.TOO_FEW -> tr("עוד מעט") to Ink.tertiary
        }
        Text("${pct(t.accuracy)} · $label", color = color, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 11.5.sp,
            modifier = Modifier.clip(RoundedCornerShape(20.dp)).background(Color.White.copy(alpha = 0.12f))
                .border(1.dp, Color.White.copy(alpha = 0.18f), RoundedCornerShape(20.dp)).padding(horizontal = 9.dp, vertical = 5.dp))
    }
}

@Composable
private fun TrendChip(label: String, topic: String, delta: Double) {
    Column(verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(topic, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp)
            Text("${if (delta >= 0) "↑" else "↓"}${Math.round(kotlin.math.abs(delta))}%", color = if (delta >= 0) Ink.good else Ink.weak,
                fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp)
        }
    }
}

@Composable
private fun Legend(items: List<Pair<String, Color>>) {
    Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        items.forEach { (label, c) ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                Box(Modifier.size(10.dp).clip(RoundedCornerShape(3.dp)).background(c))
                Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 11.5.sp)
            }
        }
    }
}

@Composable
private fun NamedList(items: List<Named>) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        items.forEach {
            Column(Modifier.fillMaxWidth().glassInset(10.dp).padding(horizontal = 9.dp, vertical = 6.dp), verticalArrangement = Arrangement.spacedBy(1.dp)) {
                Text(it.name, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.sp)
                Text(it.detail, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 11.5.sp)
            }
        }
    }
}

// MARK: - Devices

@Composable
private fun DevicesCard(child: Child, devices: List<ChildDevice>, live: Boolean, onAdd: () -> Unit, onRemove: (ChildDevice) -> Unit) {
    val girl = child.isGirl
    ReportCard(tr("המכשירים של %@", child.name)) {
        devices.forEachIndexed { idx, d ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                // Remove (e.g. linked to the wrong child) — confirmed before anything happens.
                var menu by remember { mutableStateOf(false) }
                Box {
                    Box(Modifier.size(28.dp).clip(CircleShape).clickable { menu = true }, contentAlignment = Alignment.Center) {
                        Text("⋯", color = Ink.secondary, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                    }
                    DropdownMenu(menu, { menu = false }, containerColor = Ink.sheet) {
                        DropdownMenuItem(text = { Text("➖ " + tr("הסר מכשיר"), color = Ink.weak, fontFamily = Rounded, fontWeight = FontWeight.Bold) },
                            onClick = { menu = false; onRemove(d) })
                    }
                }
                // "אייפד של נועה" — the kind + the child; a custom device name rides along.
                val ipad = d.kind == "ipad"
                val generic = listOf(tr("אייפד"), tr("אייפון"), "iPhone", "iPad", "").contains(d.name)
                Text(tr("%@ %@ של %@", if (ipad) "📲" else "📱", if (ipad) tr("איפד") else tr("איפון"), child.name) + (if (generic) "" else " · ${d.name}"),
                    Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.5.sp)
                val recent = nowSecs() - d.lastSeenAt < 120
                val (txt, col) = when {
                    live && recent -> tr("● %@ עכשיו", if (girl) tr("משחקת") else tr("משחק")) to Ink.good
                    recent -> tr("● מחבר") to Ink.good
                    else -> tr("נראה %@", relative(d.lastSeenAt)) to Ink.secondary
                }
                Text(txt, color = col, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 12.sp)
            }
            if (d.shieldAuthorized == false && d.role != "parent") {
                Text("🛡️ " + tr("אין הרשאת ״זמן מסך״ במכשיר הזה — נעילת אפליקציות לא תעבוד בו. פתחו בו את טופי ← ⚙️ ← בקש הרשאה."),
                    color = Color(0xFFFF8A3D), fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 11.5.sp)
            }
            // The allow-list migration nudge (nil on older devices → say nothing).
            if (d.raw.bool("newAppsLocked") == false && d.shieldAuthorized != false && d.role != "parent") {
                Text("🔓 " + tr("אפליקציה חדשה שהילד מתקין לא נעולה במכשיר הזה. פתחו בו את טופי ← ⚙️ ← ״לנעול גם אפליקציות חדשות״ ובחרו מה נשאר פתוח."),
                    color = Ink.gold2, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 11.5.sp)
            }
            if (idx != devices.lastIndex) RowDivider()
        }
        if (devices.isEmpty()) EmptyLine(tr("עוד לא חבר מכשיר."))
        Box(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable(onClick = onAdd).dashedBorder().padding(vertical = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            Text("▦ " + if (devices.isEmpty()) tr("+ חברו מכשיר") else tr("+ חבור מכשיר נוסף"),
                color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 13.5.sp)
        }
    }
}

private fun Modifier.dashedBorder() = this.drawBehind {
    drawRoundRect(Color.White.copy(alpha = 0.45f), cornerRadius = CornerRadius(12.dp.toPx()),
        style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(5.dp.toPx(), 4.dp.toPx()))))
}

private fun relative(t: Double): String {
    val m = ((nowSecs() - t) / 60).toInt()
    if (m < 60) return tr("לפני %lld דק׳", maxOf(1, m))
    if (m < 60 * 24) return tr("לפני %lld שע׳", m / 60)
    return tr("לפני %lld ימים", m / (60 * 24))
}

// MARK: - Charts (drawn to scale, no library) — ChildReportView.swift

private fun DrawScope.label(tm: TextMeasurer, text: String, x: Float, y: Float, color: Color, size: Float, bold: Boolean = true) {
    val layout = tm.measure(text, TextStyle(color = color, fontSize = size.sp, fontFamily = Rounded, fontWeight = if (bold) FontWeight.Bold else FontWeight.Medium))
    drawText(layout, topLeft = Offset(x - layout.size.width / 2f, y - layout.size.height / 2f))
}

/** Bars = questions per day; line = accuracy. Bars to the busiest day, the line to 0…100 %. */
@Composable
private fun LearningTrendChart(points: List<DayPoint>, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val qLabel = tr("שאלות"); val okLabel = tr("הצלחה")
    val weekdays = points.map { it.weekday }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        val labelH = 18.dp.toPx(); val topPad = 8.dp.toPx(); val axisW = 36.dp.toPx()
        val plotH = h - labelH - topPad; val plotX0 = axisW; val plotW = w - 2 * axisW
        val n = maxOf(points.size, 1); val slot = plotW / n
        val barW = minOf(22.dp.toPx(), slot * 0.55f)
        val maxQ = maxOf(points.maxOfOrNull { it.questions } ?: 1, 1)
        fun xAt(i: Int) = plotX0 + slot * (i + 0.5f)
        for (f in listOf(0.5f, 0.75f, 1f)) {
            val y = topPad + plotH * (1 - f)
            drawLine(Color.White.copy(alpha = 0.18f), Offset(plotX0, y), Offset(plotX0 + plotW, y), 1.dp.toPx())
            label(tm, "${(f * 100).toInt()}%", w - axisW / 2, y, Color.White, 9.5f)
            label(tm, "${Math.round(maxQ * f)}", axisW / 2, y, Ink.secondary, 9.5f)
        }
        label(tm, qLabel, axisW / 2, topPad + plotH + labelH / 2, Ink.secondary, 8.5f, false)
        label(tm, okLabel, w - axisW / 2, topPad + plotH + labelH / 2, Color.White, 8.5f, false)
        points.forEachIndexed { i, p ->
            val bh = plotH * p.questions / maxQ
            val hh = maxOf(bh, if (p.questions > 0) 3.dp.toPx() else 0f)
            if (hh > 0) drawRoundRect(Color.White.copy(alpha = 0.30f), Offset(xAt(i) - barW / 2, topPad + plotH - hh), Size(barW, hh), CornerRadius(4.dp.toPx()))
        }
        val active = points.indices.filter { points[it].questions > 0 }
        fun pt(i: Int) = Offset(xAt(i), topPad + plotH * (1 - points[i].accuracy.toFloat()))
        if (active.size >= 2) {
            val path = Path().apply { active.forEachIndexed { k, i -> val o = pt(i); if (k == 0) moveTo(o.x, o.y) else lineTo(o.x, o.y) } }
            drawPath(path, Color.White, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round, join = StrokeJoin.Round))
        }
        active.lastOrNull()?.let { last ->
            val o = pt(last)
            drawCircle(Color.White.copy(alpha = 0.25f), 8.dp.toPx(), o)
            drawCircle(Color.White, 4.dp.toPx(), o)
            label(tm, "${Math.round(points[last].accuracy * 100)}%", o.x, maxOf(8.dp.toPx(), o.y - 14.dp.toPx()), Color.White, 10f)
        }
        points.indices.forEach { i ->
            if (points.size <= 7 || i % 4 == 3 || i == points.size - 1)
                label(tm, weekdays[i], xAt(i), h - labelH / 2, if (i == points.size - 1) Color.White else Ink.secondary, 9.5f, i == points.size - 1)
        }
    }
}

/** Paired bars per day: minutes earned vs minutes actually used, one scale. */
@Composable
private fun ScreenTimeChart(points: List<DayPoint>, modifier: Modifier) {
    val tm = rememberTextMeasurer()
    val mLabel = tr("דקות")
    val weekdays = points.map { it.weekday }
    Canvas(modifier) {
        val w = size.width; val h = size.height
        val labelH = 18.dp.toPx(); val topPad = 8.dp.toPx(); val axisW = 36.dp.toPx()
        val plotH = h - labelH - topPad; val plotX0 = axisW; val plotW = w - axisW
        val n = maxOf(points.size, 1); val slot = plotW / n
        val barW = minOf(11.dp.toPx(), slot * 0.28f)
        val maxM = maxOf(points.maxOfOrNull { maxOf(it.earned, it.used) } ?: 1, 1)
        fun xAt(i: Int) = plotX0 + slot * (i + 0.5f)
        for (f in listOf(0f, 0.5f, 1f)) {
            val y = topPad + plotH * (1 - f)
            if (f > 0) drawLine(Color.White.copy(alpha = 0.18f), Offset(plotX0, y), Offset(w, y), 1.dp.toPx())
            label(tm, "${Math.round(maxM * f)}", axisW / 2, y, Color.White, 9.5f)
        }
        label(tm, mLabel, axisW / 2, h - labelH / 2, Ink.secondary, 8.5f, false)
        points.forEachIndexed { i, p ->
            val cx = xAt(i)
            val eh = maxOf(plotH * p.earned / maxM, if (p.earned > 0) 3.dp.toPx() else 0f)
            val uh = maxOf(plotH * p.used / maxM, if (p.used > 0) 3.dp.toPx() else 0f)
            if (eh > 0) drawRoundRect(Color.White.copy(alpha = 0.38f), Offset(cx - barW * 0.6f - barW / 2, topPad + plotH - eh), Size(barW, eh), CornerRadius(3.dp.toPx()))
            if (uh > 0) drawRoundRect(Color(0xFF7CF3FF), Offset(cx + barW * 0.6f - barW / 2, topPad + plotH - uh), Size(barW, uh), CornerRadius(3.dp.toPx()))
            if (points.size <= 7 || i % 4 == 3 || i == points.size - 1)
                label(tm, weekdays[i], cx, h - labelH / 2, if (i == points.size - 1) Color.White else Ink.secondary, 9.5f, i == points.size - 1)
        }
    }
}

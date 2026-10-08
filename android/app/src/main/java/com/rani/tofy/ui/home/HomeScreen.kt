package com.rani.tofy.ui.home

import com.rani.tofy.ui.common.contentColumn

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.height
import com.rani.tofy.ui.theme.glassPane
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.data.Child
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.Progress
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import com.rani.tofy.ui.onboarding.ParentOnboarding
import kotlinx.coroutines.delay

/** ParentDashboardView.swift — the family at a glance. */
@Composable
fun HomeScreen(
    state: FamilyState,
    onOpenChild: (Child) -> Unit,
    onActions: (Child) -> Unit,
    /** ✏️ Avatar + name → this child's settings, in one tap (iOS homeSettingsChild). */
    onChildSettings: (Child) -> Unit,
    onAddChild: () -> Unit,
    onChores: () -> Unit,
    onSettings: () -> Unit,
    onBell: () -> Unit,
    onConnectDevice: (Child) -> Unit,
    /** 📍 The family map — null = all children, else on this child. */
    onLocation: (Child?) -> Unit = {},
    bellBadge: Int = 0,
    /** Another sheet (actions / connect / command status) owns the screen right now. */
    sheetOpen: Boolean = false,
    banners: @Composable ColumnScope.() -> Unit = {},
) {
    // The dashboard's 5 s tick: live countdowns and "in Tofy now" dots.
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(1000); tick++ } }

    // 🧭 The first-run tour (CoachMarks.swift): once per device, button by
    // button, as soon as the home really has a child on it — the new-parent
    // flow still owns the screen until it ends, so there is nothing to clash
    // with. Replayed from the settings (CoachTours.reset()).
    val ctx = LocalContext.current
    val firstChild = state.orderedChildren.firstOrNull()
    val connectFirst = state.orderedChildren.firstOrNull { !state.hasDevice(it) }
    var tour by remember { mutableStateOf(false) }
    var whatsNew by remember { mutableStateOf(false) }
    // 🔔 Parents NEED push (ParentDashboardView: ask automatically, but only
    // once there's a child to hear about and onboarding is over). Android 13+
    // asks once per install; a decline leaves the banner as the manual path.
    // The tour waits for the system dialog, so the two never overlap.
    var notifAsked by remember { mutableStateOf(false) }
    val askNotifications = com.rani.tofy.ui.activity.rememberNotificationsAsk(openSettingsOnDecline = false) { notifAsked = true }
    LaunchedEffect(firstChild?.id) {
        if (firstChild == null || ParentOnboarding.isActive(ctx)) return@LaunchedEffect
        val prefs = ctx.getSharedPreferences("tofy", android.content.Context.MODE_PRIVATE)
        val needsAsk = android.os.Build.VERSION.SDK_INT >= 33 &&
            !com.rani.tofy.ui.activity.notificationsOn(ctx) && !prefs.getBoolean("notif.autoAsked", false)
        if (needsAsk) {
            prefs.edit().putBoolean("notif.autoAsked", true).apply()
            delay(600)
            askNotifications()
            while (!notifAsked) delay(200)
        }
        if (CoachTours.isDone(CoachTours.PARENT_HOME)) {
            // ✨ After an update: what's new, once (iOS shows its list the same way).
            if (com.rani.tofy.ui.settings.WhatsNewOnce.shouldShow(ctx)) { delay(700); whatsNew = true }
            return@LaunchedEffect
        }
        delay(900)
        tour = true
    }

    Box(Modifier.fillMaxSize()) {
        GlassBackdrop {
            LazyColumn(
                Modifier.contentColumn().fillMaxSize().systemBarsPadding(),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item { Header(state, onSettings, onBell, bellBadge) }
                item { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { banners() } }
                item {
                    RowSpaced {
                        GlassButton(tr("＋ צרו ילד/ה"), Modifier.weight(1f).coachMark("p.newChild")) { onAddChild() }
                        GlassButton(tr("🧹 מטלות"), Modifier.weight(1f).coachMark("p.chores")) { onChores() }
                        GlassButton(tr("📍 מקום"), Modifier.weight(1f)) { onLocation(null) }
                    }
                }
                items(state.orderedChildren, key = { it.id }) { child ->
                    // `tick` is passed, not used as a key(): re-keying tore the card
                    // down every second, dropping its tour marks — the spotlight
                    // lost its target and the tour skipped itself to the end.
                    ChildCard(state, child, state.progress[child.id] ?: Progress.EMPTY,
                        // Like iOS: the tour marks the FIRST child's card only, and
                        // the connect button of the first child without a device.
                        marked = child.id == firstChild?.id, markConnect = child.id == connectFirst?.id,
                        tick = tick,
                        onOpen = { onOpenChild(child) }, onActions = { onActions(child) }, onConnect = { onConnectDevice(child) },
                        onSettings = { onChildSettings(child) }, onLocation = { onLocation(child) })
                }
                // 📍 Once, for families from before location — BELOW the children.
                if (showLocationIntro(state)) item { LocationIntroCard(onOpen = { onLocation(null) }) }
                if (!state.loading && state.children.isEmpty()) item {
                    Column(Modifier.fillMaxWidth().glassPane().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        H(tr("עוד אין ילדים במשפחה"), 19, align = TextAlign.Center)
                        GoldButton(tr("＋ צרו ילד/ה")) { onAddChild() }
                    }
                }
            }
        }
        if (whatsNew && !sheetOpen) com.rani.tofy.ui.settings.WhatsNewSheet { whatsNew = false }
        CoachTour(
            steps = parentTourSteps(stripNiqqud(firstChild?.name.orEmpty())),
            active = tour,
            onFinish = { tour = false; CoachTours.markDone(CoachTours.PARENT_HOME) },
        )
        // 🔄 A newer build exists (ParentDashboardView's UpdateAvailableSheet) — the
        // one place in the app that may leave for Google Play. Never stacked on
        // another sheet, the first-run tour or a child's help request: it waits
        // until the tour has run once, so a new parent meets the home first.
        val helpPrompt by com.rani.tofy.data.HelpRepository.prompted.collectAsState()
        com.rani.tofy.update.ParentUpdateHost(
            blocked = sheetOpen || tour || helpPrompt != null || ParentOnboarding.isActive(ctx) ||
                !CoachTours.isDone(CoachTours.PARENT_HOME),
        )
    }
}

@Composable
private fun Header(state: FamilyState, onSettings: () -> Unit, onBell: () -> Unit, badge: Int) {
    val user = FirebaseAuth.getInstance().currentUser
    val first = (user?.displayName ?: "").trim().split(" ").firstOrNull().orEmpty()
    val kids = state.children.size
    val playing = state.orderedChildren.firstOrNull { state.liveWindow(it) != null }
    Row(Modifier.fillMaxWidth().padding(top = 6.dp), verticalAlignment = Alignment.Top) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            H(if (first.isNotEmpty()) tr("שלום %@", first) else tr("שלום"), 27)
            val parts = buildList {
                state.household?.familyName?.let { add(it) }
                add(when (kids) { 0 -> tr("עוד אין ילדים"); 1 -> tr("ילד אחד"); 2 -> tr("שני ילדים"); else -> tr("%lld ילדים", kids) })
                playing?.let { add(if (it.isGirl) tr("%@ משחקת עכשיו 🎮", it.name) else tr("%@ משחק עכשיו 🎮", it.name)) }
            }
            P(parts.joinToString(" · "), 13.5f, color = Ink.secondary, weight = FontWeight.SemiBold)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Box(Modifier.coachMark("p.bell")) { CircleIconButton("🔔", badge = badge, onClick = onBell) }
            Box(Modifier.coachMark("p.gear")) { CircleIconButton("⚙️", onClick = onSettings) }
        }
    }
}

@Composable
private fun ChildCard(
    state: FamilyState, child: Child, s: Progress,
    marked: Boolean, markConnect: Boolean,
    @Suppress("UNUSED_PARAMETER") tick: Int,   // recomposes the live countdown each second
    onOpen: () -> Unit, onActions: () -> Unit, onConnect: () -> Unit,
    onSettings: () -> Unit,
    onLocation: () -> Unit = {},
) {
    val live = state.liveWindow(child)
    val inApp = state.isInAppNow(child)
    val hasDevice = state.hasDevice(child)
    val girl = child.isGirl
    val quietNow = child.quietHours?.activeAt(System.currentTimeMillis() / 1000.0)
    val pct = if (s.answeredToday > 0) Math.round(s.correctToday * 100.0 / s.answeredToday).toInt() else 0
    val statusText = when {
        live != null -> tr("%@ עכשיו · נשארו %@", if (girl) tr("משחקת") else tr("משחק"), formatTime(live.secondsLeft))
        inApp -> tr("בטופי עכשיו · %@", if (girl) tr("לומדת") else tr("לומד"))
        // 🏫🌙 The hours the parent set aside, while they are on.
        hasDevice && quietNow != null -> if (quietNow.kind == com.rani.tofy.data.QuietKind.SCHOOL)
            tr("🏫 זמן בית ספר עד %@", com.rani.tofy.data.QuietHours.clock(quietNow.end))
            else tr("🌙 שעת שינה עד %@", com.rani.tofy.data.QuietHours.clock(quietNow.end))
        // A child with no device of their own still plays in kid mode on this phone.
        !hasDevice && s.answeredToday == 0 && s.stars == 0 -> tr("עוד לא %@", if (girl) tr("התחילה") else tr("התחיל"))
        s.answeredToday > 0 -> tr("%@ היום", if (girl) tr("למדה") else tr("למד"))
        else -> tr("לא בטופי היום")
    }
    val pctColor = when {
        pct >= 80 && s.answeredToday > 0 -> Ink.good
        s.answeredToday < 6 -> Ink.primary
        pct >= 60 -> Ink.warn
        else -> Ink.weak
    }
    Column(Modifier.fillMaxWidth().coachMark("p.card", marked).glassPane(26.dp).clickable(onClick = onOpen).padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            // ✏️ Avatar + name open this child's settings in one tap — the rest of
            // the card opens their page (iOS: "מאוד מסובך להגיע למצב של עריכת ילד").
            Row(Modifier.weight(1f).clip(RoundedCornerShape(16.dp)).clickable(onClick = onSettings),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ChildAvatar(child, 56.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    H(child.name, 20)
                    Text("✏️", fontSize = 13.sp, modifier = Modifier.alpha(0.75f))
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(if (live != null || inApp) Ink.live else Color.White.copy(alpha = 0.35f)))
                    P(statusText, 12.5f, weight = FontWeight.SemiBold, maxLines = 1)
                }
            }
            }
            Text("$pct%", color = pctColor, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp)
        }
        // 📍 Where the child is, one tap from the map.
        LocationLine(child, onLocation)
        if (hasDevice) {
            val cap = child.dailyCapMinutes?.takeIf { it > 0 }
            RowSpaced {
                Stat(Modifier.weight(1f), "${s.minutesEarnedToday}" + (cap?.let { "/$it" } ?: ""), tr("דקות שהרוויחו היום"))
                Stat(Modifier.weight(1f), "${s.answeredToday}", tr("שאלות היום"))
                Stat(Modifier.weight(1f), "${s.correctToday}", tr("נכונות"))
            }
            RowSpaced {
                WhiteButton(tr("מידע נוסף ←"), Modifier.weight(2f)) { onOpen() }
                GlassButton(tr("⚡ פעלות"), Modifier.weight(1f).coachMark("p.actions", marked)) { onActions() }
            }
            // 🧒 Kid Mode: this phone becomes the child's for a while (screen-pinned).
            GlassButton(tr("תנו ל%@ לשחק כאן 🧒", child.name), Modifier.fillMaxWidth().coachMark("p.playHere", marked)) { com.rani.tofy.DeviceRole.startKidMode(child.id) }
        } else {
            P(tr("%@ · אין עדין מכשיר מחבר.", gradeName(child.effectiveGrade)), 13f)
            // מידע נוסף · חברו מכשיר · פעולות — side by side, in one row (Rani:
            // connecting used to REPLACE "מידע נוסף", and a row of its own grew the card).
            RowSpaced {
                CardButton(tr("מידע נוסף ←"), white = true, Modifier.weight(1.1f)) { onOpen() }
                CardButton(tr("+ חברו מכשיר"), white = false, Modifier.weight(1.1f).coachMark("p.connect", markConnect)) { onConnect() }
                CardButton(tr("⚡ פעלות"), white = false, Modifier.weight(0.9f).coachMark("p.actions", marked)) { onActions() }
            }
            GlassButton(tr("תנו ל%@ לשחק כאן 🧒", child.name), Modifier.fillMaxWidth().coachMark("p.playHere", marked)) { com.rani.tofy.DeviceRole.startKidMode(child.id) }
        }
    }
}

/** A card button whose label shrinks to fit — three of them share one row. */
@Composable
private fun CardButton(text: String, white: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(14.dp)
    Box(
        modifier.height(46.dp).clip(shape)
            .then(if (white) Modifier.background(Color.White.copy(alpha = 0.92f)) else Modifier.glassPane(14.dp, 0.18f, shadow = false))
            .clickable(onClick = onClick).padding(horizontal = 6.dp),
        contentAlignment = Alignment.Center,
    ) {
        com.rani.tofy.kid.ui.play.FitText(text, 14.sp, color = if (white) Ink.indigo else Color.White,
            weight = if (white) FontWeight.ExtraBold else FontWeight.Bold, maxLines = 1, minScale = 0.7f)
    }
}

@Composable
private fun Stat(modifier: Modifier, value: String, label: String) {
    Column(modifier.glassInset(14.dp).padding(vertical = 9.dp), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(value, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
        Text(label, color = Ink.secondary, fontFamily = Rounded, fontSize = 12.sp)
    }
}

/** Profile.gradeDisplayName — same keys as iOS. */
fun gradeName(grade: Int?): String {
    val g = grade ?: return ""
    if (g < 0) return tr("גן טרוםחובה")
    if (g == 0) return tr("גן חובה")
    val letters = listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳", "ט׳", "י׳", "יא׳", "יב׳")
    return tr("כתה %@", tr(letters[minOf(g, 12) - 1]))
}

/** Profile.gradeNameForParent — the parent's spelling, no niqqud. */
fun gradeNameForParent(grade: Int?): String {
    val g = grade ?: return ""
    if (g < 0) return tr("גן טרוםחובה")
    if (g == 0) return tr("גן חובה")
    val letters = listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳", "ט׳", "י׳", "יא׳", "יב׳")
    return tr("כיתה %@", tr(letters[minOf(g, 12) - 1]))
}

// MARK: - 📍 location on the home (iOS ParentDashboardView)

@Composable
private fun LocationLine(child: Child, onOpen: () -> Unit) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    val fixes by com.rani.tofy.ui.location.LocationRepository.fixes.collectAsState()
    val addresses by com.rani.tofy.ui.location.LocationRepository.addresses.collectAsState()
    @Suppress("UNUSED_EXPRESSION") fixes; @Suppress("UNUSED_EXPRESSION") addresses
    val state by com.rani.tofy.data.FamilyRepository.state.collectAsState()
    val f = com.rani.tofy.ui.location.LocationRepository.shownFix(child) ?: return
    val fresh = System.currentTimeMillis() / 1000.0 - f.at < 600
    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
        .background(if (fresh) Color(0xFF06D6A0).copy(alpha = 0.22f) else Color.White.copy(alpha = 0.12f))
        .border(1.5.dp, if (fresh) Color(0xFF5CFF9D).copy(alpha = 0.7f) else Color.Transparent, RoundedCornerShape(14.dp))
        .clickable(onClick = onOpen).padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        val (icon, where) = com.rani.tofy.ui.location.LocationRepository.whereParts(ctx, f, state.household?.places ?: emptyList())
        Text(icon, fontSize = 15.sp)
        Text(where,
            Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, maxLines = 1)
        Text(com.rani.tofy.ui.location.LocationRepository.relative(f.at), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 12.5.sp,
            color = if (fresh) Color(0xFF9FF5DD) else Ink.secondary)
    }
}

private fun showLocationIntro(state: FamilyState): Boolean {
    val prefs = com.rani.tofy.TofyAppRef.prefs("tofy.location.parent")
    if (prefs.getBoolean("introDismissed", false)) return false
    return state.children.any { state.hasDevice(it) } && state.children.none { com.rani.tofy.ui.location.LocationRepository.sharingOn(it) }
}

@Composable
private fun LocationIntroCard(onOpen: () -> Unit) {
    var shown by remember { mutableStateOf(true) }
    if (!shown) return
    Row(Modifier.fillMaxWidth().glassPane(22.dp).padding(14.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("📍", fontSize = 30.sp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(tr("חדש: לדעת איפה הילדים"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 17.sp)
            Text(tr("מפה, התראה כשמגיעים לבית הספר או הביתה, וצפצוף לטלפון שהלך לאיבוד."), color = Ink.secondary, fontFamily = Rounded, fontSize = 13.5.sp)
            Text(tr("להפעלה ←"), color = Color(0xFF4B3BC4), fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 15.sp,
                modifier = Modifier.clip(CircleShape).background(Color.White).clickable(onClick = onOpen).padding(horizontal = 16.dp, vertical = 9.dp))
        }
        Text("✕", color = Color.White, fontSize = 14.sp, modifier = Modifier.clip(CircleShape).background(Color.White.copy(alpha = 0.16f))
            .clickable { shown = false; com.rani.tofy.TofyAppRef.prefs("tofy.location.parent").edit().putBoolean("introDismissed", true).apply() }
            .padding(horizontal = 11.dp, vertical = 6.dp))
    }
}

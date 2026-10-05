package com.rani.tofy.ui.home

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.background
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import kotlinx.coroutines.delay

/** ParentDashboardView.swift — the family at a glance. */
@Composable
fun HomeScreen(
    state: FamilyState,
    onOpenChild: (Child) -> Unit,
    onActions: (Child) -> Unit,
    onAddChild: () -> Unit,
    onChores: () -> Unit,
    onSettings: () -> Unit,
    onBell: () -> Unit,
    onConnectDevice: (Child) -> Unit,
    bellBadge: Int = 0,
    banners: @Composable ColumnScope.() -> Unit = {},
) {
    // The dashboard's 5 s tick: live countdowns and "in Tofy now" dots.
    var tick by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(1000); tick++ } }

    GlassBackdrop {
        LazyColumn(
            Modifier.fillMaxSize().systemBarsPadding(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item { Header(state, onSettings, onBell, bellBadge) }
            item { Column(verticalArrangement = Arrangement.spacedBy(10.dp)) { banners() } }
            item {
                RowSpaced {
                    GlassButton(tr("＋ צְרוּ יֶלֶד/ה"), Modifier.weight(1f)) { onAddChild() }
                    GlassButton(tr("🧹 מַטְלוֹת"), Modifier.weight(1f)) { onChores() }
                }
            }
            items(state.orderedChildren, key = { it.id }) { child ->
                key(tick) {
                    ChildCard(state, child, state.progress[child.id] ?: Progress.EMPTY,
                        onOpen = { onOpenChild(child) }, onActions = { onActions(child) }, onConnect = { onConnectDevice(child) })
                }
            }
            if (!state.loading && state.children.isEmpty()) item {
                Column(Modifier.fillMaxWidth().glassPane().padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    H(tr("עוֹד אֵין יְלָדִים בַּמִּשְׁפָּחָה"), 19, align = TextAlign.Center)
                    GoldButton(tr("＋ צְרוּ יֶלֶד/ה")) { onAddChild() }
                }
            }
        }
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
            H(if (first.isNotEmpty()) tr("שָׁלוֹם %@ 👋", first) else tr("שָׁלוֹם 👋"), 27)
            val parts = buildList {
                state.household?.familyName?.let { add(it) }
                add(when (kids) { 0 -> tr("עוֹד אֵין יְלָדִים"); 1 -> tr("יֶלֶד אֶחָד"); 2 -> tr("שְׁנֵי יְלָדִים"); else -> tr("%lld יְלָדִים", kids) })
                playing?.let { add(if (it.isGirl) tr("%@ מְשַׂחֶקֶת עַכְשָׁיו 🎮", it.name) else tr("%@ מְשַׂחֵק עַכְשָׁיו 🎮", it.name)) }
            }
            P(parts.joinToString(" · "), 13.5f, color = Ink.secondary, weight = FontWeight.SemiBold)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            CircleIconButton("🔔", badge = badge, onClick = onBell)
            CircleIconButton("⚙️", onClick = onSettings)
        }
    }
}

@Composable
private fun ChildCard(state: FamilyState, child: Child, s: Progress, onOpen: () -> Unit, onActions: () -> Unit, onConnect: () -> Unit) {
    val live = state.liveWindow(child)
    val inApp = state.isInAppNow(child)
    val hasDevice = state.hasDevice(child)
    val girl = child.isGirl
    val pct = if (s.answeredToday > 0) Math.round(s.correctToday * 100.0 / s.answeredToday).toInt() else 0
    val statusText = when {
        live != null -> tr("%@ עַכְשָׁיו · נִשְׁאֲרוּ %@", if (girl) tr("מְשַׂחֶקֶת") else tr("מְשַׂחֵק"), formatTime(live.secondsLeft))
        inApp -> tr("בְּטוֹפִי עַכְשָׁיו · %@", if (girl) tr("לוֹמֶדֶת") else tr("לוֹמֵד"))
        !hasDevice -> tr("עוֹד לֹא %@", if (girl) tr("הִתְחִילָה") else tr("הִתְחִיל"))
        s.answeredToday > 0 -> tr("%@ הַיּוֹם", if (girl) tr("לָמְדָה") else tr("לָמַד"))
        else -> tr("לֹא בְּטוֹפִי הַיּוֹם")
    }
    val pctColor = when {
        pct >= 80 && s.answeredToday > 0 -> Ink.good
        s.answeredToday < 6 -> Ink.primary
        pct >= 60 -> Ink.warn
        else -> Ink.weak
    }
    Column(Modifier.fillMaxWidth().glassPane(26.dp).clickable(onClick = onOpen).padding(14.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            ChildAvatar(child, 56.dp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                H(child.name, 20)
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Box(Modifier.size(8.dp).clip(CircleShape).background(if (live != null || inApp) Ink.live else Color.White.copy(alpha = 0.35f)))
                    P(statusText, 12.5f, weight = FontWeight.SemiBold, maxLines = 1)
                }
            }
            Text("$pct%", color = pctColor, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 22.sp)
        }
        if (hasDevice) {
            val cap = child.dailyCapMinutes?.takeIf { it > 0 }
            RowSpaced {
                Stat(Modifier.weight(1f), "${s.minutesEarnedToday}" + (cap?.let { "/$it" } ?: ""), tr("דַּקּוֹת הַיּוֹם"))
                Stat(Modifier.weight(1f), "${s.answeredToday}", tr("שְׁאֵלוֹת הַיּוֹם"))
                Stat(Modifier.weight(1f), "${s.correctToday}", tr("נְכוֹנוֹת"))
            }
            RowSpaced {
                WhiteButton(tr("מֵידָע נוֹסָף ←"), Modifier.weight(2f)) { onOpen() }
                GlassButton(tr("⚡ פְּעֻלּוֹת"), Modifier.weight(1f)) { onActions() }
            }
        } else {
            P(tr("%@ · אֵין עֲדַיִן מַכְשִׁיר מְחֻבָּר.", gradeName(child.effectiveGrade)), 13f)
            RowSpaced {
                WhiteButton(tr("📱 חִבּוּר מַכְשִׁיר"), Modifier.weight(2f)) { onConnect() }
                GlassButton(tr("⚡ פְּעֻלּוֹת"), Modifier.weight(1f)) { onActions() }
            }
        }
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
    if (g < 0) return tr("גַּן טְרוֹם־חוֹבָה")
    if (g == 0) return tr("גַּן חוֹבָה")
    val letters = listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳", "ט׳", "י׳", "יא׳", "יב׳")
    return tr("כִּתָּה %@", tr(letters[minOf(g, 12) - 1]))
}

/** Profile.gradeNameForParent — the parent's spelling, no niqqud. */
fun gradeNameForParent(grade: Int?): String {
    val g = grade ?: return ""
    if (g < 0) return tr("גן טרום־חובה")
    if (g == 0) return tr("גן חובה")
    val letters = listOf("א׳", "ב׳", "ג׳", "ד׳", "ה׳", "ו׳", "ז׳", "ח׳", "ט׳", "י׳", "יא׳", "יב׳")
    return tr("כיתה %@", tr(letters[minOf(g, 12) - 1]))
}

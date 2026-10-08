package com.rani.tofy.ui.activity

import android.Manifest
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import com.google.firebase.firestore.FieldValue
import com.rani.tofy.data.*
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * The home's banners — ParentDashboardView.swift: only what the parent has to
 * ACT on, and only while they have to. 🧠 a child stuck on a question right
 * now, 🧹 chores waiting for approval (one-tap approve), a child's purchase
 * request, and notifications being off.
 */
@Composable
fun ColumnScope.HomeBanners(state: FamilyState, onChores: () -> Unit, onPaywall: () -> Unit = {}, onPack: (packID: String, childID: String) -> Unit = { _, _ -> }) {
    LaunchedEffect(Unit) { ChoresRepository.start(); HelpRepository.start(); ActivityStore.start() }
    val help by HelpRepository.pending.collectAsState()
    val chores by ChoresRepository.chores.collectAsState()
    val approving by ChoresRepository.approving.collectAsState()
    val kids = state.children.associateBy { it.id }

    help.forEach { HelpBanner(it) { HelpRepository.prompted.value = it } }

    // 🧹 A kid finished a chore and can't get the reward until someone approves.
    val pending = ChoresRepository.pendingApproval(chores).filter { it.childID in kids }
    pending.take(3).forEach { c ->
        val kid = kids.getValue(c.childID)
        ChoreBanner(kid, c, c.id in approving,
            onOpen = { ChoresRepository.focusChildID = c.childID; onChores() },
            onApprove = { ChoresRepository.approve(c) })
    }
    if (pending.size > 3) {
        NoticeBanner("🧹", tr("%lld מטלות מחכות לאישור שלכם!", pending.size), null, tint = Color(0xFF2EE59D)) {
            ChoresRepository.focusChildID = pending.first().childID; onChores()
        }
    }

    RequestBanners(state, onPaywall, onPack)
    NotificationsBanner()

    HelpAnswerSheetHost()
}

// MARK: 🧠 help

@Composable
private fun HelpBanner(req: HelpRequest, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().glassPane(20.dp, 0.18f).background(Color(0xFF7A5CFF).copy(alpha = 0.18f))
            .clickable(onClick = onClick).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("🧠", fontSize = 26.sp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(if (req.isGirl) tr("%@ מבקשת עזרה בשאלה", req.childName) else tr("%@ מבקש עזרה בשאלה", req.childName),
                color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            P(req.question, 12.5f, maxLines = 2)
        }
        Chevron()
    }
}

/** ParentHelpAnswerView (ParentAssistView.swift): the question and the two options as big buttons. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HelpAnswerSheetHost() {
    val req by HelpRepository.prompted.collectAsState()
    val r = req ?: return
    val scope = rememberCoroutineScope()
    var sending by remember(r.id) { mutableStateOf<String?>(null) }
    var done by remember(r.id) { mutableStateOf(false) }
    val close = { HelpRepository.prompted.value = null }
    LaunchedEffect(done) { if (done) { delay(1200); close() } }

    ModalBottomSheet(onDismissRequest = close, containerColor = Ink.sheet, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp).padding(bottom = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            H(if (r.isGirl) tr("%@ מבקשת עזרה 🧠", r.childName) else tr("%@ מבקש עזרה 🧠", r.childName), 22, align = TextAlign.Center)
            P(tr("איזו תשובה נכונה? הלחיצה שלכם מורידה את התשובה השגויה מהמסך של %@.", r.childName), 14f, color = Color.White.copy(alpha = 0.85f), align = TextAlign.Center)
            Box(Modifier.fillMaxWidth().glassInset(20.dp).padding(16.dp), contentAlignment = Alignment.Center) {
                Text(r.question, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 20.sp, textAlign = TextAlign.Center)
            }
            if (done) {
                Box(Modifier.fillMaxWidth().glassInset(18.dp).padding(vertical = 16.dp), contentAlignment = Alignment.Center) {
                    Text(tr("✅ נשלח! התשובה השגויה ירדה מהמסך"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, textAlign = TextAlign.Center)
                }
            } else {
                listOf(r.optionA to r.optionB, r.optionB to r.optionA).forEach { (opt, other) ->
                    Box(
                        Modifier.fillMaxWidth().height(58.dp).clip(RoundedCornerShape(18.dp))
                            .background(Brush.horizontalGradient(listOf(Color(0xFF5E60CE), Color(0xFF3E8BF0))))
                            .clickable(enabled = sending == null) {
                                sending = opt
                                scope.launch {
                                    val ok = HelpRepository.answer(r, opt, other)
                                    sending = null
                                    if (ok) done = true
                                }
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            if (sending == opt) CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                            Text(opt, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 19.sp)
                        }
                    }
                }
            }
            Text(if (done) tr("סגור") else tr("לא עכשיו"),
                Modifier.clickable { if (!done) HelpRepository.dismiss(r) else close() }.padding(8.dp),
                color = Color.White.copy(alpha = 0.9f), fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
        }
    }
}

// MARK: 🧹 chores

@Composable
private fun ChoreBanner(kid: Child, c: Chore, approving: Boolean, onOpen: () -> Unit, onApprove: () -> Unit) {
    val green = Color(0xFF2EE59D)
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(18.dp)).background(green.copy(alpha = 0.25f))
            .border(1.dp, green.copy(alpha = 0.6f), RoundedCornerShape(18.dp))
            .clickable(onClick = onOpen).padding(horizontal = 13.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(c.emoji, fontSize = 24.sp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(if (kid.isGirl) tr("%@ סימה מטלה", kid.name) else tr("%@ סים מטלה", kid.name),
                color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            P(tr("%@ · מחכה לאישור", c.title), 13f, color = Ink.secondary, maxLines = 2)
        }
        Box(
            Modifier.height(38.dp).clip(RoundedCornerShape(12.dp)).background(Color.White.copy(alpha = 0.92f))
                .clickable(enabled = !approving, onClick = onApprove).padding(horizontal = 14.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (approving) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                CircularProgressIndicator(Modifier.size(14.dp), color = Ink.indigo, strokeWidth = 2.dp)
                Text(tr("מאשר…"), color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
            } else Text(tr("אשרו"), color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
        }
    }
}

// MARK: 👑 / ⚽ requests from a child's device

/** A pack or world pass by id (QuestionPacks.find) — the name + emoji the parent sees. */
internal fun packLabel(id: String): Pair<String, String>? = when (id) {
    "soccer" -> "⚽" to tr("עולם הכדורגל")
    "dinosaurs" -> "🦖" to tr("דינוזאורים")
    "space" -> "🚀" to tr("חלל וכוכבים")
    "animals" -> "🐾" to tr("עולם החיות")
    "sea" -> "🌊" to tr("מעמקי הים")
    "gifted" -> "🧠" to tr("הכנה למחוננים")
    "food" -> "🍳" to tr("מטבח ומדע של אוכל")
    "israel" -> "🏛️" to tr("ישראל שלי")
    "tishrei" -> "🍎" to tr("חגי תשרי")
    "music" -> "🎵" to tr("מוזיקה")
    "body" -> "🧍" to tr("גוף האדם")
    "vehicles" -> "🚗" to tr("כלי רכב ותחבורה")
    "flags" -> "🌍" to tr("דגלים ומדינות")
    "math" -> "🧮" to tr("ממלכת המתמטיקה")
    "english" -> "🔤" to tr("ארץ אנגלית")
    "hebrew" -> "✍️" to tr("ארץ העברית")
    "logic" -> "🧩" to tr("חידות הלוגיקה")
    "science" -> "🔬" to tr("מעבדת המדעים")
    "history" -> "🏛️" to tr("מוזיאון ההיסטוריה")
    "geography" -> "🌍" to tr("מסע סביב העולם")
    "money" -> "💰" to tr("שוק הכסף")
    "reading" -> "📖" to tr("יער הסיפורים")
    "holidays" -> "🎊" to tr("החגים")
    else -> null
}

/** Children who tapped "ask a parent" for Tofy+ (premiumRequestedAt), unless the family is premium. */
internal fun premiumAskers(state: FamilyState) =
    if (state.household?.isPremium == true) emptyList() else state.orderedChildren.filter { it.raw.secs("premiumRequestedAt") != null }

/** Children who asked for a pack they don't own yet (packRequestedAt + packRequestedID). */
internal fun packAskers(state: FamilyState) = state.orderedChildren.mapNotNull { c ->
    val id = c.raw.str("packRequestedID") ?: return@mapNotNull null
    if (c.raw.secs("packRequestedAt") == null || id in c.packs) return@mapNotNull null
    val (emoji, name) = packLabel(id) ?: return@mapNotNull null
    Triple(c, emoji, name)
}

internal fun premiumAskTitle(askers: List<Child>) =
    if (askers.size == 1) tr("%@ רוצה טופי+", askers[0].name) else tr("%@ רוצים טופי+", askers.joinToString(tr(" ו")) { it.name })

/**
 * "לפתוח עכשיו" opens the Play paywall / pack purchase (behind the parent
 * code); "לא עכשיו" takes the request down on the child's side
 * (RemoteSyncManager.clearPremiumRequests / clearPackRequest).
 */
@Composable
private fun RequestBanners(state: FamilyState, onPaywall: () -> Unit, onPack: (String, String) -> Unit) {
    val scope = rememberCoroutineScope()
    val premium = premiumAskers(state)
    if (premium.isNotEmpty()) {
        RequestBanner("👑", premiumAskTitle(premium), onOpen = onPaywall) {
            scope.launch { premium.forEach { ChildRepository.update(it.id, mapOf("premiumRequestedAt" to FieldValue.delete())) } }
        }
    }
    packAskers(state).forEach { (c, emoji, name) ->
        RequestBanner(emoji, tr("%@ רוצה את %@", c.name, name), onOpen = { c.raw.str("packRequestedID")?.let { onPack(it, c.id) } }) {
            scope.launch { ChildRepository.update(c.id, mapOf("packRequestedAt" to FieldValue.delete(), "packRequestedID" to FieldValue.delete())) }
        }
    }
}

@Composable
private fun RequestBanner(emoji: String, title: String, onOpen: () -> Unit, onDismiss: () -> Unit) {
    Column(Modifier.fillMaxWidth().glassPane(20.dp, 0.18f).background(Ink.gold2.copy(alpha = 0.14f)).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(emoji, fontSize = 26.sp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            }
        }
        // Google Play Billing is in: the parent buys right here, behind the parent code.
        RowSpaced {
            WhiteButton(tr("לפתוח עכשיו"), Modifier.weight(1f), height = 40.dp, onClick = onOpen)
            GlassButton(tr("לא עכשיו"), Modifier.weight(1f), height = 40.dp, onClick = onDismiss)
        }
    }
}

// MARK: 🔕 notifications

/** Notifications can reach this phone (Android 13+: the POST_NOTIFICATIONS grant). */
internal fun notificationsOn(ctx: Context) = NotificationManagerCompat.from(ctx).areNotificationsEnabled()

internal fun openNotificationSettings(ctx: Context) {
    val i = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)
        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    runCatching { ctx.startActivity(i) }
}

/** Asks for the runtime grant; a refusal (or a pre-13 phone with them off) opens the system settings. */
@Composable
internal fun rememberNotificationsAsk(openSettingsOnDecline: Boolean = true, onResult: () -> Unit): () -> Unit {
    val ctx = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (!granted && openSettingsOnDecline) openNotificationSettings(ctx)
        onResult()
    }
    return {
        if (Build.VERSION.SDK_INT >= 33) launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
        else openNotificationSettings(ctx)
    }
}

@Composable
private fun NotificationsBanner() {
    val ctx = LocalContext.current
    var on by remember { mutableStateOf(notificationsOn(ctx)) }
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { on = notificationsOn(ctx) }
    val ask = rememberNotificationsAsk { on = notificationsOn(ctx) }
    if (on) return
    NoticeBanner("🔔", tr("ההתראות כבויות"), tr("הפעילו כדי לקבל עדכונים על הילד"), tint = Color(0xFFFF8C42), onClick = ask)
}

@Composable
private fun NoticeBanner(emoji: String, title: String, detail: String?, tint: Color, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().glassPane(18.dp, 0.16f).background(tint.copy(alpha = 0.16f)).clickable(onClick = onClick).padding(14.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(emoji, fontSize = 22.sp)
        Column(Modifier.weight(1f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, textAlign = TextAlign.Center)
            detail?.let { P(it, 12.5f, color = Color.White.copy(alpha = 0.9f), align = TextAlign.Center) }
        }
        Chevron()
    }
}

@Composable
internal fun Chevron() {
    val rtl = androidx.compose.ui.platform.LocalLayoutDirection.current == androidx.compose.ui.unit.LayoutDirection.Rtl
    Text(if (rtl) "‹" else "›", color = Ink.tertiary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
}

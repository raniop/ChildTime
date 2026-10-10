package com.rani.tofy.ui.settings

import com.rani.tofy.ui.common.contentColumn

import android.Manifest
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.app.NotificationManagerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.firebase.auth.FirebaseAuth
import com.rani.tofy.data.AccountRepository
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.SettingsRepository
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.push.PushRegistrar
import com.rani.tofy.ui.common.CoachTours
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.launch

private enum class SettingsSheet { LANGUAGE, ORDER, PIN, FEEDBACK, WHATS_NEW }

/**
 * ParentSettingsView.swift for the Android parent: what applies to a parent's
 * phone, as one sectioned glass list. Left out on purpose — they live on the
 * child's device on iOS too: FamilyActivityPicker app selection, lock-new-apps,
 * sounds, Face ID, app deletion, device role, and the reward numbers
 * (ParentSettings.swift keeps those device-local), plus StoreKit / data export.
 */
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    var addingParent by remember { mutableStateOf(false) }
    if (addingParent) { AddParentScreen(onClose = { addingParent = false }); return }

    BackHandler(onBack = onBack)
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    val state by FamilyRepository.state.collectAsState()
    val hh = state.household
    val user = FirebaseAuth.getInstance().currentUser
    val providers = remember(user?.uid) { SettingsRepository.providers }

    var sheet by remember { mutableStateOf<SettingsSheet?>(null) }
    var confirmSignOut by remember { mutableStateOf(false) }
    var deleting by remember { mutableStateOf(false) }
    var testPushMessage by remember { mutableStateOf<String?>(null) }
    // 🧭 ParentSettingsView `tourResetDone`: the home tour's last stop promises this.
    var tourResetDone by remember { mutableStateOf(false) }

    // PushManager.authorized — re-read whenever the parent comes back from the system settings.
    var pushOn by remember { mutableStateOf(NotificationManagerCompat.from(ctx).areNotificationsEnabled()) }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    DisposableEffect(lifecycle) {
        val obs = LifecycleEventObserver { _, e -> if (e == Lifecycle.Event.ON_RESUME) pushOn = NotificationManagerCompat.from(ctx).areNotificationsEnabled() }
        lifecycle.addObserver(obs)
        onDispose { lifecycle.removeObserver(obs) }
    }
    fun openNotificationSettings() {
        runCatching { ctx.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName)) }
    }
    val askPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pushOn = NotificationManagerCompat.from(ctx).areNotificationsEnabled()
        if (granted) PushRegistrar.register() else openNotificationSettings()
    }
    fun enablePush() {
        if (Build.VERSION.SDK_INT >= 33) askPermission.launch(Manifest.permission.POST_NOTIFICATIONS) else openNotificationSettings()
    }

    GlassBackdrop {
        Column(Modifier.contentColumn().fillMaxSize().systemBarsPadding().imePadding()) {
            SettingsTopBar(tr("הגדרות"), onBack)
            LazyColumn(
                Modifier.fillMaxSize(),
                contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 40.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                // 🌍 Written in both languages, so a parent who switched by mistake finds the way back.
                item {
                    Section {
                        SettingsRow("🌍", tr("שפה · Language"), I18n.language.native, chevron = true) { sheet = SettingsSheet.LANGUAGE }
                    }
                }

                // 👪 The family: its name, the parents in it, the order of the kids.
                item {
                    Section(tr("שם המשפחה"), tr("מופיע במסך ההורים ובהודעות — לכל ההורים במשפחה.")) {
                        FamilyNameRow(hh?.familyName)
                    }
                }
                // 🌍 Only when this phone's clock differs from the family's (ParentSettingsView.timeZoneSection).
                hh?.timeZone?.let { stored ->
                    val family = java.util.TimeZone.getTimeZone(stored)
                    val phone = java.util.TimeZone.getDefault()
                    val now = System.currentTimeMillis()
                    if (family.getOffset(now) != phone.getOffset(now)) item {
                        Section(tr("אזור הזמן של המשפחה"), tr("לפיו נקבעות השעות והתאריכים בהתראות — לכל ההורים במשפחה.")) {
                            FamilyTimeZoneRow(stored, phone.id)
                        }
                    }
                }
                item {
                    Section(tr("סנכרון בין מכשירים")) {
                        val name = user?.displayName?.takeIf { it.isNotBlank() }
                        val sub = buildList {
                            user?.email?.takeIf { it != name }?.let { add(it) }
                            if ("google.com" in providers) add(tr("דרך Google")) else if ("apple.com" in providers) add(tr("דרך Apple"))
                        }.joinToString(" · ").ifEmpty { null }
                        SettingsRow("✅", name ?: user?.email ?: tr("מחובר"), sub)
                        linkedParentNames(hh?.parentNames ?: emptyMap()).forEach { p ->
                            RowDivider()
                            SettingsRow("👥", p, tr("הורה במשפחה"))
                        }
                        RowDivider()
                        SettingsRow("➕", tr("הוסיפו הורה למשפחה"), titleColor = Ink.gold2, chevron = true) { addingParent = true }
                    }
                }
                if (state.children.size >= 2) item {
                    Section(tr("סדר הילדים")) {
                        SettingsRow("↕️", tr("סדר את הילדים"), chevron = true) { sheet = SettingsSheet.ORDER }
                    }
                }

                // 🔔 Notifications to this phone.
                item {
                    Section(tr("התראות להורה"), tr("קבלו עדכון כשהילד מתחיל ומסיים לשחק, פותח רצף, זוכה בגלגל מזל או מגלה תחום חדש — וגם דוח שבועי. ההתראות נשלחות בין המכשירים בבית. \"שלח התראת בדיקה\" שולח התראה אליכם עכשיו כדי לוודא שהכול עובד.")) {
                        if (pushOn) SettingsRow("🔔", tr("התראות פעילות"), titleColor = Ink.good)
                        else SettingsRow("🔕", tr("הפעל התראות חיות"), titleColor = Ink.gold2, chevron = true) { enablePush() }
                        RowDivider()
                        SettingsRow("⚙️", tr("פתחו את ההגדרות"), chevron = true) { openNotificationSettings() }
                        RowDivider()
                        SettingsRow("📨", tr("שלח התראת בדיקה"), testPushMessage) {
                            if (!pushOn) { testPushMessage = tr("צריך לאשר התראות קודם"); enablePush(); return@SettingsRow }
                            PushRegistrar.register()
                            scope.launch { testPushMessage = SettingsRepository.sendTestPush() }
                        }
                    }
                }

                // 🔐 The family parent code.
                item {
                    Section(tr("קוד הורה")) {
                        SettingsRow("🔑", tr("שנה קוד הורה"), chevron = true) { sheet = SettingsSheet.PIN }
                    }
                }

                // 📱 iOS's Screen Time rows are per-device — say where they live instead.
                item {
                    Section(tr("אפליקציות ונעילה"), tr("נעילת האפליקציות, הצלילים והתגמול על תשובות נכונות מוגדרים במכשיר של כל ילד: פותחים שם את טופי ונכנסים להגדרות עם קוד ההורה.")) {
                        SettingsRow("📱", tr("מוגדר במכשיר של כל ילד"))
                    }
                }

                // ℹ️ About, support and the legal pages.
                item {
                    Section(tr("אודות ופרטיות")) {
                        SettingsRow("✨", tr("מה חדש בטופי ✨"), chevron = true) { sheet = SettingsSheet.WHATS_NEW }
                        RowDivider()
                        // Every tour on this device (the parent's home, and a child's
                        // home on a shared phone) runs again the next time its screen opens.
                        SettingsRow(
                            "👆",
                            if (tourResetDone) tr("ההדרכה תוצג שוב במסך הבית ✓") else tr("הצגת ההדרכה שוב"),
                            titleColor = if (tourResetDone) Ink.good else Ink.primary,
                        ) { if (!tourResetDone) { CoachTours.reset(); tourResetDone = true } }
                        RowDivider()
                        SettingsRow("💬", tr("פידבק והצעות"), chevron = true) { sheet = SettingsSheet.FEEDBACK }
                        RowDivider()
                        SettingsRow("🛟", tr("עזרה ותמיכה"), chevron = true) {
                            openUrl(ctx, if (I18n.language.code == "he") "https://tofyapp.com/support" else "https://tofyapp.com/en/support")
                        }
                        RowDivider()
                        SettingsRow("🔒", tr("מדיניות פרטיות"), chevron = true) { openUrl(ctx, "https://tofyapp.com/privacy") }
                        RowDivider()
                        SettingsRow("📄", tr("תנאי שימוש"), chevron = true) { openUrl(ctx, "https://tofyapp.com/terms") }
                    }
                }

                // 🚪 The account.
                item {
                    Section(tr("פרטיות ונתונים")) {
                        SettingsRow("🚪", tr("התנתקות")) { confirmSignOut = true }
                        RowDivider()
                        SettingsRow("🗑️", tr("מחק את כל הנתונים שלי"), titleColor = Ink.weak) { deleting = true }
                    }
                }

                item {
                    Column(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(tr("טופי"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
                        P(SettingsRepository.versionLine, 13f, color = Ink.tertiary, align = TextAlign.Center)
                    }
                }
            }
        }
    }

    when (sheet) {
        SettingsSheet.LANGUAGE -> LanguageSheet { sheet = null }
        SettingsSheet.ORDER -> ChildOrderSheet(state.orderedChildren) { sheet = null }
        SettingsSheet.PIN -> ChangePinSheet(hh?.parentPinHash) { sheet = null }
        SettingsSheet.FEEDBACK -> FeedbackSheet { sheet = null }
        SettingsSheet.WHATS_NEW -> WhatsNewSheet { sheet = null }
        null -> {}
    }

    if (confirmSignOut) AlertDialog(
        onDismissRequest = { confirmSignOut = false }, containerColor = Ink.sheet,
        title = { Text(tr("להתנתק מהחשבון בטלפון הזה?"), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, color = Ink.primary) },
        text = { P(tr("המשפחה, הילדים וההתקדמות שמורים בענן — כשתתחברו שוב, הכול יחזור."), 14.5f) },
        confirmButton = {
            TextButton({
                confirmSignOut = false
                // This phone stops receiving the family's pushes, THEN the session ends.
                scope.launch { PushRegistrar.unregister(); AccountRepository.signOut() }
            }) { Text(tr("התנתקות"), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, color = Ink.weak) }
        },
        dismissButton = { TextButton({ confirmSignOut = false }) { Text(tr("בטל"), fontFamily = Rounded, color = Ink.secondary) } },
    )

    if (deleting) DeleteAccountFlow(onCancel = { deleting = false })
}

/** A section capped to a readable column (iOS .readableColumn) so tablets don't stretch it. */
@Composable
private fun Section(header: String? = null, footer: String? = null, content: @Composable androidx.compose.foundation.layout.ColumnScope.() -> Unit) {
    Box(Modifier.widthIn(max = 560.dp).fillMaxWidth()) { SettingsSection(header, footer, content) }
}

/** "משפחת גולן" — one name for the whole household; "שִׁמְרוּ" appears once it was edited. */
/** "שעון ישראל" / "Eastern Time" — in the app's language. */
private fun zoneName(id: String): String =
    runCatching {
        android.icu.util.TimeZone.getTimeZone(id).getDisplayName(false, android.icu.util.TimeZone.LONG_GENERIC, java.util.Locale(I18n.language.code))
    }.getOrNull()?.takeIf { it.isNotBlank() } ?: id

@Composable
private fun FamilyTimeZoneRow(familyID: String, phoneID: String) {
    val scope = rememberCoroutineScope()
    Column(Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 10.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("המשפחה: %@", zoneName(familyID)), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Text(tr("הטלפון הזה: %@", zoneName(phoneID)), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
        Text(
            tr("להעביר את המשפחה לאזור הזמן של הטלפון הזה"),
            Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.92f))
                .clickable { scope.launch { SettingsRepository.householdWrite { ChildRepository.setFamilyTimeZone(phoneID) } } }
                .padding(horizontal = 12.dp, vertical = 10.dp),
            color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
    }
}

@Composable
private fun FamilyNameRow(current: String?) {
    val scope = rememberCoroutineScope()
    val focus = LocalFocusManager.current
    var draft by remember { mutableStateOf(current ?: "") }
    LaunchedEffect(current) { if (draft.isEmpty()) draft = current ?: "" }
    val changed = draft.trim() != (current ?: "") && draft.isNotBlank()
    fun save() {
        val name = draft
        focus.clearFocus()
        scope.launch { SettingsRepository.householdWrite { ChildRepository.setFamilyName(name) } }
    }
    Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Text("👪", fontSize = 20.sp)
        OutlinedTextField(
            draft, { draft = it }, Modifier.weight(1f), singleLine = true,
            textStyle = androidx.compose.ui.text.TextStyle(fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, color = Color.White),
            placeholder = { Text(tr("למשל: משפחת גולן"), fontFamily = Rounded, color = Color.White.copy(alpha = 0.6f)) },
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(onDone = { if (changed) save() else focus.clearFocus() }),
            colors = glassFieldColors(), shape = RoundedCornerShape(16.dp),
        )
        if (changed) Text(
            tr("שמרו"),
            Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.92f)).clickable { save() }.padding(horizontal = 12.dp, vertical = 6.dp),
            color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp,
        )
    }
}

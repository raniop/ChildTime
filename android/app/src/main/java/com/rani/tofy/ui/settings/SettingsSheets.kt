package com.rani.tofy.ui.settings

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetValue
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.zIndex
import com.rani.tofy.data.Child
import com.rani.tofy.data.ChildRepository
import com.rani.tofy.data.SettingsRepository
import com.rani.tofy.i18n.AppLanguage
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.push.PushRegistrar
import com.rani.tofy.ui.common.ChildAvatar
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.onboarding.LocalParentPin
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun Sheet(onDismiss: () -> Unit, holdOpen: () -> Boolean = { false }, content: @Composable () -> Unit) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true, confirmValueChange = { it != SheetValue.Hidden || !holdOpen() }),
        containerColor = Ink.sheet,
    ) {
        Column(Modifier.fillMaxWidth().navigationBarsPadding().imePadding().padding(horizontal = 18.dp).padding(bottom = 18.dp)) { content() }
    }
}

/** Title in the middle, "ביטול" at start and an optional confirm at end — the sheet's nav bar. */
@Composable
private fun SheetBar(title: String, cancel: String? = null, onCancel: () -> Unit = {}, confirm: String? = null, confirmEnabled: Boolean = true, onConfirm: () -> Unit = {}) {
    Box(Modifier.fillMaxWidth().padding(bottom = 10.dp), contentAlignment = Alignment.Center) {
        cancel?.let { TextButton(onCancel, Modifier.align(Alignment.CenterStart)) { Text(it, fontFamily = Rounded, color = Ink.secondary) } }
        H(title, 18, Modifier.padding(horizontal = 80.dp), align = TextAlign.Center)
        confirm?.let {
            TextButton(onConfirm, Modifier.align(Alignment.CenterEnd), enabled = confirmEnabled) {
                Text(it, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, color = if (confirmEnabled) Ink.gold2 else Ink.tertiary)
            }
        }
    }
}

// MARK: - Language (LanguagePickerView.swift)

/** Switches at once, and tells the server so pushes arrive in the new language. */
@Composable
fun LanguageSheet(onDismiss: () -> Unit) {
    Sheet(onDismiss) {
        SheetBar(tr("שפה · Language"))
        Column(Modifier.fillMaxWidth().glassPane(20.dp)) {
            AppLanguage.entries.forEachIndexed { i, lang ->
                if (i > 0) RowDivider()
                SettingsRow(null, lang.native, trailing = {
                    if (I18n.language == lang) Text("✓", color = Ink.good, fontSize = 18.sp, fontWeight = FontWeight.Bold)
                }) {
                    I18n.set(lang)
                    PushRegistrar.register()   // parents/{uid}.language + tokenLanguages[token]
                }
            }
        }
        P(tr("השפה משתנה מיד בכל האפליקציה: טקסטים, כיוון, הקראה ושאלות."), 12.5f, Modifier.padding(14.dp), color = Ink.tertiary)
    }
}

// MARK: - Child order (ParentDashboardView.ChildOrderView)

/**
 * The family-wide manual order (households.childOrder), saved on "שמור".
 * Drag the ≡ handle — the same list-with-handles parents know from iOS. While
 * a child is being dragged the sheet refuses to close, so a downward drag moves
 * the child, not the sheet.
 */
@Composable
fun ChildOrderSheet(children: List<Child>, onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var working by remember { mutableStateOf(children) }
    var dragging by remember { mutableStateOf<String?>(null) }
    var offset by remember { mutableFloatStateOf(0f) }
    var saving by remember { mutableStateOf(false) }
    val rowPx = with(LocalDensity.current) { 64.dp.toPx() }

    Sheet(onDismiss, holdOpen = { dragging != null }) {
        SheetBar(tr("סדר הילדים"), cancel = tr("ביטול"), onCancel = onDismiss, confirm = tr("שמור"), confirmEnabled = !saving) {
            saving = true
            scope.launch {
                SettingsRepository.householdWrite { ChildRepository.setChildOrder(working.map { it.id }) }
                onDismiss()
            }
        }
        Column(Modifier.fillMaxWidth().glassPane(20.dp)) {
            working.forEachIndexed { i, c ->
                key(c.id) {
                    val isDragged = dragging == c.id
                    Row(
                        Modifier.fillMaxWidth().height(64.dp).zIndex(if (isDragged) 1f else 0f)
                            .graphicsLayer { translationY = if (isDragged) offset else 0f }
                            .background(if (isDragged) Color.White.copy(alpha = 0.16f) else Color.Transparent)
                            .padding(horizontal = 14.dp),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        ChildAvatar(c, 40.dp)
                        Text(c.name, Modifier.weight(1f), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp)
                        Box(
                            Modifier.size(44.dp).pointerInput(c.id) {
                                detectDragGestures(
                                    onDragStart = { dragging = c.id; offset = 0f },
                                    onDragEnd = { dragging = null; offset = 0f },
                                    onDragCancel = { dragging = null; offset = 0f },
                                ) { change, amount ->
                                    change.consume()
                                    offset += amount.y
                                    val idx = working.indexOfFirst { it.id == c.id }
                                    // Past half a row → swap with the neighbour and re-base the offset.
                                    if (offset > rowPx / 2 && idx < working.lastIndex) {
                                        working = working.toMutableList().also { it.add(idx + 1, it.removeAt(idx)) }; offset -= rowPx
                                    } else if (offset < -rowPx / 2 && idx > 0) {
                                        working = working.toMutableList().also { it.add(idx - 1, it.removeAt(idx)) }; offset += rowPx
                                    }
                                }
                            },
                            contentAlignment = Alignment.Center,
                        ) { Text("≡", color = Ink.secondary, fontSize = 24.sp) }
                    }
                }
                if (i < working.lastIndex) RowDivider()
            }
        }
        P(tr("גררו את הידיות כדי לקבוע את הסדר בלוח. הסדר נשמר לכל ההורים במשפחה."), 12.5f, Modifier.padding(14.dp), color = Ink.tertiary)
    }
}

// MARK: - Change parent code (ParentSettingsView.ChangePINView)

/**
 * The family code is shared (households.parentPinHash, the salted blob every
 * child device verifies), so the current one is asked first — the Android
 * settings screen has no gate in front of it the way iOS's does.
 */
@Composable
fun ChangePinSheet(currentBlob: String?, onDismiss: () -> Unit) {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var old by remember { mutableStateOf("") }
    var new by remember { mutableStateOf("") }
    var confirm by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var saving by remember { mutableStateOf(false) }
    val needsOld = currentBlob != null

    fun save() {
        if (needsOld && !ChildRepository.verifyPin(currentBlob, old)) { error = tr("הקוד הנוכחי לא נכון"); return }
        if (new.length != 4 || !new.all { it.isDigit() }) { error = tr("הקוד חייב להיות בדיוק 4 ספרות"); return }
        if (new != confirm) { error = tr("הקודים לא תואמים"); return }
        saving = true; error = null
        scope.launch {
            val ok = SettingsRepository.householdWrite { ChildRepository.setHouseholdPIN(new) }
            saving = false
            if (ok) { LocalParentPin.store(ctx, ChildRepository.pinBlob(new)); onDismiss() }
            else error = tr("משהו חסם את השליחה. נסו שוב עוד רגע.")
        }
    }

    Sheet(onDismiss) {
        SheetBar(tr("שינוי קוד הורה"), cancel = tr("ביטול"), onCancel = onDismiss)
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (needsOld) {
                P(tr("קוד נוכחי"), 13f, color = Ink.tertiary, weight = FontWeight.Bold)
                PinField(old, tr("4 ספרות")) { old = it; error = null }
            }
            P(tr("קוד חדש"), 13f, color = Ink.tertiary, weight = FontWeight.Bold)
            PinField(new, tr("4 ספרות")) { new = it; error = null }
            PinField(confirm, tr("אמת קוד")) { confirm = it; error = null }
            error?.let { P(it, 13.5f, color = Ink.weak, weight = FontWeight.Bold) }
            GoldButton(tr("שמור"), Modifier.padding(top = 6.dp), enabled = new.length == 4 && confirm.length == 4 && (!needsOld || old.length == 4), busy = saving) { save() }
        }
    }
}

@Composable
private fun PinField(value: String, label: String, onChange: (String) -> Unit) {
    OutlinedTextField(
        value, { onChange(it.filter { c -> c.isDigit() }.take(4)) }, Modifier.fillMaxWidth(), singleLine = true,
        placeholder = { Text(label, fontFamily = Rounded) },
        visualTransformation = PasswordVisualTransformation(),
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
        colors = glassFieldColors(), shape = RoundedCornerShape(12.dp),
    )
}

// MARK: - Feedback (ParentFeedbackView.swift)

@Composable
fun FeedbackSheet(onDismiss: () -> Unit) {
    var text by remember { mutableStateOf("") }
    var sent by remember { mutableStateOf(false) }
    val canSend = text.trim().length >= 3
    Sheet(onDismiss) {
        SheetBar(tr("פידבק"), cancel = tr("סגור"), onCancel = onDismiss)
        if (sent) {
            Column(Modifier.fillMaxWidth().padding(vertical = 30.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("🙏", fontSize = 60.sp)
                H(tr("תודה רבה!"), 22, align = TextAlign.Center)
                P(tr("קיבלנו את הפידבק שלכם — זה מאוד עוזר לנו."), 15f, Modifier.padding(horizontal = 24.dp), align = TextAlign.Center)
                GoldButton(tr("סגור"), Modifier.padding(top = 10.dp), onClick = onDismiss)
            }
        } else {
            Column(Modifier.fillMaxWidth().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                P(tr("נשמח לשמוע מה דעתכם — מה לשפר, מה חסר, או כל רעיון שיש לכם. כל מילה עוזרת לנו לשפר את טופי לילדים."), 13f)
                P(tr("ההודעה שלכם"), 13f, color = Ink.tertiary, weight = FontWeight.Bold)
                OutlinedTextField(
                    text, { text = it }, Modifier.fillMaxWidth().heightIn(min = 140.dp),
                    placeholder = { Text(tr("כתבו כאן…"), fontFamily = Rounded) },
                    colors = glassFieldColors(), shape = RoundedCornerShape(14.dp),
                )
                GoldButton("✈️  " + tr("שלח לנו"), enabled = canSend) {
                    SettingsRepository.submitFeedback(text.trim())
                    sent = true
                }
            }
        }
    }
}

// MARK: - What's new

/** ✨ What this Android version brought — the same list a parent sees on iOS
 *  (WhatsNewView), opened from the settings and once by itself after an
 *  update (see [WhatsNewOnce]). Parent-facing: no niqqud. */
object WhatsNewAndroid {
    data class Item(val emoji: String, val title: String, val line: String)
    val items: List<Item> get() = listOf(
        Item("📍", tr("לדעת איפה הילדים"), tr("מפה עם הילדים, התראה כשמגיעים לבית הספר או הביתה, וצפצוף לטלפון שהלך לאיבוד. רק אם תפעילו, ורק ההורים רואים")),
        Item("🏠", tr("איפה הילדים, במבט אחד"), tr("בכרטיס של כל ילד כתוב עכשיו בבית, בבית הספר או אצל סבתא, עם הסמל של המקום")),
        Item("🏫", tr("זמן בית ספר ושעת שינה"), tr("בהגדרות של כל ילד בוחרים ימים ושעות שבהם אי אפשר לפתוח דקות משחק. משחק פתוח נעצר, והדקות שנשארו חוזרות לארנק")),
        Item("🔐", tr("כספת חדשה, פשוטה יותר"), tr("במשחק הכספת כל תשובה נכונה מסובבת גלגל, ובשלושה גלגלים הכספת נפתחת")),
    )
}

@Composable
fun WhatsNewSheet(onDismiss: () -> Unit) {
    Sheet(onDismiss) {
        SheetBar(tr("מה חדש בטופי ✨"), cancel = tr("סיום"), onCancel = onDismiss)
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            WhatsNewAndroid.items.forEach { item ->
                Row(Modifier.fillMaxWidth().glassPane(20.dp).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    EmojiTile(item.emoji, 44.dp)
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(item.title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp)
                        P(item.line, 13.5f)
                    }
                }
            }
        }
        P(SettingsRepository.versionLine, 13f, Modifier.fillMaxWidth().padding(top = 14.dp), color = Ink.tertiary, align = TextAlign.Center)
    }
}

/** Shows [WhatsNewSheet] once after an update — never on a fresh install (that
 *  parent has onboarding and the tour), never twice for the same build. */
object WhatsNewOnce {
    private const val KEY = "whatsNew.seenCode"
    fun shouldShow(ctx: Context): Boolean {
        val prefs = ctx.getSharedPreferences("tofy", Context.MODE_PRIVATE)
        val current = com.rani.tofy.BuildConfig.VERSION_CODE
        val seen = prefs.getInt(KEY, -1)
        if (seen >= current) return false
        prefs.edit().putInt(KEY, current).apply()
        // First run with this key: an existing family updating shows it; a
        // brand-new install (tour not done yet) just records the build.
        return seen != -1 || com.rani.tofy.ui.common.CoachTours.isDone(com.rani.tofy.ui.common.CoachTours.PARENT_HOME)
    }
}

/** Opens a web page in the browser (privacy, terms, support). */
fun openUrl(ctx: Context, url: String) {
    runCatching { ctx.startActivity(android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))) }
}


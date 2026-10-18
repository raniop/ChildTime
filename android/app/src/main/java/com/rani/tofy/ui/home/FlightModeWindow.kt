package com.rani.tofy.ui.home

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.rani.tofy.data.Child
import com.rani.tofy.data.Commands
import com.rani.tofy.data.FamilyRepository
import com.rani.tofy.data.FlightMode
import com.rani.tofy.data.QuietHours
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.util.Locale

/**
 * ✈️ The parent's side of `FlightMode` (iOS FlightModeSheet): pick the day
 * you're back, get a code, send it to the child (or to whoever stays with
 * them). One window — the date, the code, and the three things to do with it.
 * The status line under it comes from the write's own outcome.
 */
@Composable
fun FlightModeWindow(childID: String, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        FlightModeContent(childID, onDismiss)
    }
}

/** A week from now, at eight in the evening. */
private fun defaultReturn(): ZonedDateTime =
    ZonedDateTime.now().plusDays(7).withHour(20).withMinute(0).withSecond(0).withNano(0)

private fun ZonedDateTime.unix(): Double = toEpochSecond().toDouble()
private fun zoned(unix: Double): ZonedDateTime = Instant.ofEpochSecond(unix.toLong()).atZone(ZoneId.systemDefault())

/** "יום שישי 23.10 · 20:00" in the app's language (FlightModeSheet.dateLine). */
internal fun flightDateLine(unix: Double): String {
    val locale = Locale.forLanguageTag(I18n.language.code)
    val day = android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEEdM")
    val time = "HH:mm"   // 24-hour, two digits, like every clock in Tofy
    val t = zoned(unix)
    return java.time.format.DateTimeFormatter.ofPattern(day, locale).format(t) + " · " +
        java.time.format.DateTimeFormatter.ofPattern(time, locale).format(t)
}

/** "✅ נשמר…" / "⏳ אין כרגע אינטרנט…" / "⚠️ לא נשמר…" — what the write actually did. */
private fun statusLine(out: WriteOutcome, name: String): String = when (out) {
    WriteOutcome.OK -> tr("✅ נשמר. הקוד יגיע למכשיר של %@.", name)
    WriteOutcome.QUEUED -> tr("⏳ אין כרגע אינטרנט. יישלח ברגע שיחזור.")
    WriteOutcome.DENIED, WriteOutcome.ERROR -> tr("⚠️ לא נשמר. נסו שוב.")
}

@Composable
internal fun FlightModeContent(childID: String, onClose: () -> Unit) {
    val state by FamilyRepository.state.collectAsState()
    val child = state.children.firstOrNull { it.id == childID } ?: return
    val name = stripNiqqud(child.name)
    val girl = child.isGirl
    // The live copy — it changes under us when the save lands.
    val mode = child.flightMode?.takeIf { it.isActive() }
    val scope = rememberCoroutineScope()
    val ctx = LocalContext.current
    var backAt by remember { mutableStateOf(mode?.let { zoned(it.until) } ?: defaultReturn()) }
    var editingDate by remember { mutableStateOf(false) }
    var saving by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf<String?>(null) }

    fun save(keepCode: String?) {
        val m = FlightMode(keepCode ?: FlightMode.newCode(), backAt.unix(), nowSecs())
        saving = true
        scope.launch {
            val out = Commands.setFlightMode(child.id, m)
            saving = false; editingDate = false
            status = statusLine(out, name)
        }
    }
    fun end() {
        saving = true
        scope.launch {
            val out = Commands.setFlightMode(child.id, null)
            saving = false
            status = if (out == WriteOutcome.OK || out == WriteOutcome.QUEUED) tr("מצב טיסה הסתיים. הקוד כבר לא עובד.") else statusLine(out, name)
        }
    }

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 460.dp).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(16.dp)) {
                Header(name, girl, onClose)
                if (mode != null && !editingDate) {
                    CodeCard(mode, name)
                    // Send: the share sheet, with the code and the day it stops.
                    GoldButton(tr("שליחת הקוד"), Modifier.height(52.dp), enabled = !saving) {
                        val text = tr("✈️ הקוד של %@ בטופי: %@\nפותח את המכשיר עד %@.", name, mode.code, flightDateLine(mode.until))
                        ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text), null))
                    }
                    PlainButton(tr("שינוי תאריך החזרה"), enabled = !saving) { backAt = zoned(mode.until); editingDate = true }
                    PlainButton(tr("קוד חדש"), enabled = !saving) { backAt = zoned(mode.until); save(keepCode = null) }
                    PlainButton(tr("סיום מצב טיסה"), destructive = true, enabled = !saving) { end() }
                } else {
                    DatePane(backAt) { backAt = it }
                    GoldButton(if (mode == null) tr("יצירת קוד") else tr("שמירת התאריך"), Modifier.height(52.dp), busy = saving) { save(keepCode = mode?.code) }
                    if (mode != null) PlainButton(tr("ביטול"), enabled = !saving) { editingDate = false }
                }
                status?.let {
                    Text(it, Modifier.fillMaxWidth(), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold,
                        fontSize = 14.sp, textAlign = TextAlign.Center, lineHeight = 20.sp)
                }
            }
        }
    }
}

@Composable
private fun Header(name: String, girl: Boolean, onClose: () -> Unit) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("✈️", fontSize = 34.sp)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(tr("מצב טיסה"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 22.sp)
            Text(
                if (girl) tr("טסים? %@ תקבל קוד שפותח את המכשיר שלה לבד, לכמה זמן שתבחר, עד שתחזרו. גם בלי אינטרנט. שעת השינה ממשיכה לעבוד.", name)
                else tr("טסים? %@ יקבל קוד שפותח את המכשיר שלו לבד, לכמה זמן שיבחר, עד שתחזרו. גם בלי אינטרנט. שעת השינה ממשיכה לעבוד.", name),
                color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 14.sp, lineHeight = 20.sp,
            )
        }
        val closeLabel = tr("סגירה")
        Box(
            Modifier.size(36.dp).semantics { contentDescription = closeLabel }.clip(CircleShape).background(Color.White.copy(alpha = 0.2f))
                .border(1.dp, Color.White.copy(alpha = 0.3f), CircleShape).clickable(onClick = onClose),
            contentAlignment = Alignment.Center,
        ) { Text("✕", color = Ink.primary, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
    }
}

/** "חוזרים ב־" — the day (a calendar) and the hour (15-minute steps). Never sooner than an hour from now. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DatePane(backAt: ZonedDateTime, onChange: (ZonedDateTime) -> Unit) {
    var picking by remember { mutableStateOf(false) }
    val earliest = ZonedDateTime.now().plusHours(1)
    fun set(t: ZonedDateTime) = onChange(if (t.isBefore(earliest)) earliest.withSecond(0).withNano(0) else t)
    val shape = RoundedCornerShape(16.dp)
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(tr("חוזרים ב־"), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val locale = Locale.forLanguageTag(I18n.language.code)
            val dayPattern = android.text.format.DateFormat.getBestDateTimePattern(locale, "EEEEdM")
            Box(
                Modifier.weight(1f).height(48.dp).clip(shape).background(Color.White.copy(alpha = 0.18f))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), shape).clickable { picking = true },
                contentAlignment = Alignment.Center,
            ) {
                Text(java.time.format.DateTimeFormatter.ofPattern(dayPattern, locale).format(backAt), color = Color.White, fontFamily = Rounded,
                    fontWeight = FontWeight.Bold, fontSize = 16.sp, maxLines = 1)
            }
            // The hour reads left to right, like every number.
            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Step("−") { set(backAt.minusMinutes(15)) }
                    Text(QuietHours.clock(backAt), Modifier.width(64.dp), color = Color.White, fontFamily = Rounded,
                        fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, textAlign = TextAlign.Center)
                    Step("+") { set(backAt.plusMinutes(15)) }
                }
            }
        }
        Text(tr("עד אז הקוד עובד. אחר כך הוא מפסיק לבד וטופי חוזר לחוקים הרגילים."),
            color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp, lineHeight = 18.sp)
    }
    if (picking) {
        // The Material picker works in UTC midnights; the hour is kept as it was.
        val today = LocalDate.now()
        val pickerState = rememberDatePickerState(
            initialSelectedDateMillis = backAt.toLocalDate().atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli(),
            selectableDates = object : SelectableDates {
                override fun isSelectableDate(utcTimeMillis: Long) =
                    !Instant.ofEpochMilli(utcTimeMillis).atZone(ZoneOffset.UTC).toLocalDate().isBefore(today)
            },
        )
        DatePickerDialog(
            onDismissRequest = { picking = false },
            confirmButton = {
                TextButton({
                    pickerState.selectedDateMillis?.let { ms ->
                        val d = Instant.ofEpochMilli(ms).atZone(ZoneOffset.UTC).toLocalDate()
                        set(backAt.with(d))
                    }
                    picking = false
                }) { Text(tr("סיום"), fontFamily = Rounded, fontWeight = FontWeight.Bold) }
            },
            dismissButton = { TextButton({ picking = false }) { Text(tr("ביטול"), fontFamily = Rounded) } },
            colors = DatePickerDefaults.colors(containerColor = Ink.sheet),
        ) {
            DatePicker(pickerState, title = null, headline = null, showModeToggle = false,
                colors = DatePickerDefaults.colors(containerColor = Ink.sheet))
        }
    }
}

@Composable
private fun Step(label: String, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(Modifier.size(40.dp).clip(shape).background(Color.White.copy(alpha = 0.18f)).border(1.dp, Color.White.copy(alpha = 0.3f), shape)
        .clickable(onClick = onClick), contentAlignment = Alignment.Center) {
        Text(label, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
    }
}

/** "הקוד של נוני" · the four digits, big and left to right · "עובד עד …". */
@Composable
private fun CodeCard(mode: FlightMode, name: String) {
    Column(Modifier.fillMaxWidth().glassPane(16.dp).padding(16.dp), horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(tr("הקוד של %@", name), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
        // Digits read left to right, like every number.
        CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                mode.code.forEach { d ->
                    Box(Modifier.size(56.dp, 68.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.18f)),
                        contentAlignment = Alignment.Center) {
                        Text(d.toString(), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 40.sp)
                    }
                }
            }
        }
        Text(tr("עובד עד %@", flightDateLine(mode.until)), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp, textAlign = TextAlign.Center)
    }
}

@Composable
private fun PlainButton(title: String, destructive: Boolean = false, enabled: Boolean = true, onClick: () -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Box(
        Modifier.fillMaxWidth().height(48.dp).clip(shape).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.25f), shape).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(title, color = if (destructive) Color(0xFFFFB4B4) else Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Bold,
            fontSize = 16.sp, maxLines = 1)
    }
}

/** The actions row's second line: "פעיל · הקוד 4821 עובד עד …" / "טסים? קוד שפותח לה את המכשיר…". */
internal fun flightSummary(child: Child): String {
    val m = child.flightMode?.takeIf { it.isActive() }
    if (m != null) return tr("פעיל · הקוד %@ עובד עד %@", m.code, flightDateLine(m.until))
    return if (child.isGirl) tr("טסים? קוד שפותח לה את המכשיר עד שתחזרו") else tr("טסים? קוד שפותח לו את המכשיר עד שתחזרו")
}

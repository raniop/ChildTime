package com.rani.tofy.ui.home

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.drag
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalHapticFeedback
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
import com.rani.tofy.data.CommandStatus
import com.rani.tofy.data.Commands
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.Progress
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.secs
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.roundToInt
import kotlin.math.sin

/** 🧪 Debug screenshots only: the window as it looks after a gift of this many minutes was sent. */
internal var demoGiftSent: Int? = null

/**
 * 💝 Gift minutes, from the child's card on the home screen — iOS
 * GiftMinutesSheet (Rani approved the mockup 2026-10-12: "הייתי מוסיף מתנה
 * לעמוד הראשי… ומשם פותח חלון יפה עם הסבר וכמה דקות במתנה כבר נתתי").
 * One window, top to bottom: what a gift is · what was already given · the
 * ring that sets the minutes · send.
 *
 * Sending opens nothing: the SAME screen stays, the send button gives its place
 * to one live status line (sending → saved → reached the device), and the ring
 * keeps showing what was sent ("פתרון יפה בתוך המסך ששולחים, ולא שייפתח מסך שלישי").
 */
@Composable
fun GiftMinutesWindow(child: Child, state: FamilyState, onDismiss: () -> Unit) {
    val close = { Commands.clearGiftStatus(); onDismiss() }
    Dialog(onDismissRequest = close, properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false)) {
        GiftMinutesContent(child, state, close)
    }
}

/** One full turn of the ring. More than that is a second gift. */
internal const val GIFT_RING_MINUTES = 120

private const val CLOUD_TIMEOUT = 8.0     // no backend commit by now → THIS phone has no internet
private const val DEVICE_TIMEOUT = 45.0   // no word from the device by now → it is not reachable right now

@Composable
internal fun GiftMinutesContent(child: Child, state: FamilyState, onClose: () -> Unit) {
    val name = stripNiqqud(child.name)
    val progress = state.progress[child.id] ?: Progress.EMPTY
    // What was given BEFORE this window opened: the live count grows by itself
    // once the device takes the gift, and adding what was just sent on top of
    // that would count the same minutes twice.
    val givenAtOpen = remember { progress.giftGivenToday }
    // The most one gift may hold right now: the minutes left until midnight.
    val ceiling = maxOf(5, minOf(GIFT_RING_MINUTES, Commands.minutesUntilMidnight() / 5 * 5))
    var minutes by remember { mutableIntStateOf(minOf(30, ceiling)) }
    /** The minutes that were sent — null until "שליחה" is pressed. */
    var sent by remember { mutableStateOf(demoGiftSent) }
    var nothingLeft by remember { mutableStateOf(false) }
    val status by Commands.giftStatus.collectAsState()
    // "נעל ואפס דקות מתנה" — the same action as under 🔒 on the child's actions,
    // offered here too: this is the window a parent opens to look at the gift
    // minutes, and where Rani went looking for it (2026-10-13).
    val revoke by Commands.revokeStatus.collectAsState()
    var confirmRevoke by remember { mutableStateOf(false) }
    val revoked = revoke?.takeIf { it.childID == child.id }
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    LaunchedEffect(sent, revoked != null) { if (sent != null || revoked != null) while (true) { delay(1000); now = nowSecs() } }
    LaunchedEffect(Unit) { demoGiftSent?.let { minutes = it } }

    // Confirmed first — this one IS a consequence (the same words as on the child's actions).
    if (confirmRevoke) androidx.compose.material3.AlertDialog(
        onDismissRequest = { confirmRevoke = false },
        title = { Text(tr("לנעול ולאפס את דקות המתנה של %@?", child.name), fontFamily = Rounded) },
        text = { Text(tr("המכשיר יינעל עכשיו, וכל הדקות שנתתם (💝 מתנה, ❄️ שמורות, וחלון פתוח של מתנה) יימחקו. הדקות ש%@ מלמידה לא נפגעות.",
            if (child.isGirl) tr("היא הרוויחה") else tr("הוא הרוויח")), fontFamily = Rounded) },
        confirmButton = { androidx.compose.material3.TextButton({ confirmRevoke = false; Commands.lock(child.id, revokeGift = true, inGiftWindow = true) }) {
            Text(tr("נעל ואפס"), color = Ink.weak) } },
        dismissButton = { androidx.compose.material3.TextButton({ confirmRevoke = false }) { Text(tr("בטל")) } },
        containerColor = Ink.sheet,
    )
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp).padding(top = 18.dp, bottom = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Column(Modifier.widthIn(max = 460.dp).fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                Text("💝", fontSize = 54.sp, modifier = Modifier.padding(top = 6.dp))
                Text(tr("מתנת דקות ל%@", name), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 24.sp, textAlign = TextAlign.Center)
                Text(
                    if (child.isGirl) tr("זמן מסך שאתם נותנים מהלב — בלי שאלות. %@ פותחת אותו מתי שהיא רוצה.", name)
                    else tr("זמן מסך שאתם נותנים מהלב — בלי שאלות. %@ פותח אותו מתי שהוא רוצה.", name),
                    color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 15.sp, lineHeight = 21.sp, textAlign = TextAlign.Center,
                )

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    GiftStat(givenAtOpen + (sent ?: 0), tr("נתתם היום"), Modifier.weight(1f))
                    GiftStat(progress.giftMinutes, tr("עוד לא נוצלו"), Modifier.weight(1f))   // "מחכות לנוני" was not clear (Rani)
                }
                if (sent == null) {
                    if (revoked != null) {
                        // The reset's own live status, where its button was — no second sheet.
                        val applied = (child.raw.secs("revokeGiftAppliedAt") ?: 0.0) >= revoked.stamp
                        when {
                            revoked.failed -> StatusPane("⚠️", tr("המחיקה לא נשלחה"), tr("משהו חסם את השליחה. נסו שוב עוד רגע."))
                            applied -> StatusPane("✅", tr("דקות המתנה נמחקו ✓"), tr("המכשיר של %@ אישר את המחיקה.", child.name))
                            now - revoked.stamp < DEVICE_TIMEOUT -> StatusPane(null, tr("מוחק דקות מתנה — ממתין לאישור…"), null)
                            else -> StatusPane("🕐", tr("מחיקת דקות המתנה ממתינה למכשיר"), tr("תתבצע ברגע שהמכשיר של %@ יתחבר.", child.name))
                        }
                    } else if (progress.giftMinutes > 0) {
                        val shape = RoundedCornerShape(16.dp)
                        Box(Modifier.fillMaxWidth().height(44.dp).clip(shape).background(Color.White.copy(alpha = 0.1f))
                            .border(1.dp, Color(0xFFFF8A8A).copy(alpha = 0.6f), shape).clickable { confirmRevoke = true }, contentAlignment = Alignment.Center) {
                            Text("🔒 " + tr("נעל ואפס דקות מתנה"), color = Color(0xFFFFD0D0), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp, maxLines = 1)
                        }
                    }
                }

                GiftRing(minutes, ceiling, locked = sent != null, Modifier.padding(vertical = 4.dp).size(250.dp)) { minutes = it }

                if (sent != null) {
                    // One line that tells the truth as it changes, where the button was.
                    GiftStatusLine(child, state, status?.takeIf { it.childID == child.id }, now)
                    Box(Modifier.fillMaxWidth().height(54.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.92f)).clickable(onClick = onClose),
                        contentAlignment = Alignment.Center) {
                        Text(tr("סיום"), color = Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp)
                    }
                } else {
                    GoldButton("💝 " + tr("שליחת %lld דקות", minutes), Modifier.height(58.dp)) {
                        val allowed = Commands.gift(child.id, minutes, inline = true) { null }
                        // 0 = the last minute before midnight: nothing is left to give today.
                        if (allowed > 0) { sent = allowed; minutes = allowed; now = nowSecs() } else nothingLeft = true
                    }
                    Text(
                        if (nothingLeft) tr("עוד רגע חצות — אין מה לתת להיום. מיד אחרי חצות אפשר לתת שוב.") else tr("דקות מתנה שלא נוצלו היום נשמרות למחר."),
                        color = if (nothingLeft) Ink.warn else Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.5.sp, textAlign = TextAlign.Center,
                    )
                }
            }
        }
        // ✕ in the corner (the physical one — not the reading side).
        val closeLabel = tr("סגירה")
        Box(Modifier.fillMaxSize().systemBarsPadding().padding(14.dp), contentAlignment = AbsoluteAlignment.TopLeft) {
            Box(
                Modifier.size(44.dp).semantics { contentDescription = closeLabel }.clip(CircleShape).clickable(onClick = onClose),
                contentAlignment = Alignment.Center,
            ) {
                Box(Modifier.size(36.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)).border(1.dp, Color.White.copy(alpha = 0.3f), CircleShape),
                    contentAlignment = Alignment.Center) { Text("✕", color = Ink.primary, fontSize = 15.sp, fontWeight = FontWeight.Bold) }
            }
        }
    }
}

@Composable
private fun GiftStat(value: Int, label: String, modifier: Modifier) {
    Column(modifier.glassPane(16.dp, 0.14f).padding(vertical = 10.dp, horizontal = 6.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(1.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("$value", Modifier.alignByBaseline(), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 26.sp)
            Text(tr("דק׳"), Modifier.alignByBaseline(), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
        com.rani.tofy.kid.ui.play.FitText(label, 12.5.sp, color = Ink.secondary, weight = FontWeight.SemiBold, maxLines = 1, minScale = 0.7f)
    }
}

/**
 * Where the gift is right now — the furthest hop that is KNOWN, never assumed
 * (the chain CommandStatusSheet shows, in one line).
 */
@Composable
private fun GiftStatusLine(child: Child, state: FamilyState, s: CommandStatus?, now: Double) {
    val devices = state.devicesOf(child.id)
    val elapsed = now - (s?.stamp ?: now)
    val applied = s != null && (child.raw.secs("giftAppliedAt") ?: 0.0) >= s.stamp
    when {
        s?.failed == true -> StatusPane("⚠️", tr("המתנה לא נשלחה"), tr("משהו חסם את השליחה. נסו שוב עוד רגע."))
        applied -> StatusPane("✅", tr("המתנה הגיעה למכשיר של %@ ✓", child.name), null)
        s?.reachedCloud == true -> when {
            devices.isEmpty() -> StatusPane("☁️", tr("המתנה נשלחה ונשמרה"), tr("המתנה תופיע ברגע שמכשיר יתחבר."))
            elapsed < DEVICE_TIMEOUT -> StatusPane(null, tr("המתנה נשלחה ונשמרה"), tr("ממתין למכשיר של %@…", child.name))
            else -> StatusPane("☁️", tr("המתנה נשלחה ונשמרה"), tr("המכשיר של %@ לא מחובר כרגע", child.name))
        }
        s != null && elapsed < CLOUD_TIMEOUT && !s.queued -> StatusPane(null, tr("שולח מתנה…"), null)
        else -> StatusPane("📶", tr("אין חיבור אינטרנט במכשיר שלך"), tr("המתנה שמורה ותישלח אוטומטית ברגע שיחזור החיבור — אין צורך ללחוץ שוב."))
    }
}

/** `icon` null = still in motion (a spinner). */
@Composable
private fun StatusPane(icon: String?, title: String, detail: String?) {
    Row(Modifier.fillMaxWidth().heightIn(min = 58.dp).glassPane(16.dp, 0.16f).padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Box(Modifier.width(30.dp), contentAlignment = Alignment.Center) {
            if (icon != null) Text(icon, fontSize = 22.sp) else CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.dp)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.5.sp)
            detail?.let { Text(it, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 13.sp, lineHeight = 18.sp) }
        }
    }
}

/**
 * The ring that sets the minutes: drag around it, five minutes a step, a tick
 * in the finger at each. A full turn is two hours — or less, late in the day,
 * when fewer minutes are left until midnight. After sending it shows what was
 * sent and no longer turns.
 */
@Composable
private fun GiftRing(minutes: Int, ceiling: Int, locked: Boolean, modifier: Modifier, onChange: (Int) -> Unit) {
    val haptic = LocalHapticFeedback.current
    val current by rememberUpdatedState(minutes)
    val set = { value: Int ->
        val clamped = value.coerceIn(5, ceiling)
        if (clamped != current) { onChange(clamped); haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove) }
    }
    val label = tr("מתנת דקות") + ", " + tr("%lld דקות", minutes)
    // The ring turns clockwise from the top in every language.
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Box(modifier.semantics { contentDescription = label }, contentAlignment = Alignment.Center) {
            Canvas(Modifier.fillMaxSize().pointerInput(ceiling, locked) {
                if (locked) return@pointerInput
                awaitEachGesture {
                    val centre = Offset(size.width / 2f, size.height / 2f)
                    val down = awaitFirstDown()
                    down.consume()
                    set(giftRingMinutes(down.position, centre, ceiling, current))
                    drag(down.id) { change -> change.consume(); set(giftRingMinutes(change.position, centre, ceiling, current)) }
                }
            }) {
                val line = 24.dp.toPx()
                val radius = (minOf(size.width, size.height) - line) / 2 - 8.dp.toPx()
                val fraction = minutes.toFloat() / GIFT_RING_MINUTES
                val box = Size(radius * 2, radius * 2); val origin = Offset(center.x - radius, center.y - radius)
                drawCircle(Color.White.copy(alpha = 0.18f), radius, center, style = Stroke(line))
                rotate(-90f) {
                    drawArc(Brush.sweepGradient(listOf(Color(0xFFFFE07A), Color(0xFFFF9F5A), Color(0xFFFF5F9A), Color(0xFFFFE07A)), center),
                        startAngle = 0f, sweepAngle = maxOf(1.5f, fraction * 360f), useCenter = false, topLeft = origin, size = box,
                        style = Stroke(line, cap = StrokeCap.Round))
                }
                if (!locked) {
                    val a = Math.toRadians(fraction * 360.0 - 90.0)
                    val knob = Offset(center.x + radius * cos(a).toFloat(), center.y + radius * sin(a).toFloat())
                    drawCircle(Color.Black.copy(alpha = 0.22f), (line + 12.dp.toPx()) / 2 + 2.dp.toPx(), knob + Offset(0f, 3.dp.toPx()))
                    drawCircle(Color.White, (line + 12.dp.toPx()) / 2, knob)
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (locked) tr("נשלחו") else tr("מסובבים באצבע"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 12.5.sp)
                Text("$minutes", color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 68.sp, lineHeight = 72.sp)
                Text(tr("דקות"), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp)
            }
        }
    }
}

/**
 * The minutes under a finger: clockwise from the top, in steps of five, between
 * 5 and the ceiling. Crossing the top does not jump from a full ring to an
 * empty one (or back) — the ring stops at its end. (GiftRing.minutes(at:) on iOS.)
 */
internal fun giftRingMinutes(point: Offset, centre: Offset, ceiling: Int, current: Int, ring: Int = GIFT_RING_MINUTES): Int {
    var degrees = Math.toDegrees(atan2((point.y - centre.y).toDouble(), (point.x - centre.x).toDouble())) + 90
    if (degrees < 0) degrees += 360
    var value = (degrees / 360 * ring / 5).roundToInt() * 5
    val quarter = ring / 4
    if (current >= ring - quarter && value <= quarter) value = ring          // past the top going forward
    else if (current <= quarter && value >= ring - quarter) value = 5        // past the top going back
    return value.coerceIn(5, ceiling)
}

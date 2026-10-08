package com.rani.tofy.ui.home

import android.icu.text.RelativeDateTimeFormatter
import android.icu.util.ULocale
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.CommandStatus
import com.rani.tofy.data.FamilyState
import com.rani.tofy.data.nowSecs
import com.rani.tofy.data.secs
import com.rani.tofy.i18n.I18n
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*
import kotlinx.coroutines.delay

/**
 * RemoteCommandStatusView: the honest send → cloud → device chain. The device
 * ack comes from the live listeners (child doc `giftAppliedAt`, device rows
 * `remoteLockAppliedAt`, child doc `revokeGiftAppliedAt`).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommandStatusSheet(s: CommandStatus, state: FamilyState, onDismiss: () -> Unit) {
    var now by remember { mutableDoubleStateOf(nowSecs()) }
    LaunchedEffect(s.stamp) { while (true) { delay(1000); now = nowSecs() } }
    val child = state.children.firstOrNull { it.id == s.childID } ?: return
    val name = child.name
    val devices = state.devices.filter { it.childID == s.childID && !it.removed && !it.isParentDevice }
    val elapsed = now - s.stamp
    val cloudTimeout = 8; val deviceTimeout = 45

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Ink.sheet) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(16.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            val title = when (s.kind) {
                CommandStatus.Kind.GIFT -> tr("💝 מתנה ל%@ — %@", name, if (s.minutes % 60 == 0) tr("%lld שעות", s.minutes / 60) else tr("%lld דקות", s.minutes))
                else -> tr("🔒 נעילה מרחוק — %@", name)
            }
            H(title, 20, align = TextAlign.Center)
            Column(Modifier.fillMaxWidth().glassInset(16.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                when (s.kind) {
                    CommandStatus.Kind.GIFT -> {
                        when {
                            s.failed -> Row("⚠️", tr("המתנה לא נשלחה"), tr("משהו חסם את השליחה. נסו שוב עוד רגע."))
                            s.reachedCloud -> Row("☁️", tr("המתנה נשלחה ונשמרה"), tr("גם אם המכשיר כבוי עכשיו — המתנה מחכה בענן."))
                            elapsed < cloudTimeout && !s.queued -> Spin(tr("שולח מתנה…"))
                            else -> Row("📶", tr("אין חיבור אינטרנט במכשיר שלך"), tr("המתנה שמורה ותישלח אוטומטית ברגע שיחזור החיבור — אין צורך ללחוץ שוב."))
                        }
                        val applied = (child.raw.secs("giftAppliedAt") ?: 0.0) >= s.stamp
                        when {
                            applied -> Row("🎁", tr("המתנה הגיעה למכשיר של %@ ✓", name), tr("ה-💝 כבר מופיע אצל%@.", if (child.isGirl) tr("ה") else tr("ו")))
                            devices.isEmpty() -> Row("📵", tr("אין כרגע מכשיר מחובר ל%@", name), tr("המתנה תופיע ברגע שמכשיר יתחבר."))
                            elapsed < deviceTimeout -> Spin(tr("ממתין למכשיר של %@…", name))
                            else -> Row("💤", tr("המכשיר של %@ לא מחובר כרגע", name), tr("נראה לאחרונה %@. המתנה תופיע ברגע שיתחבר — ואז תקבלו התראה.", lastSeen(devices.maxOfOrNull { it.lastSeenAt })))
                        }
                        s.note?.let { Row("ℹ️", it, null) }
                    }
                    else -> {
                        when {
                            s.reachedCloud -> Row("☁️", tr("הפקודה נשלחה"), null)
                            elapsed < cloudTimeout && !s.queued && !s.failed -> Spin(tr("שולח…"))
                            else -> Row("📶", tr("אין חיבור אינטרנט במכשיר שלך"), tr("הפקודה שמורה ותישלח אוטומטית ברגע שיחזור החיבור — אין צורך ללחוץ שוב."))
                        }
                        if (s.noDevice) Row("📵", tr("אין מכשיר מחובר ל%@", name), tr("הנעילה תחול ברגע שמכשיר יתחבר לילד."))
                        s.targets.forEach { id ->
                            val d = state.devices.firstOrNull { it.id == id }
                            val dn = d?.name ?: tr("מכשיר")
                            val acked = (d?.raw?.secs("remoteLockAppliedAt") ?: 0.0) >= s.stamp
                            when {
                                acked -> Row("🔒", tr("%@ — ננעל ✓", dn), tr("המכשיר אישר את הנעילה."))
                                elapsed < deviceTimeout -> Spin(tr("%@ — ממתין לאישור מהמכשיר…", dn))
                                else -> Row("💤", tr("%@ — לא מחובר כרגע", dn), tr("נראה לאחרונה %@. הנעילה שמורה ותחול ברגע שיתחבר — ואז תקבלו התראה.", lastSeen(d?.lastSeenAt)))
                            }
                        }
                        if (s.kind == CommandStatus.Kind.LOCK_AND_REVOKE) {
                            val applied = (child.raw.secs("revokeGiftAppliedAt") ?: 0.0) >= s.stamp
                            when {
                                s.failed -> Row("⚠️", tr("המחיקה לא נשלחה"), tr("משהו חסם את השליחה. נסו שוב עוד רגע."))
                                applied -> Row("🎁", tr("דקות המתנה נמחקו ✓"), tr("המכשיר של %@ אישר את המחיקה.", name))
                                elapsed < deviceTimeout -> Spin(tr("מוחק דקות מתנה — ממתין לאישור…"))
                                else -> Row("🎁", tr("מחיקת דקות המתנה ממתינה למכשיר"), tr("תתבצע ברגע שהמכשיר של %@ יתחבר.", name))
                            }
                        }
                    }
                }
            }
            P(if (s.kind == CommandStatus.Kind.GIFT)
                tr("אפשר לסגור — המתנה שמורה בענן, ו%@ אותה מכל מכשיר, מתי שירצו.", if (child.isGirl) tr("היא תפתח") else tr("הוא יפתח"))
              else tr("אפשר לסגור — אם האישור יגיע אחר כך, תקבלו התראה ברגע שהמכשיר יינעל."), 13f, align = TextAlign.Center)
            GoldButton(tr("הבנתי"), onClick = onDismiss)
        }
    }
}

@Composable
private fun Row(icon: String, title: String, detail: String?) {
    androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(icon, fontSize = 20.sp, modifier = Modifier.width(28.dp))
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
            detail?.let { P(it, 13f) }
        }
    }
}

@Composable
private fun Spin(title: String) {
    androidx.compose.foundation.layout.Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator(Modifier.size(18.dp), color = Ink.primary, strokeWidth = 2.dp) }
        Text(title, color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    }
}

/** RelativeDateTimeFormatter in the APP's language, like iOS. */
fun lastSeen(epoch: Double?): String {
    epoch ?: return tr("לא ידוע")
    val f = RelativeDateTimeFormatter.getInstance(ULocale(I18n.language.code))
    val d = nowSecs() - epoch
    return when {
        d < 60 -> f.format(RelativeDateTimeFormatter.Direction.PLAIN, RelativeDateTimeFormatter.AbsoluteUnit.NOW)
        d < 3600 -> f.format((d / 60).toInt().toDouble(), RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.RelativeUnit.MINUTES)
        d < 86400 -> f.format((d / 3600).toInt().toDouble(), RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.RelativeUnit.HOURS)
        else -> f.format((d / 86400).toInt().toDouble(), RelativeDateTimeFormatter.Direction.LAST, RelativeDateTimeFormatter.RelativeUnit.DAYS)
    }
}

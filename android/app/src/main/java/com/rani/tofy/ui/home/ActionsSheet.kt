package com.rani.tofy.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.Child
import com.rani.tofy.data.Commands
import com.rani.tofy.data.FamilyState
import com.rani.tofy.ui.child.resolvedCap
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*

/**
 * "⚡ פעולות" — what a parent does for ONE child, in one short window (Rani
 * approved the mockup 2026-10-08; iOS ChildActionsSheet). The two remote
 * controls and "where" up top as tiles, then the three places a parent goes
 * next. Editing is the ✏️ by the name, the device is on the card, deletion is
 * in the child's settings.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActionsSheet(child: Child, state: FamilyState, onDismiss: () -> Unit, onChores: () -> Unit, onConnect: () -> Unit, onSettings: () -> Unit,
    onScreenTime: () -> Unit = {},
                 onLocation: () -> Unit = {}) {
    var expanded by remember { mutableStateOf<String?>(null) }   // "gift" | "lock"
    var confirmRevoke by remember { mutableStateOf(false) }
    val hasDevice = state.hasDevice(child)
    val name = stripNiqqud(child.name)
    val girl = child.isGirl
    val earned = state.progress[child.id]?.minutesEarnedToday ?: 0
    val status = when {
        state.liveWindow(child) != null -> if (girl) tr("משחקת עכשיו") else tr("משחק עכשיו")
        hasDevice -> if (girl) tr("%lld דקות שהרוויחה היום", earned) else tr("%lld דקות שהרוויח היום", earned)
        else -> tr("אין עדיין מכשיר מחובר")
    }
    val (capOn, capMin) = child.resolvedCap()

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Ink.sheet) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ChildAvatar(child, 50.dp)
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    H(name, 21)
                    P(status, 13f)
                }
            }
            if (hasDevice) {
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Tile("💝", tr("מתנת דקות"), expanded == "gift", Modifier.weight(1f)) { expanded = if (expanded == "gift") null else "gift" }
                    Tile("🔒", tr("נעילה"), expanded == "lock", Modifier.weight(1f)) { expanded = if (expanded == "lock") null else "lock" }
                    Tile("📍", tr("איפה %@", name), false, Modifier.weight(1f), onClick = onLocation)
                }
                when (expanded) {
                    "gift" -> {
                        val options = listOf(15 to tr("רבע שעה"), 30 to tr("חצי שעה"), 60 to tr("שעה"), 120 to tr("שעתיים"), 240 to tr("4 שעות"))
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            options.chunked(3).forEach { row ->
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    row.forEach { (m, label) ->
                                        Chip(label, Modifier.weight(1f)) {
                                            Commands.gift(child.id, m) { wanted -> tr("ביקשתם %lld — זה המקסימום שנשאר להיום, עד חצות.", wanted) }
                                            onDismiss()
                                        }
                                    }
                                    repeat(3 - row.size) { Spacer(Modifier.weight(1f)) }
                                }
                            }
                        }
                    }
                    "lock" -> Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Chip(tr("נעל עכשיו"), Modifier.fillMaxWidth()) { Commands.lock(child.id); onDismiss() }
                        Chip(tr("נעל ואפס דקות מתנה"), Modifier.fillMaxWidth(), destructive = true) { confirmRevoke = true }
                    }
                }
            } else {
                WhiteButton(tr("+ חברו מכשיר ל%@", name), Modifier.fillMaxWidth(), onClick = onConnect)
            }
            Column(Modifier.fillMaxWidth().glassPane(20.dp, shadow = false)) {
                ActionRow("⏳", tr("זמן מסך יומי"), if (capOn) tr("עד %lld דקות ביום", capMin) else tr("בלי הגבלה יומית"), onClick = onScreenTime)
                ActionRow("🧹", tr("מטלות הבית"), tr("משימות ופרסים בבית"), onClick = onChores)
                ActionRow("⚙️", tr("כל ההגדרות של %@", name), tr("זמן, למידה, שפה ומכשיר"), last = true, onClick = onSettings)
            }
        }
    }
    if (confirmRevoke) {
        AlertDialog(
            onDismissRequest = { confirmRevoke = false },
            title = { Text(tr("לנעול ולאפס את דקות המתנה של %@?", child.name), fontFamily = Rounded) },
            text = { Text(tr("המכשיר יינעל עכשיו, וכל הדקות שנתתם (💝 מתנה, ❄️ שמורות, וחלון פתוח של מתנה) יימחקו. הדקות ש%@ מלמידה לא נפגעות.",
                if (child.isGirl) tr("היא הרוויחה") else tr("הוא הרוויח")), fontFamily = Rounded) },
            confirmButton = { TextButton({ confirmRevoke = false; Commands.lock(child.id, revokeGift = true); onDismiss() }) { Text(tr("נעל ואפס דקות מתנה"), color = Ink.weak) } },
            dismissButton = { TextButton({ confirmRevoke = false }) { Text(tr("בטל")) } },
            containerColor = Ink.sheet,
        )
    }
}

@Composable
private fun Tile(emoji: String, title: String, on: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier.fillMaxHeight().heightIn(min = 88.dp).clip(shape)
            .then(if (on) Modifier.background(Color.White.copy(alpha = 0.92f)) else Modifier.glassPane(18.dp, 0.18f, shadow = false))
            .clickable(onClick = onClick).padding(horizontal = 6.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
    ) {
        Text(emoji, fontSize = 28.sp)
        com.rani.tofy.kid.ui.play.FitText(title, 14.sp, color = if (on) Ink.indigo else Color.White, weight = FontWeight.ExtraBold, maxLines = 1, minScale = 0.7f)
    }
}

@Composable
private fun Chip(label: String, modifier: Modifier, destructive: Boolean = false, onClick: () -> Unit) {
    Box(modifier.height(44.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.92f)).clickable(onClick = onClick),
        contentAlignment = Alignment.Center) {
        Text(label, color = if (destructive) Color(0xFFC2334D) else Ink.indigo, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.5.sp, maxLines = 1)
    }
}

@Composable
private fun ActionRow(emoji: String, title: String, subtitle: String, last: Boolean = false, onClick: () -> Unit) {
    Column {
        Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 13.dp, horizontal = 14.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(emoji, fontSize = 22.sp, modifier = Modifier.width(32.dp))
            Column(Modifier.weight(1f)) {
                Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 16.sp, maxLines = 1)
                Text(subtitle, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.5.sp, maxLines = 1)
            }
            Text("‹", color = Ink.tertiary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
        }
        if (!last) HorizontalDivider(Modifier.padding(start = 58.dp), color = Color.White.copy(alpha = 0.15f))
    }
}

fun stripNiqqud(s: String) = s.replace(Regex("[֑-ׇ]"), "")

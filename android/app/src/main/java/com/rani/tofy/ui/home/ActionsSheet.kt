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
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.*
import com.rani.tofy.ui.theme.*

/** The ⚡ menu of a child card (ParentDashboardView's actions Menu), as an Android bottom sheet. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActionsSheet(child: Child, state: FamilyState, onDismiss: () -> Unit, onChores: () -> Unit, onConnect: () -> Unit, onSettings: () -> Unit) {
    var giftPicker by remember { mutableStateOf(false) }
    var confirmRevoke by remember { mutableStateOf(false) }
    val hasDevice = state.hasDevice(child)

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Ink.sheet) {
        Column(Modifier.padding(horizontal = 20.dp).padding(bottom = 28.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                ChildAvatar(child, 44.dp)
                H(child.name, 21)
            }
            Spacer(Modifier.height(12.dp))
            if (giftPicker) {
                GiftPicker(child) { minutes ->
                    Commands.gift(child.id, minutes) { wanted -> tr("ביקשתם %lld — זה המקסימום שנשאר להיום, עד חצות.", wanted) }
                    onDismiss()
                }
            } else {
                ActionRow("💝", tr("תֵּן דַּקּוֹת מַתָּנָה 💝").removeSuffix(" 💝")) { giftPicker = true }
                if (hasDevice) {
                    ActionRow("🔒", tr("נְעַל עַכְשָׁיו")) { Commands.lock(child.id); onDismiss() }
                    ActionRow("↩️", tr("נְעַל וְאַפֵּס דַּקּוֹת מַתָּנָה")) { confirmRevoke = true }
                }
                ActionRow("🧹", tr("מַטָּלוֹת"), onClick = onChores)
                ActionRow("📱", tr("חַבְּרוּ מַכְשִׁיר לְ%@", child.name), onClick = onConnect)
                if (hasDevice) ActionRow("🗑️", tr("אַפְשֵׁר מְחִיקַת אַפְּלִיקַצְיוֹת (5 דַּק')")) { Commands.allowAppRemoval(child.id); onDismiss() }
                ActionRow("✏️", tr("עריכת %@", stripNiqqud(child.name)), last = true, onClick = onSettings)
            }
        }
    }
    if (confirmRevoke) {
        AlertDialog(
            onDismissRequest = { confirmRevoke = false },
            title = { Text(tr("לִנְעֹל וּלְאַפֵּס אֶת דַּקּוֹת הַמַּתָּנָה שֶׁל %@?", child.name), fontFamily = Rounded) },
            text = { Text(tr("הַמַּכְשִׁיר יִנָּעֵל עַכְשָׁיו, וְכָל הַדַּקּוֹת שֶׁנְּתַתֶּם (💝 מַתָּנָה, ❄️ שְׁמוּרוֹת, וְחַלּוֹן פָּתוּחַ שֶׁל מַתָּנָה) יִמָּחֲקוּ. הַדַּקּוֹת שֶׁ%@ מִלְּמִידָה לֹא נִפְגָּעוֹת.",
                if (child.isGirl) tr("הִיא הִרְוִיחָה") else tr("הוּא הִרְוִיחַ")), fontFamily = Rounded) },
            confirmButton = { TextButton({ confirmRevoke = false; Commands.lock(child.id, revokeGift = true); onDismiss() }) { Text(tr("נְעַל וְאַפֵּס דַּקּוֹת מַתָּנָה"), color = Ink.weak) } },
            dismissButton = { TextButton({ confirmRevoke = false }) { Text(tr("בטל")) } },
            containerColor = Ink.sheet,
        )
    }
}

@Composable
private fun ActionRow(emoji: String, title: String, last: Boolean = false, onClick: () -> Unit) {
    Column {
        Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable(onClick = onClick).padding(vertical = 14.dp, horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Text(emoji, fontSize = 22.sp, modifier = Modifier.width(30.dp))
            Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
        }
        if (!last) HorizontalDivider(color = Color.White.copy(alpha = 0.12f))
    }
}

/** The gift durations iOS offers, capped at what's left until midnight. */
@Composable
private fun GiftPicker(child: Child, onPick: (Int) -> Unit) {
    val options = listOf(15 to tr("רֶבַע שָׁעָה"), 30 to tr("חֲצִי שָׁעָה"), 60 to tr("שָׁעָה"), 120 to tr("שְׁעָתַיִם"), 240 to tr("4 שָׁעוֹת"))
    val left = Commands.minutesUntilMidnight()
    var chosen by remember { mutableIntStateOf(30) }
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        H(tr("מַתְּנַת דַּקּוֹת"), 19)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            options.forEach { (m, label) ->
                val on = m == chosen
                Box(Modifier.clip(RoundedCornerShape(20.dp)).background(if (on) Ink.gold2 else Color.White.copy(alpha = 0.16f))
                    .clickable { chosen = m }.padding(horizontal = 16.dp, vertical = 10.dp)) {
                    Text(label, color = if (on) Ink.deep else Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold)
                }
            }
        }
        if (chosen > left) P(tr("ביקשתם %lld — זה המקסימום שנשאר להיום, עד חצות.", chosen), 13f, color = Ink.warn)
        GoldButton(tr("תֵּן דַּקּוֹת מַתָּנָה 💝"), enabled = left > 0) { onPick(chosen) }
    }
}

fun stripNiqqud(s: String) = s.replace(Regex("[֑-ׇ]"), "")

package com.rani.tofy.ui.child

import android.annotation.SuppressLint
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.R
import com.rani.tofy.data.WriteOutcome
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.delay

/** The top of a pushed page: back chevron at the start, a title, optional trailing content. */
@Composable
internal fun PageBar(title: String, onBack: () -> Unit, trailing: @Composable RowScope.() -> Unit = {}) {
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Row(Modifier.fillMaxWidth().padding(top = 4.dp, bottom = 4.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        Box(Modifier.size(42.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).clickable(onClick = onBack), contentAlignment = Alignment.Center) {
            Text(if (rtl) "›" else "‹", color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold, modifier = Modifier.offset(y = (-2).dp))
        }
        Text(title, Modifier.weight(1f), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp, maxLines = 1)
        trailing()
    }
}

/** ChildReportView.card: a titled glass pane. */
@Composable
internal fun ReportCard(title: String, modifier: Modifier = Modifier, detail: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(modifier.fillMaxWidth().glassPane(22.dp).padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(title, Modifier.weight(1f), color = Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp)
            detail?.let { Text(it, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.sp) }
        }
        content()
    }
}

@Composable
internal fun EmptyLine(text: String) = P(text, 13f, Modifier.fillMaxWidth())

/** A settings section: header text over one glass pane of rows (Form + .glassRows()). */
@Composable
internal fun SettingsSection(header: String?, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        header?.let { Text(it, Modifier.padding(horizontal = 8.dp), color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 13.sp) }
        Column(Modifier.fillMaxWidth().glassPane(18.dp).padding(horizontal = 14.dp, vertical = 4.dp)) { content() }
        footer?.let { P(it, 12.5f, Modifier.padding(horizontal = 8.dp)) }
    }
}

/** ChildSettingsView.row: emoji, title, optional value line, chevron. */
@Composable
internal fun SettingsRow(
    emoji: String, title: String, value: String? = null, valueColor: Color = Ink.secondary,
    destructive: Boolean = false, chevron: Boolean = true, trailing: (@Composable () -> Unit)? = null, onClick: (() -> Unit)?,
) {
    val rtl = LocalLayoutDirection.current == LayoutDirection.Rtl
    Row(
        Modifier.fillMaxWidth().then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier).padding(vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(emoji, fontSize = 20.sp, modifier = Modifier.width(28.dp), textAlign = TextAlign.Center)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = if (destructive) Ink.weak else Ink.primary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 16.sp)
            value?.let { Text(it, color = valueColor, fontFamily = Rounded, fontWeight = FontWeight.Medium, fontSize = 12.5.sp, maxLines = 2) }
        }
        trailing?.invoke()
        if (chevron) Text(if (rtl) "‹" else "›", color = Ink.tertiary, fontSize = 20.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
internal fun RowDivider() = Box(Modifier.fillMaxWidth().height(1.dp).background(Color.White.copy(alpha = 0.16f)))

/** A confirmation (iOS .alert with a destructive button), on the sheet's indigo. */
@Composable
internal fun Confirm(title: String, message: String?, confirm: String, destructive: Boolean = true, cancel: String = tr("בטל"), onConfirm: () -> Unit, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Ink.sheet,
        title = { Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp) },
        text = message?.let { { Text(it, color = Ink.secondary, fontFamily = Rounded, fontSize = 14.5.sp) } },
        confirmButton = {
            TextButton({ onDismiss(); onConfirm() }) {
                Text(confirm, color = if (destructive) Ink.weak else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold)
            }
        },
        dismissButton = { TextButton(onDismiss) { Text(cancel, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold) } },
    )
}

/** An info alert with one "הבנתי". */
@Composable
internal fun Notice(title: String, message: String, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss, containerColor = Ink.sheet,
        title = { Text(title, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 18.sp) },
        text = { Text(message, color = Ink.secondary, fontFamily = Rounded, fontSize = 14.5.sp) },
        confirmButton = { TextButton(onDismiss) { Text(tr("הבנתי"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold) } },
    )
}

/**
 * Honest write feedback: a DENIED or ERROR outcome says the change did NOT
 * save (QUEUED is fine — the write is durable and delivers when online).
 */
class WriteNote {
    var text by mutableStateOf<String?>(null)
        private set
    private var serial by mutableIntStateOf(0)

    fun report(out: WriteOutcome) {
        when (out) {
            WriteOutcome.DENIED -> show(tr("השנוי לא נשמר — אין כרגע הרשאה למשפחה הזו. נסו שוב בעוד רגע."))
            WriteOutcome.ERROR -> show(tr("השנוי לא נשמר. בדקו את חבור האינטרנט ונסו שוב."))
            else -> {}
        }
    }

    fun show(t: String) { text = t; serial++ }

    @Composable
    fun Host(modifier: Modifier = Modifier) {
        val t = text ?: return
        LaunchedEffect(serial) { delay(5000); text = null }
        Box(modifier.fillMaxWidth().padding(16.dp).clip(RoundedCornerShape(16.dp)).background(Color(0xFF3A1F6E).copy(alpha = 0.96f))
            .border(1.dp, Ink.weak.copy(alpha = 0.6f), RoundedCornerShape(16.dp)).clickable { text = null }.padding(14.dp)) {
            Text("⚠️ $t", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 14.sp)
        }
    }
}

/** A friend card's character, round (CharacterView portrait). */
@SuppressLint("DiscouragedApi")
@Composable
internal fun CharacterBadge(id: String?, size: Dp) {
    val ctx = LocalContext.current
    val res = ctx.resources.getIdentifier("char_${id ?: "fox"}", "drawable", ctx.packageName).takeIf { it != 0 } ?: R.drawable.char_fox
    Image(painterResource(res), null, Modifier.size(size).clip(CircleShape).background(Color.White.copy(alpha = 0.2f)), contentScale = ContentScale.Crop)
}

/** A selectable glass tile (gender / age / grade / level pickers in ProfileEditorView). */
@Composable
internal fun ChoiceTile(selected: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier.glassPane(16.dp, if (selected) 0.30f else 0.12f)
            .border(if (selected) 2.5.dp else 1.dp, if (selected) Ink.good else Color.White.copy(alpha = 0.2f), shape)
            .clickable(onClick = onClick).padding(vertical = 10.dp, horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(3.dp), content = content,
    )
}

@Composable
internal fun FieldLabel(text: String) = Text(text, color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)

@Composable
internal fun Heading(text: String) = H(text, 20)

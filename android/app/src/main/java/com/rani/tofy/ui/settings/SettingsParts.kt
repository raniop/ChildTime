package com.rani.tofy.ui.settings

import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane

/**
 * The iOS settings Form, as glass: a small header, one glass pane holding the
 * rows (glassRows), and the grey footer line under it.
 */
@Composable
fun SettingsSection(header: String? = null, footer: String? = null, content: @Composable ColumnScope.() -> Unit) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(6.dp)) {
        header?.let { P(it, 13f, Modifier.padding(horizontal = 14.dp), color = Ink.tertiary, weight = FontWeight.Bold) }
        Column(Modifier.fillMaxWidth().glassPane(16.dp), content = content)
        footer?.let { P(it, 12.5f, Modifier.padding(horizontal = 14.dp), color = Ink.tertiary) }
    }
}

/** One tappable row: emoji tile, title + optional subtitle, chevron when it leads somewhere. */
@Composable
fun SettingsRow(
    emoji: String?,
    title: String,
    subtitle: String? = null,
    titleColor: Color = Ink.primary,
    chevron: Boolean = false,
    trailing: (@Composable () -> Unit)? = null,
    onClick: (() -> Unit)? = null,
) {
    Row(
        Modifier.fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        emoji?.let { EmojiTile(it) }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(title, color = titleColor, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 16.sp, lineHeight = 20.sp)
            subtitle?.let { P(it, 12.5f, color = Ink.secondary) }
        }
        trailing?.invoke()
        if (chevron) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, null, tint = Ink.tertiary)
    }
}

/** The 44-pt rounded emoji square of ParentSettingsView.menuRow. */
@Composable
fun EmojiTile(emoji: String, size: Dp = 40.dp) {
    Box(
        Modifier.size(size).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.22f))
            .border(1.dp, Color.White.copy(alpha = 0.32f), RoundedCornerShape(16.dp)),
        contentAlignment = Alignment.Center,
    ) { Text(emoji, fontSize = 20.sp) }
}

@Composable
fun RowDivider() = Box(Modifier.fillMaxWidth().padding(horizontal = 14.dp).height(1.dp).background(Color.White.copy(alpha = 0.14f)))

/** Back chevron at top-start + a centred title — the inline navigation bar. */
@Composable
fun SettingsTopBar(title: String, onBack: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp), contentAlignment = Alignment.Center) {
        Box(
            Modifier.align(Alignment.CenterStart).size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).clickable(onClick = onBack),
            contentAlignment = Alignment.Center,
        ) { Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White) }
        H(title, 19, Modifier.padding(horizontal = 56.dp), align = TextAlign.Center)
    }
}

/** QRCodeView.swift: ZXing BitMatrix → 1 px per module, drawn without filtering so the modules stay sharp. */
@Composable
fun QrImage(text: String, size: Dp) {
    val bmp = remember(text) {
        val hints = mapOf(EncodeHintType.MARGIN to 0, EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M, EncodeHintType.CHARACTER_SET to "UTF-8")
        val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0, hints)
        val px = IntArray(m.width * m.height) { i -> if (m.get(i % m.width, i / m.width)) android.graphics.Color.BLACK else android.graphics.Color.WHITE }
        Bitmap.createBitmap(px, m.width, m.height, Bitmap.Config.ARGB_8888).asImageBitmap()
    }
    Box(Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White).padding(10.dp)) {
        Image(bmp, null, Modifier.size(size), filterQuality = FilterQuality.None)
    }
}

/** CoParentLinkingViews.StepsCard: gold numbered circles beside each step. */
@Composable
fun StepsCard(title: String, steps: List<String>) {
    Column(Modifier.fillMaxWidth().glassPane(16.dp, 0.10f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        P(title, 15f, color = Ink.gold2, weight = FontWeight.ExtraBold)
        steps.forEachIndexed { i, s ->
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
                Box(Modifier.size(26.dp).clip(CircleShape).background(Ink.gold1), contentAlignment = Alignment.Center) {
                    Text("${i + 1}", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
                }
                P(s, 15f, Modifier.weight(1f), color = Color.White, weight = FontWeight.SemiBold)
            }
        }
    }
}

@Composable
fun glassFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = Color.White, unfocusedTextColor = Color.White,
    focusedBorderColor = Color.White.copy(alpha = 0.8f), unfocusedBorderColor = Color.White.copy(alpha = 0.35f),
    focusedContainerColor = Color.White.copy(alpha = 0.10f), unfocusedContainerColor = Color.White.copy(alpha = 0.10f),
    cursorColor = Color.White, focusedLabelColor = Ink.secondary, unfocusedLabelColor = Ink.tertiary,
    focusedPlaceholderColor = Ink.tertiary, unfocusedPlaceholderColor = Ink.tertiary,
)

@Composable
fun VSpace(h: Dp) = Spacer(Modifier.height(h))

@Composable
fun HSpace(w: Dp) = Spacer(Modifier.width(w))

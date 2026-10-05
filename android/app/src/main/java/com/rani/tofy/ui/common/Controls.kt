package com.rani.tofy.ui.common

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.ui.theme.GoldBrush
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane

/** The gold capsule — the one primary action on a screen. */
@Composable
fun GoldButton(text: String, modifier: Modifier = Modifier, enabled: Boolean = true, busy: Boolean = false, onClick: () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(56.dp).clip(RoundedCornerShape(30.dp))
            .background(if (enabled) GoldBrush else androidx.compose.ui.graphics.SolidColor(Color.White.copy(alpha = 0.25f)))
            .clickable(enabled = enabled && !busy, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(24.dp), color = Ink.deep, strokeWidth = 3.dp)
        else Text(text, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 17.sp, color = Ink.deep)
    }
}

/** White pill with indigo ink — `.btn.primary` on the parent home. */
@Composable
fun WhiteButton(text: String, modifier: Modifier = Modifier, height: Dp = 46.dp, onClick: () -> Unit) {
    Box(
        modifier.height(height).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.92f)).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(text, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp, color = Ink.indigo, textAlign = TextAlign.Center, maxLines = 1) }
}

/** Glass pill — secondary actions. */
@Composable
fun GlassButton(text: String, modifier: Modifier = Modifier, height: Dp = 46.dp, radius: Dp = 14.dp, onClick: () -> Unit) {
    Box(
        modifier.height(height).glassPane(radius, 0.18f, shadow = false).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Text(text, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 14.5.sp, color = Color.White, textAlign = TextAlign.Center, maxLines = 1) }
}

@Composable
fun CircleIconButton(emoji: String, badge: Int = 0, onClick: () -> Unit) {
    Box {
        Box(Modifier.size(44.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f)).clickable(onClick = onClick), contentAlignment = Alignment.Center) {
            Text(emoji, fontSize = 19.sp)
        }
        if (badge > 0) Box(
            Modifier.align(Alignment.TopStart).clip(RoundedCornerShape(10.dp)).background(Color(0xFFFF4D5E)).padding(horizontal = 6.dp, vertical = 1.dp),
        ) { Text("$badge", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
    }
}

@Composable
fun H(text: String, size: Int = 22, modifier: Modifier = Modifier, color: Color = Ink.primary, align: TextAlign? = null) =
    Text(text, modifier, color = color, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = size.sp, textAlign = align, lineHeight = (size * 1.25).sp)

@Composable
fun P(text: String, size: Float = 14.5f, modifier: Modifier = Modifier, color: Color = Ink.secondary, weight: FontWeight = FontWeight.Medium, align: TextAlign? = null, maxLines: Int = Int.MAX_VALUE) =
    Text(text, modifier, color = color, fontFamily = Rounded, fontWeight = weight, fontSize = size.sp, textAlign = align, lineHeight = (size * 1.4).sp, maxLines = maxLines)

@Composable
fun RowSpaced(content: @Composable androidx.compose.foundation.layout.RowScope.() -> Unit) =
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically, content = content)

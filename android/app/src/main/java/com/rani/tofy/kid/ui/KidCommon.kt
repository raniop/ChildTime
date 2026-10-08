package com.rani.tofy.kid.ui

import android.annotation.SuppressLint
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.R
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane

/** WorldMapView.timeLabel: "16" when whole minutes, "16:45" with odd seconds — never quietly rounded. */
fun timeLabel(seconds: Int): String =
    if (seconds % 60 == 0) "${seconds / 60}" else "${seconds / 60}:" + "%02d".format(seconds % 60)

/** WorldMapView.clockLabel: always "m:ss". */
fun clockLabel(seconds: Int): String = "${seconds / 60}:" + "%02d".format(seconds % 60)

/** A 2D character PNG (R.drawable.char_<id>), falling back to the fox. */
@SuppressLint("DiscouragedApi")
@Composable
fun CharacterImage(id: String?, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Fit, alignment: Alignment = Alignment.Center) {
    val ctx = LocalContext.current
    val res = remember(id) {
        ctx.resources.getIdentifier("char_${id ?: "fox"}", "drawable", ctx.packageName).takeIf { it != 0 } ?: R.drawable.char_fox
    }
    Image(painterResource(res), null, modifier, alignment = alignment, contentScale = contentScale)
}

/** The "חֲזָרָה" capsule at the top start (ChildJoinView / RolePicker back). */
@Composable
fun BackCapsule(onClick: () -> Unit) {
    Row(
        Modifier.clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.14f))
            .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(Icons.AutoMirrored.Filled.ArrowBack, null, tint = Color.White, modifier = Modifier.size(16.dp))
        Text(tr("חֲזָרָה"), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold, fontSize = 15.sp)
    }
}

/** The round ✕ used by every kid cover. */
@Composable
fun CloseCircle(onClick: () -> Unit) {
    Box(
        Modifier.size(40.dp).clip(CircleShape).background(Color.White.copy(alpha = 0.22f))
            .border(1.dp, Color.White.copy(alpha = 0.32f), CircleShape).clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) { Icon(Icons.Filled.Close, null, tint = Color.White, modifier = Modifier.size(18.dp)) }
}

/** `.ctaGlass(a, b)` — the big coloured kid buttons (open time, stop, transfer). */
@Composable
fun KidCta(
    text: String, a: Color, b: Color, modifier: Modifier = Modifier, emoji: String? = null,
    busy: Boolean = false, enabled: Boolean = true, size: Int = 20, onClick: () -> Unit,
) {
    Row(
        modifier.fillMaxWidth().widthIn(max = 480.dp).clip(RoundedCornerShape(16.dp))
            .background(Brush.horizontalGradient(listOf(a, b)))
            .border(1.dp, Color.White.copy(alpha = 0.35f), RoundedCornerShape(16.dp))
            .clickable(enabled = enabled && !busy, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 15.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (busy) CircularProgressIndicator(Modifier.size(20.dp), color = Color.White, strokeWidth = 2.5.dp)
        else if (emoji != null) Text(emoji, fontSize = (size + 2).sp)
        Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = size.sp,
            maxLines = 2, textAlign = TextAlign.Center)
    }
}

/** WorldMapView.bottomHint — a pill so the CTA spot is never silently blank. */
@Composable
fun BottomHint(text: String) {
    Box(
        Modifier.fillMaxWidth().widthIn(max = 480.dp).clip(RoundedCornerShape(16.dp))
            .background(Ink.deep.copy(alpha = 0.55f)).glassPane(16.dp, 0.16f)
            .padding(horizontal = 18.dp, vertical = 12.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp,
            textAlign = TextAlign.Center, lineHeight = 19.sp)
    }
}

/**
 * The companion's speech (CompanionController.cheer/console): the fox with a
 * bubble. The iOS buddy is drawn with shapes; Android uses the fox PNG and a
 * gentle bob.
 */
@Composable
fun BuddyBubble(line: String?, modifier: Modifier = Modifier) {
    val t = rememberInfiniteTransition(label = "bob")
    val bob by t.animateFloat(0f, -6f, infiniteRepeatable(tween(1100), RepeatMode.Reverse), label = "bob")
    AnimatedVisibility(line != null, modifier, enter = fadeIn() + slideInVertically { it / 3 }, exit = fadeOut() + slideOutVertically { it / 3 }) {
        Row(verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            CharacterImage("fox", Modifier.size(58.dp).graphicsLayer { translationY = bob })
            Box(
                Modifier.padding(bottom = 22.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = 0.95f))
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            ) {
                Text(line ?: "", color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 15.sp, lineHeight = 20.sp)
            }
        }
    }
}

/**
 * A bottom card over a dimmed screen (RolePickerView.childCodeSheet style):
 * tap outside closes. Draws on top of whatever is behind it.
 */
@Composable
fun KidBottomCard(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Box(Modifier.fillMaxSize()) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.45f))
                .clickable(remember { MutableInteractionSource() }, null, onClick = onDismiss),
        )
        Column(
            Modifier.align(Alignment.BottomCenter).navigationBarsPadding().padding(12.dp).widthIn(max = 440.dp).fillMaxWidth()
                .clip(RoundedCornerShape(16.dp)).background(Ink.sheet.copy(alpha = 0.97f))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                .clickable(remember { MutableInteractionSource() }, null) {}
                .padding(horizontal = 16.dp, vertical = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(9.dp),
            content = content,
        )
    }
}

/** A centered card over a dim (the challenge / level explainers). */
@Composable
fun KidCenterCard(onDismiss: () -> Unit, content: @Composable ColumnScope.() -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Box(
            Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.5f))
                .clickable(remember { MutableInteractionSource() }, null, onClick = onDismiss),
        )
        Column(
            Modifier.padding(20.dp).widthIn(max = 440.dp).fillMaxWidth()
                .clip(RoundedCornerShape(16.dp)).background(Ink.sheet.copy(alpha = 0.97f))
                .border(1.dp, Color.White.copy(alpha = 0.3f), RoundedCornerShape(16.dp))
                .clickable(remember { MutableInteractionSource() }, null) {}
                .padding(22.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            content = content,
        )
    }
}

/** Big white title / soft body used on the kid screens. */
@Composable
fun KidTitle(text: String, size: Int = 26, modifier: Modifier = Modifier) =
    Text(text, modifier, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = size.sp,
        textAlign = TextAlign.Center, lineHeight = (size * 1.22).sp)

@Composable
fun KidBody(text: String, size: Float = 15f, modifier: Modifier = Modifier, alpha: Float = 0.88f, weight: FontWeight = FontWeight.SemiBold) =
    Text(text, modifier, color = Color.White.copy(alpha = alpha), fontFamily = Rounded, fontWeight = weight, fontSize = size.sp,
        textAlign = TextAlign.Center, lineHeight = (size * 1.4).sp)

/** A full-width glass pane column. */
@Composable
fun GlassColumn(modifier: Modifier = Modifier, radius: Dp = 22.dp, content: @Composable ColumnScope.() -> Unit) =
    Column(modifier.fillMaxWidth().glassPane(radius).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp), content = content)

@Composable
fun BoxScope.TopStart(content: @Composable () -> Unit) = Box(Modifier.align(Alignment.TopStart).padding(12.dp)) { content() }

@Composable
fun VSpace(h: Int) = Spacer(Modifier.height(h.dp))

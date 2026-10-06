package com.rani.tofy.kid.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane

/**
 * UnlockedView: the open play window — a warm "your time is on its way"
 * state while the claim runs, then the countdown (hours only from an hour up),
 * and the way out: stop-and-save (earned refunds to the wallet, gift time
 * freezes back into the 💝 pocket — nothing a parent gave is wasted).
 *
 * Android does not lock other apps yet, so the iOS line "you can switch to the
 * app you want to play now" is left out — nothing here implies enforcement.
 */
@Composable
internal fun UnlockedScreen(
    preparing: Boolean,
    gift: Boolean,
    secondsRemaining: Int,
    isGirl: Boolean,
    kidMode: Boolean,
    buddyLine: String?,
    onStop: () -> Unit,
    onKidExit: () -> Unit,
) {
    val t = rememberInfiniteTransition(label = "float")
    val bob by t.animateFloat(0f, -10f, infiniteRepeatable(tween(1400), RepeatMode.Reverse), label = "float")
    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(22.dp),
        ) {
            if (kidMode) Box(Modifier.padding(top = 10.dp)) {
                KidCta(tr("יְצִיאָה מִמַּצַּב יֶלֶד וְשִׁחְרוּר נְעִילַת הַמַּכְשִׁיר"), Color(0xFFEF4655), Color(0xFFEF4655), emoji = "🔓", size = 15, onClick = onKidExit)
            }
            Spacer(Modifier.weight(1f))
            // Gift time wears the gift heart, never the controller.
            Text(if (gift) "💝" else "🎮", fontSize = 96.sp, modifier = Modifier.graphicsLayer { translationY = bob * density })
            KidTitle(if (preparing) (if (isGirl) tr("הַזְּמַן שֶׁלָּךְ בַּדֶּרֶךְ!") else tr("הַזְּמַן שֶׁלְּךָ בַּדֶּרֶךְ!")) else tr("זְמַן מִשְׂחָק!"), 42)
            Column(
                Modifier.widthIn(max = 420.dp).fillMaxWidth().glassPane(28.dp).padding(22.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                if (preparing) {
                    KidBody(
                        if (gift) tr("מְשַׁחְרְרִים אֶת דַּקּוֹת הַמַּתָּנָה 💝")
                        else tr("מְשַׁחְרְרִים אֶת הַדַּקּוֹת שֶׁ%@ ✨", if (isGirl) tr("הִרְוַחַתְּ") else tr("הִרְוַחְתָּ")),
                        16f, alpha = 0.78f,
                    )
                    OpeningBar()
                } else {
                    KidBody(if (gift) tr("מַתָּנָה מֵאַבָּא וְאִמָּא 💝 · נוֹתְרוּ") else tr("נוֹתְרוּ"), 16f, alpha = 0.78f)
                    TimerRow(secondsRemaining)
                }
            }
            Spacer(Modifier.weight(1f))
            BuddyBubble(buddyLine, Modifier.fillMaxWidth())
            if (!preparing) Box(Modifier.padding(bottom = 36.dp)) {
                KidCta(if (gift) (if (isGirl) tr("עִצְרִי וְשִׁמְרִי אֶת הַזְּמַן 💝") else tr("עֲצֹר וּשְׁמֹר אֶת הַזְּמַן 💝")) else tr("סִיַּמְתִּי לְשַׂחֵק"), Color(0xFF5E60CE), Color(0xFF3E8BF0), onClick = onStop)
            } else Spacer(Modifier.height(36.dp))
        }
    }
}

/** Fills fast, then creeps — a slow network never looks stuck, a fast one still feels instant. */
@Composable
private fun OpeningBar() {
    val fill = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        fill.animateTo(0.72f, tween(1500, easing = LinearOutSlowInEasing))
        fill.animateTo(0.95f, tween(6000))
    }
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Box(Modifier.widthIn(max = 260.dp).fillMaxWidth().padding(vertical = 10.dp).height(14.dp).clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.22f))) {
            Box(Modifier.fillMaxWidth(fill.value.coerceAtLeast(0.05f)).height(14.dp).clip(RoundedCornerShape(50))
                .background(Brush.horizontalGradient(listOf(Ink.gold2, Ink.good))))
        }
    }
}

/** Labeled columns (שָׁעוֹת / דַּקּוֹת / שְׁנִיּוֹת), always read left-to-right like a clock. */
@Composable
private fun TimerRow(seconds: Int) {
    val showHours = seconds >= 3600
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Top) {
            if (showHours) { TimeColumn(seconds / 3600, tr("שָׁעוֹת")); Colon() }
            TimeColumn((seconds % 3600) / 60, tr("דַּקּוֹת"))
            Colon()
            TimeColumn(seconds % 60, tr("שְׁנִיּוֹת"))
        }
    }
}

@Composable
private fun TimeColumn(value: Int, label: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text("%02d".format(value), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 64.sp)
        Text(label, color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    }
}

@Composable
private fun Colon() = Text(":", color = Ink.secondary, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 64.sp)

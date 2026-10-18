package com.rani.tofy.kid.ui

import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rani.tofy.data.FlightChoice
import com.rani.tofy.data.FlightCodeGuard
import com.rani.tofy.data.FlightMode
import com.rani.tofy.data.QuietHours
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.delay
import java.time.ZonedDateTime
import kotlin.math.roundToInt

/** 🧪 Debug screenshots only: open straight on the "how long" step (iOS DEMO_FLIGHT_STEP=2). */
internal var demoFlightStep2 = false

/**
 * ✈️ The child's side of `FlightMode` (iOS FlightCodeSheet): type the code the
 * parents left, then pick how long to open. Checked on the device itself, so
 * it works with no internet. Five wrong tries → a minute's wait (never a
 * scolding). [onOpen] gets the chosen minutes — KidExperience opens the window.
 */
@Composable
internal fun FlightCodeScreen(mode: FlightMode, quietHours: QuietHours?, onOpen: (Int) -> Unit, onClose: () -> Unit) {
    BackHandler(onBack = onClose)
    var typed by remember { mutableStateOf("") }
    var unlocked by remember { mutableStateOf(demoFlightStep2) }
    var wrong by remember { mutableIntStateOf(0) }
    var hint by remember { mutableStateOf<String?>(null) }
    var wait by remember { mutableIntStateOf(FlightCodeGuard.waitSeconds()) }
    LaunchedEffect(Unit) { while (true) { delay(1000); wait = FlightCodeGuard.waitSeconds() } }
    val haptic = LocalHapticFeedback.current

    fun press(key: String) {
        haptic.performHapticFeedback(HapticFeedbackType.TextHandleMove)
        hint = null
        if (key == "⌫") { if (typed.isNotEmpty()) typed = typed.dropLast(1); return }
        if (typed.length >= 4) return
        typed += key
        if (typed.length < 4) return
        if (FlightCodeGuard.check(typed, mode)) {
            haptic.performHapticFeedback(HapticFeedbackType.LongPress)
            unlocked = true
        } else {
            wrong += 1
            hint = tr("הַקּוֹד לֹא נָכוֹן. נְנַסֶּה שׁוּב 🙂")
            typed = ""
            wait = FlightCodeGuard.waitSeconds()
        }
    }

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            Text("✈️", fontSize = 54.sp, modifier = Modifier.padding(top = 44.dp))
            if (unlocked) Durations(mode, quietHours, onOpen)
            else {
                KidTitle(tr("הַקְלִידוּ אֶת קוֹד הַטִּיסָה"), 24)
                CodeBoxes(typed, wrong)
                Text(
                    if (wait > 0) tr("חַכּוּ רֶגַע וּנְנַסֶּה שׁוּב ⏳ %lld", wait) else hint ?: " ",
                    Modifier.heightIn(min = 22.dp), color = Ink.gold2, fontFamily = Rounded, fontWeight = FontWeight.Bold,
                    fontSize = 16.sp, textAlign = TextAlign.Center,
                )
                Keypad(enabled = wait == 0, onKey = ::press)
            }
        }
        Box(Modifier.align(Alignment.TopStart).systemBarsPadding().padding(14.dp)) { CloseCircle(onClose) }
    }
}

/** Four boxes, left to right like every number; a wrong code gives them a little shake. */
@Composable
private fun CodeBoxes(typed: String, wrong: Int) {
    val shake = remember { Animatable(0f) }
    LaunchedEffect(wrong) {
        if (wrong == 0) return@LaunchedEffect
        for (x in listOf(-12f, 12f, -8f, 8f, -4f, 0f)) shake.animateTo(x, tween(50))
    }
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Row(Modifier.offset { IntOffset(shake.value.dp.roundToPx(), 0) }, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            repeat(4) { i ->
                val shape = RoundedCornerShape(16.dp)
                Box(
                    Modifier.size(58.dp, 68.dp).clip(shape).background(Color.White.copy(alpha = if (i < typed.length) 0.26f else 0.12f))
                        .border(1.dp, Color.White.copy(alpha = 0.35f), shape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(typed.getOrNull(i)?.toString() ?: "", color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 34.sp)
                }
            }
        }
    }
}

/** The 3×4 keypad — 16-radius keys, always left to right like a phone's. */
@Composable
private fun Keypad(enabled: Boolean, onKey: (String) -> Unit) {
    val rows = listOf(listOf("1", "2", "3"), listOf("4", "5", "6"), listOf("7", "8", "9"), listOf("", "0", "⌫"))
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Ltr) {
        Column(Modifier.alpha(if (enabled) 1f else 0.5f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            rows.forEach { row ->
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEach { key ->
                        if (key.isEmpty()) Box(Modifier.size(76.dp, 60.dp))
                        else {
                            val shape = RoundedCornerShape(16.dp)
                            Box(
                                Modifier.size(76.dp, 60.dp).clip(shape).background(Color.White.copy(alpha = 0.16f))
                                    .border(1.dp, Color.White.copy(alpha = 0.3f), shape).clickable(enabled = enabled) { onKey(key) },
                                contentAlignment = Alignment.Center,
                            ) {
                                Text(key, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 28.sp)
                            }
                        }
                    }
                }
            }
        }
    }
}

/** "לְכַמָּה זְמַן לִפְתֹּחַ?" — never past the parents' return; tonight's bedtime in gold. */
@Composable
private fun Durations(mode: FlightMode, quietHours: QuietHours?, onOpen: (Int) -> Unit) {
    val choices = remember(mode) { FlightMode.choices(mode, ZonedDateTime.now(), quietHours) }
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        KidTitle(tr("לְכַמָּה זְמַן לִפְתֹּחַ?"), 24)
        choices.forEach { c ->
            val shape = RoundedCornerShape(16.dp)
            Box(
                Modifier.widthIn(max = 340.dp).fillMaxWidth().height(58.dp).clip(shape)
                    .background(if (c.bedtime) Brush.verticalGradient(listOf(Ink.gold2, Ink.gold1)) else SolidColor(Color.White.copy(alpha = 0.16f)))
                    .border(1.dp, Color.White.copy(alpha = 0.3f), shape).clickable { onOpen(c.minutes) },
                contentAlignment = Alignment.Center,
            ) {
                Text(label(c), color = if (c.bedtime) Ink.deep else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 20.sp)
            }
        }
    }
}

private fun label(c: FlightChoice): String = when {
    c.bedtime -> tr("עַד שְׁעַת הַשֵּׁנָה 🌙")
    c.leftOnly -> tr("%lld דַּקּוֹת", c.minutes)
    else -> when (c.minutes) {
        15 -> tr("15 דַּקּוֹת")
        30 -> tr("חֲצִי שָׁעָה")
        60 -> tr("שָׁעָה")
        120 -> tr("שְׁעָתַיִם")
        else -> tr("שָׁלוֹשׁ שָׁעוֹת")
    }
}

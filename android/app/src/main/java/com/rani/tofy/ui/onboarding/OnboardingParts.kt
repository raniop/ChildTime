package com.rani.tofy.ui.onboarding

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import com.rani.tofy.data.Household
import com.rani.tofy.data.nowSecs
import com.rani.tofy.i18n.tr
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * OnboardingSteps.swift `ParentOnboarding`: the new-parent flow is ON from the
 * first child step until it ends (done or "later"). Local to this device, like
 * iOS's UserDefaults flag — so a relaunch mid-flow resumes it instead of
 * dropping the parent on an empty-looking home.
 */
object ParentOnboarding {
    private const val ACTIVE = "onboarding.v2.active"
    private const val CHILD = "onboarding.v2.childID"
    private val _active = MutableStateFlow<Boolean?>(null)

    private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences("tofy", Context.MODE_PRIVATE)

    /** Live flag; AppNav can keep AddChildFlow on screen while it is true. */
    fun active(ctx: Context): StateFlow<Boolean?> {
        if (_active.value == null) _active.value = prefs(ctx).getBoolean(ACTIVE, false)
        return _active
    }

    fun isActive(ctx: Context): Boolean = active(ctx).value == true

    fun begin(ctx: Context) {
        prefs(ctx).edit().putBoolean(ACTIVE, true).remove(CHILD).apply()
        _active.value = true
    }

    fun finish(ctx: Context) {
        prefs(ctx).edit().putBoolean(ACTIVE, false).remove(CHILD).apply()
        _active.value = false
    }

    /** The child this flow created — where a relaunch picks up. */
    fun childID(ctx: Context): String? = prefs(ctx).getString(CHILD, null)
    fun setChildID(ctx: Context, id: String) { prefs(ctx).edit().putString(CHILD, id).apply() }

    /** SetupChecklist.swift `SetupProgress.plan`: "own" once the parent said the child has a device. */
    fun plan(ctx: Context, childID: String): String? = prefs(ctx).getString("setup.device.$childID", null)
    fun setPlan(ctx: Context, childID: String, plan: String) { prefs(ctx).edit().putString("setup.device.$childID", plan).apply() }
}

/** For AppNav: `if (children.isEmpty() || rememberOnboardingActive()) AddChildFlow(true, …)`. */
@Composable
fun rememberOnboardingActive(): Boolean {
    val ctx = LocalContext.current
    val v by remember { ParentOnboarding.active(ctx) }.collectAsState()
    return v == true
}

/** GiftWelcomeView.swift `GiftWelcome`: a running gift this device has not welcomed yet. */
object GiftWelcome {
    // iOS keys by giftStartedAt (not in the Android Household model); the gift's
    // end date identifies the same gift just as well, and the flag is device-local.
    private fun key(hh: Household) = "giftWelcome.shown.${hh.id}.${(hh.giftUntil ?: hh.premiumUntil ?: 0.0).toLong()}"
    private fun prefs(ctx: Context) = ctx.applicationContext.getSharedPreferences("tofy", Context.MODE_PRIVATE)

    fun until(hh: Household?): Double? {
        if (hh == null || hh.premiumSource != "gift") return null
        val u = hh.giftUntil ?: hh.premiumUntil ?: return null
        return u.takeIf { it > nowSecs() }
    }

    /**
     * iOS holds the gift back while the new-parent flow runs (it is told at the
     * flow's end). `insideFlow` = asked by the flow itself as it ends, before it
     * clears its flag (clearing it first would take the flow off screen).
     */
    fun isDue(ctx: Context, hh: Household?, insideFlow: Boolean = false): Boolean {
        if (!insideFlow && ParentOnboarding.isActive(ctx)) return false
        if (until(hh) == null) return false
        return !prefs(ctx).getBoolean(key(hh!!), false)
    }

    fun markShown(ctx: Context, hh: Household?) {
        hh ?: return
        prefs(ctx).edit().putBoolean(key(hh), true).apply()
    }
}

/** Question.stripNiqqud — parent-side copy shows names without niqqud. */
fun plainName(s: String): String = s.filterNot { it.code in 0x0591..0x05C7 }

/**
 * The 1·2·3·4 bar (OnboardingStepsBar): the lead's OnboardingProgress plus the
 * "שלב N מתוך 4" line under it. `step` 5 = all done (no line).
 */
@Composable
fun StepsHeader(step: Int, note: String? = null) {
    Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
        OnboardingProgress(step = minOf(step, 4))
        if (step <= 4) P(if (note != null) tr("שלב %lld מתוך 4 · %@", step, note) else tr("שלב %lld מתוך 4", step), 12f, color = Color.White.copy(alpha = 0.8f), weight = FontWeight.SemiBold)
    }
}

/**
 * OnboardingFooter: the gold button at the same place on every screen of the
 * flow, and the text-link row under it always laid out (empty when none), so
 * moving between screens never moves the thumb. `title == null` keeps the
 * button's space empty (the connect screen waits on the other phone).
 */
@Composable
fun OnboardingFooter(title: String?, enabled: Boolean = true, busy: Boolean = false, link: String? = null, onLink: () -> Unit = {}, action: () -> Unit = {}) {
    Column(Modifier.fillMaxWidth().padding(bottom = 10.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
        if (title != null) GoldButton(title, enabled = enabled, busy = busy, onClick = action)
        else Spacer(Modifier.height(56.dp))
        Box(Modifier.height(22.dp), contentAlignment = Alignment.Center) {
            if (link != null) Text(
                link, Modifier.clickable(onClick = onLink), color = Color.White.copy(alpha = 0.85f), fontFamily = Rounded,
                fontWeight = FontWeight.Bold, fontSize = 14.sp, textDecoration = TextDecoration.Underline, maxLines = 1,
            )
        }
    }
}

/** The dashed "waiting…" capsule with a small spinner (OnboardingConnectView.waitingPill). */
@Composable
fun WaitingPill(text: String) {
    Row(
        Modifier.clip(RoundedCornerShape(50)).background(Color.White.copy(alpha = 0.16f))
            .border(1.dp, Color.White.copy(alpha = 0.5f), RoundedCornerShape(50)).padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        CircularProgressIndicator(Modifier.size(14.dp), color = Color.White, strokeWidth = 2.dp)
        Text(text, color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
    }
}

/** A numbered gold dot + line (OnboardingConnectView.step). */
@Composable
fun NumberedStep(n: Int, text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(9.dp), verticalAlignment = Alignment.Top) {
        Box(Modifier.size(24.dp).clip(CircleShape).background(Ink.gold2), contentAlignment = Alignment.Center) {
            Text("$n", color = Ink.deep, fontFamily = Rounded, fontWeight = FontWeight.Black, fontSize = 13.sp)
        }
        P(text, 14.5f, color = Color.White, weight = FontWeight.SemiBold)
    }
}

/**
 * QRCodeView.swift: the join link as a QR on a white card (a scanner needs the
 * contrast). ZXing → BitMatrix → a 1-px-per-module bitmap, scaled up without
 * filtering so the modules stay sharp. Shared by onboarding step ③ and the
 * dashboard's ConnectDeviceSheet.
 */
@Composable
fun JoinQRCard(text: String?, size: Dp) {
    Box(Modifier.clip(RoundedCornerShape(18.dp)).background(Color.White).padding(12.dp), contentAlignment = Alignment.Center) {
        if (text == null) {
            Box(Modifier.size(size), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = Ink.indigo) }
        } else {
            val bmp = remember(text) { qrBitmap(text) }
            Image(bmp.asImageBitmap(), null, Modifier.size(size), filterQuality = FilterQuality.None)
        }
    }
}

private fun qrBitmap(text: String): Bitmap {
    val hints = mapOf(EncodeHintType.MARGIN to 0, EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.M, EncodeHintType.CHARACTER_SET to "UTF-8")
    val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, 0, 0, hints)
    val w = m.width; val h = m.height
    val px = IntArray(w * h) { i -> if (m.get(i % w, i / w)) android.graphics.Color.BLACK else android.graphics.Color.WHITE }
    return Bitmap.createBitmap(px, w, h, Bitmap.Config.ARGB_8888)
}

/** The 6-character code under the QR, spaced like iOS's kerning(4). */
@Composable
fun CodeText(code: String, size: Int = 24) {
    Text(code, color = Color.White, fontFamily = FontFamily.Monospace, fontWeight = FontWeight.ExtraBold, fontSize = size.sp, letterSpacing = 4.sp, textAlign = TextAlign.Center)
}

package com.rani.tofy.kid.enforce

import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.graphics.drawable.toBitmap
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.rani.tofy.i18n.tr
import com.rani.tofy.kid.core.KidSession
import com.rani.tofy.ui.common.GlassButton
import com.rani.tofy.ui.common.GoldButton
import com.rani.tofy.ui.common.H
import com.rani.tofy.ui.common.P
import com.rani.tofy.ui.common.WhiteButton
import com.rani.tofy.ui.onboarding.NumberedStep
import com.rani.tofy.ui.onboarding.OnboardingFooter
import com.rani.tofy.ui.onboarding.StepsHeader
import com.rani.tofy.ui.onboarding.plainName
import com.rani.tofy.ui.theme.GlassBackdrop
import com.rani.tofy.ui.theme.Ink
import com.rani.tofy.ui.theme.Rounded
import com.rani.tofy.ui.theme.glassPane
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/*
 * 🧭 The Android twin of ChildLockSetupView (step ④ of the new-parent flow, on
 * the CHILD's device, said to the PARENT holding it — no niqqud) folded
 * together with ChildAppLockSetupView ("what stays open"):
 *
 *   ① Play's prominent disclosure (what the accessibility guard sees and doesn't)
 *   ② switch on Tofy's guard in Settings → Accessibility   (iOS: approve Screen Time)
 *   ③ usage access — recommended, skippable               (no iOS equivalent)
 *   ④ what stays open                                       (iOS openByDesignApps)
 *
 * Opened again later (from the gear, behind the parent code) it shows the
 * same pieces as one management screen, plus the parent's way into the
 * device's Settings (parent-only on a child device — see EnforcementPolicy).
 *
 * While this screen is up, Settings is allowed for 15 minutes (the parent is
 * sent there twice); finishing takes the allowance back.
 */

private enum class LockStep { DISCLOSURE, ACCESSIBILITY, USAGE, APPS, MANAGE }

/**
 * @param fromOnboarding true right after the device joins (shows the 1·2·3·4
 *        bar and walks the steps); false when reopened from the gear (manage).
 */
@Composable
fun ChildLockSetupScreen(onDone: () -> Unit, fromOnboarding: Boolean = !EnforcementStore.setupDone(LocalContext.current)) {
    val ctx = LocalContext.current
    var guardOn by remember { mutableStateOf(EnforcementStatus.isActive(ctx)) }
    var usageOn by remember { mutableStateOf(UsageAccess.isGranted(ctx)) }
    var triedSettings by remember { mutableStateOf(false) }
    var picking by remember { mutableStateOf(false) }
    var openApps by remember { mutableStateOf(EnforcementStore.openByDesign(ctx)) }
    var step by remember {
        mutableStateOf(
            when {
                !fromOnboarding -> LockStep.MANAGE
                !EnforcementStore.disclosureAccepted(ctx) -> LockStep.DISCLOSURE
                !guardOn -> LockStep.ACCESSIBILITY
                !usageOn -> LockStep.USAGE
                else -> LockStep.APPS
            }
        )
    }

    // The walk-through sends the parent to Settings — let them through. (Manage
    // mode grants it only on a tap: see openAccessibilitySettings.)
    DisposableEffect(Unit) {
        if (fromOnboarding) EnforcementStore.allowTemporarily(ctx, AllowList.settingsPackages(ctx), 15)
        onDispose { }
    }

    // Back from Settings: re-read both grants and move on by ourselves.
    val owner = LocalLifecycleOwner.current
    DisposableEffect(owner) {
        val obs = LifecycleEventObserver { _, e ->
            if (e == Lifecycle.Event.ON_RESUME) {
                guardOn = EnforcementStatus.isActive(ctx)
                usageOn = UsageAccess.isGranted(ctx)
                EnforcementStatus.refresh(ctx)
                if (step == LockStep.ACCESSIBILITY && guardOn) step = if (usageOn) LockStep.APPS else LockStep.USAGE
                else if (step == LockStep.USAGE && usageOn) step = LockStep.APPS
            }
        }
        owner.lifecycle.addObserver(obs)
        onDispose { owner.lifecycle.removeObserver(obs) }
    }

    fun finish() {
        EnforcementStore.markSetupDone(ctx)
        // The setup allowance ends here; Settings is parent-only again.
        EnforcementStore.clearTemporary(ctx)
        onDone()
    }

    BackHandler {
        when {
            picking -> picking = false
            step == LockStep.MANAGE || step == LockStep.DISCLOSURE -> finish()
            else -> Unit   // the flow's steps move forward only (iOS has no back here)
        }
    }

    if (picking) {
        AlwaysOpenAppsPicker(initial = openApps, onSave = { sel ->
            EnforcementStore.setOpenByDesign(ctx, sel)
            openApps = sel
            picking = false
        }, onClose = { picking = false })
        return
    }

    val doc by KidSession.childDoc.collectAsState()
    val name = plainName((doc?.get("name") as? String).orEmpty().trim())
    val girl = doc?.get("gender") == "girl"

    GlassBackdrop {
        Column(
            Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 22.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            if (fromOnboarding) StepsHeader(4, tr("רק הורה"))
            Column(
                Modifier.weight(1f).widthIn(max = 520.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                when (step) {
                    LockStep.DISCLOSURE -> ProminentDisclosureBody()
                    LockStep.ACCESSIBILITY -> AccessibilityBody(name, girl, triedSettings && !guardOn)
                    LockStep.USAGE -> UsageBody()
                    LockStep.APPS -> AppsBody(openApps.size) { picking = true }
                    LockStep.MANAGE -> ManageBody(guardOn, usageOn, openApps.size,
                        onGuard = { triedSettings = true; openAccessibilitySettings(ctx) },
                        onUsage = { runCatching { ctx.startActivity(UsageAccess.settingsIntent(ctx)) } },
                        onApps = { picking = true },
                        onDeviceSettings = { openDeviceSettingsForParent(ctx) })
                }
            }
            Box(Modifier.widthIn(max = 520.dp).fillMaxWidth().padding(top = 10.dp)) {
                when (step) {
                    // Never a dead end — but said for what it is (ChildLockSetupView).
                    LockStep.DISCLOSURE -> OnboardingFooter(tr("מאשרים וממשיכים"), link = tr("להמשיך בלי נעילה (לא מומלץ)"),
                        onLink = { finish() }) {
                        EnforcementStore.markDisclosureAccepted(ctx)
                        step = if (guardOn) (if (usageOn) LockStep.APPS else LockStep.USAGE) else LockStep.ACCESSIBILITY
                    }
                    LockStep.ACCESSIBILITY -> OnboardingFooter(
                        if (triedSettings && !guardOn) tr("נסו שוב") else tr("פתיחת הגדרות הנגישות"),
                        link = if (triedSettings && !guardOn) tr("להמשיך בלי נעילה (לא מומלץ)") else null,
                        onLink = { finish() },
                    ) { triedSettings = true; openAccessibilitySettings(ctx) }
                    LockStep.USAGE -> OnboardingFooter(tr("פתיחת ההגדרות"), link = tr("אעשה את זה אחר כך"),
                        onLink = { step = LockStep.APPS }) {
                        runCatching { ctx.startActivity(UsageAccess.settingsIntent(ctx)) }
                    }
                    LockStep.APPS -> OnboardingFooter(
                        when { name.isEmpty() -> tr("סיימתי"); girl -> tr("סיימתי — %@ יכולה להתחיל", name); else -> tr("סיימתי — %@ יכול להתחיל", name) },
                        link = if (openApps.isEmpty()) tr("אבחר אחר כך") else null, onLink = { finish() },
                    ) { finish() }
                    LockStep.MANAGE -> OnboardingFooter(tr("סיימתי")) { finish() }
                }
            }
        }
    }
}

// ── ① Play's prominent disclosure ──────────────────────────────────────────

/**
 * Google Play requires an in-app disclosure, BEFORE the person is sent to the
 * accessibility settings, saying what is accessed and why, with an explicit
 * "agree" action (the footer's "מאשרים וממשיכים") and a way to decline
 * ("להמשיך בלי נעילה"). Keep the words in sync with the Play Console
 * accessibility declaration and res/values/strings_enforce.xml.
 */
@Composable
fun ProminentDisclosureScreen(onAccept: () -> Unit, onDecline: () -> Unit) {
    val ctx = LocalContext.current
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 22.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally) {
            Column(Modifier.weight(1f).widthIn(max = 520.dp).fillMaxWidth().verticalScroll(rememberScrollState()).padding(top = 16.dp),
                horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
                ProminentDisclosureBody()
            }
            Box(Modifier.widthIn(max = 520.dp).fillMaxWidth().padding(top = 10.dp)) {
                OnboardingFooter(tr("מאשרים וממשיכים"), link = tr("להמשיך בלי נעילה (לא מומלץ)"), onLink = onDecline) {
                    EnforcementStore.markDisclosureAccepted(ctx); onAccept()
                }
            }
        }
    }
}

@Composable
private fun ProminentDisclosureBody() {
    Text("🛡️", fontSize = 48.sp)
    H(tr("לפני שמפעילים את הנעילה"), 26, align = TextAlign.Center)
    P(tr("כדי לנעול את שאר האפליקציות עד שהילד מרוויח זמן, טופי משתמש בשירות הנגישות של אנדרואיד."), 16f,
        color = Color.White.copy(alpha = 0.92f), weight = FontWeight.SemiBold, align = TextAlign.Center)
    Column(Modifier.fillMaxWidth().glassPane(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        P(tr("מה טופי עושה עם זה"), 15f, color = Color.White, weight = FontWeight.ExtraBold)
        Bullet("👀", tr("רואה רק איזו אפליקציה נפתחת עכשיו — כדי לדעת אם היא פתוחה או נעולה"))
        Bullet("🔒", tr("מציג את מסך הנעילה של טופי מעל אפליקציה נעולה, ומחזיר למסך הבית"))
        // Play's parental-control exception requires disclosing the uninstall guard.
        if (AllowList.GUARD_UNINSTALL) Bullet("🧷", tr("מונע מהילד למחוק אפליקציות (גם את טופי) או לשנות הגדרות בלי קוד ההורה"))
        Spacer(Modifier.height(4.dp))
        P(tr("מה טופי לא עושה"), 15f, color = Color.White, weight = FontWeight.ExtraBold)
        Bullet("🚫", tr("לא קורא את מה שכתוב על המסך, לא רואה הודעות או סיסמאות, ולא מקליד או לוחץ במקומכם"))
        Bullet("📵", tr("לא שומר ולא שולח לאף אחד את שמות האפליקציות — ההחלטה נעשית במכשיר עצמו"))
        Bullet("🔔", tr("להורים מדווחים רק אם הנעילה פועלת או כובתה"))
    }
    P(tr("אפשר לכבות את זה בכל רגע בהגדרות ← נגישות ← טופי. הגדרות המכשיר נפתחות לילד רק עם קוד ההורה."), 13.5f,
        color = Color.White.copy(alpha = 0.8f), align = TextAlign.Center)
}

@Composable
private fun Bullet(emoji: String, text: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        Text(emoji, fontSize = 17.sp)
        P(text, 14.5f, color = Color.White, weight = FontWeight.SemiBold)
    }
}

// ── ② the guard ────────────────────────────────────────────────────────────

@Composable
private fun AccessibilityBody(name: String, girl: Boolean, failed: Boolean) {
    if (name.isNotEmpty()) Pill(tr("✓ מחובר ל%@", name), mint = true)
    H(tr("מפעילים את הנעילה של טופי"), 26, align = TextAlign.Center)
    P(when { name.isEmpty() -> tr("כך טופי נועל את שאר האפליקציות עד שמרוויחים זמן")
             girl -> tr("כך טופי נועל את שאר האפליקציות עד ש%@ מרוויחה זמן", name)
             else -> tr("כך טופי נועל את שאר האפליקציות עד ש%@ מרוויח זמן", name) },
        16f, color = Color.White.copy(alpha = 0.9f), weight = FontWeight.SemiBold, align = TextAlign.Center)
    InstructionCard(tr("ייפתחו הגדרות הנגישות"), listOf(
        tr("מקישים על ״טופי״ (לפעמים תחת ״אפליקציות שהורדו״ או ״אפליקציות מותקנות״)"),
        tr("מפעילים את המתג ומאשרים"),
        tr("חוזרים לכאן"),
    ))
    if (failed) P(tr("הנעילה עוד לא פועלת — פתחו שוב את ההגדרות והפעילו את טופי."), 14f,
        color = Color(0xFFFFE28A), weight = FontWeight.Bold, align = TextAlign.Center)
}

// ── ③ usage access ─────────────────────────────────────────────────────────

@Composable
private fun UsageBody() {
    Pill(tr("✓ הנעילה פועלת"), mint = true)
    Text("📊", fontSize = 44.sp)
    H(tr("עוד הרשאה אחת (מומלץ)"), 26, align = TextAlign.Center)
    P(tr("״גישה לנתוני שימוש״ עוזרת לטופי לנעול מיד גם אחרי שהמכשיר נכבה ונדלק. טופי לא שומר ולא שולח את הנתונים האלה."),
        15f, color = Color.White.copy(alpha = 0.92f), weight = FontWeight.SemiBold, align = TextAlign.Center)
    InstructionCard(null, listOf(tr("בהגדרות שייפתחו: מקישים על ״טופי״ ומפעילים את הגישה")))
}

// ── ④ what stays open ──────────────────────────────────────────────────────

@Composable
private fun AppsBody(count: Int, onPick: () -> Unit) {
    Text("📱", fontSize = 52.sp)
    H(tr("מה נשאר פתוח?"), 28, align = TextAlign.Center)
    P(tr("כל האפליקציות במכשיר הזה יהיו נעולות עד שהילד מרוויח זמן מסך בטופי — גם אפליקציה שתותקן מחר. טופי, הטלפון ומסך הבית תמיד פתוחים. בחרו כאן מה עוד נשאר פתוח, למשל הודעות, מצלמה ושעון. אפשר לשנות בכל עת."),
        15.5f, color = Color.White.copy(alpha = 0.9f), align = TextAlign.Center)
    AppsButton(count, onPick)
}

@Composable
private fun AppsButton(count: Int, onPick: () -> Unit) =
    WhiteButton(if (count > 0) tr("%lld אפליקציות נשארות פתוחות · הקישו לעריכה", count) else tr("בחרו מה נשאר פתוח"),
        Modifier.fillMaxWidth(), height = 56.dp, onClick = onPick)

// ── manage (reopened from the gear) ────────────────────────────────────────

@Composable
private fun ManageBody(
    guardOn: Boolean, usageOn: Boolean, openCount: Int,
    onGuard: () -> Unit, onUsage: () -> Unit, onApps: () -> Unit, onDeviceSettings: () -> Unit,
) {
    Text("🛡️", fontSize = 44.sp)
    H(tr("נעילת האפליקציות"), 28, align = TextAlign.Center)
    if (guardOn) Pill(tr("✓ הנעילה פועלת"), mint = true)
    else Column(Modifier.fillMaxWidth().glassPane(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp),
        horizontalAlignment = Alignment.CenterHorizontally) {
        P(tr("הנעילה כבויה"), 16f, color = Ink.warn, weight = FontWeight.ExtraBold)
        GoldButton(tr("פתיחת הגדרות הנגישות"), onClick = onGuard)
    }
    if (guardOn && !usageOn) Column(Modifier.fillMaxWidth().glassPane(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        P(tr("הגישה לנתוני שימוש כבויה — מומלץ להפעיל"), 14.5f, color = Color.White, weight = FontWeight.Bold)
        GlassButton(tr("פתיחת ההגדרות"), Modifier.fillMaxWidth(), onClick = onUsage)
    }
    AppsButton(openCount, onApps)
    Column(Modifier.fillMaxWidth().glassPane(18.dp).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        P(tr("הגדרות המכשיר נעולות לילד, כדי שלא יוכל לכבות את טופי. צריכים אותן? פותחים לכמה דקות:"), 14f, color = Color.White)
        GlassButton(tr("פתיחת הגדרות המכשיר ל-10 דקות"), Modifier.fillMaxWidth(), onClick = onDeviceSettings)
    }
}

// ── the picker ─────────────────────────────────────────────────────────────

/**
 * "מה נשאר פתוח" — every launchable app on this device with a tick (the
 * FamilyActivityPicker of ChildAppLockSetupView, minus categories: Android has
 * none to offer). Stored locally (EnforcementStore), applied immediately.
 */
@Composable
fun AlwaysOpenAppsPicker(initial: Set<String>, onSave: (Set<String>) -> Unit, onClose: () -> Unit) {
    val ctx = LocalContext.current
    BackHandler(onBack = onClose)
    var sel by remember { mutableStateOf(initial) }
    val apps by produceState<List<AllowList.App>?>(null) {
        value = withContext(Dispatchers.IO) { AllowList.launchableApps(ctx) }
    }
    GlassBackdrop {
        Column(Modifier.fillMaxSize().systemBarsPadding().padding(horizontal = 18.dp, vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            H(tr("מה נשאר פתוח"), 24, align = TextAlign.Center)
            P(tr("טופי, הטלפון ומסך הבית תמיד פתוחים"), 13.5f, align = TextAlign.Center)
            Box(Modifier.weight(1f).widthIn(max = 520.dp).fillMaxWidth()) {
                val list = apps
                if (list == null) CircularProgressIndicator(Modifier.align(Alignment.Center), color = Color.White)
                else LazyColumn(Modifier.fillMaxSize().glassPane(20.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    items(list, key = { it.pkg }) { app ->
                        val on = app.pkg in sel
                        Row(
                            Modifier.fillMaxWidth().clickable { sel = if (on) sel - app.pkg else sel + app.pkg }
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            val bmp = remember(app.pkg) { runCatching { app.icon?.toBitmap(96, 96)?.asImageBitmap() }.getOrNull() }
                            if (bmp != null) Image(bmp, null, Modifier.size(36.dp).clip(RoundedCornerShape(9.dp)))
                            else Box(Modifier.size(36.dp).clip(RoundedCornerShape(9.dp)).background(Color.White.copy(alpha = 0.2f)))
                            Text(app.label, Modifier.weight(1f), color = Color.White, fontFamily = Rounded, fontWeight = FontWeight.Bold,
                                fontSize = 15.5.sp, maxLines = 1)
                            Box(
                                Modifier.size(26.dp).clip(CircleShape)
                                    .background(if (on) Color(0xFF2ED6A1) else Color.White.copy(alpha = 0.18f)),
                                contentAlignment = Alignment.Center,
                            ) { if (on) Text("✓", color = Color.White, fontWeight = FontWeight.Black, fontSize = 15.sp) }
                        }
                    }
                }
            }
            Box(Modifier.widthIn(max = 520.dp).fillMaxWidth()) {
                OnboardingFooter(tr("שמירה"), link = tr("סְגִירָה"), onLink = onClose) { onSave(sel) }
            }
        }
    }
}

// ── small parts + actions ──────────────────────────────────────────────────

@Composable
private fun Pill(text: String, mint: Boolean) {
    Text(text, Modifier.clip(RoundedCornerShape(50)).background(if (mint) Color(0xFF2ED6A1) else Color.White.copy(alpha = 0.16f))
        .padding(horizontal = 14.dp, vertical = 7.dp),
        color = if (mint) Color(0xFF053B26) else Color.White, fontFamily = Rounded, fontWeight = FontWeight.ExtraBold, fontSize = 14.sp)
}

/** The white card of ChildLockSetupView ("יופיע חלון של אפל") with numbered steps. */
@Composable
private fun InstructionCard(title: String?, steps: List<String>) {
    Column(Modifier.fillMaxWidth().glassPane(16.dp, 0.18f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (title != null) P(title, 16f, color = Color.White, weight = FontWeight.ExtraBold)
        if (steps.size == 1) P(steps[0], 14.5f, color = Color.White, weight = FontWeight.SemiBold)
        else steps.forEachIndexed { i, s -> NumberedStep(i + 1, s) }
    }
}

internal fun openAccessibilitySettings(ctx: Context) {
    // Settings is parent-only on a child device — this screen's allowance covers it.
    EnforcementStore.allowTemporarily(ctx, AllowList.settingsPackages(ctx), 15)
    runCatching { ctx.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

/** The parent's way into the device's Settings: 10 minutes, then parent-only again. */
fun openDeviceSettingsForParent(ctx: Context, minutes: Int = 10) {
    EnforcementStore.allowTemporarily(ctx, AllowList.settingsPackages(ctx), minutes)
    runCatching { ctx.startActivity(Intent(Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
}

